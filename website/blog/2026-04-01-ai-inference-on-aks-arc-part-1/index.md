---
title: "AI Inference on AKS Arc - Part 1: Generative AI with Open‑Source LLM Server"
date: 2026-03-27
description: "Generative & Predictive AI Inference on Azure Arc: A Multi‑Part Lab Series."
authors:
- datta-rajpure
tags: ["aks-arc", "ai", "inference"]
---

This part of the series focuses on generative AI inference using open‑source large language model (LLM) servers deployed on AKS enabled by Azure Arc. The labs demonstrate how to run LLM inference workloads on Arc‑enabled Kubernetes using GPUs, while maintaining local execution, Arc‑based management, and repeatable operational patterns suitable for on‑premises and edge environments.
This approach is especially relevant for customers who cannot rely on fully managed cloud AI services due to data locality, latency, cost, or hardware availability constraints.
<!-- truncate -->

## Introduction

Part 1 of this series introduces generative AI inference on AKS enabled by Azure Arc using open‑source LLM servers. The goal of this part is not to optimize models or benchmark throughput, but to establish a correct, debuggable, and repeatable operational baseline for running GPU‑accelerated LLM inference workloads on Arc‑enabled Kubernetes clusters in on‑premises and edge environments.
The labs focus on simplicity, transparency, and operational correctness, avoiding platform‑specific abstractions or managed services. All scenarios in Part 1 use standalone LLM servers (such as Ollama and vLLM) deployed directly as Kubernetes workloads. This makes the inference stack explicit and observable, allowing readers to understand how model serving, GPU resource allocation, and request handling behave in an Arc‑managed environment before introducing more advanced inference pipelines later in the series.

**Expected Learnings – By completing Part 2, you will:**
- How to deploy and operate GPU‑accelerated LLM inference workloads on AKS enabled by Azure Arc
- How open‑source LLM servers behave operationally when running on NVIDIA GPU‑backed Kubernetes nodes
- What baseline deployment patterns, resource constraints, and operational considerations apply before adopting optimized, multi‑model, or managed inference stacks
These labs intentionally prioritize clarity over optimization, setting the foundation for the predictive and optimized inference scenarios introduced in later parts of the series.

:::note
Before starting these labs, ensure that all prerequisites described in **Part 0: Introduction, Audience, and Lab Contract** are fully met.

Part 1 labs assume a fully functioning **AKS enabled by Azure Arc** environment and do not repeat cluster, tooling, or accelerator setup steps unless explicitly stated.

**All labs in Part 1 are GPU‑only.** They require access to **at least one NVIDIA GPU‑enabled node** with a correctly configured and functioning NVIDIA device plugin. CPU‑only inference scenarios are **not covered** in this part.

GPU enablement, driver installation, and device plugin or GPU Operator setup are considered **out of scope** and are not repeated in these labs.
:::
## AI Inference with Ollama on Azure Arc (Generative LLM)
**Scenario:** Deploy a local large language model using the Ollama LLM runtime on an Arc-enabled AKS cluster. Ollama is an open-source LLM server that makes it easy to run small models on-premises with an OpenAI-compatible API. In this lab, you will set up Ollama on a GPU-enabled Arc cluster and serve an example 7B LLM, then query it with a test prompt to verify end-to-end inference.
### Deploying the Ollama Model Server
First, ensure you have connected to your Arc-enabled cluster (see Prerequisites) and that it has a GPU node with the NVIDIA device plugin ready (the GPU Operator should be installed). If your cluster has both GPU and CPU nodes, you may label a GPU node (e.g. `kubectl label node <NodeName> apps=ollama`) to ensure the Ollama pod schedules on a GPU node. Next, create a Kubernetes manifest (e.g. ollama-deployment.yaml) for the Ollama Deployment and Service:
```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ollama
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ollama
  template:
    metadata:
      labels:
        app: ollama
    spec:
      containers:
      - name: ollama
        image: ollama/ollama:latest
        ports:
        - containerPort: 11434
        resources:
          limits:
            nvidia.com/gpu: 1   # use one GPU
---
apiVersion: v1
kind: Service
metadata:
  name: ollama-service
  namespace: default
spec:
  type: LoadBalancer
  selector:
    app: ollama
  ports:
  - protocol: TCP
    port: 11434
    targetPort: 11434
```

This defines a **Deployment** running one instance of the ollama/ollama:latest container image, exposing the server on port **11434**, and requesting 1 GPU (nvidia.com/gpu: 1) so it runs on your GPU node. A LoadBalancer Service on port 11434 forwards requests to the pod; on Azure Stack HCI, if no external load balancer is available, you can use port-forwarding to access the service. Apply the manifest to start the Ollama server:
```powershell
kubectl apply -f ollama-deployment.yaml
kubectl get pods -l app=ollama -w    # watch pod status
```
Wait until the ollama pod is Running! 

### Loading a Model and Testing Inference
Once the server is running, load a test model and send an inference API request. The example below uses a small (~2.2 GB) model called “phi3”. Run the following to pull the model weights inside the running Ollama pod:
```powershell
$podName = (kubectl get pods -l app=ollama -o name)
kubectl exec -it $podName -- ollama pull phi3
```
After the ollama pull command prints “success,” the model is ready. If no external IP is assigned to ollama-service, run `kubectl port-forward svc/ollama-service 11434:11434` to expose port 11434 on localhost.

Now issue a test generate request to the server’s HTTP API (port 11434). For example, using PowerShell:
```powershell
# Use localhost with port-forward; if using external IP, replace URI accordingly:
Invoke-RestMethod -Method Post -Uri "http://localhost:11434/api/generate" `
    -ContentType "application/json" `
    -Body '{"model": "phi3", "prompt": "What is Azure Kubernetes?", "stream": false}'
```

### Clean Up
When finished, remove the Ollama resources to free up the GPU. 
```powershell
# Use your manifest to delete the deployment and service:
kubectl delete -f ollama-deployment.yaml

# You can also delete the resources by name:
  # Delete the LoadBalancer service to release its external IP (if any)
  kubectl delete service ollama-service

  # Delete the Ollama deployment (which will also terminate the pod)
  kubectl delete deployment ollama

# remove node labels if added
$nodeName = (kubectl get nodes -l app=ollama -o name)
kubectl label node $nodeName apps-
```

## AI Inference with vLLM on Azure Arc (Generative LLM)
**Scenario:** Serve a local large language model using the vLLM inference engine on an Arc-enabled AKS cluster. vLLM is a high-performance LLM serving engine that uses an optimized memory management algorithm (PagedAttention) to support efficient text generation with large models. Here we deploy a sample Mistral 7B model (quantized ~4 GB) on Arc using vLLM’s OpenAI-like API, then query it with a prompt to verify the response.

### Deploying the vLLM Model Server
After connecting to your Arc-enabled cluster (see Prerequisites), confirm the cluster’s GPU node is ready and run the NVIDIA GPU Operator if not already installed (to provide the device plugin). Then prepare a Kubernetes manifest (e.g. vllm-deploy.yaml) to run the vLLM server and expose it:

```YAML
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-mistral
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-mistral
  template:
    metadata:
      labels:
        app: vllm-mistral
    spec:
      containers:
      - name: vllm-container
        image: vllm/vllm-openai:latest
        command: ["python3", "-m", "vllm.entrypoints.openai.api_server"]
        args: ["--model", "TheBloke/Mistral-7B-v0.1-AWQ",
               "--quantization", "awq", "--dtype", "float16",
               "--host", "0.0.0.0", "--port", "8000",
               "--max-model-len", "4096", "--gpu-memory-utilization", "0.80",
               "--enforce-eager"]
        ports:
        - containerPort: 8000
        resources:
          limits:
            nvidia.com/gpu: 1
        volumeMounts:
        - name: shm
          mountPath: /dev/shm
      volumes:
      - name: shm
        emptyDir:
          medium: Memory
          sizeLimit: "2Gi"
---
apiVersion: v1
kind: Service
metadata:
  name: vllm-service
spec:
  selector:
    app: vllm-mistral
  ports:
  - protocol: TCP
    port: 80
    targetPort: 8000
  type: LoadBalancer
```

This Deployment launches one vllm/vllm-openai:latest container that runs vLLM’s OpenAI-compatible API server for the Mistral-7B model (TheBloke/Mistral-7B-v0.1-AWQ from Hugging Face). The container is configured with a 4096 token context, uses 80% of GPU memory (--gpu-memory-utilization 0.80), and employs AWQ 4-bit quantized weights (to fit in a ~16 GB GPU). It requests 1 GPU, and mounts a 2 GiB emptyDir at /dev/shm for fast memory access. A Service vllm-service is used to forward port 80 to the container’s port 8000 (the API) as a LoadBalancer.

Apply the manifest to start the vLLM server:
```powershell
kubectl apply -f vllm-deploy.yaml
kubectl get pods -l app=vllm-mistral -w   # watch for vllm-mistral pod to run
```

Kubernetes will pull the container image and start the server. Wait for the vllm-mistral pod to reach Running. Once running, if no external IP address is assigned to vllm-service, open a terminal and port-forward it (e.g. `kubectl port-forward svc/vllm-service 8080:80`) to access the API at http://localhost:8080.

### Testing the LLM Endpoint
With the vLLM server ready, send a test completion request to verify the deployed model. Using PowerShell’s Invoke-RestMethod, call the /v1/completions endpoint with a JSON body specifying the model and a prompt:
```powershell
# Using localhost with port-forward; replace $SERVICE_IP if using external LB
Invoke-RestMethod -Method Post -Uri "http://localhost:8080/v1/completions" `
    -ContentType "application/json" `
    -Body '{"model": "TheBloke/Mistral-7B-v0.1-AWQ", "prompt": "What is AKS Arc", "max_tokens": 25}'
```
This OpenAI-style API call asks the model (Mistral-7B) to complete the prompt “What is AKS Arc” with up to 25 tokens. The server should return a JSON with a "choices" array containing the model’s generated text (e.g., a sentence about What is AKS Arc as an on-premises cloud). The health endpoint (GET /health) can also be checked for an OK status to confirm the service is up.

### Clean Up
Use your manifest to delete the vLLM deployment and service when done:
```powershell
kubectl delete -f vllm-deploy.yaml
```
This removes the vllm-mistral Deployment (stopping the pod) and the Service. If no more GPU inference is needed, you may also remove the GPU Operator (`helm uninstall <release-name>`) to reclaim cluster resources.
