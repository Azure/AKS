# AKS Repository - GitHub Copilot Instructions

> **Scope**: Repository-wide standards, conventions, and build commands.  
> **Module-Specific**: See `AGENTS.md` files in subdirectories.  
> **File-Specific**: See `.github/instructions/*.instructions.md` for targeted patterns.
## Repository Overview

This repository contains resources, examples, and documentation for the Azure Kubernetes Service (AKS) Engineering team:

- **Production Website**: <https://blog.aks.azure.com> (Docusaurus blog in `website/`)
- **Examples**: Real-world AKS scenarios, troubleshooting guides, and configurations
- **VHD Notes**: Node image release notes for AKS Ubuntu, Windows, Mariner, and Azure Linux
- **AI Conformance**: AKS service version compliance profiles
- **Community**: Open-source collaboration with AKS users and contributors

## Repository Structure

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

## Key Architectural Patterns & Workflows

### Website (Docusaurus 3.8.1)

Blog-only site using TypeScript/React components. See `website/AGENTS.md` for:
- Directory structure and architecture
- Build pipeline and deployment
- Component development patterns
- Cookie consent and analytics setup
- Troubleshooting common issues

See `.github/instructions/website.blog.instructions.md` for blog content guidelines.

### Examples Module

**Pattern**: Standalone YAML manifests and shell scripts demonstrating AKS features.

**Structure**:
- Each subdirectory represents a scenario (e.g., `fleet/`, `istio-based-service-mesh/`)
- Include `README.md` with: purpose, prerequisites, commands, expected output
- Shell scripts must include: `set -euo pipefail`, error handling, prerequisite validation
- No external build step required—ready for `kubectl apply` or `bash script.sh`

### VHD Notes

**Pattern**: Chronological changelog files documenting node image releases.

**File naming**: `YYYYMMDD.VV.V.txt` or date-based format (e.g., `2025-01-15.txt`).

**Content**: Package versions, patches, feature additions, listed chronologically.

## General Standards

### Code Style

- **Markdown**: Follow CommonMark spec
- **YAML**: 2-space indentation, no tabs
- **Shell scripts**: Use shellcheck-compliant bash
- **TypeScript**: Follow TypeScript ESLint recommended rules
- **React**: Functional components with hooks (no class components)

### File Naming

- **Markdown**: `kebab-case.md`
- **TypeScript/React**: `PascalCase.tsx` for components, `camelCase.ts` for utilities
- **CSS**: `kebab-case.css` or `ComponentName.module.css`
- **YAML**: `kebab-case.yaml` or `kebab-case.yml`
- **Shell scripts**: `kebab-case.sh`

### Documentation

- **README files**: Every major directory should have a README.md explaining its purpose
- **Code comments**: Explain *why*, not *what* (code should be self-documenting)
- **Examples**: Include both inline comments and accompanying README

## Build & Development

### Website (`website/`)

See `website/AGENTS.md` for detailed build instructions, troubleshooting, and validation.

```bash
cd website
npm install     # Install dependencies
npm start       # Dev server with hot reload
npm run build   # Production build (must succeed)
npm run typecheck  # TypeScript validation
```

### Examples

Most examples are standalone YAML files or scripts:

```bash
# Validate Kubernetes YAML
kubectl apply --dry-run=client -f examples/fleet/kuard/deployment.yaml

# Run example script with error handling
bash examples/kernel-1095-issue/remediate.sh
```

**Example script template**:
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

### VHD Notes

Text files documenting node image changes. No build process required.

**Update pattern**:
1. Locate directory: `vhd-notes/{image-type}/` (e.g., `AzureLinux/`, `AKSMariner/`)
2. Create/edit file: `YYYYMMDD.VV.V.txt`
3. List changes chronologically with package versions and patch details
4. Commit with: `docs(vhd-notes): update {image-type} {version}`

## Git Workflow

### Branch Strategy

- **master**: Main branch, stable code (protected)
- **Feature branches**: Short-lived, descriptive names
  - `add-fleet-examples`
  - `fix-blog-typo`
  - `docs-update-vhd-notes`

### Commit Messages

Follow Conventional Commits (https://www.conventionalcommits.org/):

```text
<type>(<scope>): <subject>
<body>
<footer>
```

**Types** (in practice):

- `feat`: New feature or post
- `fix`: Bug fix (broken links, typos, build errors)
- `docs`: Documentation changes (examples, README, VHD notes)
- `style`: Formatting (no functional change)
- `refactor`: Code restructuring
- `chore`: Maintenance tasks

**Scope examples**: `website`, `examples`, `vhd-notes`, `blog`, `github-actions`

**Real Examples from This Repo**:

```text
feat(website): add AKS MCP server blog post
Explains how to use Azure MCP servers in GitHub Copilot and Claude.
docs(examples): add Fleet Manager multi-cluster setup guide
Includes YAML manifests and setup instructions for Azure Kubernetes
Fleet Manager scenarios.
fix(website): correct broken link in webinar metadata
Updates author URL to match current GitHub profile.
```

### Pull Requests

- **Title**: Concise, follows conventional commit format
- **Description**: 
  - What changed and why
  - Link to related issues/discussions
  - Any validation steps performed
- **Testing**: Describe validation (e.g., "npm run build passed")
- **Screenshots**: Include for UI changes to website

## Azure/Kubernetes Best Practices

### YAML Manifests

```yaml
# Good: Explicit resource limits
apiVersion: v1
kind: Pod
metadata:
  name: example-pod
  labels:
    app: example
spec:
  containers:
  - name: app
    image: myregistry.azurecr.io/app:v1.2.3
    resources:
      requests:
        memory: "64Mi"
        cpu: "250m"
      limits:
        memory: "128Mi"
        cpu: "500m"
```
**Always include**:
- Resource requests and limits
- Labels for organization
- Image tags (never `:latest`)
- Security contexts where applicable

### Shell Scripts

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures
# Good: Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl not found"
    exit 1
fi
# Good: Use variables for reusability
CLUSTER_NAME="${CLUSTER_NAME:-my-aks-cluster}"
RESOURCE_GROUP="${RESOURCE_GROUP:-my-resource-group}"
```

### Documentation

- Include prerequisites (tools, versions, permissions)
- Provide example commands with placeholder values
- Explain expected outcomes
- Document troubleshooting steps

## Security & Privacy

### Secrets Management

- ❌ Never commit secrets, tokens, or credentials
- ✅ Use Azure Key Vault for sensitive data
- ✅ Use environment variables for configuration
- ✅ Add sensitive patterns to `.gitignore`

### Personal Information

- ❌ No personal email addresses (use generic team contacts)
- ❌ No customer-specific information
- ✅ Anonymize examples and logs

## Testing & Validation

### Website

See `website/AGENTS.md` for troubleshooting and the full quality checklist.

### Examples

```bash
# Validate Kubernetes YAML (dry-run)
kubectl apply --dry-run=client -f examples/*/manifest.yaml
# Lint shell scripts
shellcheck examples/*/script.sh
# Manual test (in AKS cluster)
bash examples/kernel-1095-issue/remediate.sh
```

### VHD Notes

No automated validation—manual review for:
- Correct filename format: `YYYYMMDD.VV.V.txt`
- Chronological ordering of entries
- Package versions and patch information

## Common Tasks & Workflows

### Add Blog Post

See `website/AGENTS.md` for the complete workflow and `.github/instructions/website.blog.instructions.md` for content guidelines.

### Add Example Configuration

1. Create directory: `examples/my-example/`
2. Add YAML/scripts (with `set -euo pipefail` for shells)
3. Create `README.md` with:
   - Purpose / problem being solved
   - Prerequisites (tools, cluster setup)
   - Step-by-step usage commands
   - Expected output
4. Include comments in YAML/scripts explaining non-obvious decisions
5. Test in clean environment before committing

### Update Webinar Agenda

See `website/AGENTS.md` for webinar agenda format and maintenance.

### Integration Points with External Services

1. **Azure Static Web Apps**: Website auto-deploys from `main` → `website/` output
2. **GitHub Actions**: CI/CD validates PR changes (build, typecheck, links)
3. **Analytics (GA4)**: Integrated via `src/utils/analytics.ts` (client-side)
4. **RSS/Atom Feeds**: Auto-generated at build time, available as `rss.xml` and `feed.xml`

## Support & Contact

- **Issues**: <https://github.com/Azure/AKS/issues>
- **Discussions**: <https://github.com/Azure/AKS/discussions>
- **Email**: brian.redmond@microsoft.com
- **Community Calls**: See <https://blog.aks.azure.com/webinars>

## Related Resources

- **AKS Documentation**: <https://learn.microsoft.com/azure/aks>
- **AKS Roadmap**: <https://github.com/orgs/Azure/projects/685>
- **AKS Releases**: <https://github.com/Azure/AKS/releases>
- **Troubleshooting**: <https://learn.microsoft.com/troubleshoot/azure/azure-kubernetes>

---

**Last Updated**: 2025-10-04  
**Maintainer**: AKS Engineering Team