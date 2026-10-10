{ pkgs, lib, config, ... }:
{
  languages.javascript = {
    enable = true;
    npm.enable = true;
  };
  languages.ruby = {
    enable = true;
    version = "3.3.11";
    lsp.enable = false;
  };
  packages = with pkgs; [ libffi libyaml openssl zlib ];
  # Share frozen gems between root, blog, and infrastructure environments.
  env.BUNDLE_PATH = lib.mkForce "${config.env.DEV_STATE}/blog/${builtins.baseNameOf config.languages.ruby.package.outPath}/bundle";
  env.BUNDLE_FROZEN = "true";
  env.BLOG_PORT = lib.mkDefault "4000";
  tasks."blog:setup" = {
    cwd = "${config.git.root}/sites/blog.mads-hartmann.com";
    before = [ "devenv:enterShell" ];
    status = "bundle check";
    exec = ''
      gem install bundler --version "$(awk '/^BUNDLED WITH$/{getline; print $1}' Gemfile.lock)" --no-document
      # This gem has both mkmf and Rake extensions; Rake rejects Bundler's build flags.
      if [[ "$(< Gemfile.lock)" == *"    google-protobuf (3.25.2)"* ]] &&
        ! gem list --installed --exact google-protobuf --version 3.25.2 >/dev/null; then
        CONFIGURE_ARGS="''${CONFIGURE_ARGS:-} --with-cflags=-Wno-error=format-security" \
          gem install google-protobuf --version 3.25.2 --platform ruby --no-document
      fi
      bundle install
    '';
  };
  tasks."blog:build" = {
    cwd = config.git.root;
    after = [ "blog:setup" "markdown:setup" ];
    exec = "scripts/build.sh blog";
  };
  processes.blog = {
    cwd = "${config.git.root}/sites/blog.mads-hartmann.com";
    after = [ "blog:setup" ];
    exec = ''
      bundle exec jekyll serve --no-watch --disable-disk-cache --drafts --source src \
        --destination "$DEV_REPO_ROOT/.build/blog-preview" --host 127.0.0.1 --port "$BLOG_PORT"
    '';
    watch.paths = [ ./src ../shared/header ];
    ready.http.get.port = lib.toInt config.env.BLOG_PORT;
    ready.period = 1;
  };
}
