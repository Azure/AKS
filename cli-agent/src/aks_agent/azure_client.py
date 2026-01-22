"""
Azure client for AKS CLI Agent.
"""

from typing import Dict, List, Optional, Any
from azure.mgmt.containerservice import ContainerServiceClient
from azure.mgmt.resource import ResourceManagementClient
from azure.core.exceptions import ResourceNotFoundError

from .auth import AzureAuth


class AzureClient:
    """Azure client wrapper for AKS operations."""
    
    def __init__(self, auth: AzureAuth):
        """Initialize Azure client with authentication."""
        self.auth = auth
        self.credential = auth.get_credential()
        self.subscription_id = auth.get_subscription_id()
        
        if not self.subscription_id:
            raise RuntimeError("No Azure subscription found. Please run 'az login' first.")
        
        self.aks_client = ContainerServiceClient(
            credential=self.credential,
            subscription_id=self.subscription_id
        )
        
        self.resource_client = ResourceManagementClient(
            credential=self.credential,
            subscription_id=self.subscription_id
        )
    
    def get_cluster_info(self, cluster_name: str, resource_group: str) -> Dict[str, Any]:
        """Get detailed information about an AKS cluster."""
        try:
            cluster = self.aks_client.managed_clusters.get(resource_group, cluster_name)
            
            # Extract relevant cluster information
            cluster_info = {
                'name': cluster.name,
                'location': cluster.location,
                'provisioning_state': cluster.provisioning_state,
                'kubernetes_version': cluster.kubernetes_version,
                'dns_prefix': cluster.dns_prefix,
                'fqdn': cluster.fqdn,
                'node_resource_group': cluster.node_resource_group,
                'enable_rbac': cluster.enable_rbac,
                'network_profile': self._extract_network_profile(cluster.network_profile),
                'agent_pool_profiles': self._extract_agent_pools(cluster.agent_pool_profiles),
                'addon_profiles': self._extract_addon_profiles(cluster.addon_profiles),
                'tags': dict(cluster.tags) if cluster.tags else {}
            }
            
            return cluster_info
        
        except ResourceNotFoundError:
            raise RuntimeError(f"AKS cluster '{cluster_name}' not found in resource group '{resource_group}'")
        except Exception as e:
            raise RuntimeError(f"Failed to get cluster info: {str(e)}")
    
    def get_cluster_status(self, cluster_name: str, resource_group: str) -> Dict[str, Any]:
        """Get cluster status and health information."""
        try:
            cluster_info = self.get_cluster_info(cluster_name, resource_group)
            
            status = {
                'provisioning_state': cluster_info['provisioning_state'],
                'kubernetes_version': cluster_info['kubernetes_version'],
                'agent_pools': []
            }
            
            # Get agent pool details
            agent_pools = self.aks_client.agent_pools.list(resource_group, cluster_name)
            for pool in agent_pools:
                status['agent_pools'].append({
                    'name': pool.name,
                    'count': pool.count,
                    'vm_size': pool.vm_size,
                    'provisioning_state': pool.provisioning_state,
                    'power_state': pool.power_state.code if pool.power_state else None,
                    'orchestrator_version': pool.orchestrator_version
                })
            
            return status
        
        except Exception as e:
            raise RuntimeError(f"Failed to get cluster status: {str(e)}")
    
    def list_clusters(self, resource_group: Optional[str] = None) -> List[Dict[str, Any]]:
        """List AKS clusters in a resource group or subscription."""
        try:
            if resource_group:
                clusters = self.aks_client.managed_clusters.list_by_resource_group(resource_group)
            else:
                clusters = self.aks_client.managed_clusters.list()
            
            cluster_list = []
            for cluster in clusters:
                cluster_list.append({
                    'name': cluster.name,
                    'resource_group': cluster.id.split('/')[4],  # Extract RG from resource ID
                    'location': cluster.location,
                    'kubernetes_version': cluster.kubernetes_version,
                    'provisioning_state': cluster.provisioning_state
                })
            
            return cluster_list
        
        except Exception as e:
            raise RuntimeError(f"Failed to list clusters: {str(e)}")
    
    def get_cluster_credentials(self, cluster_name: str, resource_group: str) -> Dict[str, Any]:
        """Get cluster credentials information."""
        try:
            # Get admin credentials info (metadata only)
            creds = self.aks_client.managed_clusters.list_cluster_admin_credentials(
                resource_group, cluster_name
            )
            
            return {
                'has_admin_credentials': len(creds.kubeconfigs) > 0,
                'credential_count': len(creds.kubeconfigs)
            }
        
        except Exception as e:
            return {
                'has_admin_credentials': False,
                'credential_count': 0,
                'error': str(e)
            }
    
    def get_node_pools(self, cluster_name: str, resource_group: str) -> List[Dict[str, Any]]:
        """Get information about cluster node pools."""
        try:
            node_pools = self.aks_client.agent_pools.list(resource_group, cluster_name)
            
            pool_info = []
            for pool in node_pools:
                pool_info.append({
                    'name': pool.name,
                    'count': pool.count,
                    'vm_size': pool.vm_size,
                    'os_type': pool.os_type,
                    'orchestrator_version': pool.orchestrator_version,
                    'provisioning_state': pool.provisioning_state,
                    'power_state': pool.power_state.code if pool.power_state else None,
                    'mode': pool.mode,
                    'max_pods': pool.max_pods,
                    'availability_zones': list(pool.availability_zones) if pool.availability_zones else []
                })
            
            return pool_info
        
        except Exception as e:
            raise RuntimeError(f"Failed to get node pools: {str(e)}")
    
    def _extract_network_profile(self, network_profile) -> Optional[Dict[str, Any]]:
        """Extract network profile information."""
        if not network_profile:
            return None
        
        return {
            'network_plugin': network_profile.network_plugin,
            'network_policy': network_profile.network_policy,
            'pod_cidr': network_profile.pod_cidr,
            'service_cidr': network_profile.service_cidr,
            'dns_service_ip': network_profile.dns_service_ip,
            'docker_bridge_cidr': network_profile.docker_bridge_cidr,
            'load_balancer_sku': network_profile.load_balancer_sku
        }
    
    def _extract_agent_pools(self, agent_pools) -> List[Dict[str, Any]]:
        """Extract agent pool information."""
        if not agent_pools:
            return []
        
        pools = []
        for pool in agent_pools:
            pools.append({
                'name': pool.name,
                'count': pool.count,
                'vm_size': pool.vm_size,
                'os_type': pool.os_type,
                'mode': pool.mode,
                'max_pods': pool.max_pods
            })
        
        return pools
    
    def _extract_addon_profiles(self, addon_profiles) -> Dict[str, Dict[str, Any]]:
        """Extract addon profile information."""
        if not addon_profiles:
            return {}
        
        addons = {}
        for addon_name, addon_profile in addon_profiles.items():
            addons[addon_name] = {
                'enabled': addon_profile.enabled,
                'config': dict(addon_profile.config) if addon_profile.config else {}
            }
        
        return addons