# PyTorch ML DevContainer Template

Template for PyTorch ML projects optimized for 12GB VRAM GPUs with safe dependency management and automatic external project integration.

## What This Template Provides

**Core Components:**
- NVIDIA PyTorch container (25.04-py3) with CUDA support
- VSCode devcontainer integration
- Persistent volumes for models, datasets, and caches
- Dependency conflict resolution with `resolve-dependencies.py`
- Automatic external project integration with directory mapping

**Key Features:**
- Automatic GPU access configuration
- Development tools: black, flake8, pre-commit, uv package manager
- Safe dependency installation that respects NVIDIA container packages
- Smart directory mapping for external ML/AI repositories
- Automatic symlink creation and volume mount configuration

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

Integrate an existing ML/AI repository with automatic directory mapping.

**1. Create Project (HOST)**
```bash
mkdir my-ml-project && cd my-ml-project
```

**2. Copy Template Files (HOST)**
Copy all template files to project directory

**3. Run Setup with External Repo (HOST)**
```bash
chmod +x setup-project.sh && ./setup-project.sh --clone-repo https://github.com/user/ml-project.git
```

This automatically:
- Clones the external repository
- Scans for common ML directories (data, datasets, models, checkpoints, results, logs, outputs, examples)
- Creates `project-mappings.yaml` with discovered mappings
- Updates `devcontainer.json` with volume mounts
- Creates symlinks between template structure and external project

**4. Open in VSCode (HOST)**
```bash
code .
```

**5. Reopen in Container**
VSCode will prompt to reopen in container

**6. Test Integration (DEVCONTAINER)**
```bash
# Test external project
cd cloned-project && python --version

# Run project's test commands to identify missing mappings
python test.py --help
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
├── data/                               # Dataset cache (persistent volume)
├── logs/                               # Training logs
├── experiments/                        # Experiment tracking
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
│   ├── devcontainer.json              # Modified with volume mounts
│   ├── devcontainer.json.backup       # Original backup
│   └── setup-environment.sh
├── scripts/
│   └── resolve-dependencies.py
├── external-project/                   # Cloned repository
│   ├── datasets/ -> ../data            # Symlinked to persistent volume
│   ├── checkpoints/ -> ../models       # Symlinked to persistent volume
│   ├── results/ -> ../experiments      # Symlinked to persistent volume
│   └── ...                             # Original project structure
├── project-mappings.yaml               # Auto-generated mappings
├── configs/                            # Configuration files
├── tests/                              # Test files
├── models/                             # Saved models (persistent volume)
├── data/                               # Dataset cache (persistent volume)
├── logs/                               # Training logs
├── experiments/                        # Experiment tracking
├── .cache/                             # Cache directories (persistent volumes)
│   ├── huggingface/
│   └── torch/
├── requirements.txt                    # Your dependencies
├── requirements-filtered.txt           # Filtered requirements (auto-generated)
├── nvidia-provided.txt                 # NVIDIA packages (auto-generated)
├── pyproject.toml                      # Project configuration
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

## External Project Integration Details

### Automatic Directory Scanning
The setup script scans for these common ML/AI directories:
- `data` - Input datasets
- `datasets` - Alternative dataset location
- `models` - Model definitions/code
- `checkpoints` - Saved model weights
- `results` - Training/inference outputs
- `logs` - Training logs
- `outputs` - General outputs
- `examples` - Example scripts/notebooks

### Generated Files
- **project-mappings.yaml**: Documents discovered directory mappings
- **devcontainer.json.backup**: Original configuration backup
- **Modified devcontainer.json**: Updated with volume mounts for discovered directories

### Limitations
- Does not handle git submodules (documented in code comments)
- Pattern matching may miss custom directory structures
- Manual intervention required for complex project layouts

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

**Missing Directory Mappings:**
If the automatic scan missed directories, add them manually:

```bash
# Create symlink to template directory
ln -s ../data external-project/missing-datasets

# For persistent data, add volume mount to devcontainer.json
"source=project-missing-data,target=/workspaces/project/external-project/missing-datasets,type=volume"
# Then rebuild container: Ctrl+Shift+P -> "Rebuild Container"
```

**Directory Conflicts:**
```bash
# Check discovered mappings
cat project-mappings.yaml

# Remove conflicting symlinks and create regular directory
rm external-project/conflicting-dir
mkdir external-project/conflicting-dir
```

**Testing Integration:**
```bash
# Run external project's commands to identify missing mappings
cd external-project && python test.py --help
cd external-project && python train.py --help

# Check for file access errors indicating missing mappings
cd external-project && python -c "import sys; print(sys.path)"
```

**Manual Mapping Fixes (Live Container):**
```bash
# Create missing directories
mkdir -p missing-dir

# Create symlinks (no container rebuild needed)
ln -s ../missing-dir external-project/expected-name

# Update project-mappings.yaml for documentation
echo "  - template_dir: \"missing-dir\"" >> project-mappings.yaml
echo "    project_dir: \"external-project/expected-name\"" >> project-mappings.yaml
echo "    type: \"manual\"" >> project-mappings.yaml
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

# Restore original devcontainer.json if needed
cp .devcontainer/devcontainer.json.backup .devcontainer/devcontainer.json

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

### Manual External Project Integration

If automatic scanning fails:

```bash
# Create project-mappings.yaml manually
cat > project-mappings.yaml << EOF
project:
  name: "custom-project"
  repo: "https://github.com/user/custom-project.git"
  
discovered_directories:
  - template_dir: "data"
    project_dir: "custom-project/custom-data"
    type: "manual"
EOF

# Create symlinks manually
ln -s ../data custom-project/custom-data
```

## Hardware Requirements

- **GPU:** 12GB VRAM minimum (RTX 3080 Ti, RTX 4070 Ti, etc.)
- **RAM:** 32GB system RAM recommended
- **Storage:** 1TB NVMe SSD
- **OS:** Linux with NVIDIA drivers + Docker + NVIDIA Container Toolkit

## Current Status

✅ **Completed:**
- Devcontainer configuration with GPU access
- Dependency conflict resolution system
- External project integration with automatic directory mapping
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
- **Custom directory patterns:** Modify scanning logic in setup-project.sh

## License

MIT License - feel free to use this template for your ML projects.
