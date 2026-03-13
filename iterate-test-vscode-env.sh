#!/bin/bash

# Use this script to remove an existing test environment and recreate a new one with the same name in ~/tmp/
# It clears out the old devcontainer images and the vscode project configuration before copying over the new one and
# running setup-project.sh in the new project directory.
# This script can be run from any directory — it uses its own location as the template source.

# Check if a project name was provided
if [ -z "$1" ]; then
  echo "Usage: ./iterate-test-vscode-env.sh <project_name>"
  exit 1
fi

PROJECT_NAME=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/tmp/$PROJECT_NAME"
WORKSPACE_STORAGE="$HOME/.config/Code/User/workspaceStorage"
BACKUPS_DIR="$HOME/.config/Code/Backups"
GLOBAL_STORAGE="$HOME/.config/Code/User/globalStorage"
STORAGE_JSON="$GLOBAL_STORAGE/storage.json"
STATE_DB="$GLOBAL_STORAGE/state.vscdb"

# Check if VS Code is running and prompt before continuing
if pgrep code > /dev/null 2>&1; then
  echo "⚠️  VS Code is currently running."
  read -r -p "Kill VS Code and continue? [y/N] " answer
  if [[ "$answer" =~ ^[Yy]$ ]]; then
    echo "🛑 Killing VS Code..."
    pkill code 2>/dev/null || true
    sleep 5
    if pgrep code > /dev/null 2>&1; then
      echo "⚠️  Still running, force killing..."
      pkill -9 code 2>/dev/null || true
      sleep 2
    fi
    if pgrep code > /dev/null 2>&1; then
      echo "❌ Could not kill VS Code. Close it manually and re-run."
      exit 1
    fi
    echo "✅ VS Code stopped."
  else
    echo "Exiting."
    exit 0
  fi
fi

if [ -d "$HOME/tmp" ]; then
  echo "🔥 Starting teardown for: $PROJECT_NAME"

  # 1. Delete the project directory in ~/tmp/
  if [ -d "$TARGET_DIR" ]; then
    echo "📁 Deleting project directory $TARGET_DIR..."
    sudo rm -rf "$TARGET_DIR"
  else
    echo "📁 Project directory $TARGET_DIR not found, skipping."
  fi

  # 2. Find and remove the Docker containers whose image matches vsc-${PROJECT_NAME}
  echo "🐳 Looking for containers with image matching vsc-${PROJECT_NAME}..."
  CONTAINER_IDS=$(docker ps -a --format '{{.ID}} {{.Image}}' \
    | awk -v pat="^vsc-${PROJECT_NAME}" '$2 ~ pat {print $1}')

  if [ -n "$CONTAINER_IDS" ]; then
    while IFS= read -r CID; do
      echo "🐳 Removing container: $CID"
      docker rm -v -f "$CID"
    done <<< "$CONTAINER_IDS"
  else
    echo "🐳 No containers found with image matching vsc-${PROJECT_NAME}, skipping."
  fi

  # Remove the matching images
  IMAGES=$(docker images --format '{{.Repository}}' | grep -E "^vsc-${PROJECT_NAME}" || true)
  if [ -n "$IMAGES" ]; then
    while IFS= read -r IMAGE; do
      echo "🗑️  Removing image: $IMAGE"
      docker rmi "$IMAGE" 2>/dev/null || echo "⚠️  Could not remove image $IMAGE"
    done <<< "$IMAGES"
  else
    echo "🐳 No images matching vsc-${PROJECT_NAME} found, skipping."
  fi

  # 3. Clear the VS Code workspace storage
  echo "🧹 Searching for VS Code workspace cache for $PROJECT_NAME..."
  while IFS= read -r HASH_DIR; do
    echo "🗑️  Deleting VS Code workspace cache: $HASH_DIR"
    rm -rf "$HASH_DIR"
  done < <(grep -rl "$PROJECT_NAME" "$WORKSPACE_STORAGE" 2>/dev/null | xargs -I{} dirname {} | sort -u)

  # 4. Clear the VS Code Backups directory entries for this project
  if [ -d "$BACKUPS_DIR" ]; then
    echo "🧹 Searching for VS Code backup data for $PROJECT_NAME..."
    while IFS= read -r BACKUP_ENTRY; do
      echo "🗑️  Deleting VS Code backup: $BACKUP_ENTRY"
      rm -rf "$BACKUP_ENTRY"
    done < <(grep -rl "$PROJECT_NAME" "$BACKUPS_DIR" 2>/dev/null | xargs -I{} dirname {} | sort -u)
  fi

  # 5. Purge project references from VS Code global storage (storage.json + state.vscdb)
  echo "🧹 Removing project references from VS Code global storage..."
  python3 - <<PYEOF
import json, sqlite3, os, sys

target = "$TARGET_DIR"
target_name = "$PROJECT_NAME"

# --- storage.json ---
storage_path = "$STORAGE_JSON"
if os.path.exists(storage_path):
    try:
        with open(storage_path) as f:
            data = json.load(f)
        changed = False
        for section in ("workspaces", "files"):
            entries = data.get("recentlyOpened", {}).get(section, [])
            filtered = [e for e in entries if target not in str(e)]
            if len(filtered) != len(entries):
                data.setdefault("recentlyOpened", {})[section] = filtered
                changed = True
        if changed:
            with open(storage_path, "w") as f:
                json.dump(data, f, indent=2)
            print(f"✅ Removed {target_name} from storage.json recentlyOpened")
        else:
            print(f"ℹ️  No recentlyOpened entries found for {target_name} in storage.json")
    except Exception as e:
        print(f"⚠️  storage.json update failed: {e}", file=sys.stderr)

# --- state.vscdb ---
state_db = "$STATE_DB"
if os.path.exists(state_db):
    try:
        conn = sqlite3.connect(state_db)
        c = conn.cursor()
        c.execute("SELECT key FROM ItemTable WHERE value LIKE ?", (f'%{target}%',))
        rows = c.fetchall()
        if rows:
            for (key,) in rows:
                print(f"  Removing state.vscdb entry: {key}")
            c.execute("DELETE FROM ItemTable WHERE value LIKE ?", (f'%{target}%',))
            conn.commit()
            print(f"✅ Removed {len(rows)} state.vscdb entries referencing {target_name}")
        else:
            print(f"ℹ️  No state.vscdb entries found for {target_name}")
        conn.close()
    except Exception as e:
        print(f"⚠️  state.vscdb update failed: {e}", file=sys.stderr)
PYEOF

  echo "✅ Teardown complete! Time to copy over the new project files"
else
  echo "📂 ~/tmp does not exist, skipping teardown. Creating ~/tmp/..."
  mkdir -p "$HOME/tmp"
fi

cp -r "$SCRIPT_DIR" "$TARGET_DIR"
cd "$TARGET_DIR" || exit
./setup-project.sh
code .

echo "✅ New project created at $TARGET_DIR and VSCode should be up and running"
