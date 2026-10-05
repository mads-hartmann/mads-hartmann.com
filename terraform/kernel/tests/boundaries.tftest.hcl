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
    condition     = alltrue([for name, policy in aws_iam_role_policy.state : jsondecode(policy.policy).Statement[1].Resource == "${aws_s3_bucket.state.arn}/stacks/${local.identities[name].stack}.tfstate" && jsondecode(policy.policy).Statement[2].Resource == "${aws_s3_bucket.state.arn}/stacks/${local.identities[name].stack}.tfstate.tflock"])
    error_message = "Every CI role must access only its own state object and lock."
  }
  assert {
    condition     = alltrue([for policy in aws_iam_role_policy.site_apply : jsondecode(policy.policy).Statement[6].Condition["ForAllValues:StringEquals"]["route53:ChangeResourceRecordSetsRecordTypes"] == ["A", "AAAA"]])
    error_message = "Site roles may manage only IPv4 and IPv6 DNS aliases."
  }
  assert {
    condition     = contains(jsondecode(aws_iam_role_policy.state["shared-apply"].policy).Statement[3].Action, "iam:*") && jsondecode(aws_iam_role_policy.state["shared-apply"].policy).Statement[3].Effect == "Deny"
    error_message = "CI must not administer IAM."
  }
  assert {
    condition     = github_repository_environment_deployment_policy.main.branch_pattern == "main" && github_actions_variable.deployment["TERRAFORM_DEPLOY_ENABLED"].value == "true"
    error_message = "Production deployment must be enabled and restricted to main."
  }
  assert {
    condition     = github_branch_default.main.branch == "main" && !github_branch_default.main.rename && !github_branch_default.main.wait_for_rename && length(github_repository_ruleset.main.conditions[0].ref_name[0].include) == 1 && one(github_repository_ruleset.main.conditions[0].ref_name[0].include) == "refs/heads/main"
    error_message = "The kernel must preserve main and protect it without renaming the branch."
  }
  assert {
    condition     = jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Action == "acm:RequestCertificate" && jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Condition.StringEquals["acm:ValidationMethod"] == "DNS" && jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Condition.StringEquals["aws:RequestTag/Stack"] == "shared" && jsondecode(aws_iam_role_policy.shared_apply.policy).Statement[3].Condition["ForAllValues:StringEquals"]["acm:DomainNames"] == ["mads-hartmann.com", "*.mads-hartmann.com"]
    error_message = "Shared CI may request only DNS-validated certificates for this domain."
  }
  # Check the IAM permissions AWS evaluates for tagged create calls, including
  # TagResource before a new resource has any existing Stack tag.
  assert {
    condition = alltrue(flatten([for stack, policy in aws_iam_role_policy.site_apply : [for action in ["cloudfront:CreateDistribution", "cloudfront:CreateFunction"] :
      anytrue([for statement in jsondecode(policy.policy).Statement :
        statement.Effect == "Allow" && contains(flatten([statement.Action]), action) && statement.Resource == "*" && try(statement.Condition.StringEquals["aws:RequestTag/Stack"], "") == stack
      ])
    ]]))
    error_message = "Each site's tagged distribution/function create call needs its IAM create action on Resource=* with its requested Stack tag."
  }
  assert {
    condition = alltrue([for stack, policy in aws_iam_role_policy.site_apply :
      anytrue([for statement in jsondecode(policy.policy).Statement :
        statement.Effect == "Allow" && contains(flatten([statement.Action]), "cloudfront:TagResource") && contains(flatten([statement.Resource]), "arn:aws:cloudfront::${var.account_id}:distribution/*") && contains(flatten([statement.Resource]), "arn:aws:cloudfront::${var.account_id}:function/mads-sites-${stack}") && try(statement.Condition.StringEquals["aws:RequestTag/Stack"], "") == stack && try(statement.Condition.StringEqualsIfExists["aws:ResourceTag/Stack"], "") == stack
      ])
    ])
    error_message = "Initial distribution/function tagging must work without an existing tag and must reject resources already tagged for another stack."
  }
  assert {
    condition = alltrue(flatten([for stack, policy in aws_iam_role_policy.site_apply : [for action in ["cloudfront:UpdateFunction", "cloudfront:PublishFunction", "cloudfront:DeleteFunction", "cloudfront:UntagResource"] :
      anytrue([for statement in jsondecode(policy.policy).Statement :
        statement.Effect == "Allow" && contains(flatten([statement.Action]), action) && statement.Resource == "arn:aws:cloudfront::${var.account_id}:function/mads-sites-${stack}" && try(statement.Condition.StringEquals["aws:ResourceTag/Stack"], "") == stack
      ])
    ]]))
    error_message = "Existing function mutations must stay restricted to the site's named and Stack-tagged function."
  }
}
