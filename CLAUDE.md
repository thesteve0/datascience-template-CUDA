# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a PyTorch ML devcontainer template optimized for NVIDIA GPUs (12GB VRAM minimum). It provides a pre-configured development environment based on the NVIDIA PyTorch container with safe dependency management that preserves NVIDIA's optimized CUDA packages.

## Key Commands

### Host Machine (before opening in container)
```bash
# Initialize a new project from template
chmod +x setup-project.sh && ./setup-project.sh

# Initialize with external repository integration
./setup-project.sh --clone-repo https://github.com/user/repo.git
```

### Inside Devcontainer
```bash
# Filter dependencies to avoid NVIDIA conflicts
python scripts/resolve-dependencies.py requirements.txt

# Install filtered dependencies (sudo required for system packages)
sudo uv pip install --system -r requirements-filtered.txt

# Install single package
sudo uv pip install --system <package-name>

# Verify GPU access
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
nvidia-smi

# Code quality
black src/ tests/
flake8 src/ tests/
pre-commit run --all-files
```

## Architecture

### Template Files (before setup-project.sh runs)
- `Dockerfile` - Wraps NVIDIA PyTorch container, removes Ubuntu 24.04's pre-existing `ubuntu` user to fix UID mapping
- `devcontainer.json` - Container config with GPU access, named volumes, SSH agent forwarding
- `setup-environment.sh` - Runs inside container on creation, extracts nvidia-provided.txt, installs dev tools
- `setup-project.sh` - Runs on host to initialize project structure and replace template placeholders
- `resolve-dependencies.py` - Filters requirements to skip packages already provided by NVIDIA

### After setup-project.sh runs
```
project/
├── .devcontainer/
│   ├── Dockerfile
│   ├── devcontainer.json
│   └── setup-environment.sh
├── scripts/
│   └── resolve-dependencies.py
├── src/{project-name}/          # Standalone mode
│   └── __init__.py
└── {cloned-repo}/               # External repo mode (in .gitignore)
```

### Storage Model
- **Bind mount**: Main project directory for real-time code editing
- **Named volumes**: `models/`, `data/`, `.cache/` directories for large files and caches

## Dependency Management

The NVIDIA container includes optimized builds of PyTorch, NumPy, and other packages. The `resolve-dependencies.py` script:
1. Reads `nvidia-provided.txt` (generated on container startup)
2. Compares against your `requirements.txt`
3. Creates `requirements-filtered.txt` with conflicting packages commented out

Always use the filtered file for installation to preserve NVIDIA's CUDA-optimized builds.

## Template Placeholders

`setup-project.sh` replaces these in .json, .sh, and .py files:
- `{{PROJECT_NAME}}` - Directory name
- `{{DEV_USER}}` - Container username (hostname-devcontainer)
- `{{DEV_UID}}` - Container user ID (default: 2112)
- `{{GIT_NAME}}` / `{{GIT_EMAIL}}` - From host's git config

## Known Issues

**torchao/transformers conflict**: NVIDIA's bundled torchao may be incompatible with newer transformers versions (4.50+). May need to pin `transformers<4.50`. See NEXT-SESSION-TODO.md for details.

## Claude Code Integration (Optional)

See `addingClaudeCode.md` for instructions on adding Claude Code with Google Vertex AI authentication to the devcontainer.