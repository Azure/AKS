---
title: "Fine tune language models with KAITO on AKS"
description: "Make your AI model even smarter, in just a few steps"
date: 2024-08-19
author: Sachi Desai
categories: AI
---

**Introduction**

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

To use your new fine-tuned adapter, the inference workspace can now accept one or more adapters whose strength values can be adjusted (default of 1.0) to customize model behavior. 

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

As new inference requests come in, they'll flow through the model and adapters so the response will be altered based on new training data and adjusted based on the strength of each adapter. 

Here is an example of what an un-tuned `phi-3-mini-128k-instruct` model response looks like, versus a fine-tuned `phi-3-mini-128k-instruct` model:

![Screenshot of untuned model response](/blog/assets/images/kaito_untuned_phi3_response.png)
*Screenshot of un-tuned model response*

![Screenshot of tuned model response](/blog/assets/images/kaito_tuned_phi3_response.png)
*Screenshot of tuned model response*

You can see in the two screenshots above, that the base `phi-3-mini-128k-instruct` model with no fine-tuning wasn’t quite sure of what the user means by “AKS”. However, with a little bit of fine-tuning with a [dataset](https://huggingface.co/datasets/ishaansehgal99/kubernetes-reformatted-remove-outliers) optimized for Kubernetes and cloud platforms, it is quickly able to discern that the user is looking for an answer related to Kubernetes and provides a better response. There is still a bit of work to do when it comes to prompt engineering and/or fine-tuning tweaks but it’s clearly on the right path!

**Summary**

With KAITO’s new fine-tuning capability, you can now give open-source models additional training for specific tasks, which will generate more context-aware results to your business needs. KAITO supports small language model (SLM) families like Phi-3, which you can choose to reduce costs and fine-tune quickly in comparison to larger, general-purpose models. The best part is that as new data flows in, you can iterate with multiple adapters to improve model performance and achieve this sort of ML workflow all within your AKS cluster and with just a few lines of YAML!

We’re just getting started and would love your feedback. To learn more about KAITO fine-tuning, AI model deployment on AKS or KAITO’s roadmap in general, check out the following links.

**Resources**

- [KAITO fine-tuning guide](https://github.com/Azure/kaito/tree/main/docs/tuning)
- [Concepts - Fine-tuning language models for AI and machine learning workflows](https://learn.microsoft.com/azure/aks/concepts-fine-tune-language-models)
- [Concepts - Small and large language models](https://learn.microsoft.com/azure/aks/concepts-ai-ml-language-models)
- [KAITO Roadmap](https://github.com/orgs/Azure/projects/669)
