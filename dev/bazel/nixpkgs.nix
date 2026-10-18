# A pinned NIX_PATH entry for rules_nixpkgs; also usable directly by Nix.
args:
let pins = (builtins.fromJSON (builtins.readFile ../../devenv.yaml)).inputs;
in import (builtins.getFlake pins.nixpkgs.url).outPath args
