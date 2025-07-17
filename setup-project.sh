#!/bin/bash
set -e

# Set PROJECT_NAME to current directory name
PROJECT_NAME=$(basename "$PWD")

echo "Setting up $PROJECT_NAME development environment..."

# Replace template placeholders in all files
echo "Updating template files..."
find . -name "*.json" -o -name "*.sh" -o -name "*.py" | xargs sed -i "s/{{PROJECT_NAME}}/$PROJECT_NAME/g"

# Create required directories
echo "Creating directory structure..."
mkdir -p .devcontainer
mkdir -p src/${PROJECT_NAME}
mkdir -p {scripts,configs,tests,models,data,logs,experiments}
mkdir -p .cache/{huggingface,torch,pip}

# Move devcontainer files to proper location
echo "Setting up devcontainer..."
mv devcontainer.json .devcontainer/
mv setup-environment.sh .devcontainer/
mv resolve-dependencies.py .devcontainer/

# Create Python package structure
touch src/__init__.py
touch src/${PROJECT_NAME}/__init__.py
touch tests/__init__.py

echo "Setup complete!"
echo "Project: $PROJECT_NAME"
echo ""
echo "Next steps:"
echo "1. Open IntelliJ Ultimate"
echo "2. Remote Development → Create Dev Container"
echo "3. Point to this project folder"
echo "4. Select 'Create Dev Container and Mount Sources'"