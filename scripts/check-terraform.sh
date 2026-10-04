#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Offline checks must not load a backend already configured for human migration.
verification_dir="$(mktemp -d)"
trap 'rm -rf "$verification_dir"' EXIT
export TF_DATA_DIR="$verification_dir/format"
export TF_PLUGIN_CACHE_DIR="$verification_dir/providers"
mkdir -p "$TF_PLUGIN_CACHE_DIR"
terraform fmt -check -recursive terraform/kernel terraform/stacks terraform/modules
for root in terraform/kernel terraform/stacks/shared terraform/stacks/homepage terraform/stacks/blog terraform/stacks/uses terraform/modules/static-site; do
  export TF_DATA_DIR="$verification_dir/$root"
  mkdir -p "$TF_DATA_DIR"
  terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$root" validate -no-color
  terraform -chdir="$root" test -no-color
done
