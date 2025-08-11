#!/bin/bash
set -e

echo "Setting up {{PROJECT_NAME}} PyTorch ML environment..."

# --- Permissions Block ---
# Create a shared group with the host's GID and add the container user to it
# This allows seamless file sharing between host and container
CONTAINER_GROUP_NAME="{{CONTAINER_GROUP_NAME}}"
HOST_GID={{HOST_GID}}
DEV_USER={{DEV_USER}}

# Create the shared group using the host's GID if it doesn't already exist
if ! getent group ${CONTAINER_GROUP_NAME} > /dev/null && ! getent group ${HOST_GID} > /dev/null; then
    sudo groupadd -g ${HOST_GID} ${CONTAINER_GROUP_NAME}
fi

# Add the container user to the shared group
sudo usermod -aG ${CONTAINER_GROUP_NAME} ${DEV_USER}

# Set ownership and group write permissions for the workspace
sudo chown -R ${DEV_USER}:${CONTAINER_GROUP_NAME} /workspaces/{{PROJECT_NAME}}
sudo chmod -R g+w /workspaces/{{PROJECT_NAME}}
# --- End of Permissions Block ---

WORKSPACE_DIR="/workspaces/{{PROJECT_NAME}}"

# Generate nvidia-provided.txt
echo "Extracting NVIDIA-provided packages..."
if [ -f /etc/pip/constraint.txt ]; then
    grep -E "==" /etc/pip/constraint.txt | sort > ${WORKSPACE_DIR}/nvidia-provided.txt
else
    pip freeze > ${WORKSPACE_DIR}/nvidia-provided.txt
fi

# Update system packages
apt-get update && apt-get install -y \
    git curl wget build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv package manager
echo "Installing uv package manager..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.local/bin:$PATH"

# Install development tools
pip install --no-cache-dir black flake8 pre-commit

# Configure git identity
echo "Configuring git identity..."
git config --global user.name "{{GIT_NAME}}"
git config --global user.email "{{GIT_EMAIL}}"
git config --global init.defaultBranch main



echo "Setup complete!"
echo "Put images in ./datasets/ - they'll appear in pytorch-CycleGAN-and-pix2pix/datasets/"
