#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
site="${1:-all}"
case "$site" in all|homepage|blog|uses|computer) ;; *) echo 'Usage: scripts/build.sh [all|homepage|blog|uses|computer]' >&2; exit 2;; esac
if [[ "$site" == all ]]; then
  bazel build //:sites
else
  bazel build "//:${site}_manifest"
fi
python3 scripts/export-sites.py "$site" "$(bazel info bazel-bin)"
