{ pkgs, ... }:
{
  # TODO: The eventmachine gem is failing to install, to reporduce:
  #       devenv shell
  #       bundle install
  # Haven't figured out why yet.
  packages = [
    # pkgs.ruby_3_1
    # pkgs.openssl_1_1
    # pkgs.zlib
    # pkgs.gnumake
    # pkgs.gcc
  ];
  # languages.nix.enable = true;
  languages.ruby.enable = true;
  processes = {
    serve.exec = "bundle install && bundle exec jekyll serve --watch --drafts --source src";
  };
}
