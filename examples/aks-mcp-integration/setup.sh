#!/bin/bash

# AKS-MCP Setup Script
# This script helps users download and configure the AKS-MCP Server

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        arm64) ARCH="arm64" ;;
        aarch64) ARCH="arm64" ;;
        *) print_error "Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    case $OS in
        linux) PLATFORM="linux-${ARCH}" ;;
        darwin) PLATFORM="darwin-${ARCH}" ;;
        mingw*|msys*|cygwin*) PLATFORM="windows-${ARCH}.exe" ;;
        *) print_error "Unsupported OS: $OS"; exit 1 ;;
    esac
    
    echo $PLATFORM
}

# Function to check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check if Azure CLI is installed
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed. Please install it first:"
        print_error "https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
        exit 1
    fi
    
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        print_warning "kubectl is not installed. It's recommended for cluster access."
    fi
    
    # Check if user is logged in to Azure
    if ! az account show &> /dev/null; then
        print_error "You are not logged in to Azure. Please run 'az login' first."
        exit 1
    fi
    
    print_status "Prerequisites check completed successfully."
}

# Function to download AKS-MCP binary
download_aks_mcp() {
    local platform=$1
    local binary_name="aks-mcp"
    
    if [[ $platform == *"windows"* ]]; then
        binary_name="aks-mcp.exe"
    fi
    
    print_status "Downloading AKS-MCP Server for $platform..."
    
    # Get the latest release URL
    local download_url="https://github.com/Azure/aks-mcp/releases/latest/download/aks-mcp-${platform}"
    
    # Download the binary
    if command -v wget &> /dev/null; then
        wget -O "$binary_name" "$download_url"
    elif command -v curl &> /dev/null; then
        curl -L -o "$binary_name" "$download_url"
    else
        print_error "Neither wget nor curl is available. Please install one of them."
        exit 1
    fi
    
    # Make it executable (not needed on Windows)
    if [[ $platform != *"windows"* ]]; then
        chmod +x "$binary_name"
    fi
    
    print_status "Downloaded $binary_name successfully."
    echo "$binary_name"
}

# Function to install binary to system path
install_binary() {
    local binary=$1
    
    if [[ "$EUID" -eq 0 ]]; then
        # Running as root
        mv "$binary" /usr/local/bin/
        print_status "Installed aks-mcp to /usr/local/bin/"
    else
        # Not running as root
        print_warning "Not running as root. Binary left in current directory."
        print_warning "To install globally, run: sudo mv $binary /usr/local/bin/"
    fi
}

# Function to create sample configuration
create_sample_config() {
    local config_dir="$HOME/.config/mcp"
    local config_file="$config_dir/mcp.json"
    
    print_status "Creating sample MCP configuration..."
    
    # Create directory if it doesn't exist
    mkdir -p "$config_dir"
    
    # Get user input for cluster details
    echo ""
    read -p "Enter your AKS cluster name: " cluster_name
    read -p "Enter your resource group name: " resource_group
    read -p "Enter your subscription ID (optional): " subscription_id
    
    # Create configuration
    cat > "$config_file" << EOF
{
  "mcpServers": {
    "aks-mcp": {
      "command": "aks-mcp",
      "args": [
        "--cluster-name", "$cluster_name",
        "--resource-group", "$resource_group"
$(if [ -n "$subscription_id" ]; then echo "        ,\"--subscription\", \"$subscription_id\""; fi)
      ]
    }
  }
}
EOF
    
    print_status "Created MCP configuration at $config_file"
}

# Function to verify installation
verify_installation() {
    print_status "Verifying installation..."
    
    if command -v aks-mcp &> /dev/null; then
        print_status "AKS-MCP is available in PATH"
        aks-mcp --version || print_warning "Could not get version info"
    else
        print_warning "AKS-MCP is not in PATH. You may need to use ./aks-mcp or install it globally"
    fi
}

# Main function
main() {
    echo "========================================="
    echo "    AKS-MCP Server Setup Script"
    echo "========================================="
    echo ""
    
    # Check prerequisites
    check_prerequisites
    
    # Detect platform
    platform=$(detect_platform)
    print_status "Detected platform: $platform"
    
    # Download binary
    binary=$(download_aks_mcp "$platform")
    
    # Install binary (if running as root or user confirms)
    if [[ "$EUID" -eq 0 ]]; then
        install_binary "$binary"
    else
        echo ""
        read -p "Install aks-mcp to /usr/local/bin? (requires sudo) [y/N]: " install_choice
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            sudo mv "$binary" /usr/local/bin/
            print_status "Installed aks-mcp to /usr/local/bin/"
        fi
    fi
    
    # Create sample configuration
    echo ""
    read -p "Create sample MCP configuration? [Y/n]: " config_choice
    if [[ ! $config_choice =~ ^[Nn]$ ]]; then
        create_sample_config
    fi
    
    # Verify installation
    verify_installation
    
    echo ""
    print_status "Setup completed!"
    echo ""
    echo "Next steps:"
    echo "1. Configure your VS Code with MCP extension"
    echo "2. Start using AI assistants with AKS context"
    echo "3. Visit https://github.com/Azure/aks-mcp for more information"
}

# Run main function
main "$@"