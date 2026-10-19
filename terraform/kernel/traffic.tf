# Log resource policies are account-wide permission-management operations. Keep
# them in the manually applied kernel instead of granting that power to CI.
resource "aws_cloudwatch_log_resource_policy" "traffic" {
  region      = "us-east-1"
  policy_name = "mads-sites-traffic"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [for stack in sort(keys(var.site_buckets)) : {
      Sid       = "Delivery${title(stack)}"
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${stack}-access:log-stream:*"
      Condition = {
        StringEquals = { "aws:SourceAccount" = var.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${stack}" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "traffic_read" {
  for_each = local.identities
  name     = "InspectTrafficInfrastructure"
  role     = aws_iam_role.github[each.key].id
  policy = each.value.stack == "shared" ? jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["cloudwatch:GetDashboard"], Resource = "arn:aws:cloudwatch::${var.account_id}:dashboard/mads-sites-traffic" }
    ]
    }) : jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:DescribeLogGroups", "logs:DescribeResourcePolicies"], Resource = "*" },
      { Effect = "Allow", Action = ["logs:ListTagsForResource", "logs:GetDeliverySource", "logs:GetDeliveryDestination"], Resource = [
        "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${each.value.stack}-access",
        "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${each.value.stack}",
        "arn:aws:logs:us-east-1:${var.account_id}:delivery-destination:mads-sites-${each.value.stack}",
      ] },
      { Effect = "Allow", Action = ["logs:GetDelivery", "logs:ListTagsForResource"], Resource = "arn:aws:logs:us-east-1:${var.account_id}:delivery:*", Condition = { StringEquals = { "aws:ResourceTag/Stack" = each.value.stack } } },
    ]
  })
}

resource "aws_iam_role_policy" "traffic_apply" {
  for_each = var.site_buckets
  name     = "ManageTrafficInfrastructure"
  role     = aws_iam_role.github["${each.key}-apply"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:PutRetentionPolicy", "logs:DeleteRetentionPolicy", "logs:TagResource", "logs:UntagResource"], Resource = [
        "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${each.key}-access",
        "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${each.key}-access:*",
      ] },
      { Effect = "Allow", Action = ["cloudfront:AllowVendedLogDeliveryForResource"], Resource = "arn:aws:cloudfront::${var.account_id}:distribution/*", Condition = { StringEquals = { "aws:ResourceTag/Stack" = each.key } } },
      { Effect = "Allow", Action = ["logs:PutDeliverySource", "logs:DeleteDeliverySource"], Resource = "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${each.key}" },
      { Effect = "Allow", Action = ["logs:PutDeliveryDestination"], Resource = "arn:aws:logs:us-east-1:${var.account_id}:delivery-destination:mads-sites-${each.key}", Condition = { ArnEquals = { "logs:DeliveryDestinationResourceArn" = "arn:aws:logs:us-east-1:${var.account_id}:log-group:mads-sites-${each.key}-access" } } },
      { Effect = "Allow", Action = ["logs:DeleteDeliveryDestination"], Resource = "arn:aws:logs:us-east-1:${var.account_id}:delivery-destination:mads-sites-${each.key}" },
      { Effect = "Allow", Action = ["logs:CreateDelivery"], Resource = [
        "arn:aws:logs:us-east-1:${var.account_id}:delivery:*",
        "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${each.key}",
        "arn:aws:logs:us-east-1:${var.account_id}:delivery-destination:mads-sites-${each.key}",
      ], Condition = { StringEquals = { "aws:RequestTag/Stack" = each.key } } },
      { Effect = "Allow", Action = ["logs:UpdateDeliveryConfiguration", "logs:DeleteDelivery", "logs:TagResource", "logs:UntagResource"], Resource = "arn:aws:logs:us-east-1:${var.account_id}:delivery:*", Condition = { StringEquals = { "aws:ResourceTag/Stack" = each.key } } },
      # CreateDelivery authorizes initial tags before the delivery exists.
      { Effect = "Allow", Action = ["logs:TagResource"], Resource = "arn:aws:logs:us-east-1:${var.account_id}:delivery:*", Condition = {
        StringEquals         = { "aws:RequestTag/Stack" = each.key }
        StringEqualsIfExists = { "aws:ResourceTag/Stack" = each.key }
      } },
      { Effect = "Allow", Action = ["logs:TagResource", "logs:UntagResource"], Resource = [
        "arn:aws:logs:us-east-1:${var.account_id}:delivery-source:mads-sites-${each.key}",
        "arn:aws:logs:us-east-1:${var.account_id}:delivery-destination:mads-sites-${each.key}",
      ] },
    ]
  })
}

resource "aws_iam_role_policy" "traffic_dashboard_apply" {
  name = "ManageTrafficDashboard"
  role = aws_iam_role.github["shared-apply"].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["cloudwatch:PutDashboard", "cloudwatch:DeleteDashboards"]
      Resource = "arn:aws:cloudwatch::${var.account_id}:dashboard/mads-sites-traffic"
    }]
  })
}
