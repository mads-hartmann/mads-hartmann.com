#!/usr/bin/env bash
# Preview uses the same immutable npm and gem dependencies as Bazel builds.
set -euo pipefail
cd "$(dirname "$0")/.."
modules="$(nix build --extra-experimental-features 'nix-command flakes' --impure \
  --no-link --print-out-paths --file dev/bazel/tools.nix blogNpm)"
# This ignored directory contained npm's generated dependencies before Bazel.
rm -rf sites/blog.mads-hartmann.com/node_modules
ln -s "$modules/node_modules" sites/blog.mads-hartmann.com/node_modules
