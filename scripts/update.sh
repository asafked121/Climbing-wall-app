#!/bin/bash

# Navigate to the project directory
# Since this script is in the scripts directory, we navigate one level up
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR/.." || exit

echo "Starting nightly update..."

echo "Checking for updates..."

# Fetch the latest changes without merging
git fetch origin main

# Compare local HEAD with remote branch
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ "$LOCAL" != "$REMOTE" ]; then
    echo "New changes detected. Pulling and rebuilding..."
    
    # Stash any local changes (e.g. permission changes) that would block a pull
    git stash
    git pull origin main
    git stash drop

    # Rebuild and restart the containers in detached mode
    docker compose up -d --build

    # Prune old images to save disk space on the laptop
    docker image prune -f

    echo "Update applied at $(date)"
else
    echo "Up to date. No rebuild needed."
fi
