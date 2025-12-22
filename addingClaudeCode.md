# Adding Claude Code to datascience-template-CUDA

## Overview
This document describes how to integrate Claude Code into the datascience-template-CUDA devcontainer with Red Hat corporate authentication via Google Vertex AI. This integration allows Claude Code access inside the container while using the host's existing gcloud credentials and configuration.

## Prerequisites
Before implementing these changes, ensure your **host machine** has:
- Claude Code installed and working (`claude` command available)
- gcloud CLI configured with Application Default Credentials
- Environment variable `ANTHROPIC_VERTEX_PROJECT_ID` set in your .bashrc or .zshrc
- Successful authentication to Google Vertex AI (verify with `claude` then `/status`)

## Configuration Details
- **GCP Region**: `us-east5` (Red Hat standard)
- **Quota Project**: `cloudability-it-gemini` (static for all Red Hat users)
- **Authentication**: Application Default Credentials (ADC) from host
- **Project ID**: Read from host environment variable `ANTHROPIC_VERTEX_PROJECT_ID` (never stored in git)

## Implementation Steps

### 1. Update devcontainer.json
**File**: `.devcontainer/devcontainer.json`

**a) Add Claude Code feature** to the `features` section (after the `common-utils` feature):
```json
"ghcr.io/anthropics/devcontainer-features/claude-code:1": {}
```

**b) Add credential mounts** to the `mounts` array:
```json
"source={{PROJECT_NAME}}-claude,target=/home/{{DEV_USER}}/.claude,type=volume",
"source=${localEnv:HOME}${localEnv:USERPROFILE}/.config/gcloud,target=/home/{{DEV_USER}}/.config/gcloud,type=bind,readonly"
```

**c) Add Vertex AI environment variables** to the `containerEnv` object:
```json
"CLAUDE_CODE_USE_VERTEX": "1",
"CLOUD_ML_REGION": "us-east5",
"ANTHROPIC_VERTEX_PROJECT_ID": "${localEnv:ANTHROPIC_VERTEX_PROJECT_ID}",
"GOOGLE_CLOUD_PROJECT": "${localEnv:ANTHROPIC_VERTEX_PROJECT_ID}"
```

**Complete features section should look like:**
```json
"features": {
  "ghcr.io/devcontainers/features/github-cli:1": {},
  "ghcr.io/devcontainers/features/common-utils:2": {
    "username": "{{DEV_USER}}",
    "uid": "{{DEV_UID}}",
    "gid": "{{DEV_UID}}",
    "upgradePackages": false
  },
  "ghcr.io/anthropics/devcontainer-features/claude-code:1": {}
}
```

**Complete mounts section should include:**
```json
"mounts": [
  "source={{PROJECT_NAME}}-models,target=/workspaces/{{PROJECT_NAME}}/models,type=volume",
  "source={{PROJECT_NAME}}-datasets,target=/workspaces/{{PROJECT_NAME}}/data,type=volume",
  "source={{PROJECT_NAME}}-cache-hf,target=/workspaces/{{PROJECT_NAME}}/.cache/huggingface,type=volume",
  "source={{PROJECT_NAME}}-cache-torch,target=/workspaces/{{PROJECT_NAME}}/.cache/torch,type=volume",
  "source={{PROJECT_NAME}}-claude,target=/home/{{DEV_USER}}/.claude,type=volume",
  "source=${localEnv:HOME}${localEnv:USERPROFILE}/.config/gcloud,target=/home/{{DEV_USER}}/.config/gcloud,type=bind,readonly"
]
```

**Complete containerEnv section should include:**
```json
"containerEnv": {
  "NVIDIA_VISIBLE_DEVICES": "all",
  "CUDA_VISIBLE_DEVICES": "0",
  "PYTORCH_CUDA_ALLOC_CONF": "expandable_segments:True,max_split_size_mb:512,garbage_collection_threshold:0.6",
  "PYTHONPATH": "/workspaces/{{PROJECT_NAME}}/src",
  "HF_HOME": "/workspaces/{{PROJECT_NAME}}/.cache/huggingface",
  "TORCH_HOME": "/workspaces/{{PROJECT_NAME}}/.cache/torch",
  "TRANSFORMERS_CACHE": "/workspaces/{{PROJECT_NAME}}/.cache/huggingface/transformers",
  "SSH_AUTH_SOCK": "/tmp/ssh-agent.sock",
  "CLAUDE_CODE_USE_VERTEX": "1",
  "CLOUD_ML_REGION": "us-east5",
  "ANTHROPIC_VERTEX_PROJECT_ID": "${localEnv:ANTHROPIC_VERTEX_PROJECT_ID}",
  "GOOGLE_CLOUD_PROJECT": "${localEnv:ANTHROPIC_VERTEX_PROJECT_ID}"
}
```

**Important Note**: `${localEnv:VAR_NAME}` reads from the host's environment variables. This keeps the project ID out of git while leveraging the existing Red Hat setup in .bashrc/.zshrc.

---

### 2. Update setup-project.sh
**File**: `setup-project.sh`

**Add verification message** for Claude Code setup after the sed replacements (around line 58-59, before the clone/standalone logic):

```bash
# Verify Claude Code prerequisites
echo ""
echo "Claude Code Integration:"
if [ -n "$ANTHROPIC_VERTEX_PROJECT_ID" ]; then
    echo "✓ ANTHROPIC_VERTEX_PROJECT_ID is set: $ANTHROPIC_VERTEX_PROJECT_ID"
else
    echo "⚠ WARNING: ANTHROPIC_VERTEX_PROJECT_ID not set in your environment"
    echo "  Please complete the Red Hat Claude Code setup:"
    echo "  1. Add to ~/.bashrc or ~/.zshrc:"
    echo "     export ANTHROPIC_VERTEX_PROJECT_ID=your-project-id"
    echo "  2. Source your shell config: source ~/.bashrc"
    echo "  See README.md for full setup instructions"
fi
```

**Note**: No changes needed to the sed replacements - the GCP project ID comes from the host environment, not from placeholders.

---

### 3. Update setup-environment.sh
**File**: `.devcontainer/setup-environment.sh`

**Add Claude Code verification** after the git configuration section (after line 53), before the final echo statements:

```bash
# Verify Claude Code and Vertex AI configuration
echo "Verifying Claude Code setup..."
if [ -d "/home/${DEV_USER}/.config/gcloud" ]; then
    echo "✓ gcloud credentials mounted"
else
    echo "⚠ WARNING: gcloud credentials not found. Run 'gcloud auth application-default login' on host."
fi

if command -v claude &> /dev/null; then
    echo "✓ Claude Code installed"
    echo "Run 'claude' to start, then use '/status' to verify Vertex AI connection"
else
    echo "⚠ Claude Code not found - will be installed by devcontainer feature"
fi
```

**Update the final echo messages** (replace line 58):
```bash
echo "Setup complete!"
echo "Claude Code configured with Vertex AI (us-east5)"
echo "Run 'claude' and then '/status' to verify your GCP project connection"
```

Remove the hardcoded dataset message (line 58 currently references pytorch-CycleGAN-and-pix2pix).

---

### 4. Update README.md
**File**: `README.md`

**a) Add new section after "Prerequisites: SSH Agent for GitHub"** (insert after line 47):

```markdown
## Prerequisites: Claude Code with Google Vertex AI (Red Hat Users)

This template integrates Claude Code using Red Hat's corporate Google Vertex AI setup. Before using the devcontainer, verify your host machine is configured:

### 1. Verify Host Configuration

Ensure Claude Code is working on your host:
```bash
# Verify gcloud credentials exist
ls ~/.config/gcloud/application_default_credentials.json

# Verify environment variable is set
echo $ANTHROPIC_VERTEX_PROJECT_ID  # Should show your project ID

# Test Claude Code on host
claude
/status  # Should show "Google Vertex AI" provider
/exit
```

### 2. Inside the Devcontainer

Once the container is running, Claude Code will be available with your host credentials:
```bash
# Launch Claude Code
claude

# Verify connection
/status
```

You should see:
- Provider: "Google Vertex AI"
- Project: Your team's GCP project ID
- Region: us-east5

**How it works:**
- Your gcloud credentials are mounted read-only from `~/.config/gcloud`
- The `ANTHROPIC_VERTEX_PROJECT_ID` environment variable is read from your host shell
- Claude Code settings are persisted in a named volume
- No re-authentication needed - uses your existing ADC

**Troubleshooting:**
If authentication fails inside the container, re-run on your host:
```bash
gcloud auth application-default login
gcloud auth application-default set-quota-project cloudability-it-gemini
```
```

**b) Update Quick Start sections** to mention Claude Code verification:

In **"Option A: Standalone Project"**, add before step 3:
```markdown
**2.5. Verify Claude Code (HOST)**
Ensure `claude` works on your host and `echo $ANTHROPIC_VERTEX_PROJECT_ID` shows your project ID.
```

In **"Option B: External Project Integration"**, add before step 3:
```markdown
**2.5. Verify Claude Code (HOST)**
Ensure `claude` works on your host and `echo $ANTHROPIC_VERTEX_PROJECT_ID` shows your project ID.
```

**c) Add troubleshooting section** before "## Advanced Usage" (around line 414):

```markdown
### Claude Code and Vertex AI Issues

**Claude Code not found:**
```bash
# Inside devcontainer, verify installation
which claude
# Should show: /usr/local/bin/claude or similar

# If missing, rebuild container
# In VSCode: Command Palette -> Dev Containers: Rebuild Container
```

**Authentication errors:**
```bash
# On HOST machine, re-authenticate
gcloud auth application-default login
gcloud auth application-default set-quota-project cloudability-it-gemini

# Verify credentials exist
ls ~/.config/gcloud/application_default_credentials.json

# Restart the devcontainer to pick up new credentials
```

**Wrong project or region:**
```bash
# Inside Claude Code CLI
/status

# Should show:
# Provider: Google Vertex AI
# Project: [your-team-project-id]
# Region: us-east5

# If incorrect, check devcontainer.json has correct values
echo $ANTHROPIC_VERTEX_PROJECT_ID
echo $CLOUD_ML_REGION
```

**Environment variable not set:**
```bash
# On HOST, check if variable is set
echo $ANTHROPIC_VERTEX_PROJECT_ID

# If empty, add to ~/.bashrc or ~/.zshrc:
echo 'export ANTHROPIC_VERTEX_PROJECT_ID=your-project-id' >> ~/.bashrc
source ~/.bashrc

# Then rebuild the devcontainer
```

**Quota or permission errors:**
- Verify you're using the correct project ID from the Red Hat spreadsheet
- Ensure you've completed the [Red Hat approval form](https://docs.google.com/forms/d/e/1FAIpQLSdIphsk9TlTR-TPSsk9xiNLqmgSCJJ2BLTOWLMM667X1vmsMg/viewform)
- Contact #help-rh-code-assist on Slack for Red Hat-specific issues
- Check that `cloudability-it-gemini` is set as your quota project:
  ```bash
  gcloud config get-value billing/quota_project
  ```
```

---

### 5. Update .gitignore
**File**: `.gitignore`

**Add credential exclusions** at the end of the file:

```gitignore
# Claude Code and GCP credentials
.config/gcloud/
application_default_credentials.json
.claude/
gcloud-credentials.json
*.json.crypt
```

---

## Security Considerations

1. **Project ID never in git**: Uses `${localEnv:ANTHROPIC_VERTEX_PROJECT_ID}` to read from host environment - the project ID is never written to any committed files
2. **Read-only credential mount**: gcloud credentials are mounted read-only to prevent accidental modification
3. **No credentials in git**: .gitignore prevents credential files from being committed
4. **Named volume for Claude settings**: User preferences and session data persist across rebuilds but stay isolated
5. **Quota project isolation**: Uses Red Hat's `cloudability-it-gemini` quota project to track usage centrally
6. **No gcloud CLI in container**: Reduces attack surface by only mounting existing credentials, not installing full SDK
7. **Safe for public repositories**: Template can be shared publicly - users provide their own project ID via environment variable

---

## Verification Steps

After implementing these changes:

### 1. On Host
Verify gcloud ADC and environment variable are configured:
```bash
# Check gcloud credentials
gcloud auth application-default print-access-token

# Verify project ID is set in your shell
echo $ANTHROPIC_VERTEX_PROJECT_ID  # Should show your project ID
```

### 2. Run Setup
Execute `setup-project.sh` - it will warn if ANTHROPIC_VERTEX_PROJECT_ID is not set:
```bash
./setup-project.sh
```

### 3. Open in VSCode
```bash
code .
```
Then reopen in container when prompted.

### 4. Inside Container
Verify environment variables are passed through:
```bash
echo $CLAUDE_CODE_USE_VERTEX  # Should be: 1
echo $CLOUD_ML_REGION         # Should be: us-east5
echo $ANTHROPIC_VERTEX_PROJECT_ID  # Should be: [your-project-id]
```

### 5. Launch Claude Code
```bash
claude
```

Then inside the Claude Code CLI:
```
/status
```

Expected output:
- Provider: "Google Vertex AI"
- Project: Your team's GCP project ID
- Region: us-east5

---

## Files Modified Summary

| File | Location | Changes |
|------|----------|---------|
| devcontainer.json | `.devcontainer/` | Add Claude Code feature, gcloud mount, environment variables |
| setup-project.sh | Root | Add Claude Code verification message |
| setup-environment.sh | `.devcontainer/` | Add Claude Code and gcloud verification |
| README.md | Root | Add prerequisites section, update Quick Start, add troubleshooting |
| .gitignore | Root | Add credential exclusions |

---

## Dependencies

- Host must have gcloud CLI installed and configured with ADC
- Host must have `ANTHROPIC_VERTEX_PROJECT_ID` environment variable set
- User must have valid Red Hat GCP project ID
- User must have completed Red Hat Claude Code approval form
- Docker must support read-only bind mounts
- VSCode devcontainer extension must be installed

---

## Additional Notes

### Why Environment Variables Instead of Placeholders?
The template uses `${localEnv:ANTHROPIC_VERTEX_PROJECT_ID}` instead of a `{{GCP_PROJECT_ID}}` placeholder to keep the project ID secure:
- The project ID never gets written to any committed files
- Each user provides their own project ID via their shell configuration
- The template can be safely shared in public repositories
- Follows the same pattern as existing SSH agent forwarding

### Red Hat Specific Configuration
This integration is specifically designed for Red Hat's Claude Code setup:
- Uses the `us-east5` region (Red Hat standard)
- References the `cloudability-it-gemini` quota project
- Assumes users have followed Red Hat's installation process
- Compatible with Red Hat's approval and governance process

### Persistence
- Claude Code settings (.claude directory) are stored in a named volume
- Settings persist across container rebuilds
- Each project gets its own Claude Code configuration
- Settings are isolated from other projects

---

## Rollback Plan

If you need to remove Claude Code integration:

1. Remove the Claude Code feature from devcontainer.json
2. Remove the gcloud mount and claude volume from mounts array
3. Remove the four environment variables from containerEnv
4. Remove the verification code from setup-project.sh
5. Remove the verification code from setup-environment.sh
6. Remove the Claude Code sections from README.md
7. Rebuild the container

The template will function normally without Claude Code integration.