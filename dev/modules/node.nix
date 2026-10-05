{ pkgs, ... }:
let tools = import ../packages.nix { inherit pkgs; };
in { packages = [ tools.node ]; }
