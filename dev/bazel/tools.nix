# Nix owns tool versions and locked dependencies; source files stay in Bazel.
let
  pins = (builtins.fromJSON (builtins.readFile ../../devenv.yaml)).inputs;
  versions = import ../shared/versions.nix;
in {
  pkgs ? import ./nixpkgs.nix {
    system = builtins.currentSystem;
    config.allowUnfreePredicate = pkg: builtins.elem (pkgs.lib.getName pkg) [ "terraform" ];
  },
  ruby ? (builtins.getFlake pins.nixpkgs-ruby.url).lib.mkRuby {
    inherit pkgs;
    rubyVersion = versions.ruby;
  },
}:
let
  nodejs = pkgs.${versions.node};
  npm = root: pkgs.importNpmLock.buildNodeModules {
    inherit nodejs;
    npmRoot = root;
    derivationArgs.version = "0";
  };
  buildNpm = npm ../../scripts;
  blogNpm = npm ../../sites/blog.mads-hartmann.com;
  gems = pkgs.bundlerEnv {
    name = "blog-gems";
    inherit ruby;
    gemfile = ../../sites/blog.mads-hartmann.com/Gemfile;
    lockfile = ../../sites/blog.mads-hartmann.com/Gemfile.lock;
    gemset = ../../sites/blog.mads-hartmann.com/gemset.nix;
  };
  jekyll = pkgs.writeShellScriptBin "jekyll" ''
    export PATH=${pkgs.lib.makeBinPath [ nodejs pkgs.coreutils ]}
    unset BUNDLE_PATH BUNDLE_GEMFILE GEM_HOME GEM_PATH
    exec ${gems}/bin/jekyll "$@"
  '';
  # These small files are explicit Bazel inputs. Store paths encode the complete
  # runtime/dependency closures, so tool changes invalidate consuming actions.
  siteTools = name: modules: extra: pkgs.writeTextFile {
    name = "${name}-tools";
    destination = "/tool.json";
    text = builtins.toJSON ({
      node = "${nodejs}/bin/node";
      siteModules = "${modules}/node_modules";
      buildModules = "${buildNpm}/node_modules";
    } // extra);
  };
in {
  homepage = siteTools "homepage" (npm ../../sites/mads-hartmann.com) {};
  uses = siteTools "uses" (npm ../../sites/uses.mads-hartmann.com) {};
  computer = siteTools "computer" (npm ../../sites/computer.mads-hartmann.com) {};
  blog = siteTools "blog" blogNpm { jekyll = "${jekyll}/bin/jekyll"; };
  checks = siteTools "checks" buildNpm {
    path = pkgs.lib.makeBinPath [ pkgs.python3 pkgs.git pkgs.bash pkgs.coreutils pkgs.gnugrep pkgs.gnused ];
    python = "${pkgs.python3}/bin/python3";
  };
  node = pkgs.writeShellScriptBin "node" ''
    exec ${nodejs}/bin/node "$@"
  '';
  python = pkgs.writeShellScriptBin "python3" ''
    exec ${pkgs.python3}/bin/python3 "$@"
  '';
  actionlint = pkgs.writeShellScriptBin "actionlint" ''
    exec ${pkgs.actionlint}/bin/actionlint "$@"
  '';
  inherit gems jekyll blogNpm;
  bazel = pkgs.${versions.bazel};
}
