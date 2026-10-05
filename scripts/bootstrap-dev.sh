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
version="$(read_pin devenvVersion)"
fingerprint="$(read_pin fingerprint)"
profile="${XDG_STATE_HOME:-$HOME/.local/state}/mads-hartmann-dev/$fingerprint"
mkdir -p "$(dirname "$profile")"
if [[ ! -x "$profile/bin/devenv" || ! -x "$profile/bin/direnv" || ! -x "$profile/bin/bash" ]]; then
  nix "${nix_flags[@]}" \
    --extra-substituters https://devenv.cachix.org \
    --extra-trusted-public-keys 'devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw=' \
    profile install --profile "$profile" \
    "$(read_pin devenvRef)" "$(read_pin nixpkgsRef)#direnv" "$(read_pin nixpkgsRef)#bashInteractive" >&2
fi
installed_version="$("$profile/bin/devenv" --version)"
case "$installed_version" in
  "devenv $version"|"devenv $version ("*|"devenv $version+"*) ;;
  *) echo "Expected devenv $version; found $installed_version" >&2; exit 1 ;;
esac
profile_bin="$(cd "$profile/bin" && pwd -P)"
printf 'export PATH=%q:"$PATH"\n' "$profile_bin"
