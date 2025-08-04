#!/bin/bash
set -e

echo "Setting up {{PROJECT_NAME}} PyTorch ML environment..."

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
export PATH="$HOME/.cargo/bin:$PATH"

# Install development tools
pip install --no-cache-dir black flake8 pre-commit

echo "Setup complete!"
echo "Put images in ./datasets/ - they'll appear in pytorch-CycleGAN-and-pix2pix/datasets/"
