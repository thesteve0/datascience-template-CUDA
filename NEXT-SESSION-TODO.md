# Next Session TODO - HIGH PRIORITY

## Issue: torchao/transformers Version Conflict in NVIDIA 25.10 Container

**Status**: UNRESOLVED - Needs investigation and fix before template is production-ready

**Discovered**: 2025-12-22 during docling GPU verification testing

---

## Problem Description

When users install packages that depend on newer versions of `transformers` (like docling 2.65.0), they encounter a `ModuleNotFoundError` due to incompatibility between NVIDIA's bundled `torchao` and the newer `transformers` library.

### Error Message
```
ModuleNotFoundError: No module named 'torchao.prototype.safetensors.safetensors_utils'

The above exception was the direct cause of the following exception:

Traceback (most recent call last):
  File "<string>", line 3, in <module>
  File "/usr/local/lib/python3.12/dist-packages/docling/document_converter.py", line 66, in <module>
    from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline
  File "/usr/local/lib/python3.12/dist-packages/docling/pipeline/standard_pdf_pipeline.py", line 43, in <module>
    from docling.models.code_formula_model import CodeFormulaModel, CodeFormulaModelOptions
  File "/usr/local/lib/python3.12/dist-packages/docling/models/code_formula_model.py", line 17, in <module>
    from transformers import AutoModelForImageTextToText, AutoProcessor
  File "/usr/local/lib/python3.12/dist-packages/transformers/utils/import_utils.py", line 2320, in __getattr__
    raise ModuleNotFoundError(
ModuleNotFoundError: Could not import module 'AutoProcessor'. Are this object's requirements defined correctly?
```

### Version Conflict Details

**NVIDIA-provided packages (from base container)**:
- `torchao @ file:///opt/pytorch/ao` - Version: 0.14.0+git
- `torch @ file:///opt/transfer/torch-2.9.0a0%2B145a3a7bda.nv25.10-...`
- `transformers` - Initially provided by NVIDIA (compatible with their torchao)

**User-installed packages** (example: docling):
- `docling` - Version: 2.65.0
- `transformers` - Version: 4.57.3 (upgraded as dependency of docling)

**Root Cause**:
- NVIDIA's `torchao` (0.14.0+git) is a custom build installed from a local wheel
- Newer `transformers` versions (4.50+) expect `torchao.prototype.safetensors.safetensors_utils` module
- NVIDIA's custom `torchao` doesn't include this module structure
- When docling upgrades transformers to 4.57.3, it breaks compatibility with NVIDIA's torchao

### Impact

Users cannot use packages that depend on newer transformers versions, including:
- `docling` (document parsing library)
- Any other package that requires `transformers>=4.50`

The error prevents these packages from importing, even though they're successfully installed.

---

## Reproduction Steps

1. Start with NVIDIA PyTorch 25.10 container (Ubuntu 24.04)
2. Install docling: `sudo uv pip install --system docling`
3. Try to import docling pipeline:
   ```python
   from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline
   pipeline = StandardPdfPipeline()
   ```
4. Error occurs during import

---

## Current Status

### What Works ✅
- Container builds successfully
- UID matching works (1000:1000)
- PyTorch CUDA available and working
- GPU detected (device count: 1)
- Accelerate library can use GPU
- docling package installs successfully
- Basic imports work (import docling, import torch, import transformers)

### What Fails ❌
- Importing docling's StandardPdfPipeline
- Importing docling's DocumentConverter
- Any transformers functionality that uses torchao quantization features

---

## Potential Solutions (INVESTIGATE IN NEXT SESSION)

### Option A: Pin transformers to Compatible Version (RECOMMENDED FIRST)
**Approach**: Keep NVIDIA's torchao, downgrade transformers

**Steps**:
1. Determine the maximum transformers version compatible with torchao 0.14.0+git
2. Test versions: Try `transformers<4.50`, `transformers<4.45`, etc.
3. Update dependency resolution script to handle this constraint
4. Document the pin in README with explanation

**Pros**:
- Preserves NVIDIA's optimized torchao
- Least likely to break other NVIDIA optimizations
- More conservative approach

**Cons**:
- Users can't use latest transformers features
- May conflict with packages requiring newer transformers

**Testing needed**:
```bash
# In container
sudo uv pip install --system 'transformers<4.50'
python -c "from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline; print('Success')"
```

### Option B: Upgrade torchao from PyPI
**Approach**: Replace NVIDIA's torchao with official PyPI version

**Steps**:
1. Uninstall NVIDIA's torchao: `sudo pip uninstall torchao`
2. Install PyPI torchao: `sudo uv pip install --system torchao`
3. Test PyTorch functionality still works
4. Test docling works

**Pros**:
- Latest transformers compatibility
- Users can install any modern ML package

**Cons**:
- May lose NVIDIA-specific optimizations in torchao
- Could break other NVIDIA packages that depend on their custom torchao
- Riskier approach

**Testing needed**:
```bash
# Check what depends on torchao
pip show torchao
# Check if uninstalling breaks anything
sudo pip uninstall -y torchao
sudo uv pip install --system torchao
python -c "import torch; print(torch.cuda.is_available())"
python -c "from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline; print('Success')"
```

### Option C: Add torchao to nvidia-provided.txt Filtering
**Approach**: Treat this as a known NVIDIA package conflict that needs filtering

**Steps**:
1. Update `resolve-dependencies.py` to detect torchao conflicts
2. Add special handling for transformers version constraints when torchao is present
3. Document the limitation in README

**Pros**:
- Automates the workaround
- Users get clear error message about the conflict

**Cons**:
- Doesn't solve the underlying issue
- Users still limited to older transformers

### Option D: Contact NVIDIA / Wait for Fix
**Approach**: This may be a bug in NVIDIA's container

**Steps**:
1. Check NVIDIA PyTorch container release notes for known issues
2. Test newer NVIDIA containers (25.11, 25.12 if available)
3. File issue with NVIDIA if this is a bug

---

## Investigation Checklist for Next Session

- [ ] Check NVIDIA PyTorch 25.10 release notes for known torchao issues
- [ ] Test if newer NVIDIA containers (25.11+) fix this
- [ ] Determine exact transformers version range compatible with torchao 0.14.0+git
- [ ] Test Option A: Downgrade transformers, verify docling works
- [ ] Test Option B: Upgrade torchao, verify no NVIDIA optimizations broken
- [ ] Check what other packages depend on NVIDIA's torchao:
  ```bash
  grep -r "torchao" /opt/pytorch/
  pip show torchao
  ```
- [ ] Document findings in CHANGELOG.md
- [ ] Update README.md with workaround if needed
- [ ] Update `resolve-dependencies.py` if automatic filtering needed

---

## Test Commands for Verification

```bash
# Check versions
docker exec <container> pip show torchao transformers | grep -E "Name:|Version:"

# Test transformers downgrade
docker exec <container> sudo uv pip install --system 'transformers<4.50'
docker exec <container> python -c "from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline; print('Success')"

# Test torchao upgrade
docker exec <container> sudo pip uninstall -y torchao
docker exec <container> sudo uv pip install --system torchao
docker exec <container> python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
docker exec <container> python -c "from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline; print('Success')"

# Verify GPU still works after any changes
docker exec <container> python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}'); print(f'Devices: {torch.cuda.device_count()}')"
```

---

## Additional Context

### Container Information
- **Container**: NVIDIA PyTorch 25.10-py3
- **Base OS**: Ubuntu 24.04
- **Python**: 3.12.3
- **CUDA**: Available and working
- **uv**: Pre-installed at /usr/local/bin/uv
- **/etc/pip/constraint.txt**: Empty (changed from previous versions)

### Related Files
- `/var/home/spousty/git/datascience-template-CUDA/resolve-dependencies.py` - May need updates
- `/var/home/spousty/git/datascience-template-CUDA/README.md` - May need troubleshooting section
- `/var/home/spousty/git/datascience-template-CUDA/CHANGELOG.md` - Document solution

### Test Environment
- **Test project**: `/tmp/test-cuda-template`
- **Container name**: `beautiful_goldberg` (at time of discovery)
- **nvidia-provided.txt**: Successfully generated via pip freeze (219 packages)

---

## Success Criteria

When this issue is resolved, the following should work:

1. ✅ Install docling successfully: `sudo uv pip install --system docling`
2. ✅ Import docling pipeline without errors:
   ```python
   from docling.pipeline.standard_pdf_pipeline import StandardPdfPipeline
   pipeline = StandardPdfPipeline()
   ```
3. ✅ Verify GPU usage:
   ```python
   print(f'Pipeline device: {pipeline.device}')
   # Should show: cuda or cuda:0
   ```
4. ✅ PyTorch CUDA still works
5. ✅ Other NVIDIA optimizations still functional
6. ✅ Solution documented in README.md
7. ✅ CHANGELOG.md updated

---

## Notes

- This issue was discovered on 2025-12-22 during final verification testing
- The Ubuntu 24.04 permission fix is complete and working
- All other aspects of the template are functional
- This is the last blocking issue before the template is production-ready
- Priority: HIGH - blocks users from using modern transformer-based packages

---

**IMPORTANT**: Start next session by reading this file and deciding on the investigation approach.
