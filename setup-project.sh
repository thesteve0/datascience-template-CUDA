#!/bin/bash
set -e

# Parse arguments
CLONE_REPO=""
IDE_CHOICE=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --clone-repo)
            CLONE_REPO="$2"
            shift 2
            ;;
        --ide)
            IDE_CHOICE="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--clone-repo <git-url>] [--ide <vscode|jetbrains|both>]"
            exit 1
            ;;
    esac
done


# ==============================================================================
# --- Configuration ---
# All project constants are defined here. Edit these values to change the setup.
# ==============================================================================

# Set the project name equal to the directory name
PROJECT_NAME=$(basename "$PWD")

# Automatically get Git identity from your global .gitconfig
GIT_NAME=$(git config user.name)
GIT_EMAIL=$(git config user.email)

# Define the username and user ID for inside the container.
# DEV_UID matches the host user's UID so that bind-mounted workspace files
# are writable inside the container. The Dockerfile deletes the ubuntu user
# (UID 1000) before common-utils runs, so any host UID is safe to use here.
DEV_USER=$(whoami)-devcontainer
DEV_UID=$(id -u)

# ==============================================================================
# --- IDE Selection ---
# ==============================================================================

if [ -z "$IDE_CHOICE" ]; then
    echo ""
    echo "Which IDE(s) do you want to configure?"
    echo "  1) VSCode only"
    echo "  2) JetBrains only (PyCharm / IntelliJ IDEA)"
    echo "  3) Both VSCode and JetBrains"
    read -p "Enter choice [1-3, default: 1]: " ide_num
    case $ide_num in
        2) IDE_CHOICE="jetbrains" ;;
        3) IDE_CHOICE="both" ;;
        *) IDE_CHOICE="vscode" ;;
    esac
fi

echo "IDE configuration: $IDE_CHOICE"

# ==============================================================================
# --- Script Logic ---
# ==============================================================================

echo "Setting up $PROJECT_NAME development environment..."

# Replace template placeholders
find . \( -name "*.json" -o -name "*.sh" -o -name "*.py" -o -name "*.toml" \) | xargs sed -i \
    -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{GIT_NAME}}/$GIT_NAME/g" \
    -e "s/{{GIT_EMAIL}}/$GIT_EMAIL/g" \
    -e "s/{{DEV_USER}}/$DEV_USER/g" \
    -e "s/{{DEV_UID}}/$DEV_UID/g"


# Create template_docs/ and move template reference documentation into it.
# This keeps the project root clean for user-facing files.
mkdir -p template_docs
for doc in README.md QUICKSTART.md IMPLEMENTATION-PROGRESS.md PRODUCTION-DEPLOYMENT.md CHANGELOG.md NEXT-SESSION-TODO.md CLAUDE.md; do
    [ -f "$doc" ] && mv "$doc" template_docs/ || true
done

# Create base directories and move devcontainer infrastructure files.
# These are always needed regardless of IDE — both VSCode and JetBrains Gateway
# read .devcontainer/devcontainer.json to launch the container.
mkdir -p .devcontainer scripts
mv Dockerfile .devcontainer/
mv devcontainer.json .devcontainer/
mv setup-environment.sh .devcontainer/
[ -f resolve-dependencies.py ] && mv resolve-dependencies.py scripts/ || true

# Generate user-facing skeleton files in the project root.
cat > "GETTING_STARTED.md" << SKELETONEOF
# Getting Started with ${PROJECT_NAME}

## First-time setup checklist
- [ ] Verify GPU: \`python -c "import torch; print(torch.cuda.is_available())"\`
- [ ] Add your first package: \`uv add <package-name>\`
- [ ] Run formatter check: \`ruff check .\`
- [ ] Reference docs in template_docs/ for dependency management notes
SKELETONEOF

cat > "README.md" << SKELETONEOF
# ${PROJECT_NAME}
SKELETONEOF

cat > "CLAUDE.md" << SKELETONEOF
# CLAUDE.md

Project-specific guidance for Claude Code.
SKELETONEOF

# Generate JetBrains .idea/ configuration files.
# These tell PyCharm/IntelliJ which Python SDK to use, enable Git, and configure
# the Ruff plugin. workspace.xml is intentionally omitted — it's user-specific state
# and should not be committed to the project repository.
if [ "$IDE_CHOICE" = "jetbrains" ] || [ "$IDE_CHOICE" = "both" ]; then
    echo "Generating JetBrains .idea/ configuration..."
    mkdir -p .idea

    # Python module definition — type PYTHON_MODULE tells PyCharm this is a Python project.
    cat > ".idea/${PROJECT_NAME}.iml" << 'IDEEOF'
<?xml version="1.0" encoding="UTF-8"?>
<module type="PYTHON_MODULE" version="4">
  <component name="NewModuleRootManager">
    <content url="file://$MODULE_DIR$" />
    <orderEntry type="inheritedJdk" />
    <orderEntry type="sourceFolder" forTests="false" />
  </component>
</module>
IDEEOF

    # Module registry — references the .iml file above.
    # $PROJECT_DIR$ is an IntelliJ path macro, not a shell variable; \$ escapes it.
    cat > ".idea/modules.xml" << IDEEOF
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectModuleManager">
    <modules>
      <module fileurl="file://\$PROJECT_DIR\$/.idea/${PROJECT_NAME}.iml" filepath="\$PROJECT_DIR\$/.idea/${PROJECT_NAME}.iml" />
    </modules>
  </component>
</project>
IDEEOF

    # Python SDK — points PyCharm at the .venv created by setup-environment.sh.
    # PyCharm will auto-discover the interpreter if the SDK name doesn't match exactly;
    # the project-jdk-type="Python SDK" is what triggers that discovery.
    cat > ".idea/misc.xml" << 'IDEEOF'
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="ProjectRootManager" version="2" project-jdk-name="Python 3.12 (.venv)" project-jdk-type="Python SDK" />
</project>
IDEEOF

    # Git integration — maps the project root to the Git VCS.
    cat > ".idea/vcs.xml" << 'IDEEOF'
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="VcsDirectoryMappings">
    <mapping directory="$PROJECT_DIR$" vcs="Git" />
  </component>
</project>
IDEEOF

    # Standard .gitignore for .idea/ — excludes user-specific files from version control.
    cat > ".idea/.gitignore" << 'IDEEOF'
# Default ignored files
/shelf/
/workspace.xml
# Editor-based HTTP Client requests
/httpRequests/
# Datasource local storage ignored files
/dataSources/
/dataSources.local.xml
IDEEOF

    echo "JetBrains .idea/ configuration created"
fi

if [ -n "$CLONE_REPO" ]; then
    # External repo mode
    CLONED_REPO_NAME=$(basename "$CLONE_REPO" .git)
    echo "External repo mode: integrating $CLONED_REPO_NAME"

    # Check for naming conflicts
    if [ -d "$CLONED_REPO_NAME" ]; then
        echo "Error: Directory $CLONED_REPO_NAME already exists"
        exit 1
    fi

    # Update PYTHONPATH in devcontainer.json for external repo
    sed -i "s|\"PYTHONPATH\": \"/workspaces/$PROJECT_NAME/src\"|\"PYTHONPATH\": \"/workspaces/$PROJECT_NAME/$CLONED_REPO_NAME\"|g" .devcontainer/devcontainer.json

    # Clone repo
    git clone "$CLONE_REPO" "$CLONED_REPO_NAME"

    # Add to .gitignore
    echo "$CLONED_REPO_NAME/" >> .gitignore

    echo "Setup complete! External repo cloned to ./$CLONED_REPO_NAME"
    echo "PYTHONPATH set to /workspaces/$PROJECT_NAME/$CLONED_REPO_NAME"

else
    # Standalone mode
    echo "Standalone mode"

    # Create additional directories for standalone
    mkdir -p src/${PROJECT_NAME} {configs,tests,datasets,models}

    # Create Python structure
    touch src/__init__.py src/${PROJECT_NAME}/__init__.py tests/__init__.py

    # Marker file used as a signal that this was initialized in standalone mode
    touch .standalone-project
fi

echo ""
echo "=========================================="
echo "Setup complete! Project: $PROJECT_NAME"
echo "IDE: $IDE_CHOICE"
echo "=========================================="
echo ""

if [ "$IDE_CHOICE" = "vscode" ] || [ "$IDE_CHOICE" = "both" ]; then
    echo "VSCode next steps:"
    echo "  1. code ."
    echo "  2. Reopen in Container when prompted"
    echo "  3. In container terminal: uv add <package>"
    echo ""
fi

if [ "$IDE_CHOICE" = "jetbrains" ] || [ "$IDE_CHOICE" = "both" ]; then
    echo "JetBrains next steps:"
    echo "  1. Open JetBrains Gateway"
    echo "  2. New Connection > Dev Containers > select this folder"
    echo "  3. Gateway builds the container and opens PyCharm/IntelliJ inside it"
    echo "  4. In the IDE terminal: uv add <package>"
    echo "  Note: Ruff and GitHub Copilot plugins install automatically via devcontainer.json"
    echo ""
fi

echo "Verify GPU access (in container terminal):"
echo "  python test-gpu.py"
