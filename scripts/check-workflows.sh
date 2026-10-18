#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
exec bazel test //:workflows_test //:deployments_test
