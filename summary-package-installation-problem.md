# Package Installation Problem Summary

## Context

This document summarizes the core problem with using `uv add` inside the NVIDIA PyTorch devcontainer
without overwriting NVIDIA's optimized libraries. It is intended as a starting point for a fresh
troubleshooting session.

---

## The Two Distinct Problems

There are two separate but related problems — not one:

### Problem 1 — Package Invisibility (the root issue)

uv cannot see what NVIDIA has installed in `dist-packages`. Even with `--system-site-packages` on
the venv, uv's resolver does not treat NVIDIA's packages as satisfied. Evidence: uv still attempts
to install `numpy` from scratch even though it is already present and importable in the container.
uv's dependency resolver operates from a blank slate with respect to NVIDIA's entire package set.

### Problem 2 — Permission Denied on Writes (downstream symptom)

When uv tries to install packages that NVIDIA already provides (both ML packages it doesn't know
about, and general utility deps like `platformdirs`, `mdurl` that NVIDIA happens to also ship), it
hits `Permission denied (os error 13)` writing `.dist-info` metadata files. This is a consequence
of Problem 1 — if uv knew the packages were already installed, it would never attempt the write.

**Important**: The permission errors from Problem 2 are arguably the only thing currently
*preventing* silent overwrites from completing. If writes succeeded, uv would silently replace
NVIDIA's CUDA-optimized builds with generic PyPI versions, breaking GPU performance or CUDA
compatibility without any error.

---

## Evidence Collected

- uv attempts to install `numpy` despite NVIDIA having installed it and it being importable
- `--system-site-packages` venv flag is not sufficient to make uv recognize `dist-packages` contents
- `Permission denied (os error 13)` confirmed on `.dist-info` file writes for `platformdirs-4.9.2`
  and `mdurl-0.1.2`
- The failing packages are not NVIDIA ML packages — they are general utility deps that NVIDIA
  happens to also ship
- uv runs as non-root (`spousty-devcontainer`), confirmed by cache path
  `/home/spousty-devcontainer/.cache/uv/`
- uv falls back to full-copy mode (not hardlinks) because the uv cache and the workspace bind mount
  are on different filesystems — every install goes through a real file copy, exposing permission
  failures that hardlinking might have bypassed silently

---

## Why ROCm Works and CUDA Does Not

AMD and NVIDIA made different structural choices about where to install Python packages, and that
difference is the root of the asymmetry.

### ROCm (AMD) — Works

AMD's ROCm container installs all Python packages into `/opt/venv` — a real, standard Python
virtual environment. The `setup-environment.sh` does one thing: `sudo chown -R $(whoami):$(whoami)
/opt/venv`. After that, the user owns the venv. When `uv pip install` runs, it installs directly
into `/opt/venv/lib/python3.13/site-packages/`. uv can see every package AMD pre-installed because
they are all in the same standard venv location uv already knows to look at.

- No `.pth` file needed
- No symlinks needed
- No permission workarounds needed
- uv sees all AMD packages as installed and does not try to reinstall them

### CUDA (NVIDIA) — Does Not Work

NVIDIA installs packages into `/usr/local/lib/python3.12/dist-packages/` — a system Python path,
not a venv. When we create a project venv at `/workspaces/test/.venv`, uv only knows about packages
inside that venv. NVIDIA's packages are invisible to uv's resolver.

The `.pth` file added to the venv's `site-packages/` solves only the **Python import path**
problem: `import torch` works. But uv does not use Python's import machinery to determine what is
installed — it reads `.dist-info` directories in `site-packages`. The `.pth` file does nothing for
uv's resolver. So uv looks at the venv's `site-packages`, sees no `torch`, no `numpy`, no
`platformdirs`, and concludes they all need to be installed.

The import bridge and uv's package resolution live in completely separate layers that do not
communicate.

### Comparison

| | ROCm (AMD) | CUDA (NVIDIA) |
|---|---|---|
| Where packages live | `/opt/venv` (real venv) | `/usr/local/lib/*/dist-packages/` (system Python) |
| uv sees them as installed? | Yes — same venv | No — different location |
| Write access needed? | Just `chown` the venv | Must write through to NVIDIA's dirs |
| `.pth` file needed? | No | Yes, but only fixes imports, not uv resolution |

---

## The Fundamental Tension

uv is designed to have full ownership of its managed environment. NVIDIA's container is designed to
provide a pre-built, root-owned Python stack in a non-standard location. These two assumptions are
in direct conflict whenever any package in a user's dependency tree overlaps with anything NVIDIA
has installed — even incidentally.

AMD's choice to use a real venv at `/opt/venv` aligns naturally with how Python tooling works.
NVIDIA's choice to use `dist-packages` puts its packages outside the reach of standard venv
tooling. Every workaround attempted so far — `.pth` bridges, `.dist-info` symlinks, `chmod` on
NVIDIA dirs — is patching around that fundamental structural misalignment rather than resolving it.

---

## Approaches Attempted (for reference — do not re-litigate these)

Several workarounds were attempted in `setup-environment.sh` and `Dockerfile` during the previous
session. None fully resolved the problem. The new session should focus on a different strategy
rather than refining the same approaches.