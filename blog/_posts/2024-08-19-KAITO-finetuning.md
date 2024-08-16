---
title: "Fine tune language models with KAITO on AKS"
description: "Make your AI model even smarter, in just a few steps"
date: 2024-08-19
author: Sachi Desai
categories: AI
---

## Introduction

You may have heard of the [Kubernetes AI Toolchain Operator](https://github.com/Azure/kaito/tree/main) (KAITO) announced at Ignite 2023 and KubeCon Europe this year. The open source project has gained popularity in recent months by introducing a streamlined approach to AI model deployment and flexible infrastructure provisioning on Kubernetes.

With the [v0.3.0 release](https://github.com/Azure/kaito/releases/tag/v0.3.0), KAITO has expanded the supported model library to include the Phi-3 model, but the biggest (and most exciting) addition is the ability to fine-tune open-source models. Why should you be excited about fine-tuning? Well, it’s because fine-tuning is one way of giving your foundation model additional training using a specific dataset to enhance accuracy, which ultimately improves the interaction with end-users.


## Fine-tuning a foundation model is sometimes necessary

Let’s experiment with [Phi-3-mini-128K](https://huggingface.co/microsoft/Phi-3-medium-128k-instruct), a robust and high-performing model that’s a bit smaller in size than your average LLM. We’ll use the following [chatbot UI tool](https://streamlit.io/), connected to a Phi-3 inference service deployed by KAITO, and ask a basic question about AKS:

Here’s an example of what the fine-tuning workspace looks like when training on a dataset found on HuggingFace:

```bash
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: workspace-tuning-phi-3
resource:
  instanceType: Standard_NC24ads_A100_v4
  labelSelector:
    matchLabels:
      app: tuning-phi-3
tuning:
  preset:
    name: phi-3-mini-128k-instruct
  method: qlora
  input:
    urls:
      - https://huggingface.co/datasets/myuser/mydataset/resolve/main/data/train-00000-of-00001.parquet?download=true
  output:
    image: myregistry.azurecr.io/adapters/myadapter:0.0.1
    imagePushSecret: myregistrysecret
```

For the most part, the `Workspace` resource is similar as before. Here, we see that KAITO recommends a minimum GPU VM SKU of “Standard_NC24ads_A100_v4” for the tuning job.  You can update the `instanceType` to a larger GPU VM SKU, but either way, you should make sure there’s enough GPU quota in your Azure subscription prior to deploying applying the workspace to your AKS cluster. 

> Note: Be sure to check out this [quickstart guide](https://learn.microsoft.com/azure/quotas/quickstart-increase-quota-portal) on how to request quota increase in the Azure Portal, if you have never done that before.

Fine-tuning jobs will run using default tuning configurations defined by KAITO; however, you can optionally create a ConfigMap in your cluster and reference it as your config in the tuning spec. You can configure default parameters to change your fine-tuning result as outlined in this doc: https://github.com/Azure/kaito/tree/main/docs/tuning#categorized-key-parameters

> Note: If you choose to pull and push from private registries, you must create a Kubernetes “docker-registry” secret and reference it as your `imagePullSecret`/`imagePushSecret`.

After deploying the KAITO workspace, KAITO will create a `Job` workload in the same namespace as the workspace and run to completion. This can take several hours depending on the size of your input model and dataset.  Once the fine-tuning job is complete, an adapter result will be stored in the output location specified in your workspace tuning output settings. This adapter layer is stored as a container image, holding a subset of updated weights of your model based on what it learned from your input dataset. As a result, the image is lightweight, portable, conveniently version controlled, and can be pulled into new inferencing jobs!

To use our new fine-tuned adapter, the inference workspace will now accept one or more adapters to customize model behavior.

Here is an example of what a fine-tuned inference workspace looks like:

```bash
apiVersion: kaito.sh/v1alpha1
kind: Workspace
metadata:
  name: workspace-phi-3-mini-adapter
resource:
  instanceType: Standard_NC6s_v3
  labelSelector:
    matchLabels:
      apps: phi-3-adapter
inference:
  preset:
    name: phi-3-mini-128k-instruct
  adapters:
    - source:
        name: myadapter
        image: myregistry.azurecr.io/adapters/myadapter:0.0.1
        imagePullSecrets:
          - myregistrysecret
      strength: "1.0"
```

As new inference requests come in, they’ll flow through the model that merges the adapters and the response will be affected by the newly trained data. 
Great! After updating our inference endpoint to leverage the new adapter, let’s ask the same question and check the response from the fine-tuned phi-3-mini-128k-instruct model:


*Screenshot of un-tuned model response*

![Screenshot of tuned model response](/blog/assets/images/kaito_tuned_phi3_response.png)
*Screenshot of tuned model response*

That definitely looks more accurate – the fine-tuned model quickly discerned that we’re looking for an answer related to Kubernetes and provided a much better response. However, there’s always room to improve the model’s accuracy for domain specific questions. We can improve upon or find new input datasets to create new tuning adapters. This iterative tuning process can be done by repeating the steps described above.

## Other options to make models smarter

Retrieval-Augmented Generation (RAG) is another common technique used to improve the inference accuracy of foundation models. Compared to LoRA fine-tuning, RAG eliminates the need of training Jobs to generate adapters. It has a more complicated workflow with additional components like a vector database, indexing and query servers, etc. The good news is that RAG support with a simple user experience is in KAITO’s roadmap. 🚀

## Summary

Users expect LLMs to stay on task and provide accurate answers. While foundation models on their own have a wealth of knowledge, they often need to be refined for specific tasks. This can be achieved by leveraging techniques like fine-tuning or RAG, but the process of implementing these techniques is not always straightforward. As you saw, with KAITO, it becomes **really easy**. All you need to do is specify an input dataset, a GPU SKU, and off it goes! KAITO will take care of the rest. Its adapter design makes it very portable to attach to multiple workspaces or even attach multiple adapters to a single workspace. In the end, we can see that the inference and tuning workspaces along with adapters can become fundamental building blocks in your overall ML workflow.

We’re just getting started and would love your feedback. To learn more about KAITO fine-tuning, AI model deployment on AKS or KAITO’s roadmap in general, check out the following links:

**Resources**

- [KAITO fine-tuning guide](https://github.com/Azure/kaito/tree/main/docs/tuning)
- [Concepts - Fine-tuning language models for AI and machine learning workflows](https://learn.microsoft.com/azure/aks/concepts-fine-tune-language-models)
- [Concepts - Small and large language models](https://learn.microsoft.com/azure/aks/concepts-ai-ml-language-models)
- [KAITO Roadmap](https://github.com/orgs/Azure/projects/669)
