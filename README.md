# PyTorch ML DevContainer Template

Template for PyTorch ML projects optimized for 12GB VRAM GPUs with safe dependency management and external project integration.

## What This Template Provides

**Core Components:**
- NVIDIA PyTorch container (26.02-py3) with CUDA support
- VSCode and JetBrains Gateway devcontainer integration
- Persistent volumes for models, datasets, and caches
- Safe dependency management that preserves NVIDIA's CUDA-optimized packages
- External project integration with simple cloning

**Key Features:**
- Automatic GPU access configuration
- Development tools: ruff, pre-commit, uv package manager
- Safe dependency installation that respects NVIDIA container packages
- Fork-friendly external repo integration using bind mounts
- Simple clone approach (no submodules or complex directory mapping)

## Prerequisites: SSH Agent for GitHub

To push changes to GitHub or clone private repositories using SSH from within the devcontainer, you must have your SSH agent running on your **host machine** with your identities added. The container securely connects to this agent.

#### 1. Check Your Agent
On your **host machine's terminal**, run this command to see if your keys are loaded:
```bash
ssh-add -l
```
* ✅ If you see the fingerprint of your key, you're all set.
* ❌ If you see The agent has no identities, you need to add your key:

```bash
# Adds your default key (e.g., ~/.ssh/id_rsa)
# If you want the non-default then just add the path to the private key at the end
# of the command
ssh-add
```
* ❌ If you see Could not open a connection to your authentication agent, the agent isn't running. You need to start it first:

```bash
eval "$(ssh-agent -s)"
ssh-add
```

### 2. Making Keys Persistent (Optional)
The SSH agent "forgets" your keys when you reboot. To have them load automatically, you'll need to configure your system's Keychain (macOS) or add a script to your Autostart applications (Linux with KDE/GNOME).

## Quick Start

### Option A: Standalone Project

Create a new ML project from scratch with the template structure.

**1. Create Project (HOST)**
```bash
mkdir my-ml-project && cd my-ml-project
```

**2. Copy Template Files (HOST)**
Copy all template files (devcontainer.json, setup-environment.sh, setup-project.sh, Dockerfile) to project directory

**3. Run Setup (HOST)**

`setup-project.sh` will prompt you to choose your IDE (VSCode, JetBrains, or both):
```bash
chmod +x setup-project.sh && ./setup-project.sh
# Or specify IDE directly:
./setup-project.sh --ide vscode
./setup-project.sh --ide jetbrains
./setup-project.sh --ide both
```

**4a. Open in VSCode (HOST)**
```bash
code .
```
VSCode will prompt: "Reopen in Container" — or use Command Palette: `Dev Containers: Reopen in Container`

Installed extensions include: Python, Pylance, Ruff, Jupyter, and GitHub Copilot.

**4b. Open in JetBrains Gateway (HOST)**
1. Open JetBrains Gateway
2. New Connection > Dev Containers > select the project folder
3. Gateway builds the container and opens PyCharm/IntelliJ inside it
4. When prompted to configure a Python SDK: select **uv**, path `/usr/local/bin/uv`, **Select existing** environment — the `.venv` will appear automatically

**5. Install Dependencies (DEVCONTAINER)**
```bash
# Add packages directly — uv handles NVIDIA conflict avoidance automatically
uv add transformers datasets accelerate wandb
```

**6. Verify Setup (DEVCONTAINER)**
```bash
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"
python test-gpu.py
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

**4. Open in your IDE and start the devcontainer** (see step 4a/4b above)

**5. Test Integration (DEVCONTAINER)**
```bash
# Test external project
cd cloned-repo && python --version

# Run project's commands to test setup
python -c "import sys; print(sys.path)"
```

**6. Install Dependencies (DEVCONTAINER)**
```bash
# Add packages directly — uv handles NVIDIA conflict avoidance automatically
uv add -r external-repo/requirements.txt
```

## Project Structure

### Standalone Project
```
my-ml-project/
├── .devcontainer/
│   ├── devcontainer.json              # Container configuration
│   └── setup-environment.sh           # Environment setup script
├── template_docs/                      # Template reference documentation
├── src/my-ml-project/                  # Main package code
├── configs/                            # Configuration files
├── tests/                              # Test files
├── models/                             # Saved models (persistent volume)
├── datasets/                           # Dataset cache (persistent volume)
├── .cache/                             # Cache directories (persistent volumes)
│   ├── huggingface/
│   └── torch/
├── requirements.txt                    # Your dependencies
├── nvidia-provided.txt                 # NVIDIA packages (auto-generated)
├── pyproject.toml                      # Project configuration
├── GETTING_STARTED.md                  # First-time setup checklist
└── README.md
```

### External Project Integration
```
my-ml-project/
├── .devcontainer/
│   ├── devcontainer.json              # Container configuration
│   └── setup-environment.sh           # Environment setup script
├── template_docs/                      # Template reference documentation
├── external-repo/                     # Cloned repository (in .gitignore)
│   ├── src/                            # Original project structure
│   ├── data/                           # Original data directory
│   ├── models/                         # Original models directory
│   └── ...                             # All original files preserved
├── .gitignore                          # Contains external-repo/
├── requirements.txt                    # Your dependencies
├── nvidia-provided.txt                 # NVIDIA packages (auto-generated)
├── GETTING_STARTED.md                  # First-time setup checklist
└── README.md
```

## Project Storage and File Management

This project uses a hybrid storage model to balance performance and ease of use. The main project directory is a **bind mount** for real-time code editing, while large datasets, models, and caches are stored in **named volumes** for better I/O performance.

These two types of storage require different methods for adding files from your host computer.

### Storage Layout

| Path in Container                     | Type         | Purpose                                  | How to Add Files             |
| :------------------------------------ | :----------- | :--------------------------------------- | :--------------------------- |
| `/workspaces/{{PROJECT_NAME}}/`       | Bind Mount   | Main project source code & scripts.      | Copy files on host           |
| `/workspaces/{{PROJECT_NAME}}/models` | Named Volume | Trained models & checkpoints.           | Use `docker cp`              |
| `/workspaces/{{PROJECT_NAME}}/data`   | Named Volume | Large datasets.                          | Use `docker cp`              |
| `/workspaces/{{PROJECT_NAME}}/.cache`| Named Volume | Caching for Hugging Face, PyTorch, etc. | Automatic                    |

<br/>

### Workflow 1: Adding Code to the Project (Bind Mount)

Use this method for source code, configuration files, or anything else you plan to commit to Git.

1.  **On your host machine,** copy or move files directly into your project folder (e.g., `~/git/{{PROJECT_NAME}}/src/`).
2.  The files will appear instantly inside the devcontainer.
3.  **Inside the devcontainer terminal,** you can now use `git add`, edit, and run the files as needed.

---
### Workflow 2: Adding Models or Datasets (Named Volumes)

Use this method for large files that you don't want to commit to Git.

1.  **On your host machine,** find your running container's ID or name:
    ```bash
    docker ps
    ```
2.  Use the `docker cp` command to copy the file from your host into the container's volume.

    **Example for a model:**
    ```bash
    # Syntax: docker cp <path_on_host> <container_id>:<path_in_container>
    docker cp ~/Downloads/my_model.pth d6c23051a929:/workspaces/{{PROJECT_NAME}}/models/
    ```

    **Example for a dataset:**
    ```bash
    docker cp ~/Downloads/my_dataset.zip d6c23051a929:/workspaces/{{PROJECT_NAME}}/data/
    ```
After the copy is complete, the files will be available inside the container at the specified path.

## Dependency Management

### How NVIDIA Package Isolation Works

The NVIDIA PyTorch container installs 200+ packages (torch, numpy, flash-attn, etc.) into
`/usr/local/lib/pythonX.Y/dist-packages` — a system path outside any virtual environment.
`uv`'s resolver normally cannot see these packages, causing it to reinstall them with generic
PyPI builds that lack CUDA optimizations.

`setup-environment.sh` solves this with a three-layer approach, applied automatically on
container creation:

1. **Project venv** (`.venv`) created with `--system-site-packages` so Python can import from
   NVIDIA's paths.

2. **`.pth` bridge** (`_nvidia_bridge.pth`) added to the venv's `site-packages/`, pointing to
   NVIDIA's `dist-packages/` directory. This makes `import torch` work inside the venv.

3. **Stub `.dist-info` entries** created in the venv's `site-packages/` for every NVIDIA package.
   uv detects installed packages by reading `METADATA` from `.dist-info` directories inside the
   target environment. With stubs present, uv's resolver sees NVIDIA packages as already
   satisfied and skips reinstalling them. Only genuinely new packages are written to the venv.

4. **`constraint-dependencies`** injected into `pyproject.toml` as a second safety layer, pinning
   all NVIDIA packages to their exact container versions to prevent accidental upgrades.

The result: `uv add transformers` installs only transformers (and its non-NVIDIA deps) — numpy,
torch, and the rest remain NVIDIA's optimized CUDA builds.

### Package Detection: `nvidia-provided.txt`

On container startup, `setup-environment.sh` extracts the full list of NVIDIA-provided packages
to `nvidia-provided.txt`. This file is used to populate the `constraint-dependencies` block in
`pyproject.toml`. You can inspect it to see exactly what NVIDIA ships:

```bash
cat nvidia-provided.txt | grep -E "torch|numpy|flash"
```

## Development Workflow

### Package Management

The project uses a `.venv` virtual environment with NVIDIA's packages visible to uv via stub
`.dist-info` entries (see [Dependency Management](#dependency-management) for details). You can
use standard `uv` commands without `sudo` and without any pre-filtering step:

```bash
# Add a single package
uv add transformers

# Add multiple packages
uv add wandb accelerate datasets

# Add from a requirements file
uv add -r requirements.txt

# Install project in development mode (if pyproject.toml has a src layout)
uv pip install -e .
```

**What NOT to do:**

| Command | Why to avoid |
|---------|-------------|
| `uv sync --exact` | Removes packages not in `pyproject.toml` — would delete NVIDIA stub entries and break the environment |
| `uv remove torch` / `uv remove numpy` | Empty `RECORD` in stubs causes uninstall to fail; these are NVIDIA's packages and should not be removed |
| `pip install <pkg>` or `sudo uv pip install --system <pkg>` | Bypasses the venv, may overwrite NVIDIA packages in dist-packages |

If you need to update a package that NVIDIA also ships (e.g., a newer transformers), be aware
that uv will install it into the venv alongside the NVIDIA stub — the venv version takes
precedence for imports. This is intentional for packages where you need a newer version than
NVIDIA provides. The `constraint-dependencies` block in `pyproject.toml` prevents unintentional
version changes; remove the constraint for a specific package only if you explicitly want to
upgrade it.

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

# Run code formatting and linting
ruff check .
ruff format .

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

# Install dependencies safely — uv automatically avoids overwriting NVIDIA packages
uv add -r requirements.txt
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

### Dependency Issues

**Verify uv sees NVIDIA packages as installed:**
```bash
# Should list torch, numpy, flash-attn, etc. — all from NVIDIA stubs
uv pip list | grep -E "torch|numpy|flash"
```

**Verify NVIDIA builds are still active after installing new packages:**
```bash
# File path should point to dist-packages, NOT .venv/lib/...
python -c "import numpy; print(numpy.__file__)"
# Expected: /usr/local/lib/python3.12/dist-packages/numpy/__init__.py

python -c "import torch; print(torch.cuda.is_available())"
# Expected: True
```

**If a package conflicts with NVIDIA's version:**
The `constraint-dependencies` block in `pyproject.toml` pins NVIDIA packages. If you explicitly
need a newer version, remove that package's constraint from `pyproject.toml` before running
`uv add`. Understand that this will install the PyPI version into the venv, shadowing NVIDIA's
CUDA-optimized build — test GPU functionality after doing so.

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

### Multi-Stage Dependency Installation

For complex dependency chains, `uv add` handles each stage naturally:

```bash
# Stage 1: Core ML libraries
uv add -r requirements-core.txt

# Stage 2: Additional tools
uv add -r requirements-tools.txt
```

### Inspecting What NVIDIA Provides

If you need to see exactly what packages and versions NVIDIA ships (e.g., to understand what
`constraint-dependencies` is pinning):

```bash
# Full list of NVIDIA-provided packages (generated on container startup)
cat nvidia-provided.txt

# Check if a specific package is NVIDIA-provided
grep -i "numpy" nvidia-provided.txt
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

**Strategic use of bind mounts and named volumes:**
- Persistent volumes for models, datasets, caches
- No symlinks to avoid filesystem complexity
- Cross-platform compatibility

**Error on conflicts:**
- Setup fails fast on naming conflicts
- Clear error messages for troubleshooting
- No automatic conflict resolution

**NVIDIA package isolation via stub dist-info (not symlinks):**
- Earlier iterations tried symlinking `.dist-info` directories from NVIDIA's path into the venv.
  This caused `Permission denied` errors when uv tried to write through symlinks into NVIDIA's
  read-only system directories.
- The current approach copies only the `METADATA` file from each `.dist-info` into a fresh stub
  directory in the venv. uv reads `METADATA` for resolution but never needs to write to it for
  detection purposes. NVIDIA's actual files are never touched.
- Stub entries are recreated from scratch on every container build, so they always match the
  container's actual NVIDIA package versions.

## Current Status

✅ **Completed:**
- Devcontainer configuration with GPU access (NVIDIA 26.02-py3)
- Safe dependency management via uv with NVIDIA package isolation
- External project integration with simple cloning
- Project structure and tooling setup (ruff, pre-commit)
- VSCode integration with Python extensions and Ruff
- JetBrains Gateway integration (PyCharm/IntelliJ) with automatic SDK discovery
- IDE selection prompt in `setup-project.sh` (VSCode / JetBrains / both)

🔄 **Future Enhancements:**
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
