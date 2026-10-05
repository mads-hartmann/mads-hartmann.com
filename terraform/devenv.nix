{ config, ... }:
{
  # The offline tests read site artifacts, so include their build prerequisites.
  imports = [ ../devenv.nix ];
  tasks."infra:check" = {
    cwd = config.git.root;
    after = [ "repo:build" ];
    exec = "scripts/check-terraform.sh";
  };
  processes.homepage.start.enable = false;
  processes.blog.start.enable = false;
  processes.uses.start.enable = false;
}
