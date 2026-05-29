#!/usr/bin/env bash
# bootstrap.sh — run this once on a fresh Ubuntu machine to turn it into a PVE VDI thin client
# Usage: curl -fsSL https://raw.githubusercontent.com/brownkurts/bootstrap-vdi/main/bootstrap.sh | sudo bash

set -euo pipefail

REPO_URL="https://github.com/brownkurts/bootstrap-vdi.git"
BRANCH="main"

echo "[bootstrap-vdi] Starting VDI thin client setup..."
echo "[bootstrap-vdi] Repo: $REPO_URL"

# Ensure ansible and git are installed
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq ansible git

# Run ansible-pull against this machine
echo "[bootstrap-vdi] Running ansible-pull..."
ansible-pull \
    --url "$REPO_URL" \
    --checkout "$BRANCH" \
    --inventory "localhost," \
    --connection local \
    site.yml

echo "[bootstrap-vdi] Done. System will reboot."
