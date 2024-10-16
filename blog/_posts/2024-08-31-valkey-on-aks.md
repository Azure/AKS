---
title: "Launch Valkey on AKS Today!"
description: "Valkey is a high-performance database forked from Redis. Annoucing a your local guide to deploying Valkey on AKS."
date: 2024-08-31
author: Kenneth Kilty
categories: general
---

## Introduction

[Valkey](https://valkey.io/), an open source database forked from Redis, is a ubiquitous key-value, in-memory data structure store that can be used as a database, cache, and message broker. As part of our continuing series on running stateful applications in Azure Kubernetes Service (AKS), we've released a new guide developed by the [FastTrack for Azure - Independent Software Vendors (ISVs) and Startups](https://learn.microsoft.com/en-us/shows/azure-videos/fasttrack-for-azure-isvs-and-startups) team that offers a practical real-world example of deploying Valkey on AKS.

[Azure FastTrack](https://azure.microsoft.com/en-us/pricing/offers/azure-fasttrack/) provides tailored guidance from Azure engineers to accelerate your cloud projects and assist with migration from other cloud providers.

## What’s in the guide?

This guide covers essential topics such as using Azure Availability Zones with AKS, leveraging the Kubernetes [External Secrets Operator](https://external-secrets.io/latest/) with [Azure Key Vault provider for Secrets Store CSI Driver](https://learn.microsoft.com/en-us/azure/aks/csi-secrets-store-driver), and scaling considerations. It draws on the lessons learned from supporting ISV's and startups that depend on AKS for running critical workloads on Azure.

Additional highlights include using the [Reloader](https://github.com/stakater/Reloader) project to automatically manage restarts for Valkey cluster nodes during configuration changes and pulling official Valkey images into [Azure Container Registry](https://learn.microsoft.com/en-us/azure/container-registry/) to provide a means to manage container lifecycle and security. The guide also incorporates high-availability guidance using [multi-zone AKS clusters](https://learn.microsoft.com/en-us/azure/aks/availability-zones) and recommended distribution of Valkey replica pods.

We hope you give the guide a try and share your feedback!

## Upcoming

Look for a new guide showcasing running [MongoDB](https://github.com/mongodb/mongo) on AKS using the [Percona](https://github.com/percona/percona-server-mongodb-operator) operator. This guide, produced by the same FastTrack team, also includes elements of high-availability and scaling considerations gleaned from experience supporting startup customers on Azure using AKS.

Don’t forget to subscribe to our [Really Simple Syndication (RSS) feed](https://azure.github.io/AKS/feed.xml) to stay tuned for upcoming posts in the series!

Until next time ✌️
