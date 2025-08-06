# PyTorch ML DevContainer Template

Template for PyTorch ML projects optimized for 12GB VRAM GPUs with safe dependency management and external project integration.

## What This Template Provides

**Core Components:**
- NVIDIA PyTorch container (25.04-py3) with CUDA support
- VSCode devcontainer integration
- Persistent volumes for models, datasets, and caches
- Dependency conflict resolution with `resolve-dependencies.py`
- External project integration with simple cloning

**Key Features:**
- Automatic GPU access configuration
- Development tools: black, flake8, pre-commit, uv package manager
- Safe dependency installation that respects NVIDIA container packages
- Fork-friendly external repo integration using bind mounts
- Simple clone approach (no submodules or complex directory mapping)

## Quick Start

### Option A: Standalone Project

Create a new ML project from scratch with the template structure.

**1. Create Project (HOST)**
```bash
mkdir my-ml-project && cd my-ml-project
```

**2. Copy Template Files (HOST)**
Copy all template files (devcontainer.json, setup-environment.sh, resolve-dependencies.py, setup-project.sh, cleanup-script.sh) to project directory

**3. Run Setup (HOST)**
```bash
chmod +x setup-project.sh && ./setup-project.sh
```

**4. Open in VSCode (HOST)**
```bash
code .
```

**5. Reopen in Container**
- VSCode will prompt: "Reopen in Container"
- Or use Command Palette: `Dev Containers: Reopen in Container`

**6. Install Dependencies (DEVCONTAINER)**
```bash
# Create requirements.txt with your ML dependencies
cat > requirements.txt << EOF
transformers>=4.30.0
datasets
accelerate
wandb
EOF

# Filter dependencies to avoid conflicts
python scripts/resolve-dependencies.py requirements.txt

# Install filtered dependencies
uv pip install --break-system-packages --system -r requirements-filtered.txt
```

**7. Verify Setup (DEVCONTAINER)**
```bash
# Test GPU access
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
```

### Option B: External Project Integration

Integrate an existing ML/AI repository using simple cloning approach.

**0. Fork the repository you are going to want to use**

**1. Create Project (HOST)**
```bash
mkdir my-ml-project && cd my-ml-project
```

**2. Copy Template Files (HOST)**
Copy all template files to project directory

**3. Run Setup with External Repo (HOST)**
Use the git URL for your forked project. This way if you make changes you can save them back to your fork.
```bash
chmod +x setup-project.sh && ./setup-project.sh --clone-repo https://github.com/user/ml-project.git
```

This automatically:
- Clones the external forked repository to project root
- Sets PYTHONPATH to point to cloned repo
- Adds cloned repo to .gitignore
- Configures devcontainer for external repo access

**4. Open in VSCode (HOST)**
```bash
code .
```

**5. Reopen in Container**
VSCode will prompt to reopen in container

**6. Test Integration (DEVCONTAINER)**
```bash
# Test external project
cd cloned-repo && python --version

# Run project's commands to test setup
python -c "import sys; print(sys.path)"
```

**7. Install Dependencies (DEVCONTAINER)**
```bash
# Extract dependencies from external project
# (from requirements.txt, environment.yml, pyproject.toml, etc.)

# Filter dependencies
python scripts/resolve-dependencies.py requirements.txt

# Install
uv pip install --break-system-packages --system -r requirements-filtered.txt
```

## Project Structure

### Standalone Project
```
my-ml-project/
├── .devcontainer/
│   ├── devcontainer.json              # Container configuration
│   └── setup-environment.sh           # Environment setup script
├── scripts/
│   └── resolve-dependencies.py        # Dependency conflict resolver
├── src/my-ml-project/                  # Main package code
├── configs/                            # Configuration files
├── tests/                              # Test files
├── models/                             # Saved models (persistent volume)
├── datasets/                           # Dataset cache (persistent volume)
├── .cache/                             # Cache directories (persistent volumes)
│   ├── huggingface/
│   └── torch/
├── requirements.txt                    # Your dependencies
├── requirements-filtered.txt           # Filtered requirements (auto-generated)
├── nvidia-provided.txt                 # NVIDIA packages (auto-generated)
├── pyproject.toml                      # Project configuration
└── README.md
```

### External Project Integration
```
my-ml-project/
├── .devcontainer/
│   ├── devcontainer.json              # Container configuration
│   └── setup-environment.sh           # Environment setup script
├── scripts/
│   └── resolve-dependencies.py        # Dependency conflict resolver
├── external-repo/                     # Cloned repository (in .gitignore)
│   ├── src/                            # Original project structure
│   ├── data/                           # Original data directory
│   ├── models/                         # Original models directory
│   └── ...                             # All original files preserved
├── .gitignore                          # Contains external-repo/
├── requirements.txt                    # Your dependencies
├── requirements-filtered.txt           # Filtered requirements (auto-generated)
├── nvidia-provided.txt                 # NVIDIA packages (auto-generated)
└── README.md
```

## Dependency Management

### How Conflict Resolution Works

1. **NVIDIA Package Detection:**
   - Extracts packages from NVIDIA container to `nvidia-provided.txt`
   - Example: `torch==2.5.0+cu124`, `numpy==1.26.4`

2. **Conflict Filtering:**
   - `resolve-dependencies.py` compares your requirements against NVIDIA packages
   - Skips packages that would conflict: `torch`, `numpy`, `PIL`, etc.
   - Comments out conflicts in filtered file with explanation

3. **Safe Installation:**
   - Only installs packages that don't conflict with NVIDIA's optimized versions
   - Preserves NVIDIA's CUDA-optimized builds

### Example Filter Output

**Original requirements.txt:**
```
torch>=2.0.0
transformers>=4.30.0
numpy>=1.24.0
vllm>=0.3.0
```

**Generated requirements-filtered.txt:**
```
# torch>=2.0.0  # Skipped: NVIDIA provides torch==2.5.0+cu124
transformers>=4.30.0
# numpy>=1.24.0  # Skipped: NVIDIA provides numpy==1.26.4
vllm>=0.3.0
```

## Development Workflow

### Package Management

**Using uv with system environment:**
Since we're working with NVIDIA's pre-configured PyTorch container, we install into the system environment rather than creating virtual environments. This preserves NVIDIA's optimized CUDA and PyTorch installations:

```bash
# Add individual packages
uv pip install --system transformers

# Install from requirements
uv pip install --system -r requirements-filtered.txt

# Install project in development mode
uv pip install --system -e .
```

**Adding new dependencies:**
```bash
# HOST: Add to requirements.txt
echo "wandb>=0.15.0" >> requirements.txt

# DEVCONTAINER: Filter and install
python scripts/resolve-dependencies.py requirements.txt
uv pip install --system -r requirements-filtered.txt
```

### Working with External Projects

**External repo approach:**
- Uses simple git clone (not submodules)
- Cloned repo added to .gitignore
- PYTHONPATH points to cloned repo
- No automatic directory mapping or symlinks
- Fork-friendly: changes to template don't affect external repo

**Making changes to external repo:**
```bash
# Work directly in cloned repo
cd external-repo
git checkout -b my-feature
# Make changes
git add . && git commit -m "My changes"
git push origin my-feature
```

### Code Quality

```bash
# Install pre-commit hooks
pre-commit install

# Run code formatting
black src/ tests/
flake8 src/ tests/

# Run pre-commit on all files
pre-commit run --all-files
```

## Troubleshooting

### External Project Integration Issues

**Clone conflicts:**
If directory already exists, setup will fail. Remove existing directory or use different project name.

**PYTHONPATH issues:**
```bash
# Check PYTHONPATH in container
echo $PYTHONPATH
# Should show: /workspaces/project-name/external-repo

# Verify Python can find modules
python -c "import sys; print('\n'.join(sys.path))"
```

**Missing dependencies:**
```bash
# Check external repo for dependency files
ls external-repo/ | grep -E "(requirements|environment|pyproject)"

# Extract and filter dependencies
python scripts/resolve-dependencies.py external-repo/requirements.txt
uv pip install --system -r requirements-filtered.txt
```

**Working with forks:**
```bash
# In external-repo directory
git remote add upstream https://github.com/original/repo.git
git fetch upstream
git checkout -b sync-upstream
git merge upstream/main
```

### Container Issues
```bash
# Rebuild container
Dev Containers: Rebuild Container

# Check GPU access
nvidia-smi
python -c "import torch; print(torch.cuda.device_count())"
```

### Dependency Conflicts
```bash
# Check filtered dependencies
cat requirements-filtered.txt | grep "# Skipped"

# See NVIDIA-provided packages
head -20 nvidia-provided.txt

# Test dependency installation
uv pip install --system -r requirements-filtered.txt
```

### Performance Issues
```bash
# Check GPU memory usage
python -c "import torch; print(f'GPU Memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.1f}GB')"

# Monitor GPU utilization
watch -n 1 nvidia-smi

# Check container resource limits
docker stats
```

## Advanced Usage

### Custom Dependency Lists

If you need to use a different base container:

```bash
# Extract packages from your specific container
docker run --rm your-container:tag pip freeze > custom-nvidia-provided.txt

# Use custom list
python scripts/resolve-dependencies.py requirements.txt --nvidia-file custom-nvidia-provided.txt
```

### Multi-Stage Dependency Installation

For complex dependency chains:

```bash
# Stage 1: Core ML libraries
python scripts/resolve-dependencies.py requirements-core.txt
uv pip install --system -r requirements-core-filtered.txt

# Stage 2: Additional tools
python scripts/resolve-dependencies.py requirements-tools.txt
uv pip install --system -r requirements-tools-filtered.txt
```

### Working with Multiple External Repos

```bash
# Create separate template projects
mkdir project-a && cd project-a
# Copy template files and run setup
./setup-project.sh --clone-repo https://github.com/user/repo-a.git

cd ../
mkdir project-b && cd project-b  
# Copy template files and run setup
./setup-project.sh --clone-repo https://github.com/user/repo-b.git
```

## Hardware Requirements

- **GPU:** 12GB VRAM minimum (RTX 3080 Ti, RTX 4070 Ti, etc.)
- **RAM:** 32GB system RAM recommended
- **Storage:** 1TB NVMe SSD
- **OS:** Linux with NVIDIA drivers + Docker + NVIDIA Container Toolkit

## Key Design Decisions

**Fork-friendly approach:**
- External repos cloned, not submoduled
- Template changes don't affect external repo
- Simple directory structure without complex mapping

**Bind mounts throughout:**
- Persistent volumes for models, datasets, caches
- No symlinks to avoid filesystem complexity
- Cross-platform compatibility

**Error on conflicts:**
- Setup fails fast on naming conflicts
- Clear error messages for troubleshooting
- No automatic conflict resolution

## Current Status

✅ **Completed:**
- Devcontainer configuration with GPU access
- Dependency conflict resolution system
- External project integration with simple cloning
- Project structure and tooling setup
- VSCode integration with Python extensions

🔄 **Future Enhancements:**
- GUI for dependency management
- Additional ML framework templates
- Automated testing integration
- Multi-GPU support configuration

## Contributing

This template is designed to be forked and customized. Common customizations:

- **Different base containers:** Update devcontainer.json image
- **Additional tools:** Add to setup-environment.sh
- **Custom external repo patterns:** Modify setup-project.sh logic

## License

MIT License - feel free to use this template for your ML projects.
