#!/usr/bin/env bash
# Install only environment activation tools. Project tools belong to devenv.
set -euo pipefail
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
if ! command -v nix >/dev/null 2>&1; then
  echo 'Install Nix first: https://docs.determinate.systems/getting-started/' >&2
  exit 1
fi
nix_flags=(--extra-experimental-features 'nix-command flakes')
read_pin() {
  nix "${nix_flags[@]}" eval --raw --file "$repo_root/dev/bootstrap.nix" "$1"
}
nix_flags+=(
  --extra-substituters https://devenv.cachix.org
  --extra-trusted-public-keys 'devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw='
)
tools=("$(read_pin devenvRef)" "$(read_pin nixpkgsRef)#direnv" "$(read_pin nixpkgsRef)#bashInteractive")
# Realize the replacement first; leave installed tools available if a build fails.
nix "${nix_flags[@]}" build --no-link "${tools[@]}"
# Replace just the activation tools, including duplicate entries from older runs.
nix "${nix_flags[@]}" profile remove 'devenv(-[0-9]+)?' 'direnv(-[0-9]+)?' 'bashInteractive(-[0-9]+)?'
nix "${nix_flags[@]}" profile install "${tools[@]}"
echo 'Setup complete. Run devenv shell from the root or a project directory.'
