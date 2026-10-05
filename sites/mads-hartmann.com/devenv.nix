{ pkgs, lib, config, ... }:
{
  imports = [ ../../dev/modules/node.nix ];
  packages = [ pkgs.watchexec ];
  env.HOMEPAGE_PORT = lib.mkDefault "8080";
  tasks."homepage:build" = {
    cwd = config.git.root;
    exec = "scripts/build.sh homepage";
  };
  processes.homepage = {
    cwd = config.git.root;
    exec = ''
      watchexec --shell=none --restart --watch sites/mads-hartmann.com/src --watch sites/shared/header \
        --watch routing --watch scripts/build-routing.mjs --watch scripts/build-homepage.mjs -- \
        bash -c 'scripts/build.sh homepage && exec python3 -m http.server "$HOMEPAGE_PORT" --bind 127.0.0.1 --directory .build/homepage'
    '';
    ready.exec = "python3 ${lib.escapeShellArg "${config.git.root}/dev/scripts/check-server.py"} homepage";
    ready.period = 1;
  };
}
