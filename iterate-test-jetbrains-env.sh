#!/bin/bash

# Use this script to remove an existing test environment and recreate a new one with the same name in ~/tmp/
# It clears out the old devcontainer images before copying over the new template and
# running setup-project.sh in the new project directory.
# Open the resulting project via JetBrains Gateway manually after this script completes.
# This script can be run from any directory — it uses its own location as the template source.

# Check if a project name was provided
if [ -z "$1" ]; then
  echo "Usage: ./iterate-test-jetbrains-env.sh <project_name>"
  exit 1
fi

PROJECT_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/tmp/$PROJECT_NAME"

if [ -d "$HOME/tmp" ]; then
  echo "🔥 Starting teardown for: $PROJECT_NAME"

  # 1. Delete the project directory in ~/tmp/
  if [ -d "$TARGET_DIR" ]; then
    echo "📁 Deleting project directory $TARGET_DIR..."
    sudo rm -rf "$TARGET_DIR"
  else
    echo "📁 Project directory $TARGET_DIR not found, skipping."
  fi

  # 2. Find and remove the Docker containers and project-specific image for this project.
  #
  # JetBrains Gateway image naming convention:
  #   jb-devcontainer-{project_dir}_{devcontainer_name_normalized}:latest
  # where the devcontainer name comes from the "name" field in devcontainer.json,
  # lowercased with spaces replaced by underscores.
  #
  # Example: project "jb-test" + name "jb-test PyTorch ML Development"
  #   → jb-devcontainer-jb-test_jb-test_pytorch_ml_development:latest
  #
  # We match on the prefix "jb-devcontainer-{PROJECT_NAME}_" which is unique per project.
  #
  # Images we intentionally do NOT delete (shared across JetBrains devcontainer projects):
  #   jb-{hash}-uid:latest           — UID-remapped base image (22GB, expensive to rebuild)
  #   jb-devcontainer-features-*     — devcontainer features layer
  #   jetbrains/devcontainers-helper — JetBrains tooling

  IMAGE_PATTERN="jb-devcontainer-${PROJECT_NAME}_"
  echo "🐳 Looking for project image matching: ${IMAGE_PATTERN}..."

  PROJECT_IMAGE=$(docker images --format '{{.Repository}}:{{.Tag}}' \
    | grep "^${IMAGE_PATTERN}" || true)

  if [ -n "$PROJECT_IMAGE" ]; then
    # Find and remove any containers using this image (container names are random in JetBrains)
    while IFS= read -r IMG; do
      CONTAINER_IDS=$(docker ps -a --filter "ancestor=${IMG}" --format '{{.ID}}')
      if [ -n "$CONTAINER_IDS" ]; then
        while IFS= read -r CID; do
          echo "🐳 Removing container: $CID (image: $IMG)"
          docker rm -v -f "$CID"
        done <<< "$CONTAINER_IDS"
      fi
      echo "🗑️  Removing image: $IMG"
      docker rmi "$IMG" 2>/dev/null || echo "⚠️  Could not remove image $IMG"
    done <<< "$PROJECT_IMAGE"
  else
    echo "🐳 No project image matching ${IMAGE_PATTERN} found, skipping."
  fi

  echo "✅ Teardown complete! Time to copy over the new project files"
else
  echo "📂 ~/tmp does not exist, skipping teardown. Creating ~/tmp/..."
  mkdir -p "$HOME/tmp"
fi

cp -r "$SCRIPT_DIR" "$TARGET_DIR"
cd "$TARGET_DIR" || exit
./setup-project.sh

echo "✅ New project created at $TARGET_DIR — open it in JetBrains Gateway to build and start the devcontainer."
