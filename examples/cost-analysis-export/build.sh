#!/bin/bash
set -euo pipefail

# Build and push Docker image for AKS Cost Analysis Export

if [ -z "${DOCKER_IMAGE:-}" ]; then
    echo -n "Enter your Docker image name (e.g., your-registry/aks-cost-export:latest): "
    read -r DOCKER_IMAGE
fi

echo "Building multi-arch Docker image: $DOCKER_IMAGE"

# Create buildx builder if it doesn't exist
docker buildx create --name multiarch --use --bootstrap 2>/dev/null || docker buildx use multiarch

# Build and push multi-arch image
docker buildx build --platform linux/amd64,linux/arm64 -t "$DOCKER_IMAGE" --push .

echo "✅ Multi-arch image built and pushed: $DOCKER_IMAGE"

echo ""
echo "To deploy, run:"
echo "DOCKER_IMAGE=$DOCKER_IMAGE ./deploy.sh"