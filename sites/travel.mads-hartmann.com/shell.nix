let 
  nixpkgs = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/6e66e44c5e8d14da2fee7caf3aa60536c52e4d2b.tar.gz") { };
in
nixpkgs.mkShell {
  nativeBuildInputs = [
    nixpkgs.go
    nixpkgs.hugo
    nixpkgs.exiftool
  ];
}
