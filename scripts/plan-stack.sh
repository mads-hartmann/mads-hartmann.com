#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
case "${1:-}" in shared|homepage|blog|uses) ;; *) exit 2;; esac
root="terraform/stacks/$1"
terraform -chdir="$root" init -input=false -lockfile=readonly -backend-config=backend.hcl
test "$(terraform -chdir="$root" workspace show)" = default
terraform -chdir="$root" plan -input=false -lock-timeout=5m -no-color
