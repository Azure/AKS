#!/usr/bin/env python3
"""
AKS CLI Agent - Main CLI interface
"""

import os
import sys
import click
from rich.console import Console
from rich.panel import Panel
from rich.text import Text

from .agent import AKSAgent
from .auth import AzureAuth
from .config import Config

console = Console()


@click.group()
@click.option('--config', '-c', help='Path to configuration file')
@click.option('--verbose', '-v', is_flag=True, help='Enable verbose logging')
@click.pass_context
def cli(ctx, config, verbose):
    """AKS CLI Agent - AI-powered operations and diagnostics for Azure Kubernetes Service."""
    ctx.ensure_object(dict)
    ctx.obj['config_path'] = config
    ctx.obj['verbose'] = verbose


@cli.command()
@click.argument('query', required=True)
@click.option('--cluster', '-c', help='AKS cluster name')
@click.option('--resource-group', '-g', help='Azure resource group')
@click.option('--subscription', '-s', help='Azure subscription ID')
@click.pass_context
def agent(ctx, query, cluster, resource_group, subscription):
    """Execute an AI-powered query against your AKS cluster."""
    try:
        # Load configuration
        config = Config(ctx.obj.get('config_path'))
        
        # Initialize Azure authentication
        auth = AzureAuth()
        if not auth.is_authenticated():
            console.print("❌ Azure CLI authentication required. Please run 'az login' first.", style="red")
            sys.exit(1)
        
        # Initialize the AKS agent
        aks_agent = AKSAgent(config, auth)
        
        # Set cluster context if provided
        if cluster or resource_group or subscription:
            aks_agent.set_context(
                cluster_name=cluster,
                resource_group=resource_group,
                subscription_id=subscription
            )
        
        # Display query
        console.print(Panel(
            Text(query, style="bold cyan"),
            title="🤖 AKS Agent Query",
            border_style="blue"
        ))
        
        # Execute the query
        console.print("🔍 Analyzing your AKS environment...")
        result = aks_agent.execute_query(query)
        
        # Display results
        console.print(Panel(
            result,
            title="📋 Analysis Results",
            border_style="green"
        ))
        
    except Exception as e:
        console.print(f"❌ Error: {str(e)}", style="red")
        if ctx.obj.get('verbose'):
            import traceback
            console.print(traceback.format_exc())
        sys.exit(1)


@cli.command()
def status():
    """Check the status of the AKS Agent and its dependencies."""
    try:
        console.print("🔍 Checking AKS Agent status...")
        
        # Check Azure CLI
        auth = AzureAuth()
        if auth.is_authenticated():
            account_info = auth.get_account_info()
            console.print(f"✅ Azure CLI authenticated as: {account_info.get('user', {}).get('name', 'Unknown')}")
        else:
            console.print("❌ Azure CLI not authenticated. Run 'az login' first.", style="red")
        
        # Check kubectl
        import subprocess
        try:
            result = subprocess.run(['kubectl', 'version', '--client'], capture_output=True, text=True)
            if result.returncode == 0:
                console.print("✅ kubectl available")
            else:
                console.print("❌ kubectl not available or not configured", style="red")
        except FileNotFoundError:
            console.print("❌ kubectl not installed", style="red")
        
        # Check configuration
        config = Config()
        if config.is_configured():
            console.print("✅ AKS Agent configured")
        else:
            console.print("⚠️  AKS Agent not configured. AI features may be limited.", style="yellow")
        
        console.print("\n📖 For help, run: aks-agent --help")
        
    except Exception as e:
        console.print(f"❌ Error checking status: {str(e)}", style="red")
        sys.exit(1)


@cli.command()
def configure():
    """Interactive configuration setup for the AKS Agent."""
    console.print("🛠️  AKS Agent Configuration Setup")
    console.print("This will help you configure AI providers and default cluster settings.\n")
    
    config = Config()
    config.interactive_setup()
    
    console.print("✅ Configuration completed! You can now use the AKS Agent.", style="green")


def main():
    """Entry point for the AKS CLI Agent."""
    # Add the parent directory to Python path to ensure imports work
    current_dir = os.path.dirname(os.path.abspath(__file__))
    parent_dir = os.path.dirname(current_dir)
    if parent_dir not in sys.path:
        sys.path.insert(0, parent_dir)
    
    cli()


if __name__ == '__main__':
    main()