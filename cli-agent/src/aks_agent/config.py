"""
Configuration management for AKS CLI Agent.
"""

import os
import yaml
from pathlib import Path
from typing import Dict, Optional, Any
from rich.console import Console
from rich.prompt import Prompt, Confirm

console = Console()


class Config:
    """Manages configuration for the AKS CLI Agent."""
    
    DEFAULT_CONFIG_DIR = Path.home() / ".aks-agent"
    DEFAULT_CONFIG_FILE = DEFAULT_CONFIG_DIR / "config.yaml"
    
    def __init__(self, config_path: Optional[str] = None):
        self.config_path = Path(config_path) if config_path else self.DEFAULT_CONFIG_FILE
        self._config = {}
        self.load_config()
    
    def load_config(self):
        """Load configuration from file."""
        if self.config_path.exists():
            try:
                with open(self.config_path, 'r') as f:
                    self._config = yaml.safe_load(f) or {}
            except (yaml.YAMLError, IOError) as e:
                console.print(f"⚠️  Warning: Could not load config file: {e}", style="yellow")
                self._config = {}
        else:
            self._config = self.get_default_config()
    
    def save_config(self):
        """Save configuration to file."""
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        try:
            with open(self.config_path, 'w') as f:
                yaml.dump(self._config, f, default_flow_style=False)
        except IOError as e:
            console.print(f"❌ Error saving config: {e}", style="red")
            raise
    
    def get_default_config(self) -> Dict[str, Any]:
        """Get default configuration."""
        return {
            "ai_provider": {
                "type": "azure_openai",
                "endpoint": "",
                "api_key": "",
                "model": "gpt-4"
            },
            "clusters": {
                "default_resource_group": "",
                "default_cluster": ""
            },
            "logging": {
                "level": "INFO",
                "file": str(self.DEFAULT_CONFIG_DIR / "logs" / "agent.log")
            },
            "features": {
                "auto_approve_read_operations": True,
                "auto_approve_diagnostics": True,
                "enable_telemetry": False
            }
        }
    
    def get(self, key: str, default=None):
        """Get configuration value using dot notation."""
        keys = key.split('.')
        value = self._config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value
    
    def set(self, key: str, value: Any):
        """Set configuration value using dot notation."""
        keys = key.split('.')
        config = self._config
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        config[keys[-1]] = value
    
    def is_configured(self) -> bool:
        """Check if the agent is properly configured."""
        ai_type = self.get('ai_provider.type')
        if ai_type == 'azure_openai':
            return bool(self.get('ai_provider.endpoint') and self.get('ai_provider.api_key'))
        elif ai_type == 'openai':
            return bool(self.get('ai_provider.api_key'))
        elif ai_type == 'anthropic':
            return bool(self.get('ai_provider.api_key'))
        return False
    
    def interactive_setup(self):
        """Interactive configuration setup."""
        console.print("🤖 AI Provider Configuration")
        
        # AI Provider selection
        ai_providers = ["azure_openai", "openai", "anthropic", "none"]
        current_provider = self.get('ai_provider.type', 'azure_openai')
        
        provider_choice = Prompt.ask(
            "Select AI provider",
            choices=ai_providers,
            default=current_provider
        )
        
        self.set('ai_provider.type', provider_choice)
        
        if provider_choice != 'none':
            # API configuration
            if provider_choice == 'azure_openai':
                endpoint = Prompt.ask(
                    "Azure OpenAI endpoint URL",
                    default=self.get('ai_provider.endpoint', '')
                )
                self.set('ai_provider.endpoint', endpoint)
            
            api_key = Prompt.ask(
                "API key",
                password=True,
                default=self.get('ai_provider.api_key', '')
            )
            self.set('ai_provider.api_key', api_key)
            
            model = Prompt.ask(
                "Model name",
                default=self.get('ai_provider.model', 'gpt-4')
            )
            self.set('ai_provider.model', model)
        
        console.print("\n🏢 Default Cluster Configuration")
        
        # Default cluster settings
        resource_group = Prompt.ask(
            "Default resource group",
            default=self.get('clusters.default_resource_group', '')
        )
        self.set('clusters.default_resource_group', resource_group)
        
        cluster_name = Prompt.ask(
            "Default cluster name",
            default=self.get('clusters.default_cluster', '')
        )
        self.set('clusters.default_cluster', cluster_name)
        
        console.print("\n🔧 Advanced Settings")
        
        # Features
        auto_read = Confirm.ask(
            "Auto-approve read-only operations?",
            default=self.get('features.auto_approve_read_operations', True)
        )
        self.set('features.auto_approve_read_operations', auto_read)
        
        auto_diag = Confirm.ask(
            "Auto-approve diagnostic commands?",
            default=self.get('features.auto_approve_diagnostics', True)
        )
        self.set('features.auto_approve_diagnostics', auto_diag)
        
        # Save configuration
        try:
            self.save_config()
            console.print(f"\n✅ Configuration saved to: {self.config_path}", style="green")
        except Exception as e:
            console.print(f"\n❌ Failed to save configuration: {e}", style="red")
            raise