---
title: "Local Development on AKS with mirrord"
description: "Learn how mirrord simplifies Kubernetes local development."
date: 2024-12-04 # date is important. future dates will not be published
author: Gemma Tipper # must match the authors.yml in the _data folder
categories: general # general, operations, networking, security, developer topics, add-ons
---

>Hi everyone,
>
>The awesome team at Metalbear recently shared an insightful blog post showcasing how to use mirrord with Azure Kubernetes Service. I'm excited to highlight their work, as the blog dives deep into how mirrord simplifies testing your code directly in a Kubernetes environment. Happy reading! 
>
>DISCLAIMER. The following blog is authored by MetalBear at the request of Microsoft. Microsoft is publishing this blog in the AKS Engineering Blog as a convenience to its readers.
>
>Quentin Petraroia - Product Manager for Azure Kubernetes Service

## Introduction

Developing applications for Kubernetes can mean a lot of time spent waiting and relatively little time spent writing code. Whenever you want to test your code changes in the cluster, you usually have to build your application, deploy it to the cluster, and attach a remote debugger (or add a bunch of logs). These iterations can be incredibly time-consuming. Thankfully, there is a way to bridge the gap between your local environment and a remote cluster, making them feel seamlessly connected. mirrord, which can be used as a plugin for VSCode or IntelliJ or directly in the CLI, is an open-source tool that does exactly that (and much more).

Tools like this (dubbed "remocal" development tools) are designed to improve your experience when developing applications intended to be deployed in a cluster. The point of mirrord is to shift left on cloud testing and shorten the dev loop from hours to seconds. It's the kind of thing you set up once and then can't imagine living without because it feels like magic.

![Screenshot of the inner dev loop](/assets/images/mirrord-on-aks/mirrord-dev-loop.png)



In short, mirrord lets you connect your local process with your development or staging cluster. It grabs env vars, files and traffic from the cluster in a way that makes your process think it's running remotely. The approach of mirrord is unique in that instead of simply starting a VPN, it hooks system calls in the local process and proxies traffic to the cluster.

mirrord is also highly configurable, allowing for very granular specification of exactly what comes from the cluster and what comes from the local environment. Additionally, mirrord is easy to use with any kind of cluster configuration, no matter what service meshes or other more complex architecture it uses. It works just as well regardless of the size and shape of your cluster.

Some other pros of using mirrord over similar solutions include:
- no root privileges are required on your machine
- super fast start up speed
- you can run multiple local processes at the same time


## Using mirrord with AKS

mirrord is cloud agnostic and seamlessly supports AKS. Additionally, the setup process is exceedingly simple: as long as you can access your cluster with `kubectl`, you can run mirrord and start developing with a lightning fast feedback loop.

Next up are a couple of walkthroughs for using the mirrord VSCode plugin to develop parts of the [AKS store demo sample](https://github.com/Azure-Samples/aks-store-demo); the [first example](#a-practical-example-rust) looks at `product-service`, a Rust application, and [the second](#another-practical-example-golang) looks at `makeline-service`, which is written in Go. Feel free to try both or whichever one interests you more. They are completely independent of each other, but I would recommend reading the Rust example even if you only want to follow the Go walkthrough.

## A practical example: Rust

And now for a guide on how to start using mirrord for yourself, using the [AKS store demo sample](https://github.com/Azure-Samples/aks-store-demo). You'll need the following:

- An AKS cluster with the store demo deployed (you can use either the full deployment or the reduced one from `aks-store-quickstart.yaml` for this example), accessible from your machine with `kubectl`
- Rust (I prefer to install the Rust compiler using [Rustup](https://rustup.rs/))
- A local clone of the store demo

First, deploy the store demo - the easiest way to deploy the reduced sample is by running `kubectl apply -f aks-store-quickstart.yaml` from the store demo directory. Make sure all pods are in Ready state, then open the `product-service` folder in VSCode.

You'll also want to open the store front in a browser. The following command prints the IP: 

```
kubectl get service store-front --output 'jsonpath={..status.loadBalancer.ingress[0].ip}'
```

You should see the store UI before it’s been affected by any of our local changes.

![Screenshot of the AKS pet store demo app](/assets/images/mirrord-on-aks/aks-pet-store.png)

Next is installing mirrord: search for "mirrord" in the VSCode extensions tab (or find it [here](https://marketplace.visualstudio.com/items?itemName=MetalBear.mirrord)) and install it - a `mirrord` status icon should show up on the bottom bar of the IDE. Click it once so the circle next to "mirrord" is filled (this means it's enabled).

![Screenshot of the mirrord extension in vs code](/assets/images/mirrord-on-aks/mirrord-vscode-extension.png)

![Screenshot of the mirrord extension in the vs code toolbar](/assets/images/mirrord-on-aks/mirrord-vscode-toolbar.png)

As a quick sanity check, hit F5 to run `product-service` in debug mode (if it asks, let VSCode generate run configurations from `Cargo.toml` and use the configuration called "Debug executable 'product-service'"). mirrord will ask which target to use (that is, the pod or deployment whose traffic, files, and other input and output mirrord should proxy to your local process), so choose the pod from the `product-service` deployment. When you refresh the store front UI in your browser, you should see incoming traffic to `product-service` in the cluster printing out in the terminal.

![Screenshot of the mirrord logs](/assets/images/mirrord-on-aks/mirrord-logs.png)

Nice! We're mirroring the traffic coming into the target on the cluster to our local process and all we had to do was download a plugin. This doesn't affect the cluster because mirroring traffic is non-intrusive - requests are handled by the remote pod, and any response we send from our local process is discarded. Now let's get intrusive and change the details of some of our products. Stop the debugger so we don't have to look at constant log spam.

The details of all the products available in our store are stored in `src/data.rs`. Let’s say that we want to change some of the product details to target high-income pet owners specifically: go ahead and replace the first three products (lines 6-26) of that file with the following:

```rust
        Product {
            id: 1,
            name: "Premium Contoso Catnip's Friend".to_string(),
            price: 19.99,
            description: "Watch your feline friend embark on a fishing adventure with Premium Contoso Catnip's Friend toy. Packed with premium irresistible catnip and premium dangling fish lure.".to_string(),
            image: "/catnip.jpg".to_string()
        },
        Product {
            id: 2,
            name: "Premium Salty Sailor's Squeaky Squid".to_string(),
            price: 16.99,
            description: "Let your dog set sail (premium-ly) with the Premium Salty Sailor's Squeaky Squid. This interactive toy provides hours of fun, featuring multiple squeakers and crinkle tentacles.".to_string(),
            image: "/squid.jpg".to_string()
        },
        Product {
            id: 3,
            name: "Premium Mermaid's Mice Trio".to_string(),
            price: 112.99,
            description: "Entertain your premium kitty with the Mermaid's Mice Trio. These adorable plush premium mice are dressed as mermaids and filled with catnip to captivate their curiosity.".to_string(),
            image: "/mermaid.jpg".to_string()
        },
```

In order to configure mirrord, hover over the plugin name in the toolbar and click "Settings", which will create a `mirrord.json` file with some default configuration values. You can see the default network mode is "mirror" - change that to "steal" so that we can intercept traffic to our local process and return traffic from the local process into the cluster. If you only want to steal a subset of the traffic you can use filtered stealing, which only intercepts traffic matching a preconfigured filter - you can read more about this [in the docs](https://mirrord.dev/docs/using-mirrord/steal/).

While we have the settings open, let's specify our target so we don't have to keep selecting it in the GUI. Under the `"feature"` field, add: `"target": "deployment/product-service"`. The full `mirrord.json` now looks like this:

```json
{
	"feature": {
    	"network": {
        	"incoming": "mirror",
        	"outgoing": true
    	},
    	"fs": "read",
    	"env": true
	},
	"target": "deployment/product-service"
}
```

This time, when you refresh the store front, you'll see that the product details have changed in line with our local version of `product-service`.

![Screenshot of the updated pet store](/assets/images/mirrord-on-aks/aks-pet-store-updated.png)


When the store-front app in the cluster sent a request to get the product details, mirrord stole the request and sent it to our local version, which sent a response containing our changes that was then sent back to the store front in the cluster through mirrord, showing up on the webpage.

## A(nother) practical example: Golang

Let's have a look at a service that does something more complicated: `makeline-service` is the component that communicates with the `store-admin`, the RabbitMQ order queue, and the MongoDB order database in order to process and complete orders.

You'll need:
- An AKS cluster with the store demo deployed (you’ll need the full deployment from  `aks-store-all-in-one.yaml` for this one), accessible from your machine with `kubectl`
- Go (available from [their website](https://go.dev/doc/install))
- A local clone of the store demo

Open `makeline-service` in VSCode and make sure mirrord is enabled (refer to the [Rust example](A practical example: Rust) for instructions). Next, open mirrord’s configuration by hovering over the `mirrord` status icon in the bottom bar and clicking “Settings”. Replace the contents of the `mirrord.json` file that was created with the following:

```json
{
	"feature": {
    	"network": {
        	"incoming": "steal",
        	"outgoing": true
    	},
    	"fs": "read",
    	"env": true
	},
	"target": "deployment/makeline-service"
}
```

Keep the `store-admin` page open so that we can track orders (grab the IP with `kubectl get service store-admin --output 'jsonpath={..status.loadBalancer.ingress[0].ip}'`) and make sure that new orders are being placed:

![Screenshot of the pet store admin page](/assets/images/mirrord-on-aks/aks-pet-store-admin-page.png)

Say, for example, that you have had a genius new idea regarding order spam detection: you want to try discarding orders in the queue that contain more than one type of item.

Clicking on some of the orders, you can see that they’re a random collection of usually a few different types of item, like this (note that orders are created in a way such that some will have multiple entries for the same kind of item - we think these are spam too, and we only want to process orders with a single item entry):

![Screenshot of the pet store orders](/assets/images/mirrord-on-aks/aks-pet-store-orders.png)

We don’t want these, they’re (possibly) spam! Change the contents of `main.go` as follows: replace lines 77-78 with this code for our new anti-spam measure:

```go
// NEW: Discard orders containing more than 1 different type of item
var new_orders []Order
for _, order := range orders {
	if len(order.Items) <= 1 {
    	new_orders = append(new_orders, order)
	}
}

// Save orders to database
err = client.repo.InsertOrders(new_orders)
```

Re-run the debugger, refresh the `store-admin` page and check for new orders - they should all be orders with only one type of item, which you can check by clicking on the order number:

![Screenshot of the pet store admin orders](/assets/images/mirrord-on-aks/aks-pet-store-admin-orders.png)

Much better. This means that mirrord not only stole traffic for the `makeline-service` deployment - it also read messages from RabbitMQ and wrote new entries to MongoDB, all without messing around with configuration and credentials! It can do this because by targeting the `makeline-service` pod, it reads the environment variables and files from that pod in the cluster.


## Summary / Further Reading

In summary: if you're looking for a tool to make developing and testing Kubernetes applications easier (and faster), then give mirrord a try - it's easy and free to start using, simple to configure and powerful enough to work well with large and complex clusters. Even though the examples here are simple, mirrord has the potential to completely transform how you work on a day-to-day basis.

Of course, this post only scratches the surface of what mirrord can do. You can run it in a container, you can use it for port-forwarding to the cluster (or in reverse from the cluster), you can split Kafka and SQS queues, and so on and so forth. Stay updated on the latest features through the [MetalBear blog](https://metalbear.co/blog/) or dive straight into the [mirrord docs](https://mirrord.dev/docs/overview/introduction/) to get started. Have questions? Join our friendly [Discord server](https://discord.gg/metalbear) and say hello! For additional guidance on getting started with AKS, don’t forget to check out the [AKS documentation](https://learn.microsoft.com/en-us/azure/aks/).
