#!/usr/bin/env bash
# Generate a single KCL module from multiple CRDs.
#
# Loops over a list of CRD URLs, runs the dagger `convert-crd` function per
# CRD into a temp dir, and merges the outputs into one module directory.
#
# Usage:
#   scripts/generate-module-from-crd-dir.sh <module-name> <version> <crd-url> [<crd-url> ...]
#
# Example:
#   scripts/generate-module-from-crd-dir.sh crossplane-provider-kubernetes 0.1.0 \
#     https://raw.githubusercontent.com/.../kubernetes.crossplane.io_objects.yaml \
#     https://raw.githubusercontent.com/.../kubernetes.crossplane.io_providerconfigs.yaml

set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "usage: $0 <module-name> <version> <crd-url> [<crd-url> ...]" >&2
  exit 1
fi

MODULE_NAME="$1"; shift
VERSION="$1"; shift
CRD_URLS=("$@")

REPO_ROOT="$(git rev-parse --show-toplevel)"
MODULE_DIR="${REPO_ROOT}/models/${MODULE_NAME}"
DAGGER_MOD="github.com/stuttgart-things/dagger/kcl@v0.36.0"

mkdir -p "${MODULE_DIR}"

TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "${TMP_ROOT}"' EXIT

for i in "${!CRD_URLS[@]}"; do
  url="${CRD_URLS[$i]}"
  out="${TMP_ROOT}/crd-${i}"
  mkdir -p "${out}"
  echo "▶ [${i}] convert-crd: ${url}"
  dagger call -m "${DAGGER_MOD}" convert-crd \
    --crd-source "${url}" \
    export --path="${out}" >/dev/null

  # Collision check: any .k file that already exists in the module with
  # different content is a real conflict — halt so the operator can resolve.
  while IFS= read -r -d '' f; do
    rel="${f#${out}/}"
    dst="${MODULE_DIR}/${rel}"
    if [ -f "${dst}" ] && ! cmp -s "${f}" "${dst}"; then
      echo "ERROR: schema collision at ${rel}" >&2
      diff -u "${dst}" "${f}" >&2 || true
      exit 2
    fi
  done < <(find "${out}" -type f -name '*.k' -print0)

  # Merge: schemas + shared k8s types. Skip kcl.mod (written below).
  rsync -a --exclude='kcl.mod' --exclude='kcl.mod.lock' "${out}/" "${MODULE_DIR}/"
done

cat > "${MODULE_DIR}/kcl.mod" <<EOF
[package]
name = "${MODULE_NAME}"
edition = "v0.12.3"
version = "${VERSION}"
EOF

echo "✅ module written to ${MODULE_DIR}"
