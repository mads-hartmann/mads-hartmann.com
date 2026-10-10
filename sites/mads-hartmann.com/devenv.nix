{ lib, config, ... }:
{
  languages.javascript = {
    enable = true;
    npm.enable = true;
  };
  env.HOMEPAGE_PORT = lib.mkDefault "8080";
  tasks."homepage:build" = {
    cwd = config.git.root;
    exec = "scripts/build.sh homepage";
  };
  processes.homepage = {
    cwd = config.git.root;
    exec = ''
      scripts/build.sh homepage &&
        exec python3 -m http.server "$HOMEPAGE_PORT" --bind 127.0.0.1 --directory .build/homepage
    '';
    watch.paths = [ ./src ../shared/header ../../routing ../../scripts/build-routing.mjs ../../scripts/build-homepage.mjs ];
    ready.http.get.port = lib.toInt config.env.HOMEPAGE_PORT;
    ready.period = 1;
  };
}
