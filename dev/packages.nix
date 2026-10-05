{ pkgs }:
let
  ruby = if toString pkgs.ruby_3_3.version == "3.3.11" then pkgs.ruby_3_3 else
    (pkgs.mkRuby {
      version = pkgs.mkRubyVersion "3" "3" "11" "";
      hash = "sha256-WfD6+xpZoF3DdlEXrz+mjhU+tIJUcIVJ8yHB6eB416A=";
    }).override { docSupport = false; yjitSupport = false; };
  # Match Gemfile.lock instead of the package set's Bundler default.
  bundler = pkgs.buildRubyGem {
    inherit ruby;
    gemName = "bundler";
    version = "4.0.16";
    source.sha256 = "d6ca5dd440c24f9abce9844cf44cc8e18c6a553de65a47efb4544137af92c47d";
    dontPatchShebangs = true;
    postFixup = ''
      substituteInPlace "$out/bin/bundle" --replace-fail "activate_bin_path" "bin_path"
    '';
    meta.mainProgram = "bundle";
  };
  terraformArchive = {
    x86_64-linux = {
      platform = "linux_amd64";
      hash = "2bc2fcfff033265c9e02ca0351f01794eb122f62a9b2a49a3294b9e49eaab5e4";
    };
    aarch64-darwin = {
      platform = "darwin_arm64";
      hash = "ecdef65e24193d627f27c39baeda31295f08c938d8a3d4764f442fb916d4b7dc";
    };
  }.${pkgs.stdenv.hostPlatform.system} or
    (throw "The development environment supports x86_64-linux and aarch64-darwin.");
  # Official release archives; hashes are from HashiCorp's SHA256SUMS.
  terraform = pkgs.stdenvNoCC.mkDerivation {
    pname = "terraform";
    version = "1.16.5";
    src = pkgs.fetchurl {
      url = "https://releases.hashicorp.com/terraform/1.16.5/terraform_1.16.5_${terraformArchive.platform}.zip";
      sha256 = terraformArchive.hash;
    };
    nativeBuildInputs = [ pkgs.unzip ];
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/bin"
      unzip -j "$src" terraform -d "$out/bin"
      chmod +x "$out/bin/terraform"
      runHook postInstall
    '';
    meta = {
      mainProgram = "terraform";
      license = pkgs.lib.licenses.bsl11;
      platforms = [ "x86_64-linux" "aarch64-darwin" ];
    };
  };
in { inherit ruby bundler terraform; node = pkgs.nodejs_24; }
