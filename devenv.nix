{ pkgs, config, ... }:
let
  versions = import ./dev/shared/versions.nix;
  buildTools = import ./dev/bazel/tools.nix { inherit pkgs; ruby = config.languages.ruby.package; };
in {
  packages = with pkgs; [
    actionlint awscli2 bashInteractive curl direnv gawk gh git gnumake jq
    kubectl kubectx python3 stern watchexec
    libffi libyaml openssl zlib bundix
    buildTools.bazel buildTools.jekyll
  ];

  languages.javascript = {
    enable = true;
    package = pkgs.${versions.node};
  };
  languages.ruby = {
    enable = true;
    version = versions.ruby;
    lsp.enable = false;
  };
  languages.terraform.enable = true;

  # Keep tool and dependency caches local, platform-specific, and ignored.
  env.DEV_STATE = "${config.git.root}/.devenv-state/${pkgs.stdenv.hostPlatform.system}";
  env.npm_config_cache = "${config.env.DEV_STATE}/npm-cache";
}
