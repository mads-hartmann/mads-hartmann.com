{ pkgs, lib, config, ... }:
{
  imports = [ ../../dev/modules/node.nix ../../dev/modules/ruby.nix ];
  packages = [ pkgs.watchexec ];
  env.BLOG_PORT = lib.mkDefault "4000";
  tasks."blog:setup" = {
    cwd = config.git.root;
    before = [ "devenv:enterShell" ];
    status = "python3 dev/scripts/setup.py blog --check";
    exec = "python3 dev/scripts/setup.py blog";
  };
  tasks."blog:build" = {
    cwd = config.git.root;
    after = [ "blog:setup" ];
    exec = "scripts/build.sh blog";
  };
  processes.blog = {
    cwd = "${config.git.root}/sites/blog.mads-hartmann.com";
    after = [ "blog:setup" ];
    exec = ''
      watchexec --shell=none --restart --watch "$DEV_REPO_ROOT/sites/shared/header" -- \
        bundle exec jekyll serve --watch --drafts --source src \
        --destination "$DEV_REPO_ROOT/.build/blog-preview" --host 127.0.0.1 --port "$BLOG_PORT"
    '';
    ready.exec = "python3 ${lib.escapeShellArg "${config.git.root}/dev/scripts/check-server.py"} blog";
    ready.period = 1;
  };
}
