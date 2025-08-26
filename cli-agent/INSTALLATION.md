# Installation Guide - AKS CLI Agent

This guide covers different ways to install and use the AKS CLI Agent.

## Quick Start (Demo Mode)

For a quick demonstration of the AKS CLI Agent capabilities:

```bash
# Clone the repository
git clone https://github.com/Azure/AKS.git
cd AKS

# Run the demo CLI
./az-aks-agent.sh --help
./az-aks-agent.sh status
./az-aks-agent.sh "why is my node not ready?"
```

## Full Installation

### Prerequisites

1. **Azure CLI** - Install from [Azure CLI documentation](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Python 3.8+** - Required for full AI-powered features
3. **kubectl** - For Kubernetes cluster access
4. **AKS cluster access** - Via `az aks get-credentials`

### Step 1: Install Python Dependencies

```bash
cd AKS/cli-agent
pip install -r requirements.txt
```

### Step 2: Install the CLI Agent

```bash
# Install in development mode
pip install -e .

# Or install from source
pip install .
```

### Step 3: Azure CLI Authentication

```bash
# Login to Azure
az login

# Set your subscription (if you have multiple)
az account set --subscription "your-subscription-id"

# Get AKS cluster credentials
az aks get-credentials --resource-group your-rg --name your-cluster
```

### Step 4: Configure the Agent

```bash
# Check status
aks-agent status

# Interactive configuration
aks-agent configure
```

## Azure CLI Extension Integration

### Option 1: Shell Alias (Recommended for Testing)

Add to your shell profile (`~/.bashrc`, `~/.zshrc`, etc.):

```bash
# Add AKS Agent as 'az aks agent' command
alias az='function _az() { 
    if [[ "$1" == "aks" && "$2" == "agent" ]]; then 
        shift 2; 
        /path/to/AKS/az-aks-agent.sh "$@"; 
    else 
        command az "$@"; 
    fi; 
}; _az'
```

### Option 2: Azure CLI Extension (Advanced)

For organizations wanting to distribute the AKS Agent as a proper Azure CLI extension:

1. Package the extension following [Azure CLI extension guidelines](https://docs.microsoft.com/en-us/cli/azure/azure-cli-extensions-overview)
2. Distribute via private extension repository
3. Install using `az extension add --source path/to/extension`

### Option 3: Direct Python Usage

```bash
# Run directly with Python
python -m aks_agent.cli agent "your query here"

# Or use the installed console script
aks-agent "your query here"
```

## Configuration

### AI Provider Setup

Create `~/.aks-agent/config.yaml`:

```yaml
# For Azure OpenAI
ai_provider:
  type: "azure_openai"
  endpoint: "https://your-resource.openai.azure.com/"
  api_key: "your-api-key"
  model: "gpt-4"

# For OpenAI
ai_provider:
  type: "openai"
  api_key: "your-openai-api-key"
  model: "gpt-4"

# For Anthropic Claude
ai_provider:
  type: "anthropic"
  api_key: "your-anthropic-api-key"
  model: "claude-3-sonnet-20240229"

clusters:
  default_resource_group: "your-rg"
  default_cluster: "your-cluster"
```

### Environment Variables

Alternatively, use environment variables:

```bash
# Azure OpenAI
export AKS_AGENT_AI_PROVIDER=azure_openai
export AKS_AGENT_AZURE_OPENAI_ENDPOINT=https://your-resource.openai.azure.com/
export AKS_AGENT_API_KEY=your-api-key

# OpenAI
export AKS_AGENT_AI_PROVIDER=openai
export AKS_AGENT_API_KEY=your-openai-api-key

# Default cluster
export AKS_AGENT_DEFAULT_RG=your-rg
export AKS_AGENT_DEFAULT_CLUSTER=your-cluster
```

## Verification

### Test Basic Functionality

```bash
# Check status
az aks agent status

# Test with your cluster
az aks agent "how is my cluster healthy?"

# Test specific scenarios
az aks agent "check node health"
az aks agent "diagnose DNS issues"
az aks agent "why are pods pending?"
```

### Test AI Features

```bash
# Complex troubleshooting (requires AI provider)
az aks agent "My application is experiencing intermittent connection timeouts. The pods are running but users report 503 errors occasionally."

# Cost optimization analysis
az aks agent "Analyze my cluster for cost optimization opportunities"
```

## Troubleshooting Installation

### Common Issues

1. **Import errors**: Ensure all Python dependencies are installed
   ```bash
   pip install -r requirements.txt
   ```

2. **Azure CLI not found**: Install Azure CLI from official Microsoft documentation

3. **Permission errors**: Ensure you have RBAC permissions on the AKS cluster
   ```bash
   # Check your permissions
   az aks show --resource-group your-rg --name your-cluster
   kubectl auth can-i get pods
   ```

4. **kubectl not configured**: Get cluster credentials
   ```bash
   az aks get-credentials --resource-group your-rg --name your-cluster
   kubectl cluster-info
   ```

### Logging and Debugging

Enable verbose mode for troubleshooting:

```bash
az aks agent --verbose "your query"
```

Check logs:
```bash
tail -f ~/.aks-agent/logs/agent.log
```

## Security Considerations

- **Local Execution**: All diagnostics run locally on your machine
- **Azure RBAC**: Inherits your Azure CLI permissions
- **API Keys**: Store securely in configuration or environment variables
- **Network Access**: Only requires access to Azure APIs and Kubernetes API server

## Updating

```bash
cd AKS
git pull origin main
cd cli-agent
pip install -e . --upgrade
```

## Uninstallation

```bash
# Remove installed package
pip uninstall aks-cli-agent

# Remove configuration
rm -rf ~/.aks-agent

# Remove shell aliases (if used)
# Edit your shell profile to remove the alias
```