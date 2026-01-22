"""
Azure Authentication module for AKS CLI Agent.
"""

import json
import subprocess
from typing import Dict, Optional

from azure.identity import DefaultAzureCredential, AzureCliCredential
from azure.core.exceptions import ClientAuthenticationError


class AzureAuth:
    """Handles Azure authentication using Azure CLI credentials."""
    
    def __init__(self):
        self.credential = None
        self._account_info = None
    
    def is_authenticated(self) -> bool:
        """Check if user is authenticated with Azure CLI."""
        try:
            result = subprocess.run(
                ['az', 'account', 'show'],
                capture_output=True,
                text=True,
                timeout=10
            )
            return result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            return False
    
    def get_credential(self):
        """Get Azure credential object."""
        if not self.credential:
            try:
                # First try Azure CLI credential
                self.credential = AzureCliCredential()
                # Test the credential
                token = self.credential.get_token("https://management.azure.com/.default")
                return self.credential
            except ClientAuthenticationError:
                # Fallback to DefaultAzureCredential
                self.credential = DefaultAzureCredential()
        
        return self.credential
    
    def get_account_info(self) -> Optional[Dict]:
        """Get current Azure account information."""
        if self._account_info:
            return self._account_info
        
        try:
            result = subprocess.run(
                ['az', 'account', 'show'],
                capture_output=True,
                text=True,
                timeout=10
            )
            if result.returncode == 0:
                self._account_info = json.loads(result.stdout)
                return self._account_info
        except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
            pass
        
        return None
    
    def get_subscription_id(self) -> Optional[str]:
        """Get current subscription ID."""
        account_info = self.get_account_info()
        if account_info:
            return account_info.get('id')
        return None
    
    def list_subscriptions(self) -> list:
        """List available subscriptions."""
        try:
            result = subprocess.run(
                ['az', 'account', 'list'],
                capture_output=True,
                text=True,
                timeout=30
            )
            if result.returncode == 0:
                return json.loads(result.stdout)
        except (subprocess.TimeoutExpired, FileNotFoundError, json.JSONDecodeError):
            pass
        
        return []