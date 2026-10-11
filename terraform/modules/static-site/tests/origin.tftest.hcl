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
  certificate_arn = "arn:aws:acm:us-east-1:790804032123:certificate/ab1542c8-a6eb-43dd-a1ca-2d624c27efba"
  content_dir     = "../../../.build/homepage"
  routing_file    = "../../../.build/routing/homepage.js"
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
    condition     = one(aws_cloudfront_distribution.distribution.origin).origin_access_control_id == aws_cloudfront_origin_access_control.site.id && length(one(aws_cloudfront_distribution.distribution.origin).s3_origin_config) == 0
    error_message = "The distribution must use its signed origin access control."
  }
  assert {
    condition     = length(jsondecode(aws_s3_bucket_policy.policy.policy).Statement) == 3 && jsondecode(aws_s3_bucket_policy.policy.policy).Statement[0].Principal.Service == "cloudfront.amazonaws.com" && jsondecode(aws_s3_bucket_policy.policy.policy).Statement[0].Condition.StringEquals["AWS:SourceArn"] == aws_cloudfront_distribution.distribution.arn
    error_message = "Only this CloudFront distribution may read site objects."
  }
  assert {
    condition     = length(aws_route53_record.records) == length(var.domains) * 2 && toset([for record in aws_route53_record.records : record.type]) == toset(["A", "AAAA"])
    error_message = "Every site domain must have both IPv4 and IPv6 aliases."
  }
  assert {
    condition     = length(aws_s3_object.pages) == 1 && length(aws_s3_object.assets) == 2 && aws_s3_object.assets["index.md"].content_type == "text/markdown; charset=utf-8" && aws_s3_object.assets["llms.txt"].content_type == "text/plain; charset=utf-8"
    error_message = "Upload the homepage and its Markdown and llms.txt representations with correct content types."
  }
  assert {
    condition     = alltrue([for header in one(aws_cloudfront_response_headers_policy.site.custom_headers_config).items : header.override && (header.header == "Vary" ? header.value == "Accept, Accept-Encoding" : header.header == "Link" && header.value == "</llms.txt>; rel=\"describedby\"; type=\"text/plain\"")])
    error_message = "Caches must distinguish negotiated formats, and all responses must advertise llms.txt."
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
run "reject_missing_build" {
  command = plan
  variables { content_dir = "../../../.build/missing-site" }
  expect_failures = [aws_s3_bucket.bucket]
}
