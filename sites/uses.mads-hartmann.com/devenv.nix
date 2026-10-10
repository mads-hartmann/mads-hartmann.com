{ lib, config, ... }:
let projectRoot = "${config.git.root}/sites/uses.mads-hartmann.com";
in
{
  languages.javascript = {
    enable = true;
    directory = projectRoot;
    npm.enable = true;
  };
  env.USES_PORT = lib.mkDefault "8081";
  tasks."uses:setup" = {
    cwd = projectRoot;
    before = [ "devenv:enterShell" ];
    execIfModified = map (path: "${projectRoot}/${path}") [ "package.json" "package-lock.json" "node_modules" ];
    exec = "npm ci --ignore-scripts --no-audit --no-fund";
  };
  tasks."uses:build" = {
    cwd = config.git.root;
    after = [ "uses:setup" "markdown:setup" ];
    exec = "scripts/build.sh uses";
  };
  processes.uses = {
    cwd = config.git.root;
    after = [ "uses:setup" "markdown:setup" ];
    exec = ''
      scripts/build.sh uses &&
        exec python3 -m http.server "$USES_PORT" --bind 127.0.0.1 --directory .build/uses
    '';
    watch.paths = [ ./index.md ../shared/header ./build.mjs ./package.json ./package-lock.json ../../scripts/build-markdown.mjs ];
    ready.http.get.port = lib.toInt config.env.USES_PORT;
    ready.period = 1;
  };
}
