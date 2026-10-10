{ pkgs, config, ... }:
{
  packages = with pkgs; [ bashInteractive curl direnv gawk git jq python3 ];
  env.DEV_REPO_ROOT = config.git.root;
  env.DEV_STATE = "${config.git.root}/.devenv-state/${pkgs.stdenv.hostPlatform.system}";
  env.npm_config_cache = "${config.env.DEV_STATE}/npm-cache";
  languages.javascript.package = pkgs.nodejs_24;
  tasks."markdown:setup" = {
    cwd = config.git.root;
    before = [ "devenv:enterShell" ];
    execIfModified = map (path: "${config.git.root}/${path}") [ "package.json" "package-lock.json" "node_modules" ];
    exec = "npm ci --ignore-scripts --no-audit --no-fund";
  };
  profiles.kubernetes.module.packages = with pkgs; [ kubectl kubectx stern ];
}
