# AKS CLI Agent

AI-powered command-line experience for Azure Kubernetes Service (AKS) operations and diagnostics.

## Overview

The AKS CLI Agent is an intelligent assistant that helps you troubleshoot, optimize, and operate your AKS clusters with AI-driven insights and automated diagnostics. Built on open-source foundations with secure, local execution.

## Features

- **Context-aware troubleshooting** for common AKS issues
- **Integration with Azure CLI** authentication and RBAC
- **Local execution** - no data leaves your environment
- **Extensible architecture** for custom workflows
- **AI-powered diagnostics** with actionable recommendations

## Installation

### Prerequisites

- Azure CLI installed and configured (`az login`)
- Python 3.8 or later
- kubectl configured for your AKS cluster

### Install the CLI Agent

```bash
# Clone the repository
git clone https://github.com/Azure/AKS.git
cd AKS/cli-agent

# Install dependencies
pip install -r requirements.txt

# Install the CLI agent
pip install -e .
```

## Usage

### Basic Commands

```bash
# Get help and available commands
az aks agent --help

# General cluster health check
az aks agent "how is my cluster healthy-cluster in resource group my-rg"

# Troubleshoot node issues
az aks agent "why is one of my nodes in NotReady state?"

# Diagnose DNS problems
az aks agent "why are my pods failing DNS lookups?"

# Pod scheduling diagnostics
az aks agent "why is my pod stuck in Pending state?"

# Cluster optimization
az aks agent "how can I optimize the cost of my cluster?"
```

### Troubleshooting Scenarios

#### Node Health Issues
```bash
az aks agent "diagnose node health issues in my cluster"
```

#### DNS Failures
```bash
az aks agent "troubleshoot DNS resolution problems"
```

#### Pod Scheduling Problems
```bash
az aks agent "analyze why pods are not scheduling"
```

#### Cluster Optimization
```bash
az aks agent "provide cost optimization recommendations"
```

## Architecture

The AKS CLI Agent is built with:

- **HolmesGPT Framework**: Open-source agentic AI for Kubernetes diagnostics
- **AKS-MCP Server**: Model Context Protocol server for AKS-specific tools
- **Azure SDK**: Secure authentication and API access
- **Local Execution**: All diagnostics run on your machine

## Security

- **Azure CLI Authentication**: Uses your existing `az login` session
- **RBAC Compliance**: Respects your Azure permissions
- **Local Processing**: No cluster data sent to external services
- **Bring Your Own AI**: Configure your preferred AI provider

## Configuration

Create a configuration file at `~/.aks-agent/config.yaml`:

```yaml
ai_provider:
  type: "azure_openai"  # or "openai", "anthropic"
  endpoint: "your-azure-openai-endpoint"
  api_key: "your-api-key"

clusters:
  default_resource_group: "my-rg"
  default_cluster: "my-cluster"

logging:
  level: "INFO"
  file: "~/.aks-agent/logs/agent.log"
```

## Development

### Contributing

We welcome contributions! Please see [CONTRIBUTING.md](../CONTRIBUTING.md) for guidelines.

### Building from Source

```bash
# Clone and setup development environment
git clone https://github.com/Azure/AKS.git
cd AKS/cli-agent

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install in development mode
pip install -e .[dev]

# Run tests
python -m pytest tests/

# Run linting
flake8 src/
black src/
```

## Support

For issues and feature requests, please use the [AKS GitHub repository](https://github.com/Azure/AKS/issues).

For urgent support with your AKS clusters, please use [official Azure support channels](https://azure.microsoft.com/support/).

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE.MD) file for details.