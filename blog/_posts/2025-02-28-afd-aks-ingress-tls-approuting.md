---
title: End-to-End TLS Encryption with AKS App Routing and AFD
description: Using Azure Front Door in-front of AKS App Routing Internal to provide end-to-end TLS encryption of application traffic.
authors: 
  - steve_griffith
---

# End to End TLS Encryption with AKS App Routing Internal and AFD

## Introduction

In this walkthrough we'll create deploy an app with end to end TLS encryption, using Azure Front Door as the Internet Facing TLS endpoint and AKS App Routing Ingress as the internal in-cluster ingress controller. 

We'll use Azure Key Vault to store the TLS certificate, and will use App Routing Key Vault integration to get the certificate secret into the ingress controller. 

> *Note:* We'll be walking through step by step, showing the moving parts, via the Azure CLI. If you'd like to see a full implementation of a very similar deployment using Bicep, check out the link below:

[End-to-end TLS with AKS, Azure Front Door, Azure Private Link Service, and NGINX Ingress Controller](https://learn.microsoft.com/en-us/samples/azure-samples/aks-front-door-end-to-end-tls/aks-front-door-end-to-end-tls/)

Let's get to it....

## Network Setup

First, we'll need to establish the network where our AKS cluster will be deployed. Nothing special in our network design. Just a Vnet with a single subnet for the cluster.

```bash
# Set starting environment variables
RG=E2ETLSLab
LOC=eastus2

# Create the Resource Group
az group create -g $RG -l $LOC

# Get the resource group id
RG_ID=$(az group show -g $RG -o tsv --query id)

# Set environment variables for the VNet creation
VNET_NAME=lablab-vnet
VNET_ADDRESS_SPACE=10.140.0.0/16
AKS_SUBNET_ADDRESS_SPACE=10.140.0.0/24

# Create the Vnet along with the initial subet for AKS
az network vnet create \
-g $RG \
-n $VNET_NAME \
--address-prefix $VNET_ADDRESS_SPACE \
--subnet-name aks \
--subnet-prefix $AKS_SUBNET_ADDRESS_SPACE 

# Get a subnet resource ID, which we'll need when we create the AKS cluster
VNET_SUBNET_ID=$(az network vnet subnet show -g $RG --vnet-name $VNET_NAME -n aks -o tsv --query id)
```

## Cluster Creation

Now, lets create the AKS cluster. This will be a very plain AKS cluster, for simplicity, however we will deploy to our above created subnet and will enable the following features:

- *AKS App Routing:* This will deploy managed Nginx Ingress
- *App Routing Default Nginx Controller:* This allows us to ensure that the default deployment of App Routing uses a private IP
- *Key Vault CSI Driver:* The Key Vault CSI driver will be used by App Routing to access our certificate in Azure Key Vault.

```bash
# NOTE: Make sure you give your cluster a unique name
CLUSTER_NAME=e2etlslab

# Cluster Creation Command
az aks create \
-g $RG \
-n $CLUSTER_NAME \
--node-count 2 \
--enable-app-routing \
--app-routing-default-nginx-controller Internal \
--enable-addons azure-keyvault-secrets-provider \
--vnet-subnet-id $VNET_SUBNET_ID

# Get the cluster identity
CLUSTER_IDENTITY=$(az aks show -g $RG -n $CLUSTER_NAME -o tsv --query identity.principalId)

# Get credentials
az aks get-credentials -g $RG -n $CLUSTER_NAME
```

## Create the Azure Key Vault and Upload Certificate

Now, lets create our Azure Key Vault and then create and upload our certificate.

```bash
# Create a key vault name
KEY_VAULT_NAME=e2elab$RANDOM

# Create the key vaule
az keyvault create --name $KEY_VAULT_NAME --resource-group $RG --location $LOC --enable-rbac-authorization false
```

For certificate creation, I actually took two separate paths.

- *Option 1:* Use Azure [App Service Certificates](https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-app-service-certificate?tabs=portal) to create and manage the certificate.
- *Option 2:* Use '[LetsEncrypt](https://letsencrypt.org/)' and [Certbot](https://certbot.eff.org/) to create the certificate.

Both options are totally fine, but have slight differences in approach, which I'll highlight below. If you're working in a large enterprise, you'll likely have a completely separate internal process for getting a certificate. In the end, all we care about is that we have a valid cert and key file.


### Option 1: App Service Certificates

We won't cover all the details of setting up a certificate with App Service Certificates, but you can review the doc [here](https://learn.microsoft.com/en-us/azure/app-service/configure-ssl-app-service-certificate?tabs=portal) for those steps.

When I created the certificate, I told App Svc Certs to store the cert in the Key Vault just created. We'll use the [Key Vault CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver) to mount the certificate into the ingress controller, but to do that we need to get the certficate into a format that the CSI driver can read. App Svc Certs stores the certificate in an Azure Key Vault in pfx format as a secret, but for the Key Vault CSI Driver we need it stored as a certificate. We can export the PFX from the Azure Key Vault Secret and then import it as a certificate.

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

I'm not going to get into all the specifics of using [Certbot](https://certbot.eff.org/) with [LetsEncrypt](https://letsencrypt.org/), but the basics are as follows. The domain I'll be using is my 'crashoverride.nyc' domain.

1. Get an internet reachable host capable of running a webserver on ports 80 and 443
2. Create an A-record for your target domain to the public IP of the server. This is required for hostname validation used by Certbot
3. Run the certbot command as a priviledged user on that web server host mentioned in #1 above

Here's a sample of the command I used to create a cert with two entries in the certificate Subject Alternate Names:

```bash
sudo certbot certonly --key-type rsa --standalone -d e2elab.crashoverride.nyc
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

## Configure the Ingress Options

We have App Routing enabled, but for our scenario we want to configure the internal endpoint for the Nginx Ingress deployment and ensure that private link is enabled, which we'll need for Azure Front Door to access the cluster ingress. This is enabled via the ```azure-load-balancer-internal``` and ```azure-pls-create```  annotations, which you may recognize from the standard load balancer Kubernetes service annotations. We'll also use the ```azure-pls-auto-approval``` annotation so that the private link will auto approve when we attach it to Azure Front Door.

You apply these settings via the NginxIngressController CRD. We could modify the default NginxIngressController deployed with App Routing, but instead we'll create a second instance. This will give us a new nginx ingress deployment specific to our needs. This allows you to have different ingress deployments with different options enabled.

```bash
# Get the Key Vault ID
KEYVAULT_ID=$(az keyvault show --name $KEY_VAULT_NAME --query "id" --output tsv)

# Link the Key Vault to App Routing
az aks approuting update --resource-group $RG --name $CLUSTER_NAME --enable-kv --attach-kv $KEYVAULT_ID

# Update the app routing config to enable internal
cat <<EOF | kubectl apply -f -
apiVersion: approuting.kubernetes.azure.com/v1alpha1
kind: NginxIngressController
metadata:
  name: nginx-private-link
spec:
  ingressClassName: nginx-private-link
  controllerNamePrefix: nginx-private-link
  loadBalancerAnnotations: 
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
    service.beta.kubernetes.io/azure-pls-create: "true"
    service.beta.kubernetes.io/azure-pls-auto-approval: "*"
EOF

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

Now we can deploy the ingress defintion. Look out for the following:

1. The 'tls-cert-keyvault-uri' annotation maps the inbound TLS request to the appropriate certificate secret
2. The 'rules' section maps the target host name to the backend service that should be targetted
3. The 'tls' section will include the target host name and it's mapping to the correct certificate, which we created above

```bash
# Get the URI of the certificate
CERT_URI=$(az keyvault certificate show --vault-name $KEY_VAULT_NAME --name $APP_CERT_NAME --query "id" --output tsv)
HOST_NAME="e2elab.crashoverride.nyc"

cat <<EOF|kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    kubernetes.azure.com/tls-cert-keyvault-uri: ${CERT_URI}
  name: aks-helloworld
  namespace: default
spec:
  ingressClassName: nginx-private-link
  rules:
  - host: ${HOST_NAME}
    http:
      paths:
      - backend:
          service:
            name: aks-helloworld
            port:
              number: 8080
        path: /hello-world
        pathType: Prefix
  tls:
  - hosts:
    - ${HOST_NAME}
    secretName: keyvault-aks-helloworld
EOF
```

Since we haven't set up the Azure Front Door yet, we cant access the app on the public IP yet. We can fake this out, however, with some curl magic. curl lets you call a local endpoint and pretend like you're connecting to a different host name. We'll need this for our ingress to match the hostname to the right certificate.

First we port-forward and then we'll curl with some special options.

>*Note:* If you prefer, you can also just edit your local 'hosts' file to fake out the DNS lookup. Just create an entry that maps your local loopback address (127.0.0.1) to your DNS name.

```bash
# In terminal 1, port-forward to the ingress nginx service name
kubectl port-forward svc/nginx-private-link-0 -n app-routing-system 8443:443

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

Now that the backend is working, lets wire up the Azure Front Door. Azure Front door will need to access our Key Vault to retrieve the certificate, so first we'll create a managed identity and grant it rights on the Key Vault, and then we'll assign that identity to the Front Door on creation.

```bash
# Create the managed identity
az identity create --name afd-identity --resource-group $RG --location $LOC

# Get identity client ID
export USER_ASSIGNED_CLIENT_ID=$(az identity show --resource-group $RG --name afd-identity --query 'clientId' -o tsv)
export USER_ASSIGNED_RESOURCE_ID=$(az identity show --resource-group $RG --name afd-identity --query 'id' -o tsv)

# Set the key vault access rights for the afd managed identity
az keyvault set-policy --name $KEY_VAULT_NAME -g $RG --secret-permissions get --spn "${USER_ASSIGNED_CLIENT_ID}"

# Create the Azure Front Door
az afd profile create \
--profile-name e2elab \
--resource-group $RG \
--identity-type UserAssigned \
--user-assigned-identities $USER_ASSIGNED_RESOURCE_ID \
--sku Premium_AzureFrontDoor 
```

We'll do the rest in our Azure Front Door instance in the Azure Portal, so open a browser to [https://portal.azure.com](https://portal.azure.com) and then navigate to your resource group and then your Azure Front Door Instance.

### Link the certificate to the AFD.

To use our certificate with Azure Front Door, we need to attach the certificate in Azure Key Vault to an Front Door Secret. We do this in the 'Secrets' pane under 'Security'.

![link certificate](/AKS/assets/images/aks-ingress-tls-approuting/linkcert.jpg)

### Create the Custom Domain Configuration

Now we tell AFD what domain we'd like to use and link that domain name to the associated secret that we just created for our certificate.

![afd add domain 1](/AKS/assets/images/aks-ingress-tls-approuting/afd-adddomain1.jpg)

Next we select the appropriate secret for our domain.

![afd add domain 2](/AKS/assets/images/aks-ingress-tls-approuting/afd-adddomain2.jpg)

Finally, we see the domain entry created and pending association with an endpoint.

![afd add domain 3](/AKS/assets/images/aks-ingress-tls-approuting/afd-adddomain3.jpg)


### Create the Origin Group

Front Door is acting as the entry point to our backend, which is referred to as the 'Origin'.

Creating the origin group is a two step process. You create the origin group, but as part of that you also add the origin hostname configuration. As part of that origin hostname setup you will check the 'Enable Private Link Service' option, which will allow you to select the private link that was automatically created by AKS for your ingress-nginx deployment. This is why the service annotations where so important when you deployed ingress-nginx.

You'll provide a message that will show up on the private link approval side. This message can be whatever you want.

![origin setup 1](/AKS/assets/images/aks-ingress-tls-approuting/origin-setup1.jpg)

Now we complete our origin setup, making sure to set the right path to our ingress health probe. In our case, the URL will forward to '/hello-world', as we know this will return an HTTP 200 response. If you have your own health endpoint, you can set that here. You'll also want to set the protocol to HTTPS. This will tell Azure Front Door that it should re-encrypt traffic when sending it to the backend.

![origin setup 2](/AKS/assets/images/aks-ingress-tls-approuting/origin-setup2.jpg)

Now we see that our origin is created, but still pending association with an endpoint.

![origin setup 3](/AKS/assets/images/aks-ingress-tls-approuting/origin-setup3.jpg)

### Create the AFD Endpoint

In 'Front Door manager' select 'Add an endpoint' and give the endpoint a name. Make note of the FQDN is provides. This will be used in our DNS for the CNAME.

![add an endpoint 1](/AKS/assets/images/aks-ingress-tls-approuting/addendpoint1.jpg)

Now we'll add a route by clicking 'Add a route'.

![add an endpoint 2](/AKS/assets/images/aks-ingress-tls-approuting/addendpoint2.jpg)

In the 'add route' screen, we'll select our origin and the associated domain, and set any additional options. At this point, you should also make note of the endpoint FQDN, which we'll need to use as our CNAME in our DNS for our host name.

![add an endpoint 3](/AKS/assets/images/aks-ingress-tls-approuting/addendpoint3.jpg)

![add an endpoint 4](/AKS/assets/images/aks-ingress-tls-approuting/addendpoint4.jpg)

When finished, your endpoint should look as follows.

![add an endpoint 5](/AKS/assets/images/aks-ingress-tls-approuting/addendpoint5.jpg)

### Update your DNS

We need our DNS name to point to the Azure Front Door endpoint, so we'll take that Front Door provided FQDN and create a CNAME record. 

![dns cname entry](/AKS/assets/images/aks-ingress-tls-approuting/dnscname.jpg)

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
