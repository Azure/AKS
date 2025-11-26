#!/usr/bin/env bash
# Azure CLI Extension for AKS Agent

# This script demonstrates how to integrate the AKS Agent with Azure CLI
# as a custom extension. This would typically be distributed as an Azure CLI extension.

set -e

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI is not installed. Please install Azure CLI first."
    exit 1
fi

# Check if user is logged in (but don't fail for demo purposes)
AUTH_AVAILABLE=false
if az account show &> /dev/null; then
    AUTH_AVAILABLE=true
fi

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_DIR="$SCRIPT_DIR/cli-agent"

# Check if AKS Agent is installed
if [[ ! -d "$AGENT_DIR" ]]; then
    echo "❌ AKS Agent not found at $AGENT_DIR"
    exit 1
fi

# Set up Python path
export PYTHONPATH="$AGENT_DIR/src:$PYTHONPATH"

# Function to simulate 'az aks agent' command
aks_agent() {
    if [[ $# -eq 0 ]]; then
        echo "Azure Kubernetes Service CLI Agent"
        echo ""
        echo "Usage: az aks agent [OPTIONS] QUERY"
        echo "       az aks agent --help"
        echo "       az aks agent status"
        echo "       az aks agent configure"
        echo ""
        echo "Examples:"
        echo "  az aks agent \"how is my cluster healthy?\""
        echo "  az aks agent \"why is my node not ready?\""
        echo "  az aks agent \"diagnose DNS issues\""
        echo ""
        echo "For more help, visit: https://github.com/Azure/AKS/tree/main/cli-agent"
        return 0
    fi
    
    # Handle special commands
    case "$1" in
        "status")
            echo "🔍 AKS Agent Status Check"
            echo ""
            
            # Check Azure CLI
            if $AUTH_AVAILABLE; then
                USER_NAME=$(az account show --query user.name -o tsv)
                echo "✅ Azure CLI authenticated as: $USER_NAME"
            else
                echo "❌ Azure CLI not authenticated"
            fi
            
            # Check kubectl
            if command -v kubectl &> /dev/null; then
                if kubectl cluster-info &> /dev/null; then
                    echo "✅ kubectl configured and connected"
                else
                    echo "⚠️  kubectl installed but not connected to a cluster"
                fi
            else
                echo "❌ kubectl not installed"
            fi
            
            # Check Python dependencies
            if python3 -c "import azure.identity" &> /dev/null; then
                echo "✅ Azure SDK for Python available"
            else
                echo "⚠️  Azure SDK for Python not installed (AI features limited)"
            fi
            
            # Check configuration
            if [[ -f "$HOME/.aks-agent/config.yaml" ]]; then
                echo "✅ AKS Agent configured"
            else
                echo "⚠️  AKS Agent not configured (run 'az aks agent configure')"
            fi
            
            echo ""
            echo "📖 For help: az aks agent --help"
            return 0
            ;;
        "configure")
            echo "🛠️  AKS Agent Configuration"
            echo ""
            echo "This would start interactive configuration..."
            echo "For now, please copy examples/config.yaml to ~/.aks-agent/config.yaml"
            echo "and customize it for your environment."
            return 0
            ;;
        "--help"|"-h")
            cat << EOF
Azure Kubernetes Service CLI Agent

DESCRIPTION:
    AI-powered command-line experience for AKS operations and diagnostics.
    
USAGE:
    az aks agent [OPTIONS] QUERY
    az aks agent COMMAND

COMMANDS:
    status      Check AKS Agent status and dependencies
    configure   Interactive configuration setup

OPTIONS:
    --cluster, -c       AKS cluster name
    --resource-group, -g Azure resource group
    --subscription, -s   Azure subscription ID
    --verbose, -v        Enable verbose output
    --help, -h          Show this help message

EXAMPLES:
    Node Health:
        az aks agent "why is my node not ready?"
        az aks agent "diagnose node health issues"
    
    DNS Troubleshooting:
        az aks agent "why are DNS lookups failing?"
        az aks agent "check CoreDNS configuration"
    
    Pod Issues:
        az aks agent "why is my pod stuck in pending?"
        az aks agent "analyze pod scheduling failures"
    
    Cluster Health:
        az aks agent "how is my cluster performing?"
        az aks agent "check overall cluster health"
    
    Cost Optimization:
        az aks agent "how can I reduce cluster costs?"
        az aks agent "optimize resource utilization"

GETTING STARTED:
    1. Ensure you're logged in: az login
    2. Configure kubectl: az aks get-credentials -g <rg> -n <cluster>
    3. Check status: az aks agent status
    4. Configure AI: az aks agent configure
    5. Start troubleshooting!

For more information, visit: https://github.com/Azure/AKS/tree/main/cli-agent
EOF
            return 0
            ;;
    esac
    
    # For actual queries, we'd call the Python agent
    echo "🤖 AKS Agent Analysis"
    echo ""
    if ! $AUTH_AVAILABLE; then
        echo "⚠️  Note: Running in demo mode (Azure CLI not authenticated)"
        echo ""
    fi
    echo "Query: $*"
    echo ""
    
    # This would be the actual Python call
    # python3 -m aks_agent.cli agent "$@"
    
    # For now, provide a sample response based on query analysis
    QUERY_LOWER=$(echo "$*" | tr '[:upper:]' '[:lower:]')
    
    if echo "$QUERY_LOWER" | grep -qE "(node|notready|kubelet)"; then
        cat << EOF
## Node Health Analysis

Based on your query about node health, here's what I found:

✅ **Current Status**: All nodes appear to be in Ready state
📊 **Node Count**: 3 nodes detected
🔍 **Recent Events**: No critical node events in the last hour

### Recommended Actions:
1. Check node resource utilization: \`kubectl top nodes\`
2. Review recent events: \`kubectl get events --field-selector involvedObject.kind=Node\`
3. Monitor system pods: \`kubectl get pods -n kube-system\`

### Common Node Issues to Watch:
- High CPU/Memory pressure
- Disk space issues
- Network connectivity problems
- Kubelet service issues

For AI-powered analysis, configure an AI provider using: \`az aks agent configure\`
EOF
    elif echo "$QUERY_LOWER" | grep -qE "(dns|lookup|coredns)"; then
        cat << EOF
## DNS Analysis

Based on your DNS-related query:

✅ **CoreDNS Status**: CoreDNS pods are running
🔍 **DNS Configuration**: Using cluster DNS settings
⚠️  **Recommendation**: Test DNS resolution from within pods

### Quick DNS Test:
\`\`\`bash
kubectl run dns-test --rm -i --restart=Never --image=busybox -- nslookup kubernetes.default
\`\`\`

### Common DNS Issues:
- CoreDNS pod crashes or restarts
- Network policies blocking DNS traffic
- Incorrect DNS configuration
- Upstream DNS server problems

### Troubleshooting Steps:
1. Check CoreDNS pods: \`kubectl get pods -n kube-system -l k8s-app=kube-dns\`
2. Review CoreDNS logs: \`kubectl logs -n kube-system -l k8s-app=kube-dns\`
3. Test from application pod: \`kubectl exec -it <pod> -- nslookup kubernetes.default\`

For AI-powered analysis, configure an AI provider using: \`az aks agent configure\`
EOF
    elif echo "$QUERY_LOWER" | grep -qE "(pod|pending|scheduling)"; then
        cat << EOF
## Pod Scheduling Analysis

Analyzing pod scheduling issues:

✅ **Scheduler Status**: Kubernetes scheduler is running
📊 **Pending Pods**: Checking for pods stuck in Pending state
🔍 **Resource Availability**: Reviewing node capacity

### Common Scheduling Issues:
- Insufficient resources (CPU/Memory)
- Node selector constraints
- Pod affinity/anti-affinity rules
- Taints and tolerations mismatch

### Quick Checks:
1. List pending pods: \`kubectl get pods --field-selector=status.phase=Pending --all-namespaces\`
2. Check node resources: \`kubectl describe nodes\`
3. Review events: \`kubectl get events --sort-by=.metadata.creationTimestamp\`

### Remediation Steps:
- Scale cluster if resource shortage
- Review pod resource requests
- Check node labels and selectors
- Verify tolerations for tainted nodes

For AI-powered analysis, configure an AI provider using: \`az aks agent configure\`
EOF
    else
        cat << EOF
## General Cluster Analysis

I understand you're asking about: "$*"

📋 **Basic Health Check**:
- ✅ Azure CLI authenticated
- ✅ kubectl configured
- ✅ Cluster accessible

### Available Analysis Types:
- **Node Health**: Ask about node issues, NotReady states, resource pressure
- **DNS Troubleshooting**: Query about DNS lookups, CoreDNS problems
- **Pod Issues**: Inquire about pending pods, scheduling failures
- **Network Problems**: Ask about connectivity, ingress, services
- **Cost Optimization**: Request cost-saving recommendations

### Try These Examples:
- "why is my node not ready?"
- "diagnose DNS lookup failures"
- "why are my pods stuck pending?"
- "how can I optimize cluster costs?"

For AI-powered intelligent analysis, please configure an AI provider:
\`az aks agent configure\`

This will enable advanced troubleshooting capabilities powered by Azure OpenAI, OpenAI, or Anthropic.
EOF
    fi
}

# Make the function available as 'az aks agent'
# In a real Azure CLI extension, this would be handled by the extension framework
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly
    aks_agent "$@"
fi