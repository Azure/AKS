---
title: End to End TLS Encryption with AKS and AFD
description: Using Azure Front Door in-front of an in-cluster nginx ingress controller to provide end-to-end TLS encryption of application traffic.
authors: 
  - steve_griffith

title: "End to End TLS Encryption with AKS and AFD"
description: "Using Azure Front Door in-front of an in-cluster nginx ingress controller to provide end-to-end TLS encryption of application traffic."
date: 2025-02-05
author: Steve Griffith 
categories:
- networking
- operations
- add-ons
tags:
- istio 
- gateway-api
---

# End to End TLS Encryption with AKS and AFD

## Introduction

In this walkthrough we'll create deploy an app with end to end TLS encryption, using Azure Front Door as the Internet Facing TLS endpoint and an Nginx Ingress controller running inside an AKS cluster as the backend. 

We'll use Azure Key Vault to store the TLS certificate, and will use the Key Vault CSI Driver to get the secrets into the ingress controller. The Key Vault CSI Driver will use Azure Workload Identity to safely retrieve the certificate.

Let's get to it....

## Network Setup

First, we'll need to establish the network where our AKS cluster will be deployed. Nothing special in our network design, other than the fact that I'm creating an Azure Network Security Group at the subnet level for added security.

```bash
# Resource Group Creation
RG=E2ETLSLab
LOC=eastus2

# Create the Resource Group
az group create -g $RG -l $LOC

# Get the resource group id
RG_ID=$(az group show -g $RG -o tsv --query id)

# Set an environment variable for the VNet name
VNET_NAME=lablab-vnet
VNET_ADDRESS_SPACE=10.140.0.0/16
AKS_SUBNET_ADDRESS_SPACE=10.140.0.0/24

# Create an NSG at the subnet level for security reasons
az network nsg create \
--resource-group $RG \
--name aks-subnet-nsg

# Get the NSG ID
NSG_ID=$(az network nsg show -g $RG -n aks-subnet-nsg -o tsv --query id)

# Create the Vnet along with the initial subet for AKS
az network vnet create \
-g $RG \
-n $VNET_NAME \
--address-prefix $VNET_ADDRESS_SPACE \
--subnet-name aks \
--subnet-prefix $AKS_SUBNET_ADDRESS_SPACE \
--network-security-group aks-subnet-nsg

# Get a subnet resource ID, which we'll need when we create the AKS cluster
VNET_SUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME -n aks -o tsv --query id)
```

## Cluster Creation

Now, lets create the AKS cluster where our workload and ingress controller will reside. This will be a very plain AKS cluster, however we will deploy to our above created subnet and will enable the following features:

- *Workload Identity:* This will be used by the Key Vault CSI Driver to retrieve the cluster certificate
- *OIDC Issuer:* This is required by Workload Identity to be used during service account fedration
- *Key Vault CSI Driver:* This will be used to retrieve the cluster certificate

> *Note:* Since I created a NSG at the subnet level, I'll need to create a custom role which will be used later for automated private link creation. If you don't have an NSG on the subnet, and just rely on the managed NSG that AKS owns, then you don't need to create the custom role documented below. 

```bash
# NOTE: Make sure you give your cluster a unique name
CLUSTER_NAME=e2etlslab

# Cluster Creation Command
az aks create \
-g $RG \
-n $CLUSTER_NAME \
--node-count 2 \
--enable-oidc-issuer \
--enable-workload-identity \
--enable-addons azure-keyvault-secrets-provider \
--vnet-subnet-id $VNET_SUBNET_ID

# Get the cluster identity
CLUSTER_IDENTITY=$(az aks show -g $RG -n $CLUSTER_NAME -o tsv --query identity.principalId)

###################################################################################################
# Grant the cluster identity rights on the cluster nsg, which we'll need later when we create the
# private link.

# NOTE: These steps are only needed if you have a custom NSG on the cluster subnet.

# Create the role definition file
cat << EOF > pl-nsg-role.json
{
    "Name": "Private Link AKS Role",
    "Description": "Grants the cluster rights on the NSG for Private Link Creation",
    "Actions": [
        "Microsoft.Network/networkSecurityGroups/join/action"
    ],
    "NotActions": [],
    "DataActions": [],
    "NotDataActions": [],
    "assignableScopes": [
        "${RG_ID}"
    ]
}
EOF

# Create the role definition in Azure
az role definition create --role-definition @pl-nsg-role.json

# Assign the role
# NOTE: New role propagation may take a minute or to, so retry as needed
az role assignment create \
--role "Private Link AKS Role" \
--assignee $CLUSTER_IDENTITY \
--scope $NSG_ID
###################################################################################################


# Get credentials
az aks get-credentials -g $RG -n $CLUSTER_NAME
```

## Setup Workload Identity

Now that we have our cluster, lets finish setting up the workload identity that will be used to retrieve our certificate from Azure Key Vault.

>*Note:* For simplicity, I'm keeping all resources in the 'default' namespace. You may want to modify this for your own deployment.

```bash
# Set the namespace where we will deploy our app and ingress controller
NAMESPACE=default

# Get the OIDC Issuer URL
export AKS_OIDC_ISSUER="$(az aks show -n $CLUSTER_NAME -g $RG --query "oidcIssuerProfile.issuerUrl" -otsv)"

# Get the Tenant ID for later
export IDENTITY_TENANT=$(az account show -o tsv --query tenantId)

# Create the managed identity
az identity create --name nginx-ingress-identity --resource-group $RG --location $LOC

# Get identity client ID
export USER_ASSIGNED_CLIENT_ID=$(az identity show --resource-group $RG --name nginx-ingress-identity --query 'clientId' -o tsv)

# Create a service account to federate with the managed identity
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    azure.workload.identity/client-id: ${USER_ASSIGNED_CLIENT_ID}
  labels:
    azure.workload.identity/use: "true"
  name: nginx-ingress-sa
  namespace: ${NAMESPACE}
EOF

# Federate the identity
az identity federated-credential create \
--name nginx-ingress-federated-id \
--identity-name nginx-ingress-identity \
--resource-group $RG \
--issuer ${AKS_OIDC_ISSUER} \
--subject system:serviceaccount:${NAMESPACE}:nginx-ingress-sa
```

## Create the Azure Key Vault and Upload Certificate

Now, lets create our Azure Key Vault and then create and upload our certificate.

```bash
# Create a key vault name
KEY_VAULT_NAME=e2elab$RANDOM

# Create the key value
az keyvault create --name $KEY_VAULT_NAME --resource-group $RG --location $LOC --enable-rbac-authorization false

# Grant access to the secret for the managed identity
az keyvault set-policy --name $KEY_VAULT_NAME -g $RG --certificate-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"
az keyvault set-policy --name $KEY_VAULT_NAME -g $RG --secret-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"
```

For certificate creation, I actually took two separate paths.

- *Option 1:* Use Azure [App Service Certificates](https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-app-service-certificate?tabs=portal) to create and manage the certificate.
- *Option 2:* Use '[LetsEncrypt](https://letsencrypt.org/)' and [Certbot](https://certbot.eff.org/) to create the certificate.

Both options are totally fine, but have slight differences in approach, which I'll highlight below. If you're working in a large enterprise, you'll likely have a completely separate internal process for getting a certificate. In the end, all we care about is that we have a valid cert and key file.


### Option 1: App Service Certificates

We won't cover all the details of setting up a certificate with App Service Certificates, but you can review the doc [here](https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-app-service-certificate?tabs=portal) for those steps.

When I created the certificate, I told App Svc Certs to store the cert in the Key Vault just created. We'll use the [Key Vault CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver) to mount the certificate into the ingress controller, but to do that we need to get the certificate into a format that the CSI driver can read. App Svc Certs stores the certificate in an Azure Key Vault in pfx format as a secret, but for the Key Vault CSI Driver we need it stored as a certificate. We can export the PFX from the Azure Key Vault Secret and then import it as a certificate.

```bash
APP_CERT_NAME=e2elab

# Get the secret name for the certificate in key vault
SECRET_NAME=$(az resource show --resource-group $RG --resource-type "Microsoft.CertificateRegistration/certificateOrders" --name $APP_CERT_NAME --query "properties.certificates.$APP_CERT_NAME.keyVaultSecretName" --output tsv)

# Download the certificate 
az keyvault secret download --file $APP_CERT_NAME.pfx --vault-name $KEY_VAULT_NAME --name $SECRET_NAME --encoding base64

# Import the certificate
az keyvault certificate import --vault-name $KEY_VAULT_NAME --name $APP_CERT_NAME --file $APP_CERT_NAME.pfx
```

### Option 2: LetsEncrypt/CertBot

I'm not going to get into all the specifics of using Certbot with LetsEncrypt, but the basic are as follows. The domain I'll be using is my 'crashoverride.nyc' domain.

1. Get an internet reachable host capable of running a webserver on ports 80 and 443
2. Create an A-record for your target domain to the public IP of the server. This is required for hostname validation used by Certbot
3. Run the certbot command as a privileged user on that web server host mentioned in #1 above

Here's a sample of the command I used to create a cert with two entries in the certificate Subject Alternate Names:

```bash
sudo certbot certonly --key-type rsa --standalone -d e2elab.crashoverride.nyc -d www.crashoverride.nyc
```

Certbot creates several files, all with the PEM file extension. This is misleading, as fullchain.pem is the 'crt' file and the privkey.pem is the 'key' file. To store these in Azure Key Vault as certs we'll need to package these files up in a PFX format.

```bash
APP_CERT_NAME=crashoverride

# export to pfx
# skipping the Password prompt
openssl pkcs12 -export -passout pass: -in fullchain.pem -inkey privkey.pem  -out ${APP_CERT_NAME}.pfx

# Import the certificate
az keyvault certificate import --vault-name $KEY_VAULT_NAME --name $APP_CERT_NAME --file $APP_CERT_NAME.pfx
```

## Set up the Key Vault CSI Secret Provider Class

Great! Now we have our network, cluster, key vault and secrets ready to go. We can now create our SecretProviderClass, which is the link between our Kubernetes resources and the secret in Azure Key Vault. We'll actually use this SecretProviderClass to mount the certificate into our ingress controller.

>*Note:* The Key Vault CSI driver uses the Kubernetes Container Storage Interface to initiate it's connection to Key Vault. That means, even though we really only care about having the certificate as a Kubernetes secret for use in our ingress definition, we still need to mount the secret as a volume to create the Kubernetes Secret. We'll mount the certificate secret to the ingress controller, but you could mount it to your app alternatively, especially if you plan to use the certificate in your app directly as well.

When you create a certificate in Azure Key Vault and then use the Key Vault CSI driver to access that certificate, you use the 'secret' object type and the certificate name. The returned secret contains the certificate key and crt file using the names tls.key and tls.crt. 

```bash
# We'll cat the SecretProviderClass directly into kubectl
# You could also just cat it out to a file and use that file to deploy
cat << EOF | kubectl apply -f -
apiVersion: secrets-store.csi.x-k8s.io/v1
kind: SecretProviderClass
metadata:
  name: crashoverride-tls
  namespace: ${NAMESPACE}
spec:
  provider: azure
  secretObjects:                            # secretObjects defines the desired state of synced K8s secret objects
    - secretName: crashoverride-tls-csi
      type: kubernetes.io/tls
      data: 
        - objectName: crashoverride
          key: crashoverride.key
        - objectName: crashoverride
          key: crashoverride.crt
  parameters:
    usePodIdentity: "false"
    clientID: ${USER_ASSIGNED_CLIENT_ID}
    keyvaultName: ${KEY_VAULT_NAME}                 # the name of the AKV instance
    objects: |
      array:
        - |
          objectName: crashoverride
          objectType: secret
    tenantId: ${IDENTITY_TENANT}                    # the tenant ID of the AKV instance
EOF
```

## Deploy the Ingress Controller

Now we're ready to create our ingress controller. For our purposes, and for it's simplicity, we're going to use ingress-nginx. The approach will be roughly the same for any ingress controller.

There are a few key points to note in the deployment below.

1. We want our ingress controller to be on an internal network with no public IP, since Azure Front Door will provide the public endpoint. To do that we'll need to apply the 'azure-load-balancer-internal' annotation.
2. Azure Front Door can only connect to a private IP address using an Azure Private Link Service. Fortunately, AKS provides the 'azure-pls-create' annotation which will automatically create and manage a private link for you.
3. As mentioned above, since we're using the Key Vault CSI Driver, we need to mount the Secret Provider Class using the secret-store driver. 

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Generate the values file we'll use to deploy ingress-nginx
cat <<EOF > nginx-ingress-values.yaml
serviceAccount:
  create: false
  name: nginx-ingress-sa
controller:
  replicaCount: 2
  service:
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
      service.beta.kubernetes.io/azure-load-balancer-internal: "true"
      service.beta.kubernetes.io/azure-pls-create: "true"
  extraVolumes:
      - name: crashoverride-secret-store
        csi:
          driver: secrets-store.csi.k8s.io
          readOnly: true
          volumeAttributes:
            secretProviderClass: "crashoverride-tls"            
  extraVolumeMounts:
      - name: crashoverride-secret-store
        mountPath: "/mnt/crashoverride"
        readOnly: true        
EOF

# Deploy ingress-nginx
helm install e2elab-ic ingress-nginx/ingress-nginx \
    --namespace $NAMESPACE \
    -f nginx-ingress-values.yaml
```

## Deploy a Sample App

We'll need a sample app to test our configuration. I personally like the '[echoserver](https://github.com/cilium/echoserver)' app from the cilium team. It's nice, as it returns the HTTP headers as the web response, which can be very useful in http request testing.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: aks-helloworld 
spec:
  replicas: 1
  selector:
    matchLabels:
      app: aks-helloworld
  template:
    metadata:
      labels:
        app: aks-helloworld
    spec:
      containers:
      - name: aks-helloworld
        image: cilium/echoserver
        ports:
        - containerPort: 8080
        env:
        - name: PORT
          value: '8080'
---
apiVersion: v1
kind: Service
metadata:
  name: aks-helloworld
spec:
  type: ClusterIP
  ports:
  - port: 8080
  selector:
    app: aks-helloworld
EOF
```

Now we can deploy the ingress definition. Look out for the following:

1. The 'tls' section maps the inbound TLS request to the appropriate certificate secret
2. The 'rules' section maps the targeted host name to the backend service that should be targetted

```bash
cat <<EOF|kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: crashoverride-ingress-tls
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$1
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - e2elab.crashoverride.nyc
    secretName: crashoverride-tls-csi 
  rules:
  - host: e2elab.crashoverride.nyc
    http:
      paths:
      - path: /hello-world
        pathType: Prefix
        backend:
          service:
            name: aks-helloworld
            port:
              number: 8080
EOF
```

Since we haven't set up the Azure Front Door yet, we can't access the app on the public IP yet. We can fake this out, however, with some curl magic. curl lets you call a local endpoint and pretend like you're connecting to a different host name. We'll need this for our ingress certificate to work.

First we port-forward and then we'll curl with some special options.

>*Note:* If you prefer, you can also just edit your local 'hosts' file to fake out the DNS lookup. Just create an entry that maps your local loopback address (127.0.0.1) to your DNS name.

```bash
# In terminal 1, port-forward to the ingress nginx service name
kubectl port-forward svc/e2elab-ic-ingress-nginx-controller 8443:443

# In terminal 2 run a curl like the following, changing out for your host name
curl -v https://e2elab.crashoverride.nyc/hello-world --connect-to e2elab.crashoverride.nyc:443:127.0.0.1:8443
```

You should have seen a successful TLS handshake with your certificate and proper hostname.

```bash
# Example
* Server certificate:
*  subject: CN=e2elab.crashoverride.nyc
*  start date: Oct 31 16:35:44 2024 GMT
*  expire date: Jan 29 16:35:43 2025 GMT
*  subjectAltName: host "e2elab.crashoverride.nyc" matched cert's "e2elab.crashoverride.nyc"
*  issuer: C=US; O=Let's Encrypt; CN=R10
*  SSL certificate verify ok.
```


## Create the Azure Front Door

Now that the backend is working, lets wire up the Azure Front Door.

```bash
# Create the Azure Front Door
az afd profile create \
--profile-name e2elab \
--resource-group $RG \
--sku Premium_AzureFrontDoor
```

We'll do the rest in the Azure Portal, so open a browser to [https://portal.azure.com](https://portal.azure.com).

### Link the certificate to the AFD.

To use our certificate with Azure Front Door, we need to attach the certificate in Azure Key Vault to an Front Door Secret. We do this in the 'Secrets' pane under 'Security'.

![link certificate](/AKS/assets/images/afd-aks-ingress-tls/linkcert.jpg)

### Create the Custom Domain Configuration

Now we tell AFD what domain we'd like to use and link that domain name to the associated secret that we just created for our certificate.

![afd add domain 1](/AKS/assets/images/afd-aks-ingress-tls/afd-adddomain1.jpg)

Next we select the appropriate secret for our domain.

![afd add domain 2](/AKS/assets/images/afd-aks-ingress-tls/afd-adddomain2.jpg)

Finally, we see the domain entry created and pending association with an endpoint.

![afd add domain 3](/AKS/assets/images/afd-aks-ingress-tls/afd-adddomain3.jpg)


### Create the Origin Group

Front Door is acting as the entry point to our backend, which is referred to as the 'Origin'.

Creating the origin group is a two step process. You create the origin group, but as part of that you also add the origin hostname configuration. As part of that origin hostname setup you will check the 'Enable Private Link Service' option, which will allow you to select the private link that was automatically created by AKS for your ingress-nginx deployment. This is why the service annotation was so important when you deployed ingress-nginx.

You'll provide a message that will show up on the private link approval side. This message can be whatever you want.

![origin setup 1](/AKS/assets/images/afd-aks-ingress-tls/origin-setup1.jpg)

Now we complete our origin setup, making sure to set the right path to our ingress health probe. In our case, the URL will forward to '/hello-world', as we know this will return an HTTP 200 response. If you have your own health endpoint, you can set that here.

![origin setup 2](/AKS/assets/images/afd-aks-ingress-tls/origin-setup2.jpg)

Now we see that our origin is created, but still pending association with an endpoint.

![origin setup 3](/AKS/assets/images/afd-aks-ingress-tls/origin-setup3.jpg)

### Create the AFD Endpoint

In 'Front Door manager' select 'Add an endpoint' and give the endpoint a name. Make note of the FQDN is provides. This will be used in our DNS for the CNAME.

![add an endpoint 1](/AKS/assets/images/afd-aks-ingress-tls/addendpoint1.jpg)

Now we'll add a route by clicking 'Add a route'.

![add an endpoint 2](/AKS/assets/images/afd-aks-ingress-tls/addendpoint2.jpg)

In the 'add route' screen, we'll select our origin and the associated domain, and set any additional options. At this point, you should also make note of the endpoint FQDN, which we'll need to use as our CNAME in our DNS for our host name.

![add an endpoint 3](/AKS/assets/images/afd-aks-ingress-tls/addendpoint3.jpg)

![add an endpoint 4](/AKS/assets/images/afd-aks-ingress-tls/addendpoint4.jpg)

When finished, your endpoint should look as follows.

![add an endpoint 5](/AKS/assets/images/afd-aks-ingress-tls/addendpoint5.jpg)

### Update your DNS

We need our DNS name to point to the Azure Front Door endpoint, so we'll take that Front Door provided FQDN and create a CNAME record. 

![dns cname entry](/AKS/assets/images/afd-aks-ingress-tls/dnscname.jpg)

### Approve the Private Link request

Ok, so we associated the Azure Front Door origin with our private link, but we never approved the private link association request. To do that, we'll need to go to the AKS managed cluster (MC_) resource group. Lets get that resource group name and then go approve the request.

```bash
# Get the managed cluster resource group name
AKS_CLUSTER_MC_RG=$(az aks show -g $RG -n $CLUSTER_NAME -o tsv --query nodeResourceGroup)
```

Back in the Azure Portal, navigate to the Managed Cluster Resource Group and find the private link.

![approve private link 1](/AKS/assets/images/afd-aks-ingress-tls/approvepl1.jpg)

Click on the 'Private endpoint connections' where you should see a pending request.

![approve private link 2](/AKS/assets/images/afd-aks-ingress-tls/approvepl2.jpg)

Select the private link and click 'Approve'.

![approve private link 3](/AKS/assets/images/afd-aks-ingress-tls/approvepl3.jpg)

You'll see a dialog box with the message you sent when creating the origin connection.

![approve private link 4](/AKS/assets/images/afd-aks-ingress-tls/approvepl4.jpg)

## Test

You should now be able to open a browser and navigate to your URL. You can also test with curl.

```bash
curl https://e2elab.crashoverride.nyc/hello-world

##########################################
# Sample Output
##########################################
Hostname: aks-helloworld-fbdf59bf-qtdks

Pod Information:
	-no pod information available-

Server values:
	server_version=nginx: 1.13.3 - lua: 10008

Request Information:
	client_address=
	method=GET
	real path=/
	query=
	request_version=1.1
	request_scheme=http
	request_uri=http://e2elab.crashoverride.nyc:8080/

Request Headers:
	accept=*/*
	host=e2elab.crashoverride.nyc
	user-agent=curl/8.7.1
	via=HTTP/2.0 Azure
	x-azure-clientip=70.18.42.220
	x-azure-fdid=c7e0d3e0-830a-4770-acae-14d27c7726f8
	x-azure-ref=
	x-azure-requestchainv2=hops=2
	x-azure-socketip=
	x-forwarded-for=10.140.0.5
	x-forwarded-host=e2elab.crashoverride.nyc
	x-forwarded-port=443
	x-forwarded-proto=https
	x-forwarded-scheme=https
	x-original-forwarded-for=
	x-real-ip=10.140.0.5
	x-request-id=8f41e792d8f0f74e90ddca9d14ba896b
	x-scheme=https

Request Body:
	-no body in request-
```

## Conclusion

 Congrats! You should now have a working Azure Front Door directing TLS secured traffic to an in cluster ingress controller!

 >*Note:* In this walk through we did not add encryption between the ingress controller and the backend deployment. This can be done by sharing the same, or different, certificate to the deployment pods. You then enable backend encryption on the ingress controller. Alternatively, you could use a service mesh between the ingress and the backend deployment.
