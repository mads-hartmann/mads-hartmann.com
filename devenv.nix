{ config, lib, ... }:
{
  imports = [
    ./sites/mads-hartmann.com/devenv.nix
    ./sites/blog.mads-hartmann.com/devenv.nix
    ./sites/uses.mads-hartmann.com/devenv.nix
    ./dev/modules/terraform.nix
  ];
  tasks."repo:setup".after = [ "blog:setup" "uses:setup" ];
  tasks."repo:build" = {
    after = [ "repo:setup" ];
    cwd = config.git.root;
    exec = "scripts/build.sh";
    before = lib.optional config.devenv.isTesting "devenv:enterTest";
  };
  tasks."repo:check" = {
    showOutput = true;
    after = [ "repo:build" ];
    cwd = config.git.root;
    exec = ''
      node scripts/check-sites.mjs
      scripts/check-terraform.sh
      scripts/check-workflows.sh
    '';
  };
  enterTest = ''
    cd "$DEV_REPO_ROOT"
    node scripts/check-sites.mjs
    scripts/check-terraform.sh
    scripts/check-workflows.sh
  '';
}
