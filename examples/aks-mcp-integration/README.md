# AKS Model Context Protocol (MCP) Server Integration

This example demonstrates how to set up and use the AKS Model Context Protocol (MCP) Server to enable AI-powered interactions with your AKS clusters.

## Overview

The AKS-MCP Server provides a secure, standards-based bridge between AI assistants (like GitHub Copilot, Claude, and Cursor) and your Azure Kubernetes Service clusters. It enables AI tools to understand your cluster state, diagnose issues, and provide intelligent recommendations.

## Quick Start

### Option 1: VS Code Extension (Recommended)

1. **Install the AKS VS Code Extension**
   ```bash
   code --install-extension ms-kubernetes-tools.vscode-aks-tools
   ```

2. **Setup AKS-MCP Server**
   - Open VS Code
   - Press `Ctrl+Shift+P` (Windows/Linux) or `Cmd+Shift+P` (macOS)
   - Run: **AKS: Setup AKS MCP Server**

3. **Verify Installation**
   - Run: **MCP: List Servers** from the Command Palette
   - Start the AKS-MCP server and verify its status

### Option 2: Manual Installation

1. **Download the binary from releases**
   ```bash
   # Download from GitHub releases page
   wget https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-linux-amd64
   chmod +x aks-mcp-linux-amd64
   sudo mv aks-mcp-linux-amd64 /usr/local/bin/aks-mcp
   ```

2. **Configure MCP server**
   Create or update your MCP configuration file (`~/.config/mcp/mcp.json`):
   ```json
   {
     "mcpServers": {
       "aks-mcp": {
         "command": "aks-mcp",
         "args": ["--cluster-name", "your-cluster-name", "--resource-group", "your-resource-group"]
       }
     }
   }
   ```

## Prerequisites

- Azure CLI installed and authenticated (`az login`)
- kubectl configured to access your AKS cluster
- Appropriate RBAC permissions for your cluster resources

## AI Assistant Integration Examples

### GitHub Copilot Chat Examples

Once AKS-MCP is configured, you can use natural language prompts:

```
@copilot How is the health of my AKS cluster?
```

```
@copilot Why is my pod in CrashLoopBackOff state? Can you help diagnose the issue?
```

```
@copilot Show me the resource utilization across my cluster nodes
```

```
@copilot Scale my frontend deployment to 5 replicas and confirm the rollout
```

### Claude/Cursor Integration

With MCP configured, Claude and Cursor can access your cluster context:

```
Analyze my cluster's network configuration and identify potential connectivity issues
```

```
Review my deployment configurations and suggest optimizations for better resource utilization
```

## Use Cases

### 1. Intelligent Diagnostics
- **Problem**: Pod startup failures
- **AI Solution**: Automatically analyze pod logs, events, and resource constraints
- **Outcome**: Root cause identification with remediation suggestions

### 2. Resource Optimization
- **Problem**: Cluster resource waste
- **AI Solution**: Analyze current usage patterns and suggest rightsizing
- **Outcome**: Cost optimization recommendations with implementation guidance

### 3. Security Analysis
- **Problem**: Security compliance validation
- **AI Solution**: Review network policies, RBAC, and security configurations
- **Outcome**: Security improvement suggestions aligned with best practices

### 4. Operational Automation
- **Problem**: Repetitive cluster management tasks
- **AI Solution**: Natural language commands for scaling, updates, and monitoring
- **Outcome**: Streamlined operations with reduced manual effort

## Security Considerations

The AKS-MCP Server implements multi-tier security:

- **Authentication**: Uses Azure CLI credentials and Azure SDK's DefaultAzureCredential
- **Authorization**: Respects existing Azure RBAC permissions
- **Access Control**: Three-tier system (readonly, readwrite, admin) with configurable permissions
- **Audit**: All operations are logged and auditable

## Configuration Options

### Permission Levels
- `readonly`: Default level, allows cluster inspection without modifications
- `readwrite`: Enables resource modifications like scaling and updates  
- `admin`: Full administrative access for advanced operations

### Cluster Selection
- Specify target cluster using `--cluster-name` and `--resource-group`
- Support for multiple cluster contexts
- Auto-discovery of available clusters in subscription

## Advanced Configuration

### Custom Tool Selection
Configure which tools are available to AI assistants:
```bash
aks-mcp --enable-tools="kubectl,azure-cli,diagnostics" --disable-tools="write-operations"
```

### Logging and Monitoring
Enable detailed logging for troubleshooting:
```bash
aks-mcp --log-level=debug --log-file=/var/log/aks-mcp.log
```

## Troubleshooting

### Common Issues

1. **Authentication failures**
   - Verify `az login` is completed
   - Check Azure CLI token validity: `az account show`

2. **Permission denied errors**
   - Verify RBAC permissions on target cluster
   - Check resource group access rights

3. **MCP server not responding**
   - Verify server is running: **MCP: List Servers**
   - Check logs for error messages
   - Restart server if needed

### Debug Commands

```bash
# Test cluster connectivity
kubectl cluster-info

# Verify Azure authentication
az account show

# Test AKS-MCP server directly
aks-mcp --test-connection
```

## Resources

- **GitHub Repository**: [Azure/aks-mcp](https://github.com/Azure/aks-mcp)
- **Blog Post**: [Announcing the AKS-MCP Server](https://blog.aks.azure.com/2025/08/06/aks-mcp-server)
- **Release Notes**: Check [AKS Changelog](../../CHANGELOG.md) for latest updates
- **Issues & Support**: [AKS Repository Issues](https://github.com/Azure/AKS/issues)

## Contributing

The AKS-MCP Server is open source and welcomes contributions:
- Report issues or request features
- Submit pull requests for improvements
- Share usage examples and best practices

Visit [Azure/aks-mcp](https://github.com/Azure/aks-mcp) to get involved!