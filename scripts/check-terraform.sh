#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
terraform fmt -check -recursive terraform/kernel terraform/stacks terraform/modules
for root in terraform/kernel terraform/stacks/shared terraform/stacks/homepage terraform/stacks/blog terraform/stacks/uses terraform/modules/static-site; do
  terraform -chdir="$root" init -backend=false -input=false -lockfile=readonly
  terraform -chdir="$root" validate -no-color
  terraform -chdir="$root" test -no-color
done
