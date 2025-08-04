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

PROJECT_NAME=$(basename "$PWD")
echo "Setting up $PROJECT_NAME development environment..."

# Replace template placeholders
find . -name "*.json" -o -name "*.sh" -o -name "*.py" | xargs sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g"

# Create directories
mkdir -p .devcontainer src/${PROJECT_NAME} {scripts,configs,tests,datasets,models}

# Move files
mv devcontainer.json .devcontainer/
mv setup-environment.sh .devcontainer/
mv resolve-dependencies.py scripts/

# Create Python structure
touch src/__init__.py src/${PROJECT_NAME}/__init__.py tests/__init__.py

# Clone repo if specified
if [ -n "$CLONE_REPO" ]; then
    git clone "$CLONE_REPO" $(basename "$CLONE_REPO" .git)
fi

echo "Setup complete! Put images in ./datasets/"
