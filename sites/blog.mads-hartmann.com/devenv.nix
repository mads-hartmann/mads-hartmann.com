{ pkgs, ... }:
let 
  gems = pkgs.bundlerEnv {
    name = "gems-for-blog";
    gemdir = ./.;
    ruby = pkgs.ruby_3_1;
    # This was a hard problem to figure out.
    # cacert is needed for bundix
    # For more context, see https://github.com/NixOS/nixpkgs/issues/66716#issuecomment-883399373
    # pkgs.cacert
    # Well that didn't fix it. Maybe I need to somehow tell Nix to use
    # export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    # but I have no idea how

    gemConfig = pkgs.defaultGemConfig // {
      sass-embedded = attrs: {
        # nativeBuildInputs = [ pkgs.cacert ];
        buildInputs = [ pkgs.cacert ];
      };
    };
  };
in 
{
  packages = [
    pkgs.bundix
    gems
  ];
  languages.ruby = {
    package = pkgs.ruby_3_1;
    enable = true;
  };
  processes = {
    serve.exec = "jekyll serve --watch --drafts --source src";
  };
}
