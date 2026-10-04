locals {
  stack      = "kernel"
  stacks     = toset(["shared", "homepage", "blog", "uses"])
  identities = { for item in setproduct(local.stacks, ["plan", "apply"]) : "${item[0]}-${item[1]}" => { stack = item[0], mode = item[1] } }
}
resource "aws_s3_bucket" "state" {
  bucket = var.state_bucket
  lifecycle { prevent_destroy = true }
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_policy" "state" {
  bucket = aws_s3_bucket.state.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.state.arn, "${aws_s3_bucket.state.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }] })
}
resource "aws_iam_openid_connect_provider" "github" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}
resource "aws_iam_role" "github" {
  for_each             = local.identities
  name                 = "mads-sites-${each.key}"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow", Action = "sts:AssumeRoleWithWebIdentity"
      Principal = { Federated = aws_iam_openid_connect_provider.github.arn }
      Condition = { StringEquals = {
        "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        "token.actions.githubusercontent.com:sub" = "${var.oidc_subject_prefix}:${each.value.mode == "apply" ? "environment:Production" : "pull_request"}"
      } }
    }]
  })
}
resource "aws_iam_role_policy" "state" {
  for_each = local.identities
  name     = "OwnStateOnly"
  role     = aws_iam_role.github[each.key].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["s3:ListBucket"], Resource = aws_s3_bucket.state.arn, Condition = { StringLike = { "s3:prefix" = ["stacks/${each.value.stack}.tfstate*", "workspaces/${each.value.stack}/*"] } } },
      { Effect = "Allow", Action = each.value.mode == "apply" ? ["s3:GetObject", "s3:PutObject"] : ["s3:GetObject"], Resource = "${aws_s3_bucket.state.arn}/stacks/${each.value.stack}.tfstate" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/stacks/${each.value.stack}.tfstate.tflock" },
      { Effect = "Deny", Action = ["iam:*", "organizations:*", "account:*"], Resource = "*" },
      { Effect = "Deny", Action = "s3:*", Resource = ["${aws_s3_bucket.state.arn}/kernel/*", "${aws_s3_bucket.state.arn}/production.tfstate"] },
      { Effect = "Deny", Action = ["s3:DeleteBucket", "s3:PutBucketPolicy", "s3:DeleteBucketPolicy", "s3:PutBucketVersioning", "s3:PutEncryptionConfiguration", "s3:PutBucketPublicAccessBlock", "s3:PutBucketAcl"], Resource = aws_s3_bucket.state.arn }
    ]
  })
}
# Plan identities can inspect production but cannot write infrastructure or another stack's state.
resource "aws_iam_role_policy" "read" {
  for_each = local.identities
  name     = "InspectInfrastructure"
  role     = aws_iam_role.github[each.key].id
  policy = jsonencode({ Version = "2012-10-17", Statement = concat([
    { Effect = "Allow", Action = ["cloudfront:Get*", "cloudfront:List*", "cloudfront:DescribeFunction", "acm:DescribeCertificate", "acm:GetCertificate", "acm:ListTagsForCertificate", "route53:GetHostedZone", "route53:ListResourceRecordSets", "route53:ListTagsForResource", "route53:GetChange"], Resource = "*" }
    ], each.value.stack == "shared" ? [] : [
    { Effect = "Allow", Action = ["s3:GetBucket*", "s3:GetEncryptionConfiguration", "s3:GetLifecycleConfiguration", "s3:GetAccelerateConfiguration", "s3:GetReplicationConfiguration", "s3:GetObject", "s3:GetObjectTagging", "s3:GetObjectAttributes", "s3:ListBucket", "s3:ListBucketVersions"], Resource = ["arn:aws:s3:::${lookup(var.site_buckets, each.value.stack, "unused")}", "arn:aws:s3:::${lookup(var.site_buckets, each.value.stack, "unused")}/*"] }
  ]) })
}
resource "aws_iam_role_policy" "site_apply" {
  for_each = var.site_buckets
  name     = "ManageSite"
  role     = aws_iam_role.github["${each.key}-apply"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["s3:CreateBucket", "s3:DeleteBucket", "s3:Get*", "s3:List*", "s3:PutBucket*", "s3:DeleteBucketPolicy", "s3:PutEncryptionConfiguration", "s3:PutObject", "s3:PutObjectTagging", "s3:DeleteObjectTagging", "s3:DeleteObject", "s3:PutBucketOwnershipControls", "s3:DeleteBucketOwnershipControls", "s3:PutBucketPublicAccessBlock", "s3:PutBucketTagging"], Resource = ["arn:aws:s3:::${each.value}", "arn:aws:s3:::${each.value}/*"] },
    { Effect = "Allow", Action = ["cloudfront:CreateDistributionWithTags"], Resource = "*", Condition = { StringEquals = { "aws:RequestTag/Stack" = each.key } } },
    { Effect = "Allow", Action = ["cloudfront:UpdateDistribution", "cloudfront:DeleteDistribution", "cloudfront:CreateInvalidation", "cloudfront:TagResource", "cloudfront:UntagResource"], Resource = "arn:aws:cloudfront::${var.account_id}:distribution/*", Condition = { StringEquals = { "aws:ResourceTag/Stack" = each.key } } },
    { Effect = "Allow", Action = ["cloudfront:CreateFunction", "cloudfront:UpdateFunction", "cloudfront:PublishFunction", "cloudfront:DeleteFunction"], Resource = "arn:aws:cloudfront::${var.account_id}:function/mads-sites-${each.key}" },
    # These CloudFront configuration APIs do not support tag-based isolation.
    { Effect = "Allow", Action = ["cloudfront:CreateOriginAccessControl", "cloudfront:UpdateOriginAccessControl", "cloudfront:DeleteOriginAccessControl", "cloudfront:CreateResponseHeadersPolicy", "cloudfront:UpdateResponseHeadersPolicy", "cloudfront:DeleteResponseHeadersPolicy"], Resource = "*" },
    { Effect = "Allow", Action = "route53:ChangeResourceRecordSets", Resource = "arn:aws:route53:::hostedzone/${var.zone_id}", Condition = { "ForAllValues:StringEquals" = {
      "route53:ChangeResourceRecordSetsNormalizedRecordNames" = each.key == "homepage" ? ["mads-hartmann.com", "www.mads-hartmann.com"] : ["${each.key}.mads-hartmann.com"]
      "route53:ChangeResourceRecordSetsRecordTypes"           = each.key == "homepage" ? ["A", "AAAA", "CNAME"] : ["A", "AAAA"]
    } } }
  ] })
}
resource "aws_iam_role_policy" "shared_apply" {
  name = "ManageSharedInfrastructure"
  role = aws_iam_role.github["shared-apply"].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["route53:UpdateHostedZoneComment", "route53:ChangeTagsForResource"], Resource = "arn:aws:route53:::hostedzone/${var.zone_id}" },
    { Effect = "Allow", Action = "route53:ChangeResourceRecordSets", Resource = "arn:aws:route53:::hostedzone/${var.zone_id}", Condition = { "ForAllValues:StringEquals" = { "route53:ChangeResourceRecordSetsRecordTypes" = ["CNAME"] }, "ForAllValues:StringLike" = { "route53:ChangeResourceRecordSetsNormalizedRecordNames" = ["_*.mads-hartmann.com"] } } },
    { Effect = "Allow", Action = ["acm:AddTagsToCertificate", "acm:RemoveTagsFromCertificate"], Resource = var.certificate_arn }
  ] })
}
resource "github_branch_default" "master" {
  repository      = var.github_repository
  branch          = "master"
  rename          = true
  wait_for_rename = true
}
resource "github_repository_environment" "production" {
  repository  = var.github_repository
  environment = "Production"
  deployment_branch_policy {
    protected_branches     = false
    custom_branch_policies = true
  }
}
resource "github_repository_environment_deployment_policy" "master" {
  repository     = var.github_repository
  environment    = github_repository_environment.production.environment
  branch_pattern = "master"
  depends_on     = [github_branch_default.master]
}
resource "github_repository_ruleset" "master" {
  repository  = var.github_repository
  name        = "master"
  target      = "branch"
  enforcement = "active"
  conditions {
    ref_name {
      include = ["refs/heads/master"]
      exclude = []
    }
  }
  rules {
    deletion         = true
    non_fast_forward = true
    pull_request { required_approving_review_count = 0 }
    required_status_checks {
      strict_required_status_checks_policy = true
      required_check { context = "Checks" }
    }
  }
  depends_on = [github_branch_default.master]
}
locals {
  github_variables = merge({
    AWS_ACCOUNT_ID           = var.account_id
    TF_STATE_BUCKET          = var.state_bucket
    TERRAFORM_DEPLOY_ENABLED = tostring(var.deploy_enabled)
  }, { for key, role in aws_iam_role.github : "AWS_ROLE_${upper(replace(key, "-", "_"))}" => role.arn })
}
resource "github_actions_variable" "deployment" {
  for_each      = local.github_variables
  repository    = var.github_repository
  variable_name = each.key
  value         = each.value
}
output "roles" { value = { for key, role in aws_iam_role.github : key => role.arn } }
