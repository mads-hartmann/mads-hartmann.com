mock_provider "aws" {
  mock_resource "aws_cloudfront_function" {
    defaults = { arn = "arn:aws:cloudfront::790804032123:function/mads-sites-test" }
  }
}
variables {
  stack           = "homepage"
  bucket_name     = "mads-hartmann.com"
  domains         = ["mads-hartmann.com", "www.mads-hartmann.com"]
  zone_id         = "Z18NSONI21UYAE"
  certificate_arn = "arn:aws:acm:us-east-1:790804032123:certificate/344b3275-d3d8-4d12-81d3-eda18bf46967"
  content_dir     = "../../../.build/homepage"
  routing_file    = "../../../.build/routing/homepage.js"
  publish_dns     = true
  legacy_oai_arn  = null
}
run "private_origin" {
  command = apply
  assert {
    condition     = aws_s3_bucket_public_access_block.public_access_block.block_public_acls && aws_s3_bucket_public_access_block.public_access_block.block_public_policy && aws_s3_bucket_public_access_block.public_access_block.ignore_public_acls && aws_s3_bucket_public_access_block.public_access_block.restrict_public_buckets
    error_message = "The origin must block every form of public S3 access."
  }
  assert {
    condition     = aws_cloudfront_origin_access_control.site.signing_behavior == "always" && aws_cloudfront_origin_access_control.site.signing_protocol == "sigv4"
    error_message = "CloudFront must sign origin requests."
  }
  assert {
    condition     = length(aws_s3_object.pages) == 1 && length(aws_s3_object.assets) == 0
    error_message = "The homepage must upload exactly one HTML file."
  }
  assert {
    condition     = length(aws_cloudfront_distribution.distribution.custom_error_response) == 0
    error_message = "Do not turn access failures into successful homepage responses."
  }
  assert {
    condition     = jsondecode(aws_s3_bucket_policy.policy.policy).Statement[2].Effect == "Deny" && jsondecode(aws_s3_bucket_policy.policy.policy).Statement[2].Condition.Bool["aws:SecureTransport"] == "false"
    error_message = "The bucket must deny insecure transport."
  }
}
run "prepare_oac_without_breaking_oai" {
  command = apply
  variables {
    use_oac        = false
    legacy_oai_arn = "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ETEST"
  }
  assert {
    condition     = one(one(aws_cloudfront_distribution.distribution.origin).s3_origin_config).origin_access_identity == "origin-access-identity/cloudfront/ETEST"
    error_message = "The first migration apply must keep the old origin selected."
  }
  assert {
    condition     = length(jsondecode(aws_s3_bucket_policy.policy.policy).Statement) == 4 && jsondecode(aws_s3_bucket_policy.policy.policy).Statement[3].Principal.AWS == "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ETEST"
    error_message = "During transition the policy must grant both identities access."
  }
}
run "reject_missing_build" {
  command = plan
  variables { content_dir = "../../../.build/missing-site" }
  expect_failures = [aws_s3_bucket.bucket]
}
