#!/usr/bin/env bash
# The shared inputs are exact revisions; refresh every environment together.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
for directory in . sites/mads-hartmann.com sites/blog.mads-hartmann.com sites/uses.mads-hartmann.com terraform; do
  (cd "$repo_root/$directory" && devenv --no-tui update)
done
(cd "$repo_root" && devenv --no-tui shell -- python3 dev/scripts/check-locks.py)
