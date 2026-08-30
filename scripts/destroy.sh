#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEV_DIR="$PROJECT_ROOT/infra/envs/dev"

echo "==> Navigating to Terraform environment directory: $DEV_DIR"

if [ ! -d "$DEV_DIR" ]; then
  echo "✗ FAILURE: Directory $DEV_DIR does not exist."
  exit 1
fi

echo "==> Destroying Terraform infrastructure..."
terraform -chdir="$DEV_DIR" destroy "$@"
