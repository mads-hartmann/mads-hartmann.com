mock_provider "aws" {}
mock_provider "github" {}

run "traffic_boundaries" {
  command = apply

  assert {
    condition = alltrue([for stack, policy in aws_iam_role_policy.traffic_apply :
      alltrue([for statement in jsondecode(policy.policy).Statement :
        !contains(statement.Action, "logs:PutResourcePolicy") && !contains(statement.Action, "logs:DeleteResourcePolicy") &&
        (!contains(statement.Action, "logs:DeleteDelivery") || try(statement.Condition.StringEquals["aws:ResourceTag/Stack"], "") == stack) &&
        (!contains(statement.Action, "logs:PutDeliveryDestination") || try(statement.Condition.ArnEquals["logs:DeliveryDestinationResourceArn"], "") == "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${stack}-access") &&
        (!contains(statement.Action, "cloudfront:AllowVendedLogDeliveryForResource") || try(statement.Condition.StringEquals["aws:ResourceTag/Stack"], "") == stack) &&
        (!contains(statement.Action, "logs:CreateDelivery") || (
          try(statement.Condition.StringEquals["aws:RequestTag/Stack"], "") == stack &&
          toset(statement.Resource) == toset([
            "arn:aws:logs:us-east-1:${var.account_id}:delivery:*",
            "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${stack}",
            "arn:aws:logs:us-east-1:${var.account_id}:delivery-destination:mads-sites-${stack}",
          ])
        ))
      ])
    ])
    error_message = "CI may configure delivery only for its own site and log destination, with no account-wide log resource policy administration."
  }
  assert {
    condition = alltrue([for statement in jsondecode(aws_cloudwatch_log_resource_policy.traffic.policy_document).Statement :
      statement.Principal.Service == "delivery.logs.amazonaws.com" &&
      statement.Condition.StringEquals["aws:SourceAccount"] == var.account_id &&
      anytrue([for stack in keys(var.site_buckets) :
        statement.Resource == "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${stack}-access:log-stream:*" &&
        statement.Condition.ArnLike["aws:SourceArn"] == "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${stack}"
      ])
    ])
    error_message = "The kernel policy must allow only AWS log delivery from this account's site sources to their matching log groups."
  }
  assert {
    condition = alltrue([for key, identity in local.identities :
      length(aws_iam_role_policy.state[key].policy) + length(aws_iam_role_policy.read[key].policy) + length(aws_iam_role_policy.traffic_read[key].policy) + (
        identity.mode != "apply" ? 0 : identity.stack == "shared" ?
        length(aws_iam_role_policy.shared_apply.policy) + length(aws_iam_role_policy.traffic_dashboard_apply.policy) :
        length(aws_iam_role_policy.site_apply[identity.stack].policy) + length(aws_iam_role_policy.traffic_apply[identity.stack].policy)
      ) <= 10240
    ])
    error_message = "All inline policies on each role must fit IAM's aggregate 10,240-character limit."
  }
}
