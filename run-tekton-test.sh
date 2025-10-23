#!/usr/bin/env bash
# Helper to run the Tekton kustomization test reliably from repo root
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR="$SCRIPT_DIR/flux-kustomization/tests"
VARS_FILE="$SCRIPT_DIR/tekton_vars.yaml"

if [ ! -f "$VARS_FILE" ]; then
  echo "vars file not found: $VARS_FILE" >&2
  exit 2
fi

cd "$TEST_DIR"
echo "Running kcl test from: $(pwd)"
kcl run test_tekton_kustomization.k -D "$VARS_FILE"
