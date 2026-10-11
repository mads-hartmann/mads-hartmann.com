#!/usr/bin/env bash
# Refresh the single root environment using its pinned inputs.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$repo_root"
exec devenv --no-tui update
