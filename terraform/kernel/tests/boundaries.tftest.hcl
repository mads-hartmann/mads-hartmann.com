mock_provider "aws" {}
mock_provider "github" {}
run "kernel_boundaries" {
  command = apply
  assert {
    condition     = jsondecode(aws_iam_role.github["homepage-apply"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:mads-hartmann/mads-hartmann.com:environment:Production"
    error_message = "Apply must use the protected Production environment."
  }
  assert {
    condition     = jsondecode(aws_iam_role.github["blog-plan"].assume_role_policy).Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] == "repo:mads-hartmann/mads-hartmann.com:pull_request"
    error_message = "Plan must not use the apply identity."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.state["blog-plan"].policy).Statement[1].Action == ["s3:GetObject"]
    error_message = "Plan must not write state."
  }
  assert {
    condition     = endswith(jsondecode(aws_iam_role_policy.state["uses-apply"].policy).Statement[1].Resource, "/stacks/uses.tfstate")
    error_message = "A stack must write only its own state key."
  }
  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.state["shared-apply"].policy).Statement[3].Action, "iam:*") && jsondecode(aws_iam_role_policy.state["shared-apply"].policy).Statement[3].Effect == "Deny"
    error_message = "CI must not administer IAM."
  }
  assert {
    condition     = github_repository_environment_deployment_policy.master.branch_pattern == "master" && github_actions_variable.deployment["TERRAFORM_DEPLOY_ENABLED"].value == "false"
    error_message = "Deployment must be restricted to master and disabled until adoption."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Action == "acm:RequestCertificate" && jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Condition.StringEquals["acm:ValidationMethod"] == "DNS" && jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Condition.StringEquals["aws:RequestTag/Stack"] == "shared" && jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Condition["ForAllValues:StringEquals"]["acm:DomainNames"] == ["mads-hartmann.com", "*.mads-hartmann.com"]
    error_message = "Shared CI may request only DNS-validated certificates for this domain."
  }
}
