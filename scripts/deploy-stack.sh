#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
stack="${1:?stack required}"
case "$stack" in shared|homepage|blog|uses) ;; *) echo 'Unknown stack' >&2; exit 2;; esac
root="terraform/stacks/$stack"
terraform -chdir="$root" init -input=false -lockfile=readonly -backend-config=backend.hcl
test "$(terraform -chdir="$root" workspace show)" = default
terraform -chdir="$root" plan -input=false -lock-timeout=5m -out=deploy.tfplan
# The plan and content are from the same checkout and stay in the same job.
terraform -chdir="$root" apply -input=false -lock-timeout=5m deploy.tfplan
rm "$root/deploy.tfplan"
if [[ "$stack" == shared ]]; then
  echo "zone_id=$(terraform -chdir="$root" output -raw zone_id)" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "certificate_arn=$(terraform -chdir="$root" output -raw certificate_arn)" >> "${GITHUB_OUTPUT:-/dev/stdout}"
else
  distribution="$(terraform -chdir="$root" output -raw distribution_id)"
  invalidation="$(aws cloudfront create-invalidation --distribution-id "$distribution" --paths '/*' --query Invalidation.Id --output text)"
  aws cloudfront wait invalidation-completed --distribution-id "$distribution" --id "$invalidation"
  host="$(terraform -chdir="$root" output -raw distribution_domain)"
  python3 scripts/smoke-test.py "$stack" "https://$host"
fi
