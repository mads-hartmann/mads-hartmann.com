let
  source = builtins.readFile ./shared/devenv.yaml;
  inputs = (builtins.fromJSON source).inputs;
in {
  devenvRef = builtins.head (builtins.split "\\?" inputs.devenv.url);
  nixpkgsRef = inputs.nixpkgs.url;
}
