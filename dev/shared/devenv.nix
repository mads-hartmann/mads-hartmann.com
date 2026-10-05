{ pkgs, lib, config, ... }:
let bootstrap = import ../bootstrap.nix;
in
{
  packages = with pkgs; [ bashInteractive curl direnv gawk git jq python3 ];
  env.DEV_REPO_ROOT = config.git.root;
  env.DEV_STATE = "${config.git.root}/.devenv-state/${pkgs.stdenv.hostPlatform.system}";
  env.npm_config_cache = "${config.env.DEV_STATE}/npm-cache";
  assertions = [{
    assertion = builtins.head (lib.splitString "+" config.devenv.cli.version) == bootstrap.devenvVersion;
    message = "This repository uses devenv ${bootstrap.devenvVersion}. Run scripts/bootstrap-dev.sh to install the pinned CLI.";
  }];
  profiles.kubernetes.module.packages = with pkgs; [ kubectl kubectx stern ];
}
