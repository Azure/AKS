"""
AI Provider implementations for AKS CLI Agent.
"""

import openai
from typing import Protocol, Optional
from abc import ABC, abstractmethod

try:
    import anthropic
    ANTHROPIC_AVAILABLE = True
except ImportError:
    ANTHROPIC_AVAILABLE = False


class AIProvider(ABC):
    """Abstract base class for AI providers."""
    
    @abstractmethod
    def generate_response(self, prompt: str) -> str:
        """Generate a response to the given prompt."""
        pass


class OpenAIProvider(AIProvider):
    """OpenAI provider implementation."""
    
    def __init__(self, api_key: str, model: str = "gpt-4"):
        self.client = openai.OpenAI(api_key=api_key)
        self.model = model
    
    def generate_response(self, prompt: str) -> str:
        """Generate response using OpenAI API."""
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system", 
                        "content": "You are an expert AKS operations specialist. Provide clear, actionable advice."
                    },
                    {"role": "user", "content": prompt}
                ],
                max_tokens=2000,
                temperature=0.1
            )
            return response.choices[0].message.content
        except Exception as e:
            raise RuntimeError(f"OpenAI API error: {str(e)}")


class AzureOpenAIProvider(AIProvider):
    """Azure OpenAI provider implementation."""
    
    def __init__(self, endpoint: str, api_key: str, model: str = "gpt-4"):
        self.client = openai.AzureOpenAI(
            azure_endpoint=endpoint,
            api_key=api_key,
            api_version="2024-02-15-preview"
        )
        self.model = model
    
    def generate_response(self, prompt: str) -> str:
        """Generate response using Azure OpenAI API."""
        try:
            response = self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {
                        "role": "system", 
                        "content": "You are an expert AKS operations specialist. Provide clear, actionable advice."
                    },
                    {"role": "user", "content": prompt}
                ],
                max_tokens=2000,
                temperature=0.1
            )
            return response.choices[0].message.content
        except Exception as e:
            raise RuntimeError(f"Azure OpenAI API error: {str(e)}")


class AnthropicProvider(AIProvider):
    """Anthropic Claude provider implementation."""
    
    def __init__(self, api_key: str, model: str = "claude-3-sonnet-20240229"):
        if not ANTHROPIC_AVAILABLE:
            raise RuntimeError("Anthropic package not available. Install with: pip install anthropic")
        
        self.client = anthropic.Anthropic(api_key=api_key)
        self.model = model
    
    def generate_response(self, prompt: str) -> str:
        """Generate response using Anthropic API."""
        try:
            response = self.client.messages.create(
                model=self.model,
                max_tokens=2000,
                system="You are an expert AKS operations specialist. Provide clear, actionable advice.",
                messages=[
                    {"role": "user", "content": prompt}
                ]
            )
            return response.content[0].text
        except Exception as e:
            raise RuntimeError(f"Anthropic API error: {str(e)}")


class AIProviderFactory:
    """Factory class for creating AI provider instances."""
    
    @staticmethod
    def create_provider(provider_type: str, config) -> Optional[AIProvider]:
        """Create an AI provider instance based on configuration."""
        if provider_type == "openai":
            api_key = config.get('ai_provider.api_key')
            model = config.get('ai_provider.model', 'gpt-4')
            if not api_key:
                raise ValueError("OpenAI API key not configured")
            return OpenAIProvider(api_key, model)
        
        elif provider_type == "azure_openai":
            endpoint = config.get('ai_provider.endpoint')
            api_key = config.get('ai_provider.api_key')
            model = config.get('ai_provider.model', 'gpt-4')
            if not endpoint or not api_key:
                raise ValueError("Azure OpenAI endpoint and API key must be configured")
            return AzureOpenAIProvider(endpoint, api_key, model)
        
        elif provider_type == "anthropic":
            api_key = config.get('ai_provider.api_key')
            model = config.get('ai_provider.model', 'claude-3-sonnet-20240229')
            if not api_key:
                raise ValueError("Anthropic API key not configured")
            return AnthropicProvider(api_key, model)
        
        else:
            raise ValueError(f"Unsupported AI provider type: {provider_type}")