let
  nixpkgs = import <nixpkgs> {};
in
nixpkgs.mkShell {
  nativeBuildInputs = [
    nixpkgs.nodejs
  ];
}