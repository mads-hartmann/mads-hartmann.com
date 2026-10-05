{ pkgs, ... }:
let tools = import ../packages.nix { inherit pkgs; };
in { packages = [ tools.terraform pkgs.actionlint ]; }
