# Quickstart Guide

Get from zero to a working GPU-enabled Python environment in about 15 minutes.

---

## Prerequisites

Before starting, confirm all of these on your **host machine**:

**NVIDIA stack:**
```bash
nvidia-smi                  # Should show your GPU and driver version
docker run --rm --runtime=nvidia --gpus all nvidia/cuda:12.0-base-ubuntu22.04 nvidia-smi
                            # Should show the same GPU inside Docker
```

If the second command fails, install the [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html).

**SSH agent (needed for GitHub access from inside the container):**
```bash
ssh-add -l                  # Should show at least one key fingerprint
```

If you see "no identities" or "could not connect":
```bash
eval "$(ssh-agent -s)"
ssh-add
```

**IDE — install one or both:**
- **VSCode**: Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
- **JetBrains**: Install [JetBrains Gateway](https://www.jetbrains.com/remote-development/gateway/)

---

## Step 1: Create Your Project

```bash
mkdir my-ml-project
cd my-ml-project
```

Copy all template files into this directory (Dockerfile, devcontainer.json, setup-environment.sh, setup-project.sh, pyproject.toml, test-gpu.py, and any other template files).

---

## Step 2: Run Setup

```bash
chmod +x setup-project.sh
./setup-project.sh
```

The script will:
- Ask which IDE(s) to configure (VSCode / JetBrains / both)
- Replace all template placeholders with your project name, git identity, and host UID
- Move devcontainer files into `.devcontainer/`
- Generate `.idea/` config files if you chose JetBrains
- Create the `src/`, `tests/`, and `configs/` directory structure

To skip the interactive prompt:
```bash
./setup-project.sh --ide vscode
./setup-project.sh --ide jetbrains
./setup-project.sh --ide both
```

---

## Step 3: Start the Devcontainer

### VSCode

```bash
code .
```

When VSCode opens, click **"Reopen in Container"** in the notification that appears bottom-right. If you miss it, open the Command Palette (`Ctrl+Shift+P`) and run `Dev Containers: Reopen in Container`.

VSCode will build the Docker image and run `setup-environment.sh`. This takes 5–10 minutes on first build (the NVIDIA base image is ~18GB). Subsequent starts are fast.

### JetBrains Gateway

1. Open **JetBrains Gateway**
2. Click **New Connection** > **Dev Containers**
3. Select your project folder
4. Choose your IDE backend (IntelliJ IDEA Ultimate or PyCharm Professional)
5. Click **Build Container and Continue**

Gateway will build the image and open the IDE inside the container. First build takes 5–10 minutes.

---

## Step 4: Configure Python SDK (JetBrains only)

After the IDE opens inside the container:

1. Go to **File > Project Structure** (or the SDK selector in the status bar)
2. Click **Add SDK > Add Python SDK**
3. Set **Environment** to `Select existing`, **Type** to `uv`
4. **Path to uv**: `/usr/local/bin/uv` (auto-filled)
5. Click the **Environment** dropdown — your `.venv` will appear automatically
6. Select it and click **OK**

VSCode configures the interpreter automatically via `devcontainer.json` — no manual step needed.

---

## Step 5: Verify GPU Access

Open a terminal inside the devcontainer and run:

```bash
python test-gpu.py
```

Expected output includes:
- `CUDA available: True`
- Your GPU name and memory
- A CPU vs GPU benchmark showing GPU speedup

Quick one-liner check:
```bash
python -c "import torch; print(torch.cuda.is_available(), torch.cuda.get_device_name(0))"
```

---

## Step 6: Verify NVIDIA Packages Are Intact

The template uses a three-layer system to prevent NVIDIA's CUDA-optimized packages from being overwritten by generic PyPI builds. Confirm it worked:

```bash
# numpy should point to NVIDIA's dist-packages, NOT .venv/lib/...
python -c "import numpy; print(numpy.__file__)"
# Expected: /usr/local/lib/python3.12/dist-packages/numpy/__init__.py

# uv should see all NVIDIA packages as already installed
uv pip list | grep -E "^torch|^numpy|^flash"
```

---

## Step 7: Install Your First Package

```bash
uv add transformers
```

Watch the output — `torch`, `numpy`, and other NVIDIA packages should **not** appear in the install list. Only genuinely new packages are installed into `.venv`.

Verify it works:
```bash
python -c "import transformers, torch; print(transformers.__version__, torch.cuda.is_available())"
```

For a `requirements.txt`:
```bash
uv add -r requirements.txt
```

---

## What NOT to Do

| Command | Why |
|---------|-----|
| `uv sync --exact` | Deletes the NVIDIA stub dist-info entries that protect CUDA packages |
| `pip install <pkg>` | Bypasses the venv, may overwrite NVIDIA's optimized builds in dist-packages |
| `sudo uv pip install --system <pkg>` | Same problem as above |
| `uv remove torch` / `uv remove numpy` | These are NVIDIA's packages; the stub RECORD is empty and removal will fail or corrupt the environment |

---

## Adding Models or Datasets

The `models/` and `data/` directories are **named volumes** (not bind mounts), so you cannot copy files into them directly from the host filesystem. Use `docker cp`:

```bash
# Find your running container ID
docker ps

# Copy a model checkpoint
docker cp ~/Downloads/model.pth <container_id>:/workspaces/my-ml-project/models/

# Copy a dataset
docker cp ~/Downloads/dataset.zip <container_id>:/workspaces/my-ml-project/data/
```

---

## Troubleshooting

**Container fails to start / postCreateCommand fails:**
Check the devcontainer log (in VSCode: click "show log" on the build notification; in Gateway: check the build output panel). The most common cause is a networking issue during `apt-get update` — retry the build.

**`Permission denied` writing files inside the container:**
The container user UID doesn't match your host UID. This shouldn't happen with the current template (it uses `$(id -u)` automatically), but if you edited `DEV_UID` manually, set it back to `$(id -u)` in `setup-project.sh` and rebuild.

**JetBrains "Loading environments..." spins forever:**
`setup-environment.sh` did not complete successfully — `.venv` and `uv.lock` are missing. Open a terminal in the container and run `.devcontainer/setup-environment.sh` manually to see where it fails.

**`torch.cuda.is_available()` returns False:**
- Confirm `nvidia-smi` works on the host
- Confirm `--runtime=nvidia` is in `runArgs` in `devcontainer.json`
- Try rebuilding the container from scratch (VSCode: `Dev Containers: Rebuild Container`)

**numpy imports from `.venv` instead of dist-packages:**
`uv sync --exact` was run, which deleted the NVIDIA stubs. Rebuild the container to restore `setup-environment.sh`'s work.