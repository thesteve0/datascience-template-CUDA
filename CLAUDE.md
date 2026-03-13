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
# Add packages — uv sees NVIDIA packages as installed, no pre-filtering needed
uv add <package-name>
uv add -r requirements.txt

# Verify GPU access
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
nvidia-smi

# Verify NVIDIA builds are intact after installing packages
python -c "import numpy; print(numpy.__file__)"
# Expected: /usr/local/lib/python3.12/dist-packages/numpy/__init__.py (NOT .venv/lib/...)

# Code quality
pre-commit run --all-files
```

### Commands to AVOID inside the devcontainer

```bash
# BREAKS the environment — removes stub dist-info entries that shield NVIDIA packages
uv sync --exact

# BYPASSES the venv — may overwrite NVIDIA's CUDA-optimized packages in dist-packages
sudo uv pip install --system <package>
pip install <package>

# FAILS silently or with errors — stubs have empty RECORD files, uninstall cannot work
uv remove torch
uv remove numpy  # (or any other NVIDIA-provided package)
```

## Architecture

### Template Files (before setup-project.sh runs)
- `Dockerfile` - Wraps NVIDIA PyTorch container, removes Ubuntu 24.04's pre-existing `ubuntu` user to fix UID mapping
- `devcontainer.json` - Container config with GPU access, named volumes, SSH agent forwarding
- `setup-environment.sh` - Runs inside container on creation; creates venv, .pth bridge, stub dist-info entries, injects constraints into pyproject.toml, installs dev tools
- `setup-project.sh` - Runs on host to initialize project structure and replace template placeholders

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

The NVIDIA container installs 200+ packages (torch, numpy, flash-attn, etc.) into
`/usr/local/lib/pythonX.Y/dist-packages` — outside any virtual environment. uv's resolver
normally cannot see these, so it would reinstall them with generic PyPI builds that lack CUDA
optimizations. `setup-environment.sh` prevents this with a three-layer approach:

1. **Project venv** at `.venv` with `--system-site-packages`
2. **`.pth` bridge** (`_nvidia_bridge.pth`) in venv's `site-packages/` — makes `import torch`
   work by adding NVIDIA's `dist-packages/` to Python's path
3. **Stub `.dist-info` entries** in venv's `site-packages/` — one per NVIDIA package, each
   containing only `METADATA` (copied from NVIDIA's real dist-info), `INSTALLER` (set to
   `nvidia-container`), and an empty `RECORD`. uv reads `METADATA` to detect installed packages;
   with stubs present it sees NVIDIA packages as satisfied and skips reinstalling them.
4. **`constraint-dependencies`** injected into `pyproject.toml` — pins all NVIDIA packages to
   their exact container versions as a second safety layer against accidental upgrades.

**Why stubs instead of symlinks**: Symlinking `.dist-info` dirs into NVIDIA's read-only path
causes `Permission denied` when uv tries to write through the symlink during installation.
Copying only `METADATA` into a fresh stub directory avoids this entirely.

**Safe to do**: `uv add <pkg>` — installs only genuinely new packages into `.venv`
**Unsafe**: `uv sync --exact` — deletes stub entries; `sudo uv pip install --system` — bypasses venv

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