# Implementation Progress: Update CUDA Template to Match ROCm Improvements

## Overview

Porting 25+ improvements from `datascience-template-ROCm` to `datascience-template-CUDA` while upgrading to NVIDIA container 26.02-py3.

## Progress Summary

| Phase | Description | Status |
|-------|-------------|--------|
| 1 | Update Base Container | **CODE COMPLETE** - Awaiting manual verification |
| 2 | Virtual Environment with .pth Bridge | Not started |
| 3 | Dependency Resolution with uv | Not started |
| 4 | setup-project.sh with IDE Selection | Not started |
| 5 | GPU Testing Scripts | Not started |
| 6 | devcontainer.json for Ruff | Not started |
| 7 | Documentation | Not started |

---

## Phase 1: Update Base Container (CODE COMPLETE)

### Changes Made
- **Dockerfile**: Updated base image from `nvcr.io/nvidia/pytorch:25.10-py3` to `nvcr.io/nvidia/pytorch:26.02-py3`

### Container Analysis (26.02-py3)
Verified via `docker run`:
- **uv pre-installed**: `/usr/local/bin/uv` version 0.10.4
- **Python version**: 3.12.3
- **Ubuntu user workaround**: Still needed (uid=1000 exists)
- **PyTorch version**: 2.11.0a0+eb65b36

### Manual Verification Required (NVIDIA GPU + VSCode)
```bash
# In temp test directory, copy template files then:
./setup-project.sh
code .
# Reopen in container when prompted

# In devcontainer terminal:
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"
```

**Expected results:**
- nvidia-smi shows GPU
- torch.cuda.is_available() returns True

**After verification:** Commit and push, then continue to Phase 2.

---

## Phase 2: Virtual Environment with .pth Bridge (NOT STARTED)

### Planned Changes
**File:** `setup-environment.sh`

1. Create project `.venv` with `--system-site-packages` flag
2. Validate Python version matches between .venv and container
3. Create `_nvidia_bridge.pth` pointing to `/usr/local/lib/python3.12/dist-packages`
4. Generate `nvidia-provided.txt` via `uv pip list --format=freeze`
5. Replace black/flake8 installation with ruff
6. Remove manual uv installation (already in container)

### Manual Verification Required
```bash
# Rebuild container in VSCode, then in terminal:
ls .venv/                        # venv exists
cat .venv/lib/python*/site-packages/_nvidia_bridge.pth  # .pth bridge exists
.venv/bin/python -c "import torch; print(torch.cuda.is_available())"  # GPU works
which ruff                       # ruff installed
```

---

## Phase 3: Dependency Resolution with uv (NOT STARTED)

### Planned Changes
**Files:** `pyproject.toml` (new template), `setup-environment.sh`

1. Create template `pyproject.toml` with `[tool.uv]` section
2. Configure `exclude-dependencies` to protect NVIDIA packages
3. Update setup-environment.sh to generate exclusion list from nvidia-provided.txt
4. Deprecate `resolve-dependencies.py` (or keep for legacy support)

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

## Phase 5: GPU Testing Scripts (NOT STARTED)

### Planned New Files
- `hello-gpu.py` - Quick 30-second sanity check
- `test-gpu.py` - Comprehensive benchmark

### Manual Verification Required
```bash
# In devcontainer terminal:
python hello-gpu.py              # Quick sanity check (~30s)
python test-gpu.py               # Full benchmark (~2-3 min)
# Both should show CUDA available and GPU name
```

---

## Phase 6: devcontainer.json for Ruff (NOT STARTED)

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

## Phase 7: Documentation (NOT STARTED)

### Planned Changes
**New files:**
- `QUICKSTART.md` - 15-minute setup guide
- `TESTING.md` - Validation report

**Update:**
- `CLAUDE.md` - Architecture overview, .pth bridge explanation

**Delete:**
- `addingClaudeCode.md` - Per user request

### Manual Verification Required
```bash
# Review documentation files for accuracy
ls QUICKSTART.md TESTING.md CLAUDE.md
ls addingClaudeCode.md           # Should fail (file deleted)
```

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

### To Create
1. `pyproject.toml` - Template with uv exclusions
2. `hello-gpu.py` - Quick GPU sanity check
3. `test-gpu.py` - Comprehensive GPU benchmark
4. `QUICKSTART.md` - 15-minute setup guide
5. `TESTING.md` - Validation report

### To Delete
1. `addingClaudeCode.md` - Remove Claude Code integration docs

### To Deprecate
1. `resolve-dependencies.py` - Replaced by uv workflow with pyproject.toml

---

## Resuming Work

When resuming after Phase 1 verification:
1. Verify Phase 1 passed on NVIDIA machine
2. Commit Phase 1 changes
3. Continue with Phase 2 implementation in setup-environment.sh
