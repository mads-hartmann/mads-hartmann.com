{ pkgs, lib, config, ... }:
{
  imports = [ ../../dev/modules/node.nix ];
  packages = [ pkgs.watchexec ];
  env.USES_PORT = lib.mkDefault "8081";
  tasks."uses:setup" = {
    cwd = config.git.root;
    before = [ "devenv:enterShell" ];
    status = "python3 dev/scripts/setup.py uses --check";
    exec = "python3 dev/scripts/setup.py uses";
  };
  tasks."uses:build" = {
    cwd = config.git.root;
    after = [ "uses:setup" ];
    exec = "scripts/build.sh uses";
  };
  processes.uses = {
    cwd = config.git.root;
    after = [ "uses:setup" ];
    exec = ''
      watchexec --shell=none --restart --watch sites/uses.mads-hartmann.com/index.md \
        --watch sites/shared/header \
        --watch sites/uses.mads-hartmann.com/build.mjs --watch sites/uses.mads-hartmann.com/package.json \
        --watch sites/uses.mads-hartmann.com/package-lock.json -- \
        bash -c 'python3 dev/scripts/setup.py uses && node sites/uses.mads-hartmann.com/build.mjs "$DEV_REPO_ROOT/.build/uses" && exec python3 -m http.server "$USES_PORT" --bind 127.0.0.1 --directory .build/uses'
    '';
    ready.exec = "python3 ${lib.escapeShellArg "${config.git.root}/dev/scripts/check-server.py"} uses";
    ready.period = 1;
  };
}
