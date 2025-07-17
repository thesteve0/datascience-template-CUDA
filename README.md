# PyTorch ML DevContainer Template

Template for PyTorch ML projects optimized for 12GB VRAM GPUs with IntelliJ IDEA remote development.

## What We Built

**Core Components:**
- NVIDIA PyTorch container (25.04-py3) with CUDA support
- IntelliJ IDEA integration via JetBrains devcontainer
- GPU-optimized configuration for 12GB VRAM
- Persistent volumes for models, datasets, and caches
- Dependency conflict resolution with resolve-dependencies.py

**Key Files:**
- `setup-project.sh` - Main setup script (creates directories, replaces templates)
- `.devcontainer/devcontainer.json` - IntelliJ/devcontainer configuration
- `.devcontainer/setup-environment.sh` - In-container ML environment setup
- `.devcontainer/resolve-dependencies.py` - Filters dependencies against NVIDIA packages
- `cleanup-script.sh` - Stop containers between sessions

## Usage

**Start New Project:**
1. Create project directory: `mkdir my-ml-project && cd my-ml-project`
2. Copy all template files (setup-project.sh, devcontainer.json, setup-environment.sh, resolve-dependencies.py, cleanup-script.sh) to project directory
3. Run: `chmod +x setup-project.sh && ./setup-project.sh`
   - Automatically uses directory name as project name
   - Creates .devcontainer structure
   - Moves files to proper locations
4. Open in IntelliJ Ultimate → Remote Development → Create Dev Container
5. Use `scripts/resolve-dependencies.py` to filter any dependency files before installing packages

**Features:**
- Automatic GPU access configuration
- ML libraries: transformers, datasets, vllm, llama-stack
- Development tools: black, pre-commit, uv package manager
- Persistent volumes for models, datasets, and caches
- Dependency conflict resolution against NVIDIA container packages

## Current Status

✅ **Completed:**
- Single-container devcontainer configuration
- GPU access and memory optimization
- Project structure creation
- Package management setup

🔄 **Next Steps:**
- Test IntelliJ devcontainer integration
- Validate GPU access within IDE
- Test ML workflow functionality

## Troubleshooting

**Container Issues:**
- GPU not found: Check NVIDIA container toolkit installation
- Permission errors: Run `cleanup-script.sh` then retry setup

**Commands:**
```bash
# Check GPU access
nvidia-smi

# Clean restart
./cleanup-script.sh && ./setup-project.sh

# View container logs
podman logs $(podman ps -q --filter "label=devcontainer.metadata")
```