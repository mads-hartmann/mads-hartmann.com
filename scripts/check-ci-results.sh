#!/usr/bin/env bash
set -euo pipefail

require_result() {
  local name="$1" required="$2" result="$3" expected
  case "$required" in
    true) expected=success ;;
    false) expected=skipped ;;
    *) echo "$name: missing or invalid requirement: $required" >&2; exit 1 ;;
  esac
  if [[ "$result" != "$expected" ]]; then
    echo "$name: expected $expected, got $result" >&2
    exit 1
  fi
}

require_result Build true "${BUILD_RESULT:-}"
require_result Terraform "${TERRAFORM_REQUIRED:-}" "${TERRAFORM_RESULT:-}"
require_result Plan "${PLAN_REQUIRED:-}" "${PLAN_RESULT:-}"
