#!/bin/bash
set -e

# Parse arguments
CLONE_REPO=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --clone-repo)
            CLONE_REPO="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--clone-repo <git-url>]"
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

# Automatically get the Group ID (GID) of the user running this script
HOST_GID=$(id -g)

# Define a standard name for the shared group
CONTAINER_GROUP_NAME=$(whoami)

# Define the username and user ID for inside the container.
# WARNING: Changing DEV_UID to a value that already exists in the base image
# (like 1000) will cause the container build to fail. Use 1001 for reliability.
DEV_USER=$(whoami)-devcontainer
DEV_UID=2112

# ==============================================================================
# --- Script Logic ---
# ==============================================================================

echo "Setting up $PROJECT_NAME development environment..."

# Replace template placeholders
find . -name "*.json" -o -name "*.sh" -o -name "*.py" | xargs sed -i \
    -e "s/{{PROJECT_NAME}}/$PROJECT_NAME/g" \
    -e "s/{{GIT_NAME}}/$GIT_NAME/g" \
    -e "s/{{GIT_EMAIL}}/$GIT_EMAIL/g" \
    -e "s/{{HOST_GID}}/$HOST_GID/g" \
    -e "s/{{CONTAINER_GROUP_NAME}}/$CONTAINER_GROUP_NAME/g" \
    -e "s/{{DEV_USER}}/$DEV_USER/g" \
    -e "s/{{DEV_UID}}/$DEV_UID/g"


# Create base directories
mkdir -p .devcontainer scripts

# Move files
mv devcontainer.json .devcontainer/
mv setup-environment.sh .devcontainer/
mv resolve-dependencies.py scripts/

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
fi

if [ -n "$CLONE_REPO" ]; then
    echo "Next steps:"
    echo "1. Open in VSCode: code ."
    echo "2. Reopen in Container when prompted"
    echo "3. Extract and filter dependencies:"
    echo "   - Create requirements.txt with project dependencies"
    echo "   - python scripts/resolve-dependencies.py requirements.txt"
    echo "   - uv pip install --system -r requirements-filtered.txt"
else
    echo "Next steps:"
    echo "1. Open in VSCode: code ."
    echo "2. Create requirements.txt with your ML dependencies"
    echo "3. Reopen in Container when prompted"
    echo "4. In container terminal:"
    echo "   - python scripts/resolve-dependencies.py requirements.txt"
    echo "   - uv pip install --system -r requirements-filtered.txt"
fi
