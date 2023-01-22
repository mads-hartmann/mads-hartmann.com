{ pkgs, ... }:
let 
  gems = pkgs.bundlerEnv {
    name = "gems-for-blog";
    gemdir = ./.;
  };
in 
{
  packages = [
    pkgs.bundix
    gems
  ];
  languages.ruby.enable = true;
  processes = {
    serve.exec = "jekyll serve --watch --drafts --source src";
  };
}
