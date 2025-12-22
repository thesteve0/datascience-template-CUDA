# Changelog

All notable changes to the datascience-template-CUDA project will be documented in this file.

## [2025-12-22] - Ubuntu 24.04 Permission Fix

### Changed
- **Simplified permission management**: Removed complex group-sharing approach in favor of direct UID matching
- **Updated base container integration**: Now uses a Dockerfile wrapper instead of direct image reference
- **Streamlined setup**: Eliminated ~19 lines of permission management code from `setup-environment.sh`

### Fixed
- **common-utils parameter names**: Changed `uid`/`gid` to `userUid`/`userGid` in devcontainer.json to fix "UID: readonly variable" error
- **README documentation**: Added `sudo` to all `uv pip install` commands - required for modifying system packages in the container
- **NVIDIA package detection**: Fixed `setup-environment.sh` to handle NVIDIA 25.10+ empty `/etc/pip/constraint.txt` - now checks if file has content before using it, falls back to `pip freeze`

### Added
- **Dockerfile**: Minimal Dockerfile that deletes Ubuntu 24.04's pre-existing `ubuntu` user (UID 1000)
- **This changelog**: Created to track major changes to the repository

### Technical Details

**Problem**: NVIDIA PyTorch container 25.10 moved to Ubuntu 24.04, which ships with a pre-existing `ubuntu` user at UID 1000. This caused the devcontainer `common-utils` feature to silently fall back to creating the dev user at UID 1001, resulting in permission mismatches between host (UID 1000) and container (UID 1001).

**Solution**: Delete the `ubuntu` user before devcontainer features run, allowing clean UID matching. This eliminates the need for the previous workaround of creating a shared group and managing group-writable permissions.

**Files Modified**:
- `Dockerfile` (new) - Deletes ubuntu user from base image
- `devcontainer.json` - Changed from `image` to `build` configuration, fixed parameter names
- `setup-environment.sh` - Removed permissions block, fixed nvidia-provided.txt generation for NVIDIA 25.10+
- `setup-project.sh` - Removed HOST_GID and CONTAINER_GROUP_NAME variables
- `README.md` - Added `sudo` to all package installation commands

**NVIDIA 25.10 Container Changes**:
- `/etc/pip/constraint.txt` is now empty (previously contained package constraints)
- `uv` package manager is now pre-installed at `/usr/local/bin/uv`
- Package inventory must be generated via `pip freeze` instead of reading constraint.txt

**Credits**: Solution ported from the [datascience-template-ROCm](https://github.com/thesteve0/datascience-template-ROCm) project, which encountered the same issue with AMD's ROCm containers.

**References**:
- [common-utils doesn't work on Ubuntu 24.04](https://github.com/devcontainers/features/issues/1265)
- [Ubuntu 24.04 UID mapping problem](https://github.com/devcontainers/images/issues/1056)
- [updateRemoteUserUID has no effect](https://github.com/microsoft/vscode-remote-release/issues/10030)

### Known Issues

**torchao/transformers Version Conflict** (UNRESOLVED):
- NVIDIA's bundled `torchao` (0.14.0+git) is incompatible with newer `transformers` versions (4.50+)
- Packages requiring newer transformers (e.g., docling 2.65.0) will fail to import with `ModuleNotFoundError`
- **See**: `NEXT-SESSION-TODO.md` for full details and investigation plan
- **Status**: Needs investigation and fix before template is production-ready
- **Workaround**: May need to pin `transformers<4.50` or upgrade torchao (testing required)

### Migration Notes

If you have an existing project using an older version of this template:
1. The new approach works automatically - no action needed for new projects
2. Existing containers will continue to work with the old group-sharing approach
3. To migrate to the new approach, rebuild your devcontainer from scratch
