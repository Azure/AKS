# AKS CLI Agent - Usage Examples

This document provides examples of how to use the AKS CLI Agent for common troubleshooting and operational scenarios.

## Prerequisites

1. Install and configure Azure CLI: `az login`
2. Configure kubectl for your AKS cluster
3. Install the AKS CLI Agent (see main README)
4. Configure AI provider (optional but recommended)

## Basic Usage Examples

### General Cluster Health

```bash
# Get overall cluster status
aks-agent "How is my cluster healthy?"

# Check cluster with specific details
aks-agent "Analyze my cluster my-aks-cluster in resource group production-rg"
```

### Node Troubleshooting

```bash
# Diagnose node issues
aks-agent "Why is one of my nodes in NotReady state?"

# Check specific node health
aks-agent "Analyze node health for aks-nodepool1-12345"

# Node resource pressure analysis
aks-agent "Are my nodes under resource pressure?"
```

### Pod Troubleshooting

```bash
# Analyze stuck pods
aks-agent "Why is my pod stuck in Pending state?"

# Check pod scheduling issues
aks-agent "Diagnose pod scheduling failures"

# Analyze failed pods
aks-agent "Why are my pods failing to start?"
```

### DNS Troubleshooting

```bash
# DNS resolution issues
aks-agent "Why are my pods failing DNS lookups?"

# CoreDNS problems
aks-agent "Check CoreDNS health and configuration"

# Service discovery issues
aks-agent "Why can't my pods reach other services?"
```

### Network Troubleshooting

```bash
# General network issues
aks-agent "Diagnose network connectivity problems"

# Ingress issues
aks-agent "Why is my ingress not working?"

# Load balancer problems
aks-agent "Analyze load balancer configuration"
```

### Performance and Optimization

```bash
# Cost optimization
aks-agent "How can I optimize the cost of my cluster?"

# Resource utilization
aks-agent "Analyze resource utilization and suggest optimizations"

# Scaling recommendations
aks-agent "Should I scale my cluster up or down?"
```

### Cluster Operations

```bash
# Upgrade analysis
aks-agent "My AKS cluster upgrade failed, what happened?"

# Configuration review
aks-agent "Review my cluster configuration for best practices"

# Security assessment
aks-agent "Analyze my cluster security posture"
```

## Advanced Usage

### With Specific Context

```bash
# Target specific cluster
aks-agent --cluster my-cluster --resource-group my-rg "Check cluster health"

# Use different subscription
aks-agent --subscription my-sub-id "List all issues in my clusters"
```

### Verbose Mode

```bash
# Get detailed diagnostic information
aks-agent --verbose "Why are my pods crashing?"
```

### Configuration Management

```bash
# Check agent status
aks-agent status

# Interactive configuration
aks-agent configure
```

## Query Patterns

The AKS CLI Agent understands various query patterns:

### Question-based Queries
- "Why is my [resource] [problem]?"
- "What's wrong with my [component]?"
- "How can I fix [issue]?"

### Action-based Queries
- "Diagnose [component] issues"
- "Check [resource] health"
- "Analyze [aspect] of my cluster"

### Optimization Queries
- "How to optimize [aspect]?"
- "Recommend improvements for [component]"
- "Best practices for [scenario]"

## Tips for Better Results

1. **Be Specific**: Include resource names, namespaces, or error messages when possible
2. **Provide Context**: Mention recent changes, deployments, or configurations
3. **Use Keywords**: Include relevant technical terms (pod, node, DNS, network, etc.)
4. **Ask Follow-up Questions**: Build on previous analysis for deeper insights

## Example Troubleshooting Session

```bash
# Initial problem report
aks-agent "My application is not accessible from the internet"

# Follow-up based on initial analysis
aks-agent "Check ingress controller logs and configuration"

# Deeper investigation
aks-agent "Analyze network policies affecting ingress traffic"

# Final resolution
aks-agent "Validate DNS configuration for my ingress domain"
```

## Integration with Existing Workflows

### CI/CD Integration

```bash
# Pre-deployment health check
aks-agent "Is my cluster ready for deployment?"

# Post-deployment validation
aks-agent "Verify deployment health for namespace production"
```

### Monitoring Integration

```bash
# Alert investigation
aks-agent "Why are my memory alerts firing?"

# Performance analysis
aks-agent "Analyze high CPU usage on node aks-nodepool1-12345"
```

### Maintenance Windows

```bash
# Pre-maintenance check
aks-agent "Prepare cluster health report for maintenance"

# Post-maintenance validation
aks-agent "Validate cluster health after upgrade"
```