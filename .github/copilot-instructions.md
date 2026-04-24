# AKS Repository - GitHub Copilot Instructions

> **Scope**: Repository-wide standards, conventions, and Microsoft style guide.  
> **Module-Specific**: See `AGENTS.md` files in subdirectories.  
> **File-Specific**: See `.github/instructions/*.instructions.md` for targeted patterns.

---

## Part 1: Repository Standards

### Repository Overview

This repository contains resources, examples, and documentation for the Azure Kubernetes Service (AKS) Engineering team:

- **Production Website**: <https://blog.aks.azure.com> (Docusaurus blog in `website/`)
- **Examples**: Real-world AKS scenarios, troubleshooting guides, and configurations
- **VHD Notes**: Node image release notes for AKS Ubuntu, Windows, Mariner, and Azure Linux
- **AI Conformance**: AKS service version compliance profiles
- **Community**: Open-source collaboration with AKS users and contributors

#### Repository Structure

```text
AKS/
├── .github/
│   ├── copilot-instructions.md          # This file (repo-wide standards)
│   └── instructions/                    # File-specific patterns
│       └── website.blog.instructions.md # Blog post guidelines
├── website/                             # Docusaurus blog site
│   ├── AGENTS.md                       # Website module guide
│   ├── blog/                           # Blog posts
│   ├── src/                            # React components
│   └── package.json
├── examples/                            # AKS configuration examples
│   ├── fleet/                          # Azure Kubernetes Fleet Manager
│   ├── istio-based-service-mesh/       # Service mesh examples
│   ├── kube-prometheus/                # Monitoring setup
│   └── vnet/                           # Networking examples
├── vhd-notes/                          # Node image release notes
│   ├── aks-ubuntu/
│   ├── AKSMariner/
│   ├── AKSWindows/
│   └── AzureLinux/
├── README.md
└── LICENSE.MD
```

---

### Code Style and File Naming

#### Code Style
- **Markdown**: Follow CommonMark spec
- **YAML**: 2-space indentation, no tabs
- **Shell scripts**: Use shellcheck-compliant bash with `set -euo pipefail`
- **TypeScript**: Follow TypeScript ESLint recommended rules
- **React**: Functional components with hooks (no class components)

#### File Naming
| Type | Convention | Example |
|:---|:---|:---|
| Markdown | `kebab-case.md` | `getting-started.md` |
| TypeScript/React components | `PascalCase.tsx` | `BlogPost.tsx` |
| TypeScript utilities | `camelCase.ts` | `analytics.ts` |
| CSS | `kebab-case.css` or `ComponentName.module.css` | `blog-post.module.css` |
| YAML | `kebab-case.yaml` or `.yml` | `deployment.yaml` |
| Shell scripts | `kebab-case.sh` | `remediate.sh` |
| VHD notes | `YYYYMMDD.VV.V.txt` | `202401.03.0.txt` |

---

### Build and Development

#### Website (`website/`)

See `website/AGENTS.md` for detailed build instructions and troubleshooting.

```bash
cd website
npm install        # Install dependencies
npm start          # Dev server with hot reload
npm run build      # Production build (must succeed)
npm run typecheck  # TypeScript validation
```

#### Examples

Most examples are standalone YAML files or scripts:

```bash
# Validate Kubernetes YAML
kubectl apply --dry-run=client -f examples/fleet/kuard/deployment.yaml

# Run example script
bash examples/kernel-1095-issue/remediate.sh
```

**Shell script template**:
```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found" >&2
    exit 1
fi

# Use environment variables with defaults
CLUSTER_NAME="${CLUSTER_NAME:-my-aks-cluster}"
RESOURCE_GROUP="${RESOURCE_GROUP:-my-resource-group}"
```

#### VHD Notes

Text files documenting node image changes. No build process required.

1. Locate directory: `vhd-notes/{image-type}/`
2. Create/edit file: `YYYYMMDD.VV.V.txt`
3. List changes chronologically with package versions
4. Commit with: `docs(vhd-notes): update {image-type} {version}`

---

### Git Workflow

#### Branch Strategy
- **master**: Main branch, stable code (protected)
- **Feature branches**: Short-lived, descriptive names (`add-fleet-examples`, `fix-blog-typo`)

#### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```text
<type>(<scope>): <subject>
```

| Type | Use for |
|:---|:---|
| `feat` | New feature or post |
| `fix` | Bug fix (broken links, typos, build errors) |
| `docs` | Documentation changes (examples, README, VHD notes) |
| `style` | Formatting (no functional change) |
| `refactor` | Code restructuring |
| `chore` | Maintenance tasks |

**Scope examples**: `website`, `examples`, `vhd-notes`, `blog`, `github-actions`

**Examples**:
```text
feat(website): add AKS MCP server blog post
docs(examples): add Fleet Manager multi-cluster setup guide
fix(website): correct broken link in webinar metadata
```

#### Pull Requests
- **Title**: Follows conventional commit format
- **Description**: What changed and why, link to related issues
- **Testing**: Describe validation (e.g., "npm run build passed")
- **Screenshots**: Include for UI changes

---

### Azure/Kubernetes Best Practices

#### YAML Manifests

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  labels:
    app: example
spec:
  containers:
  - name: app
    image: myregistry.azurecr.io/app:v1.2.3  # Never use :latest
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```

**Always include**: Resource requests/limits, labels, image tags (never `:latest`), security contexts where applicable.

#### Documentation Requirements
- Include prerequisites (tools, versions, permissions)
- Provide example commands with placeholder values
- Explain expected outcomes
- Document troubleshooting steps

---

### Security and Privacy

#### Secrets Management
- Never commit secrets, tokens, or credentials
- Use Azure Key Vault for sensitive data
- Use environment variables for configuration
- Add sensitive patterns to `.gitignore`

#### Personal Information
- No personal email addresses (use generic team contacts)
- No customer-specific information
- Anonymize examples and logs

---

### Support and Resources

- **Issues**: <https://github.com/Azure/AKS/issues>
- **Discussions**: <https://github.com/Azure/AKS/discussions>
- **AKS Documentation**: <https://learn.microsoft.com/azure/aks>
- **AKS Roadmap**: <https://github.com/orgs/Azure/projects/685>
- **Community Calls**: <https://blog.aks.azure.com/webinars>

---

## Part 2: Microsoft Style Guide

### Voice and Tone

The Microsoft voice is **simple and human**. Our voice hinges on crisp simplicity—bigger ideas and fewer words.

#### Three Voice Principles
*   **Warm and relaxed:** Natural, less formal, grounded in everyday conversation. Occasionally fun.
*   **Crisp and clear:** To the point. Write for scanning first, reading second. Make it simple above all.
*   **Ready to lend a hand:** Show customers we're on their side. Anticipate their needs.

#### Key Style Tips
*   **Get to the point fast:** Start with the key takeaway. Front-load keywords for scanning.
*   **Talk like a person:** Use optimistic, conversational language. Use contractions (*it's*, *you're*, *we're*, *let's*).
*   **Simpler is better:** Short sentences and fragments are easier to scan. Prune every excess word.
*   **Revise weak writing:** Start with verbs. Edit out *you can* and *there is/are/were*.

#### Examples
| Replace this | With this |
|:---|:---|
| If you're ready to purchase Office 365 for your organization, contact your Microsoft account representative. | Ready to buy? Contact us. |
| Invalid ID | You need an ID that looks like this: someone@example.com |
| Templates provide a starting point for creating new documents. A template can include the styles, formats, and page layouts you use frequently. | Save time by creating a document template that includes the styles, formats, and page layouts you use most often. |
| You can access Office apps across your devices, and you get online file storage and sharing. | Store files online, access them from all your devices, and share them with coworkers. |

### Cloud Computing Terms

**Azure**: Capitalize.
**back end, back-end**: Two words as a noun. Hyphenate as an adjective (*back-end services*).
**bandwidth**: One word.
**cloud, the cloud**: Don't capitalize unless referring to *Microsoft Cloud* or a product name. Use mostly as an adjective (*cloud services*). Avoid using *the cloud* as a noun—talk about *cloud computing* or *cloud services* instead.
**cloud computing**: Lowercase. Two words. Use instead of *the cloud*.
**cloud native, cloud-native**: Lowercase. Hyphenate as an adjective (*cloud-native app*). Don't use *born in the cloud*.
**content delivery network**: Lowercase. Always spell out; don't use *CDN*.
**cross-platform**: Hyphenate.
**data center**: Two words.
**edge, edge computing**: Lowercase. Use *at the edge*, not *on the edge*.
**front-end, front end**: Hyphenate as an adjective (*front-end development*). Two words as a noun.
**hybrid cloud**: Define on first mention for non-technical audiences.
**infrastructure as a service (IaaS)**: Technical audiences only. Don't capitalize as *IAAS*. Don't hyphenate as a modifier.
**the Microsoft Cloud**: Capitalize. Refers to the entire Microsoft cloud platform (Azure, Dynamics 365, Microsoft 365, etc.). Include *the* before it.
**multicloud**: One word, no hyphen. Use for technical audiences.
**multitenant, multitenancy**: One word, no hyphen.
**on-premises, off-premises**: Hyphenate in all positions. *Premises* is plural—never use *on-premise*.
**open source**: Noun. Hyphenate as an adjective (*open-source software*).
**platform as a service (PaaS)**: Technical audiences only. Don't capitalize as *PAAS*.
**server-side**: Hyphenate as an adjective.
**serverless**: One word, no hyphen.
**software as a service (SaaS)**: Don't capitalize as *SAAS*. Don't hyphenate as a modifier.
**third-party**: Hyphenate as an adjective. Two words as a noun (*third party*).

### Kubernetes Terms

#### Core Concepts
**cluster**: Lowercase. A set of nodes that run containerized applications managed by Kubernetes.
**node**: Lowercase. A worker machine in Kubernetes (physical or virtual).
**pod**: Lowercase. The smallest deployable unit in Kubernetes, containing one or more containers.
**container**: Lowercase. A lightweight, standalone executable package that includes everything needed to run an application.
**namespace**: Lowercase. A way to divide cluster resources between multiple users or projects.
**workload**: Lowercase. An application running on Kubernetes.
**object**: Lowercase. An entity in the Kubernetes system representing cluster state (e.g., Pod, Service, Deployment).
**spec**: Lowercase. Defines how each object should be configured and its desired state.
**status**: Lowercase. The current state of a Kubernetes object, managed by the system.
**name**: Lowercase. A client-provided string that uniquely identifies an object within a namespace.
**UID**: Uppercase. A Kubernetes-generated string to uniquely identify objects across the cluster.
**API group**: Lowercase. A set of related paths in the Kubernetes API.
**API server, kube-apiserver**: Lowercase. The control plane component that exposes the Kubernetes API.

#### Workload Resources
**Deployment**: Capitalize when referring to the Kubernetes resource type. Manages a replicated application.
**ReplicaSet**: One word, capitalize. Ensures a specified number of pod replicas are running.
**StatefulSet**: One word, capitalize. Manages stateful applications with stable network identifiers.
**DaemonSet**: One word, capitalize. Ensures all (or some) nodes run a copy of a pod.
**Job**: Capitalize when referring to the Kubernetes resource. Creates one or more pods and ensures successful completion.
**CronJob**: One word, capitalize. Creates Jobs on a repeating schedule.
**replica**: Lowercase. A copy or duplicate of a pod for high availability and scalability.
**init container**: Lowercase. One or more initialization containers that must run to completion before app containers start.
**sidecar container**: Lowercase. One or more containers typically started before app containers to provide supporting features.
**ephemeral container**: Lowercase. A temporary container type for debugging running pods.

#### Service and Networking
**Service**: Capitalize when referring to the Kubernetes resource type. An abstract way to expose an application running on pods.
**Ingress**: Capitalize. Manages external access to services, typically HTTP.
**Ingress controller**: *Ingress* capitalized, *controller* lowercase. A component that implements Ingress rules.
**load balancer**: Lowercase. Distributes network traffic across multiple servers.
**ClusterIP**: One word, capitalize. Default service type, exposes service on internal cluster IP.
**NodePort**: One word, capitalize. Exposes service on each node's IP at a static port.
**LoadBalancer**: One word, capitalize when referring to the Kubernetes service type.
**NetworkPolicy**: One word, capitalize. Specifies how pods are allowed to communicate with each other and other network endpoints.
**EndpointSlice**: One word, capitalize. A scalable way to track network endpoints for a Service.
**Gateway API**: Capitalize both words. A family of API kinds for modeling service networking.
**DNS**: Uppercase. Cluster-wide DNS resolution for services and pods.
**CNI (Container Network Interface)**: Spell out on first mention. The standard for network plugins in Kubernetes.

#### Configuration and Storage
**ConfigMap**: One word, capitalize. Stores non-confidential configuration data as key-value pairs.
**Secret**: Capitalize when referring to the Kubernetes resource. Stores sensitive information like passwords and tokens.
**PersistentVolume (PV)**: One word, capitalize. A piece of storage in the cluster provisioned by an administrator.
**PersistentVolumeClaim (PVC)**: One word, capitalize. A request for storage by a user.
**StorageClass**: One word, capitalize. Describes the "classes" of storage available.
**Volume**: Capitalize when referring to the Kubernetes resource. A directory containing data accessible to containers in a pod.
**CSI (Container Storage Interface)**: Spell out on first mention. The standard for storage plugins in Kubernetes.
**emptyDir**: One word, camelCase. A temporary volume that shares a pod's lifetime.
**hostPath**: One word, camelCase. Mounts a file or directory from the host node's filesystem.
**container environment variables**: Lowercase. Name-value pairs providing configuration to containers.

#### Azure Kubernetes Service (AKS)
**Azure Kubernetes Service (AKS)**: Spell out on first mention, then use *AKS*. Don't use *Azure Container Service*.
**node pool**: Two words, lowercase. A group of nodes with the same configuration in AKS.
**system node pool**: Lowercase. Hosts critical system pods.
**user node pool**: Lowercase. Hosts application workloads.
**virtual nodes**: Lowercase. Enable scaling with Azure Container Instances.
**managed identity**: Lowercase. Azure-managed credentials for AKS clusters.
**Azure CNI**: Capitalize *Azure*, uppercase *CNI*. Azure's container network interface implementation.
**kubenet**: Lowercase. Basic network plugin that creates a bridge and allocates IP addresses.
**KEDA (Kubernetes Event-driven Autoscaling)**: Spell out on first mention. Event-driven pod autoscaling for AKS.
**cluster autoscaler**: Lowercase. Automatically adjusts node pool size based on demand.
**Horizontal Pod Autoscaler (HPA)**: Capitalize resource name. Scales pod replicas based on metrics.
**Vertical Pod Autoscaler (VPA)**: Capitalize resource name. Adjusts resource requests and limits for containers.
**Azure Policy for AKS**: Capitalize *Azure Policy*. Enforces governance policies on AKS clusters.
**Azure Monitor for containers**: Capitalize *Azure Monitor*. Monitoring solution for AKS clusters.
**Microsoft Defender for Containers**: Capitalize. Security solution for containerized environments.

#### Tools and Commands
**kubectl**: Lowercase. The Kubernetes command-line tool. Pronounced "kube control" or "kube C-T-L".
**Helm**: Capitalize. A package manager for Kubernetes.
**Helm chart**: *Helm* capitalized, *chart* lowercase. A collection of files describing Kubernetes resources.
**kubeconfig**: Lowercase. Configuration file for kubectl to access clusters.
**Kustomize**: Capitalize. A tool for customizing Kubernetes configurations.
**k9s**: Lowercase. A terminal-based UI for managing Kubernetes clusters.
**Azure CLI, az**: Capitalize *Azure CLI*. Lowercase *az* command. Azure command-line interface for AKS management.

#### Other Kubernetes Terms
**control plane**: Two words, lowercase. The container orchestration layer that manages the cluster.
**kubelet**: Lowercase. An agent that runs on each node ensuring containers are running in a pod.
**kube-proxy**: Lowercase, hyphenated. Network proxy that runs on each node.
**etcd**: Lowercase. Consistent and highly available key-value store for cluster data.
**container runtime**: Lowercase. Software responsible for running containers (e.g., containerd).
**manifest**: Lowercase. A YAML or JSON file that defines Kubernetes resources.
**label**: Lowercase. Key-value pairs attached to objects for identification.
**annotation**: Lowercase. Key-value pairs for attaching non-identifying metadata.
**selector**: Lowercase. Used to filter resources based on labels.
**rolling update**: Lowercase. A deployment strategy that gradually replaces pod instances.
**liveness probe, readiness probe, startup probe**: Lowercase. Diagnostic checks that kubelet performs on containers.
**kube-controller-manager**: Lowercase, hyphenated. Control plane component that runs controller processes.
**kube-scheduler**: Lowercase, hyphenated. Control plane component that assigns pods to nodes.
**cloud-controller-manager**: Lowercase, hyphenated. Control plane component that integrates with cloud providers.
**controller**: Lowercase. A control loop that watches cluster state and makes changes to move toward desired state.
**CustomResourceDefinition (CRD)**: One word, capitalize. Defines a new custom API to extend Kubernetes.
**custom resource**: Lowercase. An extension of the Kubernetes API defined by a CRD.
**Operator**: Capitalize. A method of packaging, deploying, and managing a Kubernetes application using custom resources.
**ServiceAccount**: One word, capitalize. Provides an identity for processes running in a pod.
**RBAC (Role-Based Access Control)**: Spell out on first mention. Manages authorization through the Kubernetes API.
**Role, ClusterRole**: Capitalize. Define permissions within a namespace (Role) or cluster-wide (ClusterRole).
**RoleBinding, ClusterRoleBinding**: One word, capitalize. Grant permissions defined in a Role or ClusterRole.
**taint**: Lowercase. Prevents pods from being scheduled on a node unless they tolerate the taint.
**toleration**: Lowercase. Allows a pod to be scheduled on a node with a matching taint.
**affinity**: Lowercase. Rules that give hints to the scheduler about where to place pods.
**node affinity**: Lowercase. Constrains which nodes a pod can be scheduled on based on node labels.
**pod affinity, pod anti-affinity**: Lowercase. Constrains pod placement based on labels of other pods.
**PodDisruptionBudget (PDB)**: One word, capitalize. Limits the number of pods that can be down simultaneously.
**ResourceQuota**: One word, capitalize. Constrains aggregate resource consumption per namespace.
**LimitRange**: One word, capitalize. Constrains resource consumption per container or pod in a namespace.
**QoS class (Quality of Service class)**: Lowercase *class*. Classifies pods for scheduling and eviction decisions (Guaranteed, Burstable, BestEffort).
**finalizer**: Lowercase. A namespaced key that delays deletion until specific conditions are met.
**garbage collection**: Lowercase. Mechanisms Kubernetes uses to clean up cluster resources.
**drain**: Lowercase. The process of safely evicting pods from a node for maintenance.
**cordon**: Lowercase. Marks a node as unschedulable without evicting existing pods.
**eviction**: Lowercase. The process of terminating pods on a node.
**preemption**: Lowercase. Terminating lower-priority pods to make room for higher-priority pods.
**priority class**: Lowercase. Defines the priority of a pod relative to other pods.
**static pod**: Lowercase. A pod managed directly by the kubelet on a specific node.
**mirror pod**: Lowercase. A pod object representing a static pod in the API server.
**event**: Lowercase. A Kubernetes object describing state changes or notable occurrences.
**feature gate**: Lowercase. A set of keys to control which Kubernetes features are enabled.
**containerd**: Lowercase. An industry-standard container runtime.
**CRI-O**: Uppercase CRI, uppercase O. A lightweight container runtime for Kubernetes.
**cgroup (control group)**: Lowercase. A Linux kernel feature for resource isolation and limits.
**Pod lifecycle**: *Pod* capitalized. The sequence of states a pod passes through during its lifetime.
**image**: Lowercase. A stored instance of a container holding software needed to run an application.
**image pull policy**: Lowercase. Determines when the kubelet pulls a container image (Always, IfNotPresent, Never).

### Computer and Device Terms

#### Devices
**device, mobile device**: Use *device* as a general term for all computers, phones, and devices. Use *mobile device* only when calling out mobility.
**computer, PC**: Use *computer* when talking about computing devices other than phones. *PC* is OK when space is limited.
**phone, mobile phone, smartphone**: Use *phone* most of the time. Use *smartphone* only to distinguish from other phones. Don't use *cell phone* or *cellular phone*.
**tablet, laptop**: Use only when talking about specific classes of computers.
**Mac**: Capitalize.
**touchscreen**: One word.

#### Hardware Actions
**turn on, turn off**: Use instead of *power on/off*, *switch on/off*, *enable/disable* for features or settings.
**restart**: Use instead of *reboot*.
**set up, setup**: *Set up* (two words) is a verb. *Setup* is a noun or adjective.
**start up, startup**: *Start up* is a verb. *Startup* is a noun or adjective.
**install, uninstall**: Use for adding and removing hardware drivers and apps.
**connect, disconnect**: Use for relationships between devices or network connections.
**back up, backup**: *Back up* is a verb. *Backup* is a noun or adjective.
**download, upload**: Use as verbs. Avoid using *download* as a noun to refer to the file itself (use *file*).
**sync**: Acceptable abbreviation for *synchronize*.

#### UI Elements
**button**: Do not use *button* in instructions unless necessary for clarity (e.g., *Select Save*, not *Select the Save button*).
**checkbox**: One word.
**check mark**: Two words.
**combo box**: Two words.
**context menu**: Avoid. Use *shortcut menu*.
**desktop**: Use to refer to the working area of the screen. Do not use to refer to a computer (use *computer* or *PC*).
**dialog**: Use *dialog*, not *dialog box*.
**drop-down**: Adjective. Use *drop-down list* for the noun.
**menu bar**: Two words.
**pop-up**: Hyphenate as an adjective or noun.
**scroll bar**: Two words.
**status bar**: Two words.
**submenu**: One word.
**system tray**: Avoid. Use *notification area*.
**tab**: Use bold for tab names.
**taskbar**: One word.
**text box**: Two words.
**title bar**: Two words.
**toolbar**: One word.
**tooltip**: One word.
**wizard**: Lowercase unless part of a feature name.

#### Files and Folders
**browse**: Use *browse* to refer to looking for files.
**file name**: Two words.
**folder**: Use *folder*, not *directory*, in Windows contexts.
**disk**: Use *disk* for magnetic media (hard disk). Use *disc* for optical media (CD, DVD).
**hard drive**: Use instead of *hard disk*.
**screenshot**: One word.

### Keys and Keyboard Shortcuts

#### Terminology
*   **keyboard shortcut**: Use to describe a combination of keystrokes (e.g., *Ctrl+V*). Don't use *accelerator key*, *fast key*, *hot key*, *quick key*, or *speed key*.
*   **select**: Use to describe pressing a key. Don't use *press*, *depress*, *hit*, or *strike*.

#### Key Names
Capitalize key names: *Enter*, *Shift*, *Esc*, *Tab*, *Spacebar*, *Backspace*, *Delete*, *Ctrl*, *Alt*, *Home*, *End*, *Page up*, *Page down*, *F1–F12*, *Windows logo key*.

#### Key Combinations
*   Use the plus sign (+) with no spaces: *Ctrl+V*, *Alt+F4*, *Ctrl+Shift+Esc*.
*   Spell out: *Plus sign*, *Minus sign*, *Hyphen*, *Period*, *Comma* to avoid confusion.
*   For arrow keys, use: *Left arrow key*, *Right arrow key*, *Up arrow key*, *Down arrow key*.

### Security Terms

**antimalware, antivirus, antispyware, antiphishing**: Use only as adjectives.
**attacker, malicious hacker, unauthorized user**: Use instead of *hacker* in content for general audiences.
**authentication**: Lowercase.
**blocklist**: Use instead of *blacklist*.
**allowlist**: Use instead of *whitelist*.
**cybersecurity**: One word.
**firewall**: One word.
**malware, malicious software**: Use *malware* to describe unwanted software (viruses, worms, trojans). Define on first mention if needed.
**sign in, sign out**: Use instead of *log on/off*, *log in/out*, *login/logout*.
**vulnerability**: Use modifiers to specify type (product vulnerability, administrative vulnerability, physical vulnerability).

### Web and Internet Terms

**blog**: Lowercase.
**browser**: Lowercase.
**e-book**: Hyphenate.
**e-commerce**: Hyphenate.
**email**: One word, no hyphen. Do not use *e-mail*.
**homepage**: One word.
**inbox**: One word.
**internet**: Lowercase.
**intranet**: Lowercase.
**offline**: One word.
**online**: One word.
**web**: Lowercase.
**webpage**: One word.
**website**: One word.
**Wi-Fi**: Hyphenate. Capitalize.

### Mouse Interactions

Most of the time, don't talk about the mouse—use input-neutral terms like *select*.

**click**: Use to describe selecting an item with the mouse. Don't use *click on*.
**double-click**: Hyphenate. Don't use *double-click on*.
**drag**: Use for holding a button while moving the mouse. Don't use *click and drag* or *drag and drop*.
**hover over, point to**: Use to describe moving the pointer over an element without selecting it. Don't use *mouse over*.
**right-click**: Use for clicking with the secondary mouse button.
**pointer**: Use to refer to the on-screen pointer. Use *cursor* only for the text insertion point.
**scroll**: Use for moving content using a scroll bar or mouse wheel.
**zoom in, zoom out**: Verbs for changing magnification.

### Touch and Pen Interactions

Use input-neutral terms when possible. For touch-specific content:

**tap**: Use instead of *click*. Don't use *tap on*.
**double-tap**: Hyphenate. Use instead of *double-click*. Don't use *double-tap on*.
**tap and hold**: Use only if required by the software. Don't use *touch and hold*.
**flick**: Use to describe moving fingers to scroll through items. Don't use *scroll*.
**pan**: Use for moving the screen in multiple directions at a controlled rate. Don't use *drag* or *scroll*.
**pinch, stretch**: Use to describe zooming in/out with two fingers.
**swipe**: Use for a short, quick movement opposite to scroll direction.
**select and hold**: Use to describe pressing and holding an element.

### Developer and Technical Terms

#### Programming
**add-in**: Hyphenate.
**app**: Use *app* instead of *application* for modern Windows apps and mobile apps.
**cmdlet**: Lowercase.
**dataset**: One word.
**GitHub**: Capitalize G and H.
**JavaScript**: One word, capital J and S.
**metadata**: One word.
**.NET**: Always starts with a dot and is capitalized.
**plug-in**: Hyphenate.
**PowerShell**: One word, capital P and S.
**real-time**: Hyphenate as an adjective. Two words as a noun (*real time*).
**style sheet**: Two words.
**workgroup**: One word.

#### Protocols and Standards
**DNS**: Domain Name System.
**FTP**: File Transfer Protocol.
**HTML**: Hypertext Markup Language.
**HTTP, HTTPS**: Hypertext Transfer Protocol, Hypertext Transfer Protocol Secure.
**I/O**: Input/output.
**IP address**: Internet Protocol address.
**OS**: Operating system.
**PDF**: Portable Document Format.
**SQL**: Structured Query Language. Pronounced as letters or "sequel". Use *a SQL database*.
**SSL**: Secure Sockets Layer.
**UI**: User interface.
**URL**: Uniform Resource Locator.

#### Products and Platforms
**Bluetooth**: Capitalize.
**Control Panel**: Capitalize.
**Cortana**: Capitalize.

### Dates and Times

#### Dates
*   Use format: *Month Day, Year* (e.g., *July 31, 2016*).
*   Don't use ordinals (*1st*, *12th*, *23rd*) for dates.
*   Capitalize days of the week and months.
*   Abbreviate only when space is limited: *Sun*, *Mon*, *Tue*, *Wed*, *Thu*, *Fri*, *Sat*; *Jan*, *Feb*, *Mar*, etc.

#### Times
*   Use numerals with AM/PM: *2:00 PM*, *7:30 AM*.
*   Use *noon* and *midnight*, not *12:00 PM* or *12:00 AM*.
*   Include time zone when relevant. Capitalize: *Pacific Time*, *Eastern Time*.
*   For ranges, use *to* in text (*10:00 AM to 2:00 PM*) and en dash in schedules (*10:00 AM–2:00 PM*).

### Units of Measure

*   Use numerals for all measurements, even under 10: *3 ft*, *5 in.*, *1.76 lb*.
*   Insert a space between number and unit: *13.5 inches*, *8.0 MP*.
*   Hyphenate when modifying a noun: *13.5-inch display*, *8.0-MP camera*.
*   Use commas in numbers with four or more digits: *1,093 MB*.
*   Use singular for 1, plural for all other numbers: *1 point*, *0.5 points*, *12 points*.
*   Spell out *by* in dimensions, except use × for tile sizes, screen resolutions, and paper sizes: *10 by 12 ft room*, *1280 × 1024*.

#### Common Abbreviations
| Term | Abbreviation |
|:---|:---|
| gigabyte | GB |
| megabyte | MB |
| kilobyte | KB |
| terabyte | TB |
| gigahertz | GHz |
| megahertz | MHz |
| pixels per inch | PPI |
| dots per inch | dpi |

### Lists

#### Bulleted Lists
*   Use for items that have something in common but don't need a particular order.
*   Each item should have a consistent structure (all nouns, all verb phrases, etc.).

#### Numbered Lists
*   Use for sequential items (procedures) or prioritized items (top 10 lists).
*   Use no more than 7 steps.

#### Formatting
*   Capitalize the first word of each list item.
*   Don't use semicolons, commas, or conjunctions at the end of list items.
*   Don't use periods unless items are complete sentences.
*   If list items complete an introductory fragment ending with a colon, use periods after all items if any form a complete sentence.

### Common Spelling and Usage

#### Prefixes
**auto-**: Hyphenate if the stem word is capitalized or to avoid confusion.
**multi-**: Generally do not hyphenate words beginning with *multi* (e.g., *multicast*, *multifactor*).
**non-**: Hyphenate if the stem word is capitalized (e.g., *non-Microsoft*) or to avoid confusion.

#### Capitalization
**account, administrator, beta, client**: Lowercase.
**administrator**: Use *administrator*, not *admin*, unless space is limited.
**OK**: All caps. Do not use *Okay* or *ok*.
**ZIP Code**: Capitalize *ZIP* and *Code*.

#### Word Forms
**bit, byte**: Spell out unless in a measurement with a number (e.g., *32-bit*).
**cursor**: Use *pointer* for the mouse. Use *cursor* for the insertion point in text.
**user**: Avoid if possible. Use *you* to address the reader.
**end user**: Avoid. Use *customer*, *user*, or *you*.
**host name, user name, time zone, knowledge base**: Two words.
**x-axis, y-axis**: Hyphenate. Lowercase.

#### Phrases to Avoid
| Avoid | Use instead |
|:---|:---|
| access key, hotkey | keyboard shortcut |
| click | select |
| etc. | and so on |
| ex. | for example |
| FAQ | frequently asked questions |
| i.e. | that is |
| native | (use carefully) |
| uncheck | clear (e.g., *clear the checkbox*) |
| vs. | vs. (with period) |

#### Ensure vs. Insure
*Ensure* means to make sure something happens. *Insure* refers to insurance.

### Headings

*   Use sentence-style capitalization.
*   Keep headings short—ideally one line.
*   Don't end headings with periods. Question marks and exclamation points are OK if needed.
*   Use parallel structure for headings at the same level.
*   Don't use ampersands (&) or plus signs (+) unless referring to UI.
*   Avoid hyphens in headings (can cause awkward line breaks).
*   Use *vs.*, not *v.* or *versus*.

### Topic Guidelines

#### Accessibility
*   **People-first language:** Refer to the person first, then the disability. Use *person with a disability*, not *disabled person*. Some communities prefer identity-first language—defer to their preferences.
*   **Input-neutral verbs:** Use verbs that apply to all input methods (mouse, touch, keyboard). Use *select* instead of *click* or *tap*.
*   **Alt text:** Provide meaningful alt text for images.
*   **Links:** Use descriptive link text (not *click here*).
*   **Keyboard procedures:** Always document keyboard procedures, even if indicated in the UI.

##### Preferred Terms
| Preferred (people-first) | Acceptable (identity-first) | Do not use |
|:---|:---|:---|
| Person who is blind, person with low vision | Blind person | Sight-impaired, vision-impaired |
| Person who is deaf, person with a hearing disability | Deaf person | Hearing-impaired |
| Person with limited mobility | Physically disabled person, wheelchair user | Crippled, lame, handicapped |
| Is unable to speak, uses sign language | — | Dumb, mute |
| Has multiple sclerosis, cerebral palsy | — | Affected by, stricken with, suffers from, a victim of |
| Person without a disability | Non-disabled person | Normal person, healthy person |
| Person with a disability | Disabled person | The handicapped, people with handicaps |
| Person with cognitive disabilities | Learning disabled | Slow learner, mentally handicapped, special needs |

#### Acronyms
*   **Spell out:** Spell out acronyms on the first mention, followed by the acronym in parentheses.
*   **Plurals:** Add *s* to make an acronym plural (e.g., *APIs*). Do not use an apostrophe.
*   **Possessives:** Avoid using the possessive form of an acronym.
*   **Common acronyms:** Some acronyms (USB, URL, FAQ) do not need to be spelled out.
*   **Articles:** Use *a* or *an* depending on pronunciation (e.g., *a URL*, *an ISP*).
*   **Titles:** Avoid using acronyms in titles unless they are keywords.

#### Bias-free Communication
*   **Gender-neutral:** Use *you* or *they* instead of *he/she*. Avoid gendered terms like *chairman* (use *chair*) or *manpower* (use *workforce*).
*   **Inclusive language:** Avoid terms like *master/slave* (use *primary/secondary*), *whitelist/blacklist* (use *allowlist/blocklist*).
*   **Militaristic language:** Avoid terms like *kill chain*, *DMZ* (use *perimeter network*), *abort*, *terminate*.
*   **Focus on people:** Focus on people, not disabilities. Don't use words that imply pity (*suffering from*).
*   **Diversity:** Use diverse names and examples in fictitious scenarios.

#### Capitalization
*   **Sentence-style:** Use sentence-style capitalization for titles, headings, and UI labels (capitalize only the first word and proper nouns).
*   **Proper nouns:** Capitalize product names and proper nouns.
*   **Acronyms:** Do not capitalize the spelled-out form of an acronym unless it is a proper noun.
*   **All caps:** Do not use all caps for emphasis.
*   **Internal capitalization:** Do not use internal capitalization (e.g., *e-Book*) unless it is part of a brand name.

#### Chatbots
*   **Terminology:** Use *bot* or *virtual agent*. Do not use *robot*.
*   **Transparency:** Make it clear to the user that they are interacting with a bot.
*   **Tone:** Adapt the tone to the context (empathetic for support, casual for chat).
*   **Confirm intent:** Confirm the customer's intent before acting.
*   **Break up messages:** Break up long messages into separate, readable blocks.
*   **Closure:** Mimic the sense of closure in human interactions (e.g., "Is there anything else?").

#### Developer Content
*   **Code style:** Use code style (monospace) for keywords, variable names, and code snippets.
*   **Code examples:** Provide concise, secure, and copy-pasteable code examples. Explain the scenario and requirements.
*   **Reference docs:** Follow a consistent structure (Description, Syntax, Parameters, Return Value, Examples).
*   **Formatting:** Use consistent formatting for elements like *Classes*, *Methods*, *Parameters*.

#### Global Communications
*   **Idioms:** Avoid idioms and colloquialisms that may be hard to translate.
*   **Currency:** Use the currency code (e.g., *USD*) when referring to specific amounts.
*   **Date format:** Use *Month Day, Year* (e.g., *July 31, 2016*) to avoid ambiguity.
*   **Art:** Choose simple, generic images. Avoid hand signs and holiday images.
*   **Names:** Use *First name* and *Last name* or *Full name*. Use *Title* instead of *Honorific*.
*   **Time and place:** Include time zones. Use *Country/Region*.

#### Grammar
*   **Voice:** Use active voice (where the subject performs the action). Passive voice is OK occasionally for variety or to emphasize the action.
*   **Tense:** Use present tense. Avoid *will*, *was*, and verbs ending in *-ed*.
*   **Mood:** Use indicative mood for statements of fact. Use imperative mood for procedures. Use subjunctive mood sparingly.
*   **Person:** Use second person (*you*) to address the user. Don't use *he* or *she* in generic references—use *you*, *they*, or refer to a role.
*   **Contractions:** Use common contractions (*it's*, *you're*, *don't*, *we're*, *let's*). Don't form contractions from nouns and verbs (*Microsoft's developing*).
*   **Verbs:** Use precise verbs. Start statements with verbs. Edit out *you can*, *there is*, *there are*, *there were*.
*   **Modifiers:** Keep modifiers close to the words they modify. Place *only* carefully.
*   **Words ending in -ing:** Be clear about the role (verb, adjective, or noun). *Meeting requirements* could mean discussing requirements or fulfilling them.
*   **Prepositional phrases:** Avoid consecutive prepositional phrases. They're hard to read.

#### Numbers
##### Spell Out (Zero–Nine)
*   Whole numbers zero through nine, unless space is limited.
*   One of the numbers when two numbers from separate categories appear together (*two 3-page articles*).
*   At the beginning of a sentence.
*   Ordinal numbers (*first*, *second*). Don't add *-ly* (*firstly*).

##### Use Numerals
*   Numbers 10 or greater.
*   Numbers in UI.
*   Measurements (distance, temperature, volume, weight, pixels, points).
*   Time of day (*7:30 AM*).
*   Percentages (*5%*)—use the percent sign with numerals.
*   Dimensions. Use × for tile sizes, screen resolutions, paper sizes (*1280 × 1024*).
*   Numbers customers are directed to type.
*   Round numbers of 1 million or more (*1.5 million*).

##### Commas
*   Use in numbers with four or more digits (*1,000*, *10,000*).
*   Exception: For years and baud, use commas only with five or more digits (*2024*, *14,400 baud*).
*   Don't use in page numbers, street addresses, or decimal fractions.

##### Ranges
*   Use *from* and *through* in text (*from 10 through 15*).
*   Use en dash in tables, UI, or where space is limited (*10–15*).
*   Don't use *from* before an en dash range.

##### Fractions and Decimals
*   Hyphenate spelled-out fractions (*one-third*, but *three sixty-fourths*).
*   Include a zero before decimals less than one (*0.5*) unless the customer types the value.
*   Align decimals on the decimal point in tables.

#### Procedures and Instructions
*   **Steps:** Use numbered lists for steps. Limit to 7 steps. Write a complete sentence for each step.
*   **Verbs:** Start each step with an imperative verb.
*   **Formatting:** Use **bold** for UI elements (buttons, menus, dialog names). Don't use quotes or italics.
*   **Single steps:** Use a bullet instead of the number 1.
*   **Menu sequences:** Use right angle brackets with spaces: *Select **Accounts** > **Other accounts** > **Add an account***.

##### Input-Neutral Verbs
| Verb | Use for |
|:---|:---|
| Open | Apps, shortcut menus, files, folders |
| Close | Apps, dialog boxes, windows, files, folders |
| Leave | Websites and webpages |
| Go to | A menu or place in the UI (search, ribbon, tab) |
| Select | UI options, values, links, menu items |
| Select and hold | Pressing and holding an element for about a second |
| Clear | Removing the selection from a checkbox |
| Choose | An exclusive option where only one value can be chosen |
| Enter | Instructing the reader to type or enter a value |
| Move | Moving something from one place to another |
| Zoom, zoom in, zoom out | Changing magnification |

*   **Avoid:** *press*, *press and hold*, *right-click*, *click*, *tap* (unless input-specific).

##### Example
1.  Go to **Settings**.
2.  Select **Accounts**.
3.  Enter your password.
4.  Select **Save**.

#### Punctuation
*   **Commas:** Use the Oxford comma (comma before the conjunction in a list of three or more items). Use after introductory phrases and to join independent clauses with a conjunction.
*   **Periods:** Use one space after a period. Skip periods on headings, titles, subheadings, and list items that are three words or fewer.
*   **Semicolons:** Avoid. Break into separate sentences or use a list.
*   **Hyphens:** Use for compound adjectives (*sign-in page*, *real-time data*). Don't use unless leaving them out causes confusion.
*   **Em dashes (—):** Use without spaces for breaks in thought.
*   **En dashes (–):** Use for ranges (*10–15*) without spaces. Don't use *from* before an en dash range.
*   **Colons:** Use to introduce a list. Lowercase the word after a colon unless it's a proper noun or the start of a quotation.
*   **Exclamation points:** Use sparingly. Save for when they count.
*   **Question marks:** Use sparingly. Customers expect answers.
*   **Quotation marks:** Place closing quotes outside commas and periods, inside other punctuation.
*   **Apostrophes:** Use for contractions (*don't*) and possessives (*Insider's Guide*). Don't use for the possessive of *it* (*its*).
*   **Slashes:** Don't use as a substitute for *or*. OK for *Country/Region* where space is limited.

#### Responsive Content
*   **Paragraphs:** Keep paragraphs short (3-7 lines).
*   **Headings:** Keep headings short and scannable (one line).
*   **Short sections:** Break content into short sections.
*   **Tables:** Limit the number of columns.

#### Text Formatting
*   **Bold:** Use bold for UI elements.
*   **Italic:** Use italic for the first mention of a new term, or for book titles.
*   **Capitalization:** Do not use all caps for emphasis.
*   **Left alignment:** Use left alignment. Do not center text.
*   **Line spacing:** Do not compress line spacing.

#### URLs
*   **Format:** Use lowercase for URLs. Omit *http://www* if possible (e.g., *microsoft.com*).
*   **Link text:** Use descriptive link text (e.g., *Go to the Windows page*), not *click here*.
*   **Protocol:** Don't include *https://* unless it's not HTTP.
*   **Trailing slash:** Omit the trailing slash.

#### Word Choice
*   **Simple words:** Use simple, everyday words (*use* instead of *utilize*, *try* instead of *attempt to*).
*   **Consistency:** Use the same term for the same concept throughout.
*   **Jargon:** Avoid jargon unless the audience is technical.
*   **Contractions:** Use common contractions to sound friendly.
*   **Technical terms:** Define in context if the audience might not understand. Use plain language when possible.
*   **Avoid ambiguity:** Don't use words with multiple meanings. Don't give technical meanings to common words (*bucket* to mean *group*).
*   **Don't create new words:** Research existing terminology before creating new terms.
*   **Don't personify:** Don't attribute human characteristics to devices and products. They don't *think*, *feel*, *want*, or *see*.

##### Common Replacements
| Replace | With |
|:---|:---|
| utilize | use |
| attempt to | try |
| in order to | to |
| a number of | several, many |
| due to the fact that | because |
| prior to | before |
| subsequent to | after |
| in the event that | if |
| leverage | use |
| facilitate | help, make possible |
