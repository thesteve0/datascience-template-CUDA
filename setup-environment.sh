#!/bin/bash
set -e

echo "Setting up {{PROJECT_NAME}} PyTorch ML environment..."

# Note: No permissions block needed!
# By deleting the ubuntu user in the Dockerfile, common-utils creates our user
# with UID/GID that matches the host (typically 1000:1000), giving automatic
# permission alignment. This is simpler than the previous group-sharing approach.

WORKSPACE_DIR="/workspaces/{{PROJECT_NAME}}"

# Generate nvidia-provided.txt before creating the venv so we capture
# exactly what NVIDIA ships, with nothing from our project mixed in.
echo "Extracting NVIDIA-provided packages..."
if [ -f /etc/pip/constraint.txt ] && [ -s /etc/pip/constraint.txt ]; then
    # constraint.txt exists and has content
    grep -E "==" /etc/pip/constraint.txt | sort > ${WORKSPACE_DIR}/nvidia-provided.txt
else
    # Fall back to pip freeze (NVIDIA 25.10+ has empty constraint.txt)
    pip freeze > ${WORKSPACE_DIR}/nvidia-provided.txt
fi
echo "Found $(wc -l < ${WORKSPACE_DIR}/nvidia-provided.txt) NVIDIA-provided packages"

# Update system packages
apt-get update && apt-get install -y \
    git curl wget build-essential \
    && rm -rf /var/lib/apt/lists/*

# uv is pre-installed in NVIDIA 26.02+ containers at /usr/local/bin/uv
echo "uv version: $(uv --version)"

# Create project virtual environment
# --system-site-packages: makes NVIDIA's system packages visible inside the venv
# so uv's resolver sees torch/numpy etc. as already satisfied and won't reinstall them.
echo "Creating project virtual environment..."
uv venv --python python3 --system-site-packages ${WORKSPACE_DIR}/.venv

# Detect Python version for path construction
PYTHON_VERSION=$(python3 -c "import sys; print(f'python{sys.version_info.major}.{sys.version_info.minor}')")
echo "Python version: ${PYTHON_VERSION}"

# Validate venv Python matches system Python
SYSTEM_PY=$(python3 --version 2>&1 | cut -d' ' -f2)
VENV_PY=$(${WORKSPACE_DIR}/.venv/bin/python --version 2>&1 | cut -d' ' -f2)
if [ "$SYSTEM_PY" != "$VENV_PY" ]; then
    echo "WARNING: Python version mismatch: system=${SYSTEM_PY}, venv=${VENV_PY}"
else
    echo "Python version confirmed: ${SYSTEM_PY}"
fi

# Create .pth bridge to NVIDIA's dist-packages directory.
# NVIDIA installs packages to /usr/local/lib/pythonX.Y/dist-packages, but
# --system-site-packages only automatically includes .../site-packages.
# The bridge file adds the dist-packages path so torch, numpy, and all
# other NVIDIA-optimized packages are importable from inside the venv.
NVIDIA_DIST_PACKAGES="/usr/local/lib/${PYTHON_VERSION}/dist-packages"
VENV_SITE="${WORKSPACE_DIR}/.venv/lib/${PYTHON_VERSION}/site-packages"

if [ -d "${NVIDIA_DIST_PACKAGES}" ]; then
    echo "${NVIDIA_DIST_PACKAGES}" > "${VENV_SITE}/_nvidia_bridge.pth"
    echo "Created NVIDIA bridge: ${VENV_SITE}/_nvidia_bridge.pth -> ${NVIDIA_DIST_PACKAGES}"
else
    echo "Warning: ${NVIDIA_DIST_PACKAGES} not found, skipping bridge creation"
fi

# Inject NVIDIA package constraints into pyproject.toml.
# This is a second safety layer on top of --system-site-packages: even if uv
# tries to re-resolve torch/numpy, the constraint pins lock it to what NVIDIA
# already installed, preventing any accidental downgrade or reinstall.
echo "Injecting NVIDIA package constraints into pyproject.toml..."
python3 -c "
import os
workspace = '${WORKSPACE_DIR}'
constraints = []
with open(os.path.join(workspace, 'nvidia-provided.txt')) as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#') and '==' in line:
            constraints.append(f'  \"{line}\",')
constraint_block = '\n'.join(constraints)
pyproject_path = os.path.join(workspace, 'pyproject.toml')
with open(pyproject_path) as f:
    content = f.read()
content = content.replace('  # NVIDIA_PACKAGES_PLACEHOLDER', constraint_block)
with open(pyproject_path, 'w') as f:
    f.write(content)
print(f'Injected {len(constraints)} NVIDIA package constraints into pyproject.toml')
"

# Install development tools into the project venv (not system Python)
echo "Installing development tools (ruff, pre-commit)..."
uv pip install --python ${WORKSPACE_DIR}/.venv/bin/python ruff pre-commit

# Fix ownership so the devcontainer user can write to files created by root.
# postCreateCommand runs as root, but the workspace user is the devcontainer user.
# Bind-mount files created inside the container as root appear root-owned on the host.
WORKSPACE_UID=$(stat -c '%u' ${WORKSPACE_DIR})
WORKSPACE_GID=$(stat -c '%g' ${WORKSPACE_DIR})
if [ "${WORKSPACE_UID}" != "0" ]; then
    chown -R ${WORKSPACE_UID}:${WORKSPACE_GID} ${WORKSPACE_DIR}/.venv
    chown ${WORKSPACE_UID}:${WORKSPACE_GID} ${WORKSPACE_DIR}/nvidia-provided.txt
    echo "Fixed ownership for UID ${WORKSPACE_UID}"
fi

# Configure git identity
echo "Configuring git identity..."
git config --global user.name "{{GIT_NAME}}"
git config --global user.email "{{GIT_EMAIL}}"
git config --global init.defaultBranch main

# Verify GPU access
echo ""
echo "Verifying GPU access..."
nvidia-smi || echo "Warning: nvidia-smi failed (expected if no GPU at build time)"

echo ""
echo "Setup complete!"
echo "  Virtual environment: ${WORKSPACE_DIR}/.venv"
echo "  Add packages:        uv add <package-name>"
echo "  Verify GPU:          python -c 'import torch; print(torch.cuda.is_available())'"