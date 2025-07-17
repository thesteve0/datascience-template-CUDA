#!/bin/bash

PROJECT_NAME="{{PROJECT_NAME}}"

echo "Cleaning up $PROJECT_NAME development environment..."

# Stop any running devcontainer
echo "Stopping any running devcontainers..."
podman ps -q --filter "label=devcontainer.metadata" | xargs -r podman stop

echo "Cleanup complete. Volumes preserved."
echo ""
echo "For full cleanup (deletes all data and volumes):"
echo "  podman volume rm ${PROJECT_NAME}-models ${PROJECT_NAME}-datasets ${PROJECT_NAME}-cache-hf ${PROJECT_NAME}-cache-torch"