{ pkgs, config, lib, ... }:
{
  packages = with pkgs; [
    actionlint awscli2 bashInteractive curl direnv gawk gh git gnumake jq
    kubectl kubectx python3 stern watchexec
    libffi libyaml openssl zlib
  ];

  languages.javascript = {
    enable = true;
    package = pkgs.nodejs_24;
  };
  languages.ruby = {
    enable = true;
    version = "3.3.11";
    lsp.enable = false;
  };
  languages.terraform.enable = true;

  # Keep tool and dependency caches local, platform-specific, and ignored.
  env.DEV_STATE = "${config.git.root}/.devenv-state/${pkgs.stdenv.hostPlatform.system}";
  env.npm_config_cache = "${config.env.DEV_STATE}/npm-cache";
  env.BUNDLE_PATH = lib.mkForce "${config.env.DEV_STATE}/blog/${builtins.baseNameOf config.languages.ruby.package.outPath}/bundle";
  env.BUNDLE_FROZEN = "true";
}
