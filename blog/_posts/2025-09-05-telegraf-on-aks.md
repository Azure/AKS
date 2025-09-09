---
title: "Collecting Custom Metrics on AKS with Telegraf"
description: "How to deploy a Telegraf DaemonSet on AKS to collect custom metrics, expose them as Prometheus me## Deploying the solution

We'll deploy a modular set of Kubernetes manifests that contains:cs, and integrate with Azure Managed Prometheus and Grafana for full observability."
date: 2025-09-12
author: Diego Casati
categories:
- operations
- observability
tags:
- telegraf
- grafana
- prometheus
---

## Overview

What if you needed to collect **your own custom metrics** from workloads or nodes in AKS but didn’t want to run a full monitoring sIn this post, we saw an approach on how to integrate custom metrics into Azure's managed monitoring stack with minimal setup using `Telegraf DaemonSet`, for flexible metric collection, `Azure Managed Prometheus`, for scraping and storage, and `Azure Managed Grafana` for visualization and alerting.

While our example used network metrics, the same pattern applies to any custom data source you want to monitor in AKS. If you want to take this example one step further, we have a hands-on experience with the [AKS Labs: Advanced Observability Concepts](https://azure-samples.github.io/aks-labs/docs/operations/observability-and-monitoring) and the [Observability with Managed Prometheus and Managed Grafana at the Microsoft Reactor](https://www.youtube.com/watch?v=Dc0TqbAkQX0).k yourself?

A common question we hear from Kubernetes users is:

**"How can I scrape a specific set of custom metrics from my cluster without adding too much operational overhead?"**

If you're running Azure Kubernetes Service (AKS), the good news is that you can do exactly that with a lightweight, extensible solution:
**Telegraf + Azure Managed Prometheus + Azure Managed Grafana**.

In this post, we'll deploy a **Telegraf DaemonSet** to collect a set of **custom metrics**—in our example, we’ll use *per-interface network statistics*, but the same pattern applies to **any metric source you want**. We’ll expose these metrics in **Prometheus format** and visualize them in **Azure Managed Grafana** — all with minimal setup.

## Why This Matters

The example in this post uses **network metrics**, but you could just as easily collect:

- Application-specific counters from logs or APIs
- System-level metrics like disk I/O, custom scripts, or container stats
- Business metrics from in-cluster services

This approach gives you:

- **Cloud-native integration** with Azure Managed Prometheus
- **Scalable collection** with Kubernetes DaemonSets
- **Zero extra infrastructure** for scraping or visualization

## Solution at a Glance

Here’s the workflow we’re setting up:

```
+-----------------+    +------------------+    +-----------------+ 
|   AKS Nodes     |    |  Azure Managed   |    |  Azure Managed  | 
|                 |    |   Prometheus     |    |    Grafana      | 
| +-------------+ |    |                  |    |                 | 
| |  Telegraf   | |--->|  Scrapes via     |--->|  Dashboards &   | 
| | DaemonSet   | |    |  PodMonitor      |    |  Alerting       | 
| |:2112/metrics| |    |                  |    |                 | 
| +-------------+ |    +------------------+    +-----------------+ 
+-----------------+                                                
```

- **Telegraf DaemonSet**: runs on every node and collects *your* custom metrics.
- **Prometheus PodMonitor**: automatically scrapes those metrics endpoints.
- **Azure Managed Grafana**: visualizes and alerts on metrics without extra servers.

## Understanding the solution

For our example, we will create a custom collection of the following metrics for each network interface using `ip -s link`:

| Metric | Type | Description |
|--------|------|-------------|
| `network_interface_stats_mtu` | gauge | Maximum Transmission Unit |
| `network_interface_stats_rx_bytes` | counter | Received bytes |
| `network_interface_stats_rx_packets` | counter | Received packets |
| `network_interface_stats_rx_errors` | counter | Receive errors |
| `network_interface_stats_rx_dropped` | counter | Received packets dropped |
| `network_interface_stats_rx_missed` | counter | Received packets missed (true missed field from ip -s link) |
| `network_interface_stats_rx_multicast` | counter | Received multicast packets |
| `network_interface_stats_tx_bytes` | counter | Transmitted bytes |
| `network_interface_stats_tx_packets` | counter | Transmitted packets |
| `network_interface_stats_tx_errors` | counter | Transmission errors |
| `network_interface_stats_tx_dropped` | counter | Transmitted packets dropped |
| `network_interface_stats_tx_carrier` | counter | Carrier errors |
| `network_interface_stats_tx_collisions` | counter | Collision errors |

Each metric includes the following labels:

- `cluster`: AKS cluster identifier
- `environment`: Environment tag (configurable)
- `host`: Node hostname
- `hostname`: Node hostname (duplicate for compatibility)
- `interface`: Network interface name (eth0, eth1, etc.)
- `state`: Interface operational state

## Setup your environment variables and placeholders

In these next steps, we will set up a new AKS cluster, an Azure Managed Grafana instance, and an Azure Monitor Workspace.

```bash
export RG_NAME="rg-telegraf-on-aks"
export LOCATION="westus3"

# Azure Kubernetes Service Cluster
export AKS_CLUSTER_NAME="telegraf-on-aks"

# Azure Managed Grafana
export GRAFANA_NAME="aks-blog-${RANDOM}"

# Azure Monitor Workspace
export AZ_MONITOR_WORKSPACE_NAME="telegraf-on-aks"
```

Next, let's create our solution:

```bash
# Create resource group
az group create --name ${RG_NAME} --location ${LOCATION}

# Create an Azure Monitor Workspace
az monitor account create \
  --resource-group ${RG_NAME} \
  --location ${LOCATION} \
  --name ${AZ_MONITOR_WORKSPACE_NAME}

# Get the Azure Monitor Workspace ID
AZ_MONITOR_WORKSPACE_ID=$(az monitor account show \
  --resource-group ${RG_NAME} \
  --name ${AZ_MONITOR_WORKSPACE_NAME} \
  --query id -o tsv)
```

Create a Grafana instance. The Azure CLI extension for Azure Managed Grafana (amg) will be used for this. 

```bash
# Add the Azure Managed Grafana extension to az cli:
az extension add --name amg

# Create an Azure Managed Grafana instance:
az grafana create \
  --name ${GRAFANA_NAME} \
  --resource-group $RG_NAME \
  --location $LOCATION

# Once created, save the Grafana resource ID
GRAFANA_RESOURCE_ID=$(az grafana show \
  --name ${GRAFANA_NAME} \
  --resource-group ${RG_NAME} \
  --query id -o tsv)
```

We can now create the cluster, passing both the 'grafana-resource-id' and 'azure-monitor-workspace-resource-id' during cluster creation:

```bash
# Create the AKS cluster
az aks create \
  --name ${AKS_CLUSTER_NAME}  \
  --resource-group ${RG_NAME} \
  --node-count 1 \
  --enable-managed-identity  \
  --enable-azure-monitor-metrics \
  --grafana-resource-id ${GRAFANA_RESOURCE_ID} \
  --azure-monitor-workspace-resource-id ${AZ_MONITOR_WORKSPACE_ID}

# Get the cluster credentials
az aks get-credentials \
  --name ${AKS_CLUSTER_NAME} \
  --resource-group ${RG_NAME}
```

Verify that the PodMonitor CRD is now available in your cluster

```bash
# Check if PodMonitor CRD exists
kubectl get crd | grep podmonitor

# Expected output (Azure Managed Prometheus):
# podmonitors.azmonitoring.coreos.com                  2025-07-23T19:12:02Z
```

## Deploying the solution

We’ll deploy a single YAML manifest that contains:

- `ConfigMap` for Telegraf config + your custom metric script (`parse_ip_stats.sh`)
- `DaemonSet` to run Telegraf on each node
- `ServiceAccount`, `Service`, and `PodMonitor`

### Step 1: Create the Telegraf Configuration

First, let's create the main Telegraf configuration:

```bash
cat <<EOF > 01-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: telegraf-config
  namespace: default
data:
  telegraf.conf: |
    [global_tags]
      environment = "aks"
      cluster = "aks-telegraf"

    [agent]
      interval = "30s"
      round_interval = true
      metric_batch_size = 1000
      metric_buffer_limit = 10000
      collection_jitter = "5s"
      flush_interval = "30s"
      flush_jitter = "5s"
      precision = ""
      hostname = "\$HOSTNAME"
      omit_hostname = false

    # Custom script to parse ip -s link output
    [[inputs.exec]]
      commands = ["/usr/local/bin/parse_ip_stats.sh"]
      timeout = "10s"
      data_format = "influx"
      name_override = "network_interface_stats"

    # Prometheus metrics output
    [[outputs.prometheus_client]]
      listen = ":2112"
      metric_version = 2
      path = "/metrics"
      expiration_interval = "60s"
      collectors_exclude = ["gocollector", "process"]
EOF
```

### Step 2: Create the Network Parsing Script

Now create the ConfigMap containing our custom script that parses network interface statistics:

```bash
cat <<EOF > 02-scripts-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: telegraf-scripts
  namespace: default
data:
  parse_ip_stats.sh: |
    #!/bin/bash
    # Script to parse ip -s link output and convert to InfluxDB line protocol
    
    # Get the current timestamp in nanoseconds
    timestamp=\$(date +%s%N)
    hostname=\$(hostname)
    
    # Parse ip -s link output for network statistics
    ip -s link | awk -v ts="\$timestamp" -v host="\$hostname" '
    BEGIN {
        interface = "";
        state = "";
        mtu = 0;
    }
    
    # Parse interface line (e.g., "2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 ...")
    /^[0-9]+:/ {
        # Extract interface name (handle both regular and @ notation)
        if (match(\$0, /^[0-9]+: ([^:@]+)/)) {
            interface_match = substr(\$0, RSTART, RLENGTH);
            # Remove the number and colon prefix, then trim spaces
            gsub(/^[0-9]+: */, "", interface_match);
            interface = interface_match;
        }
        
        # Extract state from flags
        if (match(\$0, /<[^>]+>/)) {
            flags = substr(\$0, RSTART+1, RLENGTH-2);
            if (index(flags, "UP")) {
                state = "up";
            } else {
                state = "down";
            }
        }
        
        # Extract MTU
        if (match(\$0, /mtu [0-9]+/)) {
            mtu_str = substr(\$0, RSTART+4, RLENGTH-4);
            mtu = mtu_str + 0;
        }
    }
    
    # Parse RX line header (RX: bytes packets errors dropped missed mcast)
    /^[[:space:]]*RX:.*bytes.*packets.*errors.*dropped.*missed.*mcast/ {
        getline; # Get the next line with the actual numbers
        gsub(/^[[:space:]]+/, ""); # Remove leading spaces
        n = split(\$0, rx_fields);
        if (n >= 6) {
            rx_bytes = rx_fields[1];
            rx_packets = rx_fields[2];
            rx_errors = rx_fields[3];
            rx_dropped = rx_fields[4];
            rx_missed = rx_fields[5];
            rx_multicast = rx_fields[6];
        }
    }
    
    # Parse TX line header (TX: bytes packets errors dropped carrier collsns)
    /^[[:space:]]*TX:.*bytes.*packets.*errors.*dropped.*carrier.*collsns/ {
        getline; # Get the next line with the actual numbers
        gsub(/^[[:space:]]+/, ""); # Remove leading spaces
        n = split(\$0, tx_fields);
        if (n >= 6 && interface != "" && interface != "lo") {
            tx_bytes = tx_fields[1];
            tx_packets = tx_fields[2];
            tx_errors = tx_fields[3];
            tx_dropped = tx_fields[4];
            tx_carrier = tx_fields[5];
            tx_collisions = tx_fields[6];
            
            # Output metrics after processing both RX and TX (skip loopback)
            printf "network_interface_stats,interface=%s,hostname=%s,state=\"%s\" ", interface, host, state;
            printf "mtu=%si,", mtu;
            printf "rx_bytes=%si,rx_packets=%si,rx_errors=%si,rx_dropped=%si,rx_missed=%si,rx_multicast=%si,", rx_bytes, rx_packets, rx_errors, rx_dropped, rx_missed, rx_multicast;
            printf "tx_bytes=%si,tx_packets=%si,tx_errors=%si,tx_dropped=%si,tx_carrier=%si,tx_collisions=%si ", tx_bytes, tx_packets, tx_errors, tx_dropped, tx_carrier, tx_collisions;
            printf "%s\n", ts;
        }
    }
    '
EOF
```

### Step 3: Create the Service Account

Create a service account for RBAC permissions:

```bash
cat <<EOF > 03-serviceaccount.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: telegraf-sa
  namespace: default
EOF
```

### Step 4: Create the DaemonSet

Now create the main DaemonSet that runs Telegraf on each node:

```bash
cat <<EOF > 04-daemonset.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: telegraf
  namespace: default
  labels:
    app: telegraf
spec:
  selector:
    matchLabels:
      app: telegraf
  template:
    metadata:
      labels:
        app: telegraf
    spec:
      serviceAccountName: telegraf-sa
      hostNetwork: true
      hostPID: true
      tolerations:
      - key: node-role.kubernetes.io/master
        operator: Exists
        effect: NoSchedule
      - key: node-role.kubernetes.io/control-plane
        operator: Exists
        effect: NoSchedule
      containers:
      - name: telegraf
        image: telegraf:1.28
        env:
        - name: HOSTNAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        ports:
        - name: prometheus
          containerPort: 2112
          protocol: TCP
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - name: telegraf-config
          mountPath: /etc/telegraf
        - name: telegraf-scripts
          mountPath: /scripts
        - name: proc
          mountPath: /host/proc
          readOnly: true
        - name: sys
          mountPath: /host/sys
          readOnly: true
        - name: var-run-docker
          mountPath: /var/run/docker.sock
          readOnly: true
        resources:
          requests:
            memory: "64Mi"
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        command:
        - /bin/bash
        - -c
        - |
          # Install iproute2 if not present
          if ! command -v ip > /dev/null 2>&1; then
            apt-get update && apt-get install -y iproute2
          fi
          
          # Copy the parsing script to the expected location
          cp /scripts/parse_ip_stats.sh /usr/local/bin/parse_ip_stats.sh
          chmod +x /usr/local/bin/parse_ip_stats.sh
          
          # Start telegraf
          exec telegraf --config /etc/telegraf/telegraf.conf
      volumes:
      - name: telegraf-config
        configMap:
          name: telegraf-config
          defaultMode: 0755
      - name: telegraf-scripts
        configMap:
          name: telegraf-scripts
          defaultMode: 0755
      - name: proc
        hostPath:
          path: /proc
      - name: sys
        hostPath:
          path: /sys
      - name: var-run-docker
        hostPath:
          path: /var/run/docker.sock
      terminationGracePeriodSeconds: 30
EOF
```

### Step 5: Create the Service

Create a service to expose the Prometheus metrics endpoint:

```bash
cat <<EOF > 05-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: telegraf-metrics
  namespace: default
  labels:
    app: telegraf
spec:
  selector:
    app: telegraf
  ports:
  - name: prometheus
    port: 2112
    targetPort: 2112
    protocol: TCP
  type: ClusterIP
EOF
```

### Step 6: Create the PodMonitor

Finally, create the PodMonitor that tells Azure Managed Prometheus to scrape our metrics:

```bash
cat <<EOF > 06-podmonitor.yaml
apiVersion: azmonitoring.coreos.com/v1
kind: PodMonitor
metadata:
  name: telegraf-podmonitor
  namespace: default
  labels:
    app: telegraf
spec:
  selector:
    matchLabels:
      app: telegraf
  podMetricsEndpoints:
  - port: prometheus
    interval: 30s
    path: /metrics
EOF
```

### Step 7: Deploy All Components

Now deploy all the components in order:

```bash
kubectl apply -f 01-configmap.yaml
kubectl apply -f 02-scripts-configmap.yaml
kubectl apply -f 03-serviceaccount.yaml
kubectl apply -f 04-daemonset.yaml
kubectl apply -f 05-service.yaml
kubectl apply -f 06-podmonitor.yaml
```

### Verification

After a minute or two, verify everything is running: 

```bash
kubectl get daemonset telegraf
kubectl get pods -l app=telegraf
kubectl get service telegraf-metrics
kubectl get podmonitor telegraf-podmonitor
```

## Validate the Metrics  

You can check if the new metrics are now being collected correctly, by forwarding the `telegraf-metrics` service port locally and then by running `curl` against it:

```bash
kubectl port-forward svc/telegraf-metrics 2112:2112 &
curl http://localhost:2112/metrics | head -20
```

Sample output:  

```
# HELP network_interface_stats_rx_bytes Telegraf collected metric
# TYPE network_interface_stats_rx_bytes untyped
network_interface_stats_rx_bytes{interface="eth0",host="aks-node-1"} 16876971289
```

Great! At this point we know that our collection is working. Next we will look into how to visualize these new metrics in Grafana.

## Visualize in Grafana  

You can now go to your new **Azure Managed Grafana** instance and try some queries. To get the URL for your **Azure Managed Grafana**, run the following command:

```bash
GRAFANA_UI=$(az grafana show \
  --name ${GRAFANA_NAME} \
  --resource-group ${RG_NAME} \
  --query "properties.endpoint" -o tsv)

echo "Your Azure Managed Grafana is accessible at: $GRAFANA_UI"
```

Now that you know the URL, open Azure Managed Grafana and go to the `Drilldown` tab.

![Explore](/assets/images/telegraf-on-aks/grafana-drilldown.png)

Make sure the Data Source is `Managed_Prometheus_telegraf-on-aks`.

![Datasource](/assets/images/telegraf-on-aks/grafana-datasource.png)

Try to search for `network_interface_` metrics. You should see all of the new metrics that are being collected by Telegraf

![Drilldown](/assets/images/telegraf-on-aks/drilldown-metrics.png)

Next you can create **table panels** with `Instant` queries for top-N views or **time series panels** for trends over time. Here are some suggestions on metrics:

```bash
# Network throughput by node
sum(rate(network_interface_stats_rx_bytes[5m])) by (host)

# Top interfaces by traffic
topk(10, network_interface_stats_tx_bytes)

# Packet drops
sum(rate(network_interface_stats_rx_dropped[5m])) by (interface)
```
## Cleaning up

To remove these resources, you can run this command:

```bash
az group delete --name ${RG_NAME} --yes --no-wait
```

## Conclusion

In this post, we saw an approach how on to integrate custom metrics into Azure’s managed monitoring stack with minimal setup using `Telegraf DaemonSet`, for flexible metric collection, `Azure Managed Prometheus`, for scraping and storage, and `Azure Managed Grafana` for visualization and alerting.

While our example used network metrics, the same pattern applies to any custom data source you want to monitor in AKS. If you want to take this example one step further, we have a hands-on experience with the [AKS Labs: Advanced Observability Concepts](https://azure-samples.github.io/aks-labs/docs/operations/observability-and-monitoring) and the [Obervability with Managed Prometheus and Managed Grafana at the Microsoft Reactor](https://www.youtube.com/watch?v=Dc0TqbAkQX0).