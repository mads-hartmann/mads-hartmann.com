{ pkgs, lib, config, ... }:
let
  tools = import ../packages.nix { inherit pkgs; };
  bundlePath = "${config.env.DEV_STATE}/blog/${builtins.baseNameOf tools.ruby.outPath}/bundle";
in {
  languages.ruby = {
    enable = true;
    package = tools.ruby;
    bundler.package = tools.bundler;
    lsp.enable = false;
  };
  # Native gems need a compiler and headers, rather than a full C IDE toolchain.
  languages.c.enable = false;
  packages = with pkgs; [ stdenv.cc gnumake pkg-config libffi libyaml openssl zlib ];
  env.BUNDLE_PATH = lib.mkForce bundlePath;
  env.GEM_HOME = lib.mkForce "${bundlePath}/ruby/3.3.0";
  env.BUNDLE_FROZEN = "true";
  env.BUNDLE_JOBS = "4";
  env.BUNDLE_RETRY = "2";
  # Locked protobuf 3.25.2 has format warnings that Nix promotes to errors.
  # Keep the warnings; limit the compatibility flag to this gem's compilation.
  env.DEV_PROTOBUF_CFLAGS = "--with-cflags=-Wno-error=format-security";
  env.BUNDLE_USER_HOME = "${config.env.DEV_STATE}/bundler-home";
  env.GEM_SPEC_CACHE = "${config.env.DEV_STATE}/gem-spec-cache";
}
