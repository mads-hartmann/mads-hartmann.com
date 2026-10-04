# Preserve ownership if an earlier version of the kernel was already imported/applied.
moved {
  from = github_branch_default.master
  to   = github_branch_default.main
}
moved {
  from = github_repository_environment_deployment_policy.master
  to   = github_repository_environment_deployment_policy.main
}
moved {
  from = github_repository_ruleset.master
  to   = github_repository_ruleset.main
}
