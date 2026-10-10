{ pkgs, config, ... }:
{
  packages = with pkgs; [ bashInteractive curl direnv gawk git jq python3 ];
  env.DEV_REPO_ROOT = config.git.root;
  env.DEV_STATE = "${config.git.root}/.devenv-state/${pkgs.stdenv.hostPlatform.system}";
  env.npm_config_cache = "${config.env.DEV_STATE}/npm-cache";
  languages.javascript.package = pkgs.nodejs_24;
  profiles.kubernetes.module.packages = with pkgs; [ kubectl kubectx stern ];
}
