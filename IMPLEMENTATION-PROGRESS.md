# Implementation Progress: Update CUDA Template to Match ROCm Improvements

## Overview

Porting 25+ improvements from `datascience-template-ROCm` to `datascience-template-CUDA` while upgrading to NVIDIA container 26.02-py3.

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Update Base Container | **VERIFIED** - GPU works, torch imports |
| 2 | Virtual Environment with .pth Bridge | **VERIFIED** |
| 3 | Dependency Resolution with uv | **VERIFIED** |
| 4 | setup-project.sh with IDE Selection | **VERIFIED** - --ide flag, interactive prompt, .idea/ generation |
| 5 | GPU Testing Scripts | **VERIFIED** - test-gpu.py only (hello-gpu.py removed as requirement) |
| 6 | devcontainer.json for Ruff + JetBrains | **VERIFIED** - ruff settings/extensions + jetbrains plugins block |
| 6a | JetBrains SDK Discovery Fixes | **VERIFIED** - UV_PROJECT_ENVIRONMENT, uv lock in setup-environment.sh |
| 6b | UID/Permissions Fix | **VERIFIED** - DEV_UID=$(id -u) in setup-project.sh |
| 7 | Documentation | **DONE** - CLAUDE.md, README.md updated |

---

## Phase 1: Update Base Container (VERIFIED)

### Changes Made
- **Dockerfile**: Updated base image from `nvcr.io/nvidia/pytorch:25.10-py3` to `nvcr.io/nvidia/pytorch:26.02-py3`

### Container Analysis (26.02-py3)
Verified via `docker run`:
- **uv pre-installed**: `/usr/local/bin/uv` version 0.10.4
- **Python version**: 3.12.3
- **Ubuntu user workaround**: Still needed (uid=1000 exists)
- **PyTorch version**: 2.11.0a0+eb65b36

### Verification Results (PASSED)
- nvidia-smi showed GPU
- `torch.cuda.is_available()` returned True
- `uv add transformers` FAILED (no pyproject.toml) → addressed in Phases 2+3

---

## Phase 2: Virtual Environment with .pth Bridge (CODE COMPLETE)

### Changes Made
**File:** `setup-environment.sh`

1. Create project `.venv` with `uv venv --system-site-packages` flag
2. Validate Python version matches between .venv and container
3. Create `_nvidia_bridge.pth` pointing to `/usr/local/lib/pythonX.Y/dist-packages` (version detected dynamically)
4. Generate `nvidia-provided.txt` via `pip freeze` (before venv creation)
5. Replace black/flake8 installation with ruff (installed into .venv)
6. Removed manual uv installation (already in container at /usr/local/bin/uv)
7. Added `chown` to fix .venv ownership (postCreateCommand runs as root)

### Manual Verification Required
```bash
# Rebuild container in VSCode, then in terminal:
ls .venv/                        # venv exists
cat .venv/lib/python*/site-packages/_nvidia_bridge.pth  # .pth bridge exists
.venv/bin/python -c "import torch; print(torch.cuda.is_available())"  # GPU works
which ruff                       # ruff installed
```

---

## Phase 3: Dependency Resolution with uv (CODE COMPLETE)

### Changes Made
**Files:** `pyproject.toml` (new template), `setup-environment.sh`, `setup-project.sh`

1. Created template `pyproject.toml` with `[tool.uv]` `constraint-dependencies` section
2. `setup-environment.sh` reads `nvidia-provided.txt` and injects package==version constraints into `pyproject.toml` at container build time
3. `setup-project.sh` updated to replace `{{PROJECT_NAME}}` in `*.toml` files
4. `resolve-dependencies.py` kept for legacy support (deprecation in Phase 7 docs)

### Manual Verification Required
```bash
# In devcontainer, test the critical integration:

# 1. Add transformers using uv (has torch as dependency)
uv add transformers
# CRITICAL: torch should NOT be reinstalled - check output

# 2. Verify BOTH transformers AND original NVIDIA pytorch work together
python -c "import transformers; print('transformers:', transformers.__version__)"
python -c "import torch; print('torch:', torch.__version__, 'CUDA:', torch.cuda.is_available())"

# 3. Verify pyproject.toml has transformers listed
cat pyproject.toml | grep transformers
```

---

## Phase 4: setup-project.sh with IDE Selection (NOT STARTED)

### Planned Changes
**File:** `setup-project.sh`

1. Add `--ide` argument and interactive prompt (vscode/jetbrains/both)
2. Create `.idea/` directory structure for JetBrains:
   - `{PROJECT_NAME}.iml` - Python module config
   - `misc.xml` - Ruff linter enabled
   - `modules.xml`, `vcs.xml`
3. Create `.standalone-project` marker file
4. Organize template docs into `template_docs/` folder
5. Generate skeleton README.md and CLAUDE.md for user's project

### Manual Verification Required
```bash
# In temp test directory:
./setup-project.sh --ide both
ls .devcontainer/                # devcontainer files exist
ls .idea/                        # JetBrains files exist
cat .idea/misc.xml | grep -i ruff   # Ruff configured
```

---

## Phase 5: GPU Testing Scripts (VERIFIED)

### Files
- `test-gpu.py` - Comprehensive benchmark (CPU vs GPU, NN training, performance comparison)

### Manual Verification Required
```bash
# In devcontainer terminal:
python test-gpu.py               # Full benchmark (~2-3 min)
# Should show CUDA available, GPU name, and speedup metrics
```

---

## Phase 6a: JetBrains SDK Discovery Fixes (VERIFIED)

### Problem
JetBrains Gateway's "Add Python Interpreter" dialog (uv type, Select existing) spun indefinitely on "Loading environments...".

### Root Causes and Fixes

**1. `UV_PROJECT_ENVIRONMENT` not set**
JetBrains calls uv to enumerate environments; without this env var uv has no way to know where the project venv lives.
- Fix: Added `"UV_PROJECT_ENVIRONMENT": "/workspaces/{{PROJECT_NAME}}/.venv"` to `containerEnv` in `devcontainer.json`.

**2. No `uv.lock` file**
JetBrains' uv integration runs project-mode uv commands that require a lock file. Without it, uv tries to resolve 200+ NVIDIA packages from PyPI, causing the spinner.
- Fix: Added `uv lock --project ${WORKSPACE_DIR}` to `setup-environment.sh`, after NVIDIA constraints are injected into `pyproject.toml`. Safe: resolves only, installs nothing.

---

## Phase 6b: UID/Permissions Fix (VERIFIED)

### Problem
Container user was UID 2112 (hardcoded `DEV_UID=2112`). Workspace bind mount owned by host user UID 1000. Result: `Permission denied` on every write, `setup-environment.sh` postCreateCommand failed silently.

### Fix
Changed `setup-project.sh` line 41 from `DEV_UID=2112` to `DEV_UID=$(id -u)`. The Dockerfile already deletes Ubuntu's pre-existing UID 1000 user, so any host UID is safe to use.

---

## Phase 6: devcontainer.json for Ruff (VERIFIED)

### Planned Changes
**File:** `devcontainer.json`

VSCode settings:
- Remove `python.formatting.provider: black`, `python.linting.flake8Enabled`
- Add Ruff formatter and linter settings
- Replace extensions: `ms-python.black-formatter`, `ms-python.flake8` → `charliermarsh.ruff`
- Update `python.defaultInterpreterPath` to `.venv/bin/python`

Add JetBrains customization block.

### Manual Verification Required
```bash
# VSCode: rebuild container, create test.py with style issues
# Verify Ruff linting/formatting works on save

# IntelliJ: open project, create Dev Container
# Verify Ruff enabled in Settings > Tools > Ruff
```

---

## Phase 7: Documentation (DONE)

### Changes Made
**Updated:**
- `CLAUDE.md` - Added JetBrains Gateway Integration section (UV_PROJECT_ENVIRONMENT, uv lock, UID requirement, Docker image naming). Updated DEV_UID placeholder description. Updated file list.
- `README.md` - Fixed container version (25.04 → 26.02), added JetBrains to Quick Start (--ide flag, Gateway steps, SDK configuration), updated Current Status to reflect JetBrains support.
- `IMPLEMENTATION-PROGRESS.md` - All phases marked with final status, new phases 6a/6b added.

**Also completed:**
- Deleted `addingClaudeCode.md` ✅
- Deleted `resolve-dependencies.py` ✅ (replaced by uv workflow with pyproject.toml)

**Also completed:**
- `QUICKSTART.md` ✅

---

## Key NVIDIA vs ROCm Adaptations

| ROCm | NVIDIA |
|------|--------|
| `/opt/venv` | `/usr` (system Python) |
| `rocm-provided.txt` | `nvidia-provided.txt` |
| `amd-smi` | `nvidia-smi` |
| `HIP_VISIBLE_DEVICES` | `CUDA_VISIBLE_DEVICES` |
| `--device=/dev/kfd --device=/dev/dri` | `--runtime=nvidia` |
| Manual uv install | uv pre-installed (26.02+) |

---

## Files Summary

### To Modify
1. `Dockerfile` - Update base image ✅ DONE
2. `devcontainer.json` - Ruff, JetBrains, venv path
3. `setup-environment.sh` - venv creation, .pth bridge, ruff
4. `setup-project.sh` - IDE selection, .idea/ creation
5. `CLAUDE.md` - Architecture details

### Created
1. `pyproject.toml` ✅
2. `test-gpu.py` ✅
3. `QUICKSTART.md` ✅
4. `iterate-test-jetbrains-env.sh` ✅

### Deleted
1. `addingClaudeCode.md` ✅
2. `resolve-dependencies.py` ✅ (replaced by uv workflow with pyproject.toml)

---

## Resuming Work

When resuming after Phase 2+3 verification:
1. Copy template to temp dir, run `setup-project.sh`, rebuild container
2. Verify checklist below
3. If passing, commit and continue with Phase 4 (IDE selection in setup-project.sh)

### Phase 2+3 Verification Checklist
```bash
# In devcontainer terminal:
ls .venv/                        # venv exists
cat .venv/lib/python*/site-packages/_nvidia_bridge.pth  # shows /usr/local/lib/pythonX.Y/dist-packages
.venv/bin/python -c "import torch; print(torch.cuda.is_available())"  # True
which ruff                       # .venv/bin/ruff
cat nvidia-provided.txt | wc -l  # non-zero package count
cat pyproject.toml | grep "torch=="  # constraint injected

# Critical integration test:
uv add transformers              # torch should NOT be reinstalled
python -c "import transformers; print(transformers.__version__)"
python -c "import torch; print(torch.__version__, torch.cuda.is_available())"
cat pyproject.toml | grep transformers  # listed in dependencies
```
