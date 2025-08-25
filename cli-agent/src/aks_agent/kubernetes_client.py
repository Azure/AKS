"""
Kubernetes client for AKS CLI Agent.
"""

import subprocess
import json
from typing import Dict, List, Optional, Any
from kubernetes import client, config
from kubernetes.client.rest import ApiException


class KubernetesClient:
    """Kubernetes client wrapper for cluster operations."""
    
    def __init__(self):
        """Initialize Kubernetes client using default kubeconfig."""
        try:
            config.load_kube_config()
            self.v1 = client.CoreV1Api()
            self.apps_v1 = client.AppsV1Api()
        except Exception as e:
            raise RuntimeError(f"Failed to initialize Kubernetes client: {str(e)}")
    
    def get_nodes(self) -> List[Dict[str, Any]]:
        """Get information about cluster nodes."""
        try:
            nodes = self.v1.list_node()
            node_info = []
            
            for node in nodes.items:
                conditions = {c.type: c.status for c in node.status.conditions or []}
                
                node_info.append({
                    'name': node.metadata.name,
                    'status': 'Ready' if conditions.get('Ready') == 'True' else 'NotReady',
                    'version': node.status.node_info.kubelet_version,
                    'os': node.status.node_info.operating_system,
                    'arch': node.status.node_info.architecture,
                    'conditions': conditions,
                    'capacity': dict(node.status.capacity) if node.status.capacity else {},
                    'allocatable': dict(node.status.allocatable) if node.status.allocatable else {}
                })
            
            return node_info
        except ApiException as e:
            raise RuntimeError(f"Failed to get nodes: {str(e)}")
    
    def get_pods(self, namespace: Optional[str] = None, 
                 label_selector: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get information about pods."""
        try:
            if namespace:
                pods = self.v1.list_namespaced_pod(
                    namespace=namespace,
                    label_selector=label_selector
                )
            else:
                pods = self.v1.list_pod_for_all_namespaces(
                    label_selector=label_selector
                )
            
            pod_info = []
            for pod in pods.items:
                pod_info.append({
                    'name': pod.metadata.name,
                    'namespace': pod.metadata.namespace,
                    'phase': pod.status.phase,
                    'node_name': pod.spec.node_name,
                    'restart_count': sum(
                        c.restart_count for c in (pod.status.container_statuses or [])
                    ),
                    'ready': self._is_pod_ready(pod),
                    'age': self._calculate_age(pod.metadata.creation_timestamp)
                })
            
            return pod_info
        except ApiException as e:
            raise RuntimeError(f"Failed to get pods: {str(e)}")
    
    def get_events(self, namespace: Optional[str] = None,
                   field_selector: Optional[str] = None) -> List[Dict[str, Any]]:
        """Get cluster events."""
        try:
            if namespace:
                events = self.v1.list_namespaced_event(
                    namespace=namespace,
                    field_selector=field_selector
                )
            else:
                events = self.v1.list_event_for_all_namespaces(
                    field_selector=field_selector
                )
            
            event_info = []
            for event in events.items:
                event_info.append({
                    'type': event.type,
                    'reason': event.reason,
                    'message': event.message,
                    'object': f"{event.involved_object.kind}/{event.involved_object.name}",
                    'namespace': event.namespace,
                    'count': event.count,
                    'first_time': event.first_timestamp,
                    'last_time': event.last_timestamp
                })
            
            return event_info
        except ApiException as e:
            raise RuntimeError(f"Failed to get events: {str(e)}")
    
    def get_configmap(self, name: str, namespace: str = 'default') -> Optional[Dict[str, Any]]:
        """Get a specific ConfigMap."""
        try:
            cm = self.v1.read_namespaced_config_map(name=name, namespace=namespace)
            return {
                'name': cm.metadata.name,
                'namespace': cm.metadata.namespace,
                'data': dict(cm.data) if cm.data else {}
            }
        except ApiException as e:
            if e.status == 404:
                return None
            raise RuntimeError(f"Failed to get ConfigMap {name}: {str(e)}")
    
    def get_cluster_status(self) -> Dict[str, Any]:
        """Get overall cluster status information."""
        try:
            # Get version info
            version_info = {}
            try:
                version = client.VersionApi().get_code()
                version_info = {
                    'server_version': f"{version.major}.{version.minor}",
                    'git_version': version.git_version
                }
            except Exception:
                pass
            
            # Get component status
            component_status = []
            try:
                components = self.v1.list_component_status()
                for comp in components.items:
                    comp_conditions = []
                    if comp.conditions:
                        comp_conditions = [
                            {'type': c.type, 'status': c.status, 'message': c.message}
                            for c in comp.conditions
                        ]
                    
                    component_status.append({
                        'name': comp.metadata.name,
                        'conditions': comp_conditions
                    })
            except Exception:
                pass
            
            return {
                'version': version_info,
                'components': component_status
            }
        except Exception as e:
            raise RuntimeError(f"Failed to get cluster status: {str(e)}")
    
    def execute_command(self, command: List[str]) -> Dict[str, Any]:
        """Execute a kubectl command and return the result."""
        try:
            result = subprocess.run(
                ['kubectl'] + command,
                capture_output=True,
                text=True,
                timeout=30
            )
            
            return {
                'returncode': result.returncode,
                'stdout': result.stdout,
                'stderr': result.stderr,
                'success': result.returncode == 0
            }
        except subprocess.TimeoutExpired:
            return {
                'returncode': -1,
                'stdout': '',
                'stderr': 'Command timed out',
                'success': False
            }
        except Exception as e:
            return {
                'returncode': -1,
                'stdout': '',
                'stderr': str(e),
                'success': False
            }
    
    def _is_pod_ready(self, pod) -> bool:
        """Check if a pod is ready."""
        if not pod.status.conditions:
            return False
        
        for condition in pod.status.conditions:
            if condition.type == 'Ready':
                return condition.status == 'True'
        
        return False
    
    def _calculate_age(self, creation_timestamp) -> str:
        """Calculate age of a resource."""
        if not creation_timestamp:
            return "Unknown"
        
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc)
        age = now - creation_timestamp
        
        days = age.days
        hours, remainder = divmod(age.seconds, 3600)
        minutes, _ = divmod(remainder, 60)
        
        if days > 0:
            return f"{days}d{hours}h"
        elif hours > 0:
            return f"{hours}h{minutes}m"
        else:
            return f"{minutes}m"