"""
Core AKS Agent implementation - AI-powered diagnostics and operations.
"""

import json
import re
from typing import Dict, List, Optional, Any
from rich.console import Console
from rich.markdown import Markdown
from rich.panel import Panel

from .auth import AzureAuth
from .config import Config
from .diagnostics import DiagnosticsEngine
from .ai_providers import AIProviderFactory
from .kubernetes_client import KubernetesClient
from .azure_client import AzureClient

console = Console()


class AKSAgent:
    """Main AKS Agent class that orchestrates AI-powered operations."""
    
    def __init__(self, config: Config, auth: AzureAuth):
        self.config = config
        self.auth = auth
        self.ai_provider = None
        self.k8s_client = None
        self.azure_client = None
        self.diagnostics = DiagnosticsEngine(config)
        
        # Current cluster context
        self.cluster_name = config.get('clusters.default_cluster')
        self.resource_group = config.get('clusters.default_resource_group')
        self.subscription_id = auth.get_subscription_id()
        
        self._initialize_clients()
    
    def _initialize_clients(self):
        """Initialize AI and Azure clients."""
        try:
            # Initialize AI provider
            ai_provider_type = self.config.get('ai_provider.type')
            if ai_provider_type and ai_provider_type != 'none':
                self.ai_provider = AIProviderFactory.create_provider(
                    ai_provider_type, self.config
                )
            
            # Initialize Azure client
            self.azure_client = AzureClient(self.auth)
            
            # Initialize Kubernetes client (if available)
            try:
                self.k8s_client = KubernetesClient()
            except Exception as e:
                console.print(f"⚠️  Kubernetes client not available: {e}", style="yellow")
        
        except Exception as e:
            console.print(f"⚠️  Warning during client initialization: {e}", style="yellow")
    
    def set_context(self, cluster_name: Optional[str] = None, 
                   resource_group: Optional[str] = None,
                   subscription_id: Optional[str] = None):
        """Set the current cluster context."""
        if cluster_name:
            self.cluster_name = cluster_name
        if resource_group:
            self.resource_group = resource_group
        if subscription_id:
            self.subscription_id = subscription_id
    
    def execute_query(self, query: str) -> str:
        """Execute an AI-powered query against the AKS environment."""
        try:
            # Analyze the query to determine the type of operation
            query_type = self._analyze_query(query)
            
            # Gather relevant context based on query type
            context = self._gather_context(query, query_type)
            
            # If AI provider is available, use it for intelligent analysis
            if self.ai_provider:
                return self._execute_ai_query(query, context, query_type)
            else:
                return self._execute_basic_query(query, context, query_type)
        
        except Exception as e:
            return f"❌ Error executing query: {str(e)}"
    
    def _analyze_query(self, query: str) -> str:
        """Analyze the query to determine what type of operation is needed."""
        query_lower = query.lower()
        
        # Node-related queries
        if any(keyword in query_lower for keyword in ['node', 'notready', 'kubelet']):
            return 'node_health'
        
        # DNS-related queries
        if any(keyword in query_lower for keyword in ['dns', 'lookup', 'resolution', 'coredns']):
            return 'dns_troubleshooting'
        
        # Pod-related queries
        if any(keyword in query_lower for keyword in ['pod', 'pending', 'scheduling', 'evicted']):
            return 'pod_troubleshooting'
        
        # Cluster health queries
        if any(keyword in query_lower for keyword in ['cluster', 'health', 'status', 'upgrade']):
            return 'cluster_health'
        
        # Cost optimization queries
        if any(keyword in query_lower for keyword in ['cost', 'optimize', 'save', 'efficiency']):
            return 'cost_optimization'
        
        # Network-related queries
        if any(keyword in query_lower for keyword in ['network', 'connectivity', 'ingress', 'service']):
            return 'network_troubleshooting'
        
        return 'general'
    
    def _gather_context(self, query: str, query_type: str) -> Dict[str, Any]:
        """Gather relevant context for the query."""
        context = {
            'cluster_name': self.cluster_name,
            'resource_group': self.resource_group,
            'subscription_id': self.subscription_id,
            'query_type': query_type
        }
        
        try:
            # Always try to get basic cluster information
            if self.azure_client and self.cluster_name and self.resource_group:
                cluster_info = self.azure_client.get_cluster_info(
                    self.cluster_name, self.resource_group
                )
                context['cluster_info'] = cluster_info
            
            # Gather specific context based on query type
            if query_type == 'node_health' and self.k8s_client:
                context['nodes'] = self.k8s_client.get_nodes()
                context['node_events'] = self.k8s_client.get_events(field_selector='involvedObject.kind=Node')
            
            elif query_type == 'pod_troubleshooting' and self.k8s_client:
                context['pods'] = self.k8s_client.get_pods()
                context['events'] = self.k8s_client.get_events()
            
            elif query_type == 'dns_troubleshooting' and self.k8s_client:
                context['dns_pods'] = self.k8s_client.get_pods(namespace='kube-system', label_selector='k8s-app=kube-dns')
                context['coredns_config'] = self.k8s_client.get_configmap('coredns', 'kube-system')
            
            elif query_type == 'cluster_health':
                if self.k8s_client:
                    context['cluster_status'] = self.k8s_client.get_cluster_status()
                if self.azure_client:
                    context['azure_status'] = self.azure_client.get_cluster_status(
                        self.cluster_name, self.resource_group
                    )
        
        except Exception as e:
            console.print(f"⚠️  Warning gathering context: {e}", style="yellow")
        
        return context
    
    def _execute_ai_query(self, query: str, context: Dict[str, Any], query_type: str) -> str:
        """Execute query using AI provider."""
        try:
            # Create a comprehensive prompt
            prompt = self._build_ai_prompt(query, context, query_type)
            
            # Get AI response
            response = self.ai_provider.generate_response(prompt)
            
            # Parse and format the response
            return self._format_ai_response(response, query_type)
        
        except Exception as e:
            return f"❌ AI analysis failed: {str(e)}\\n\\nFalling back to basic analysis..."
    
    def _execute_basic_query(self, query: str, context: Dict[str, Any], query_type: str) -> str:
        """Execute query using basic rule-based analysis."""
        result_parts = []
        
        # Basic cluster information
        if context.get('cluster_info'):
            cluster_info = context['cluster_info']
            result_parts.append(f"## Cluster: {cluster_info.get('name', 'Unknown')}")
            result_parts.append(f"**Status:** {cluster_info.get('provisioning_state', 'Unknown')}")
            result_parts.append(f"**Kubernetes Version:** {cluster_info.get('kubernetes_version', 'Unknown')}")
            result_parts.append("")
        
        # Query-specific analysis
        if query_type == 'node_health':
            result_parts.extend(self._analyze_node_health(context))
        elif query_type == 'pod_troubleshooting':
            result_parts.extend(self._analyze_pod_issues(context))
        elif query_type == 'dns_troubleshooting':
            result_parts.extend(self._analyze_dns_issues(context))
        elif query_type == 'cluster_health':
            result_parts.extend(self._analyze_cluster_health(context))
        elif query_type == 'cost_optimization':
            result_parts.extend(self._analyze_cost_optimization(context))
        else:
            result_parts.extend(self._analyze_general(query, context))
        
        return "\\n".join(result_parts)
    
    def _build_ai_prompt(self, query: str, context: Dict[str, Any], query_type: str) -> str:
        """Build a comprehensive prompt for the AI provider."""
        prompt_parts = [
            "You are an expert AKS (Azure Kubernetes Service) operations specialist and troubleshooter.",
            "Analyze the following query and provide actionable insights based on the cluster context.",
            "",
            f"**User Query:** {query}",
            f"**Query Type:** {query_type}",
            "",
            "**Cluster Context:**"
        ]
        
        # Add context information
        for key, value in context.items():
            if value and key != 'query_type':
                prompt_parts.append(f"- {key}: {json.dumps(value, indent=2, default=str)}")
        
        prompt_parts.extend([
            "",
            "**Instructions:**",
            "1. Provide a clear diagnosis of any issues found",
            "2. Suggest specific, actionable remediation steps",
            "3. Include relevant kubectl commands or Azure CLI commands",
            "4. Explain the root cause if an issue is detected",
            "5. Use markdown formatting for clarity",
            "6. If no issues are found, provide optimization recommendations",
            "",
            "**Response Format:**",
            "## Diagnosis",
            "[Your analysis here]",
            "",
            "## Recommended Actions",
            "[Step-by-step remediation]",
            "",
            "## Additional Insights",
            "[Any additional recommendations]"
        ])
        
        return "\\n".join(prompt_parts)
    
    def _format_ai_response(self, response: str, query_type: str) -> str:
        """Format AI response for display."""
        # Clean up the response
        formatted = response.strip()
        
        # Add query type context if missing
        if "## Diagnosis" not in formatted and "##" not in formatted:
            formatted = f"## Analysis\\n\\n{formatted}"
        
        return formatted
    
    def _analyze_node_health(self, context: Dict[str, Any]) -> List[str]:
        """Analyze node health issues."""
        results = ["## Node Health Analysis"]
        
        nodes = context.get('nodes', [])
        if not nodes:
            results.append("⚠️  Unable to retrieve node information. Check kubectl connectivity.")
            return results
        
        not_ready_nodes = [n for n in nodes if n.get('status') != 'Ready']
        if not_ready_nodes:
            results.append(f"❌ **Issues Found:** {len(not_ready_nodes)} node(s) not ready")
            for node in not_ready_nodes:
                results.append(f"- Node: `{node.get('name')}` - Status: `{node.get('status')}`")
        else:
            results.append(f"✅ All {len(nodes)} nodes are in Ready state")
        
        return results
    
    def _analyze_pod_issues(self, context: Dict[str, Any]) -> List[str]:
        """Analyze pod scheduling and runtime issues."""
        results = ["## Pod Analysis"]
        
        pods = context.get('pods', [])
        if not pods:
            results.append("⚠️  Unable to retrieve pod information.")
            return results
        
        pending_pods = [p for p in pods if p.get('phase') == 'Pending']
        failed_pods = [p for p in pods if p.get('phase') == 'Failed']
        
        if pending_pods:
            results.append(f"⚠️  **Pending Pods:** {len(pending_pods)} pod(s) stuck in Pending state")
        
        if failed_pods:
            results.append(f"❌ **Failed Pods:** {len(failed_pods)} pod(s) in Failed state")
        
        if not pending_pods and not failed_pods:
            results.append("✅ No obvious pod scheduling or runtime issues detected")
        
        return results
    
    def _analyze_dns_issues(self, context: Dict[str, Any]) -> List[str]:
        """Analyze DNS-related issues."""
        results = ["## DNS Analysis"]
        
        dns_pods = context.get('dns_pods', [])
        if dns_pods:
            healthy_dns_pods = [p for p in dns_pods if p.get('phase') == 'Running']
            results.append(f"DNS Pods Status: {len(healthy_dns_pods)}/{len(dns_pods)} running")
        else:
            results.append("⚠️  Unable to check CoreDNS pod status")
        
        # Basic DNS troubleshooting suggestions
        results.extend([
            "",
            "## Recommended DNS Troubleshooting Steps:",
            "1. Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`",
            "2. Test DNS resolution: `kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default`",
            "3. Check CoreDNS logs: `kubectl logs -n kube-system -l k8s-app=kube-dns`"
        ])
        
        return results
    
    def _analyze_cluster_health(self, context: Dict[str, Any]) -> List[str]:
        """Analyze overall cluster health."""
        results = ["## Cluster Health Analysis"]
        
        cluster_info = context.get('cluster_info', {})
        if cluster_info:
            state = cluster_info.get('provisioning_state', 'Unknown')
            if state == 'Succeeded':
                results.append("✅ Cluster provisioning state: Healthy")
            else:
                results.append(f"⚠️  Cluster state: {state}")
        
        return results
    
    def _analyze_cost_optimization(self, context: Dict[str, Any]) -> List[str]:
        """Analyze cost optimization opportunities."""
        results = ["## Cost Optimization Analysis"]
        
        results.extend([
            "Here are general cost optimization recommendations:",
            "",
            "### Node Optimization",
            "- Review node utilization and consider rightsizing",
            "- Use spot instances for non-critical workloads",
            "- Enable cluster autoscaler",
            "",
            "### Resource Management",
            "- Set resource requests and limits on pods",
            "- Use horizontal pod autoscaler (HPA)",
            "- Consider vertical pod autoscaler (VPA)",
            "",
            "### Storage Optimization",
            "- Review persistent volume usage",
            "- Use appropriate storage classes",
            "- Clean up unused volumes"
        ])
        
        return results
    
    def _analyze_general(self, query: str, context: Dict[str, Any]) -> List[str]:
        """Handle general queries."""
        results = ["## General Analysis"]
        
        cluster_name = context.get('cluster_name', 'your cluster')
        results.append(f"Analyzing query about {cluster_name}...")
        
        if "help" in query.lower():
            results.extend([
                "",
                "## Available Commands",
                "- Node health: Ask about node status or NotReady issues",
                "- Pod troubleshooting: Ask about pending or failed pods",
                "- DNS issues: Ask about DNS lookups or CoreDNS problems", 
                "- Cluster health: Ask about overall cluster status",
                "- Cost optimization: Ask how to reduce cluster costs"
            ])
        else:
            results.append("For specific troubleshooting, try asking about nodes, pods, DNS, or cluster health.")
        
        return results