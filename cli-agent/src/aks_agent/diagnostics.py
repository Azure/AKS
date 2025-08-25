"""
Diagnostics engine for AKS CLI Agent.
"""

import subprocess
import json
from typing import Dict, List, Optional, Any
from .config import Config


class DiagnosticsEngine:
    """Engine for running diagnostics and collecting telemetry."""
    
    def __init__(self, config: Config):
        self.config = config
    
    def run_node_diagnostics(self, node_name: Optional[str] = None) -> Dict[str, Any]:
        """Run comprehensive node diagnostics."""
        results = {
            'node_status': self._get_node_status(node_name),
            'system_pods': self._get_system_pod_status(),
            'resource_usage': self._get_node_resource_usage(node_name),
            'events': self._get_node_events(node_name)
        }
        
        return results
    
    def run_dns_diagnostics(self) -> Dict[str, Any]:
        """Run DNS-specific diagnostics."""
        results = {
            'coredns_status': self._get_coredns_status(),
            'dns_config': self._get_dns_configuration(),
            'dns_test': self._test_dns_resolution(),
            'network_policies': self._check_network_policies()
        }
        
        return results
    
    def run_pod_scheduling_diagnostics(self, namespace: str = 'default') -> Dict[str, Any]:
        """Run pod scheduling diagnostics."""
        results = {
            'pending_pods': self._get_pending_pods(namespace),
            'resource_quotas': self._get_resource_quotas(namespace),
            'node_capacity': self._get_node_capacity(),
            'scheduler_events': self._get_scheduler_events()
        }
        
        return results
    
    def run_cluster_health_check(self) -> Dict[str, Any]:
        """Run comprehensive cluster health check."""
        results = {
            'api_server': self._check_api_server_health(),
            'etcd': self._check_etcd_health(),
            'cluster_info': self._get_cluster_info(),
            'critical_pods': self._check_critical_pods(),
            'certificates': self._check_certificate_expiry()
        }
        
        return results
    
    def _get_node_status(self, node_name: Optional[str] = None) -> Dict[str, Any]:
        """Get node status information."""
        try:
            cmd = ['kubectl', 'get', 'nodes', '-o', 'json']
            if node_name:
                cmd.append(node_name)
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_system_pod_status(self) -> Dict[str, Any]:
        """Get status of system pods."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'pods', '-n', 'kube-system', '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_node_resource_usage(self, node_name: Optional[str] = None) -> Dict[str, Any]:
        """Get node resource usage."""
        try:
            cmd = ['kubectl', 'top', 'nodes']
            if node_name:
                cmd.append(node_name)
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr
            }
        except Exception as e:
            return {'error': str(e)}
    
    def _get_node_events(self, node_name: Optional[str] = None) -> Dict[str, Any]:
        """Get events related to nodes."""
        try:
            cmd = ['kubectl', 'get', 'events', '--field-selector', 'involvedObject.kind=Node']
            if node_name:
                cmd.extend(['--field-selector', f'involvedObject.name={node_name}'])
            cmd.extend(['-o', 'json'])
            
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_coredns_status(self) -> Dict[str, Any]:
        """Get CoreDNS status."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'pods', '-n', 'kube-system', 
                '-l', 'k8s-app=kube-dns', '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_dns_configuration(self) -> Dict[str, Any]:
        """Get DNS configuration."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'configmap', 'coredns', '-n', 'kube-system', '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _test_dns_resolution(self) -> Dict[str, Any]:
        """Test DNS resolution using a test pod."""
        try:
            # Create a test pod for DNS resolution
            test_cmd = [
                'kubectl', 'run', 'dns-test', '--rm', '-i', '--restart=Never',
                '--image=busybox', '--', 'nslookup', 'kubernetes.default'
            ]
            
            result = subprocess.run(test_cmd, capture_output=True, text=True, timeout=60)
            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr
            }
        except Exception as e:
            return {'error': str(e)}
    
    def _check_network_policies(self) -> Dict[str, Any]:
        """Check network policies that might affect DNS."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'networkpolicies', '--all-namespaces', '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_pending_pods(self, namespace: str = 'default') -> Dict[str, Any]:
        """Get pods that are stuck in pending state."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'pods', '-n', namespace,
                '--field-selector=status.phase=Pending', '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_resource_quotas(self, namespace: str = 'default') -> Dict[str, Any]:
        """Get resource quotas for a namespace."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'resourcequotas', '-n', namespace, '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _get_node_capacity(self) -> Dict[str, Any]:
        """Get node capacity and allocatable resources."""
        try:
            result = subprocess.run([
                'kubectl', 'describe', 'nodes'
            ], capture_output=True, text=True, timeout=30)
            
            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr
            }
        except Exception as e:
            return {'error': str(e)}
    
    def _get_scheduler_events(self) -> Dict[str, Any]:
        """Get scheduler-related events."""
        try:
            result = subprocess.run([
                'kubectl', 'get', 'events', '--field-selector', 'source=default-scheduler',
                '-o', 'json'
            ], capture_output=True, text=True, timeout=30)
            
            if result.returncode == 0:
                return json.loads(result.stdout)
        except Exception as e:
            return {'error': str(e)}
        
        return {}
    
    def _check_api_server_health(self) -> Dict[str, Any]:
        """Check API server health."""
        try:
            result = subprocess.run([
                'kubectl', 'get', '--raw', '/healthz'
            ], capture_output=True, text=True, timeout=30)
            
            return {
                'success': result.returncode == 0,
                'status': result.stdout,
                'healthy': 'ok' in result.stdout.lower()
            }
        except Exception as e:
            return {'error': str(e)}
    
    def _check_etcd_health(self) -> Dict[str, Any]:
        """Check etcd health (if accessible)."""
        try:
            result = subprocess.run([
                'kubectl', 'get', '--raw', '/healthz/etcd'
            ], capture_output=True, text=True, timeout=30)
            
            return {
                'success': result.returncode == 0,
                'status': result.stdout,
                'healthy': 'ok' in result.stdout.lower()
            }
        except Exception as e:
            return {'error': str(e)}
    
    def _get_cluster_info(self) -> Dict[str, Any]:
        """Get basic cluster information."""
        try:
            result = subprocess.run([
                'kubectl', 'cluster-info'
            ], capture_output=True, text=True, timeout=30)
            
            return {
                'success': result.returncode == 0,
                'info': result.stdout,
                'error': result.stderr
            }
        except Exception as e:
            return {'error': str(e)}
    
    def _check_critical_pods(self) -> Dict[str, Any]:
        """Check status of critical system pods."""
        critical_components = [
            'kube-dns',
            'coredns', 
            'metrics-server',
            'kube-proxy'
        ]
        
        results = {}
        for component in critical_components:
            try:
                result = subprocess.run([
                    'kubectl', 'get', 'pods', '-n', 'kube-system',
                    '-l', f'k8s-app={component}', '-o', 'json'
                ], capture_output=True, text=True, timeout=30)
                
                if result.returncode == 0:
                    results[component] = json.loads(result.stdout)
                else:
                    results[component] = {'error': result.stderr}
            except Exception as e:
                results[component] = {'error': str(e)}
        
        return results
    
    def _check_certificate_expiry(self) -> Dict[str, Any]:
        """Check certificate expiry (basic check)."""
        try:
            # This is a simplified check - in a real implementation,
            # you'd want to check actual certificate expiration dates
            result = subprocess.run([
                'kubectl', 'get', 'csr'
            ], capture_output=True, text=True, timeout=30)
            
            return {
                'success': result.returncode == 0,
                'output': result.stdout,
                'error': result.stderr
            }
        except Exception as e:
            return {'error': str(e)}