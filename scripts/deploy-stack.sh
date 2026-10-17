#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
stack="${1:?stack required}"
case "$stack" in shared|homepage|blog|uses|computer) ;; *) echo 'Unknown stack' >&2; exit 2;; esac
root="terraform/stacks/$stack"
terraform -chdir="$root" init -input=false -lockfile=readonly -backend-config=backend.hcl
test "$(terraform -chdir="$root" workspace show)" = default
trap 'rm -f "$root/deploy.tfplan"' EXIT
plan_status=0
terraform -chdir="$root" plan -input=false -lock-timeout=5m -detailed-exitcode -out=deploy.tfplan || plan_status=$?
case "$plan_status" in
  0) echo 'No changes; skipping apply and CloudFront invalidation.' ;;
  2)
    # The plan and content are from the same checkout and stay in the same job.
    terraform -chdir="$root" apply -input=false -lock-timeout=5m deploy.tfplan
    ;;
  *) exit "$plan_status" ;;
esac
if [[ "$stack" == shared ]]; then
  if [[ "$plan_status" == 2 ]]; then changed=true; else changed=false; fi
  echo "changed=$changed" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "zone_id=$(terraform -chdir="$root" output -raw zone_id)" >> "${GITHUB_OUTPUT:-/dev/stdout}"
  echo "certificate_arn=$(terraform -chdir="$root" output -raw certificate_arn)" >> "${GITHUB_OUTPUT:-/dev/stdout}"
else
  if [[ "$plan_status" == 2 ]]; then
    distribution="$(terraform -chdir="$root" output -raw distribution_id)"
    invalidation="$(aws cloudfront create-invalidation --distribution-id "$distribution" --paths '/*' --query Invalidation.Id --output text)"
    aws cloudfront wait invalidation-completed --distribution-id "$distribution" --id "$invalidation"
  fi
  # Keep verification on no-op retries (for example after a failed smoke test).
  host="$(terraform -chdir="$root" output -raw distribution_domain)"
  python3 scripts/smoke-test.py "$stack" "https://$host"
  python3 scripts/check-http-cache.py "https://$host"
fi
