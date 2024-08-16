---
title: "Fine tune language models with KAITO on AKS"
description: "Make your AI model even smarter, in just a few steps"
date: 2024-08-19
author: Sachi Desai
categories: AI
---

**Introduction**

You may have heard of the [Kubernetes AI Toolchain Operator](https://github.com/Azure/kaito/tree/main) (KAITO) announced at Ignite 2023 and KubeCon Europe this year. The open source project has gained popularity in recent months by introducing a streamlined approach to AI model deployment and flexible infrastructure provisioning on Kubernetes.

With the [v0.3.0 release](https://github.com/Azure/kaito/releases/tag/v0.3.0) of KAITO, we’re excited to share that we’ve expanded the supported model library to include a preset configuration for Phi-3, but the biggest (any most exciting) addition is the ability to fine-tune open-source models. Fine-tuning is just one way of giving your foundation model additional training for a specific task to enhance accuracy, which ultimately improves the interaction with end-users.

All you have to do is specify your model preset and tuning method, data set, and container registry details - KAITO will automate the rest and provide a lightweight output to pull into new inferencing jobs!

**Fine-tune a Phi-3 model with KAITO**

Let’s look at what fine-tuning looks like with KAITO. We’ll use Phi-3-mini for our sample deployment. The `Phi-3-mini-128K` model is a robust and high-performing option that’s also a convenient size for fine-tuning, so we’ll use that as an example. With KAITO v0.3.0 or higher, there is an additional tuning property added to the `Workspace` specification. Within the tuning property, you can specify additional information for the tuning job such as a preset configuration for the base model, fine-tuning method using LoRA or QLoRA, input datasets, and output location for the adapter.

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
