#!/bin/bash
set -e

echo "Setting up test-ml-project PyTorch ML environment..."

# Generate nvidia-provided.txt from container constraints
echo "Extracting NVIDIA-provided packages..."
if [ -f /etc/pip/constraint.txt ]; then
    grep -E "==" /etc/pip/constraint.txt | sort > /workspace/nvidia-provided.txt
    echo "Generated nvidia-provided.txt with $(wc -l < /workspace/nvidia-provided.txt) packages"
else
    echo "Warning: /etc/pip/constraint.txt not found"
    touch /workspace/nvidia-provided.txt
fi

# Update system packages
apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install uv for fast package management
echo "Installing uv package manager..."
curl -LsSf https://astral.sh/uv/install.sh | sh
export PATH="$HOME/.cargo/bin:$PATH"

# Install development tools
echo "Installing development tools..."
pip install --no-cache-dir \
    pre-commit \
    flake8

# Install core ML libraries
echo "Installing additional ML libraries..."
pip install --no-cache-dir \
    tensorboard \
    wandb \
    mlflow

# Install LlamaStack and vLLM for AI agents and inference
pip install --no-cache-dir \
    llama-stack \
    vllm

# Install Hugging Face ecosystem
pip install --no-cache-dir --upgrade \
    transformers \
    datasets \
    tokenizers \
    evaluate \
    diffusers \
    accelerate \
    peft

# Copy dependency resolution script
cp /workspace/.devcontainer/resolve-dependencies.py /workspace/scripts/
chmod +x /workspace/scripts/resolve-dependencies.py

# Create sample configuration files
cat > /workspace/configs/config.yaml << 'EOF'
# test-ml-project Configuration
project_name: "test-ml-project"

# Model settings
model:
  max_memory_gb: 10  # Leave 2GB headroom for 12GB VRAM
  precision: "float16"
  
# Paths
paths:
  models: "/workspace/models"
  data: "/workspace/data"
  logs: "/workspace/logs"
  cache: "/workspace/.cache"

# Training settings
training:
  batch_size: 8  # Conservative for 12GB VRAM
  gradient_accumulation_steps: 4
  mixed_precision: true
EOF

# Create pyproject.toml template
cat > /workspace/pyproject.toml << 'EOF'
[project]
name = "test-ml-project"
version = "0.1.0"
description = "PyTorch ML project optimized for 12GB VRAM"
authors = [
    {name = "Your Name", email = "your.email@example.com"}
]
readme = "README.md"
license = {text = "MIT"}
requires-python = ">=3.10"
dependencies = [
    # Add your dependencies here
    # Use scripts/resolve-dependencies.py to filter against NVIDIA packages
]

[project.optional-dependencies]
dev = [
    "pre-commit",
    "pytest",
    "pytest-cov",
]
ml = [
    "wandb",
    "mlflow",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.black]
line-length = 88
target-version = ['py310']
include = '\.pyi?$'

[tool.pytest.ini_options]
testpaths = ["tests"]
python_files = ["test_*.py", "*_test.py"]
addopts = "-v --tb=short"
EOF

# Create .pre-commit-config.yaml
cat > /workspace/.pre-commit-config.yaml << 'EOF'
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-json
      - id: check-toml

  - repo: https://github.com/psf/black
    rev: 25.1.0
    hooks:
      - id: black
        language_version: python3

  - repo: https://github.com/pycqa/isort
    rev: 5.13.2
    hooks:
      - id: isort
        args: ["--profile", "black"]

  - repo: https://github.com/pycqa/flake8
    rev: 7.1.1
    hooks:
      - id: flake8
        args: [--max-line-length=88, --extend-ignore=E203]
EOF

# Create sample README
cat > /workspace/README.md << 'EOF'
# test-ml-project

PyTorch ML project optimized for 12GB VRAM GPUs with IntelliJ IDEA development.

## Project Structure

```
test-ml-project/
├── src/test-ml-project/     # Main package code
├── scripts/                  # Utility scripts
├── configs/                  # Configuration files
├── tests/                    # Test files
├── models/                   # Saved models (persistent volume)
├── data/                     # Dataset cache (persistent volume)
├── logs/                     # Training logs
├── pyproject.toml           # Project configuration
└── .devcontainer/           # Development environment
```

## Development Setup

Uses NVIDIA PyTorch container with devcontainer for reproducible development.

### Package Management

Uses [uv](https://github.com/astral-sh/uv) for fast Python package management:

```bash
# Add dependencies
uv add torch-geometric wandb

# Install project in development mode
uv pip install -e .
```

### Code Quality

```bash
# Install pre-commit hooks
pre-commit install

# Run manually
pre-commit run --all-files
```

### NVIDIA-Provided Packages

See `nvidia-provided.txt` for packages included in base container. Use `scripts/resolve-dependencies.py` to filter dependencies:

```bash
python scripts/resolve-dependencies.py pyproject.toml
```

### GPU Optimization

Configured for 12GB VRAM with memory management optimizations.
EOF

echo "Environment setup complete!"
echo "Project: test-ml-project"
echo "NVIDIA packages: $(wc -l < /workspace/nvidia-provided.txt) listed in nvidia-provided.txt"
echo "Package manager: uv (installed)"
echo "Code formatting: black (provided by NVIDIA), pre-commit (installed)"
echo ""
echo "Next steps:"
echo "1. Run 'pre-commit install' to set up git hooks"
echo "2. Use 'uv add <package>' to add dependencies"
echo "3. Use 'scripts/resolve-dependencies.py pyproject.toml' to filter dependencies"