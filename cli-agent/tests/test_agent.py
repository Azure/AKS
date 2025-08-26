"""
Unit tests for AKS CLI Agent core functionality.
"""

import pytest
import json
from unittest.mock import Mock, patch, MagicMock

# Import the modules we want to test
import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from aks_agent.agent import AKSAgent
from aks_agent.config import Config
from aks_agent.auth import AzureAuth


class TestAKSAgent:
    """Test cases for the main AKS Agent functionality."""
    
    @pytest.fixture
    def mock_config(self):
        """Create a mock configuration."""
        config = Mock(spec=Config)
        config.get.return_value = None
        return config
    
    @pytest.fixture
    def mock_auth(self):
        """Create a mock authentication object."""
        auth = Mock(spec=AzureAuth)
        auth.get_subscription_id.return_value = "test-sub-id"
        auth.is_authenticated.return_value = True
        return auth
    
    @patch('aks_agent.agent.AIProviderFactory')
    @patch('aks_agent.agent.AzureClient')
    @patch('aks_agent.agent.KubernetesClient')
    def test_agent_initialization(self, mock_k8s, mock_azure, mock_ai_factory, mock_config, mock_auth):
        """Test AKS Agent initialization."""
        # Arrange
        mock_config.get.side_effect = lambda key, default=None: {
            'ai_provider.type': 'azure_openai',
            'clusters.default_cluster': 'test-cluster',
            'clusters.default_resource_group': 'test-rg'
        }.get(key, default)
        
        # Act
        agent = AKSAgent(mock_config, mock_auth)
        
        # Assert
        assert agent.cluster_name == 'test-cluster'
        assert agent.resource_group == 'test-rg'
        assert agent.subscription_id == 'test-sub-id'
    
    def test_query_analysis_node_health(self, mock_config, mock_auth):
        """Test query analysis for node health queries."""
        # Arrange
        with patch('aks_agent.agent.AIProviderFactory'), \
             patch('aks_agent.agent.AzureClient'), \
             patch('aks_agent.agent.KubernetesClient'):
            agent = AKSAgent(mock_config, mock_auth)
        
        # Act & Assert
        assert agent._analyze_query("why is my node not ready?") == 'node_health'
        assert agent._analyze_query("kubelet issues") == 'node_health'
        assert agent._analyze_query("NotReady nodes") == 'node_health'
    
    def test_query_analysis_dns(self, mock_config, mock_auth):
        """Test query analysis for DNS queries."""
        # Arrange
        with patch('aks_agent.agent.AIProviderFactory'), \
             patch('aks_agent.agent.AzureClient'), \
             patch('aks_agent.agent.KubernetesClient'):
            agent = AKSAgent(mock_config, mock_auth)
        
        # Act & Assert
        assert agent._analyze_query("DNS lookup failures") == 'dns_troubleshooting'
        assert agent._analyze_query("coredns problems") == 'dns_troubleshooting'
        assert agent._analyze_query("name resolution issues") == 'dns_troubleshooting'
    
    def test_query_analysis_pod_scheduling(self, mock_config, mock_auth):
        """Test query analysis for pod scheduling queries."""
        # Arrange
        with patch('aks_agent.agent.AIProviderFactory'), \
             patch('aks_agent.agent.AzureClient'), \
             patch('aks_agent.agent.KubernetesClient'):
            agent = AKSAgent(mock_config, mock_auth)
        
        # Act & Assert
        assert agent._analyze_query("pod stuck pending") == 'pod_troubleshooting'
        assert agent._analyze_query("scheduling failures") == 'pod_troubleshooting'
        assert agent._analyze_query("evicted pods") == 'pod_troubleshooting'
    
    @patch('aks_agent.agent.KubernetesClient')
    @patch('aks_agent.agent.AzureClient')
    def test_execute_basic_query_node_health(self, mock_azure_client, mock_k8s_client, mock_config, mock_auth):
        """Test basic query execution for node health."""
        # Arrange
        mock_config.get.return_value = None  # No AI provider
        
        with patch('aks_agent.agent.AIProviderFactory'):
            agent = AKSAgent(mock_config, mock_auth)
            
            # Mock context data
            mock_nodes = [
                {'name': 'node1', 'status': 'Ready'},
                {'name': 'node2', 'status': 'NotReady'}
            ]
            
            context = {
                'nodes': mock_nodes,
                'cluster_name': 'test-cluster'
            }
        
        # Act
        result = agent._execute_basic_query("node health check", context, 'node_health')
        
        # Assert
        assert "Node Health Analysis" in result
        assert "1 node(s) not ready" in result
    
    def test_set_context(self, mock_config, mock_auth):
        """Test setting cluster context."""
        # Arrange
        with patch('aks_agent.agent.AIProviderFactory'), \
             patch('aks_agent.agent.AzureClient'), \
             patch('aks_agent.agent.KubernetesClient'):
            agent = AKSAgent(mock_config, mock_auth)
        
        # Act
        agent.set_context(
            cluster_name='new-cluster',
            resource_group='new-rg',
            subscription_id='new-sub'
        )
        
        # Assert
        assert agent.cluster_name == 'new-cluster'
        assert agent.resource_group == 'new-rg'
        assert agent.subscription_id == 'new-sub'


class TestConfig:
    """Test cases for configuration management."""
    
    def test_default_config(self):
        """Test default configuration values."""
        with patch('aks_agent.config.Path') as mock_path:
            mock_path.return_value.exists.return_value = False
            mock_path.return_value.parent.mkdir = Mock()
            
            config = Config()
            default_config = config.get_default_config()
            
            assert default_config['ai_provider']['type'] == 'azure_openai'
            assert default_config['logging']['level'] == 'INFO'
            assert default_config['features']['auto_approve_read_operations'] is True
    
    def test_config_get_with_dot_notation(self):
        """Test configuration get with dot notation."""
        with patch('aks_agent.config.Path') as mock_path:
            mock_path.return_value.exists.return_value = False
            
            config = Config()
            
            # Test getting nested values
            ai_type = config.get('ai_provider.type')
            assert ai_type == 'azure_openai'
            
            # Test getting non-existent values
            non_existent = config.get('non.existent.key', 'default_value')
            assert non_existent == 'default_value'


class TestAzureAuth:
    """Test cases for Azure authentication."""
    
    @patch('subprocess.run')
    def test_is_authenticated_success(self, mock_run):
        """Test successful authentication check."""
        # Arrange
        mock_run.return_value.returncode = 0
        auth = AzureAuth()
        
        # Act
        result = auth.is_authenticated()
        
        # Assert
        assert result is True
        mock_run.assert_called_once_with(
            ['az', 'account', 'show'],
            capture_output=True,
            text=True,
            timeout=10
        )
    
    @patch('subprocess.run')
    def test_is_authenticated_failure(self, mock_run):
        """Test authentication check failure."""
        # Arrange
        mock_run.return_value.returncode = 1
        auth = AzureAuth()
        
        # Act
        result = auth.is_authenticated()
        
        # Assert
        assert result is False
    
    @patch('subprocess.run')
    def test_get_account_info(self, mock_run):
        """Test getting account information."""
        # Arrange
        mock_account_info = {
            'id': 'test-subscription-id',
            'user': {'name': 'test@example.com'}
        }
        mock_run.return_value.returncode = 0
        mock_run.return_value.stdout = json.dumps(mock_account_info)
        
        auth = AzureAuth()
        
        # Act
        result = auth.get_account_info()
        
        # Assert
        assert result == mock_account_info
        assert result['id'] == 'test-subscription-id'


if __name__ == '__main__':
    pytest.main([__file__])