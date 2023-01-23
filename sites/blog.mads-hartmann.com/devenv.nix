{ pkgs, ... }:
let 
  gems = pkgs.bundlerEnv {
    name = "gems-for-blog";
    gemdir = ./.;
    ruby = pkgs.ruby_3_1;
    # For reasons beyond my understanding Nix couldn't build sass-embedded
    # as it got certificate issues.
    # 
    # The fix below instructs bundlerEnv to add cacert as a dependency when
    # building the sass-embedded package.
    #
    # The full list of gems that are part of defaultGemConfig can be found here:
    # https://github.com/NixOS/nixpkgs/blob/master/pkgs/development/ruby-modules/gem-config/default.nix
    #
    # I also tried adding pkgs.cacert to pacakges below, but those packages are just for
    # my devenv environment, and won't affect the environment used to build the gems (afaik)
    # 
    # Setting export NIX_SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt in my shell also didn't
    # change anything.
    #
    # These two issues seems related:
    #
    #   https://github.com/NixOS/nixpkgs/issues/66716
    #   https://github.com/NixOS/nixpkgs/issues/3382
    #
    # There's probably a nicer way to fix this, but I couldn't find one.
    gemConfig = pkgs.defaultGemConfig // {
      sass-embedded = attrs: {
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
