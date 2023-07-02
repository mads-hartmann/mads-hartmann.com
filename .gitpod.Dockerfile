FROM madshartmann/gitpod-nix-base:1

RUN . /home/gitpod/.nix-profile/etc/profile.d/nix.sh \
     && nix profile install --accept-flake-config github:cachix/devenv/latest \
     && nix profile install nixpkgs#nixpkgs-fmt
