let
  source = builtins.readFile ./shared/devenv.yaml;
  inputs = (builtins.fromJSON source).inputs;
in {
  devenvVersion = "2.3.1";
  devenvRef = builtins.head (builtins.split "\\?" inputs.devenv.url);
  nixpkgsRef = inputs.nixpkgs.url;
  fingerprint = builtins.substring 0 16 (builtins.hashString "sha256" source);
}
