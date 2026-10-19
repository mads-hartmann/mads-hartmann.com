mock_provider "aws" {
  override_during = plan
  mock_resource "aws_cloudwatch_log_group" {
    defaults = { arn = "arn:aws:logs:us-east-1:790804032123:log-group:mads-sites-test-access" }
  }
  mock_resource "aws_cloudwatch_log_delivery_destination" {
    defaults = { arn = "arn:aws:logs:us-east-1:790804032123:delivery-destination:mads-sites-test" }
  }
  mock_resource "aws_s3_bucket" {
    override_during = plan
    defaults = {
      id                          = "test-site"
      arn                         = "arn:aws:s3:::test-site"
      bucket_regional_domain_name = "test-site.s3.eu-central-1.amazonaws.com"
    }
  }
  mock_resource "aws_cloudfront_origin_access_control" {
    override_during = plan
    defaults        = { id = "test-oac" }
  }
  mock_resource "aws_cloudfront_distribution" {
    override_during = plan
    defaults        = { arn = "arn:aws:cloudfront::790804032123:distribution/test" }
  }
  mock_resource "aws_cloudfront_function" {
    override_during = plan
    defaults        = { arn = "arn:aws:cloudfront::790804032123:function/mads-sites-test" }
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
  command = plan
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
    condition     = aws_s3_object.pages["index.html"].content_type == "text/html; charset=utf-8"
    error_message = "Upload the homepage as HTML."
  }
  assert {
    condition = alltrue([for file, content_type in {
      "index.md"    = "text/markdown; charset=utf-8"
      "llms.txt"    = "text/plain; charset=utf-8"
      "robots.txt"  = "text/plain; charset=utf-8"
      "sitemap.xml" = "application/xml; charset=utf-8"
    } : aws_s3_object.assets[file].content_type == content_type])
    error_message = "Upload the homepage's Markdown and discovery files with correct content types."
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
run "cache_contract" {
  command = plan
  variables {
    stack        = "blog"
    content_dir  = "../../../.build/blog"
    routing_file = "../../../.build/routing/blog.js"
  }
  assert {
    condition     = one(aws_cloudfront_distribution.distribution.default_cache_behavior).cache_policy_id == "658327ea-f89d-4fab-a63d-7e88639e58f6" && one(aws_cloudfront_distribution.distribution.default_cache_behavior).compress
    error_message = "Use the Brotli/gzip managed policy with compression enabled."
  }
  assert {
    condition     = alltrue([for object in aws_s3_object.pages : object.cache_control == "public,max-age=0,s-maxage=3600,must-revalidate"]) && alltrue([for object in aws_s3_object.assets : object.cache_control == "public,max-age=0,s-maxage=3600,must-revalidate"])
    error_message = "Mutable URLs must revalidate in browsers and have bounded CDN freshness."
  }
  assert {
    condition     = length(terraform_data.immutable_assets.input.files) > 0 && alltrue([for key, digest in terraform_data.immutable_assets.input.files : startswith(key, "_assets/${digest}/")]) && terraform_data.immutable_assets.input.cache_control == "public,max-age=31536000,immutable"
    error_message = "Only byte-verified fingerprinted assets can be published as immutable."
  }
}
run "traffic_logging" {
  command = plan
  assert {
    condition = (
      aws_cloudwatch_log_group.traffic.retention_in_days == 30 &&
      aws_cloudwatch_log_group.traffic.region == "us-east-1" &&
      aws_cloudwatch_log_group.traffic.log_group_class == "STANDARD" &&
      aws_cloudwatch_log_delivery_source.traffic.region == "us-east-1" &&
      aws_cloudwatch_log_delivery_destination.traffic.region == "us-east-1" &&
      aws_cloudwatch_log_delivery.traffic.region == "us-east-1" &&
      aws_cloudwatch_log_delivery_source.traffic.resource_arn == aws_cloudfront_distribution.distribution.arn &&
      aws_cloudwatch_log_delivery_source.traffic.log_type == "ACCESS_LOGS" &&
      aws_cloudwatch_log_delivery.traffic.delivery_source_name == aws_cloudwatch_log_delivery_source.traffic.name &&
      aws_cloudwatch_log_delivery.traffic.delivery_destination_arn == aws_cloudwatch_log_delivery_destination.traffic.arn &&
      aws_cloudwatch_log_delivery_destination.traffic.delivery_destination_configuration[0].destination_resource_arn == aws_cloudwatch_log_group.traffic.arn &&
      aws_cloudwatch_log_delivery_destination.traffic.output_format == "json"
    )
    error_message = "Every site must deliver JSON CloudFront access logs to its own 30-day Standard log group through us-east-1."
  }
  assert {
    condition = (
      length(setintersection(toset(aws_cloudwatch_log_delivery.traffic.record_fields), toset(["c-ip", "cs(Cookie)", "cs-uri-query", "cs(Referer)", "x-forwarded-for"]))) == 0 &&
      alltrue([for field in ["cs-method", "cs-uri-stem", "cs(User-Agent)", "sc-status", "sc-content-type", "x-host-header"] : contains(aws_cloudwatch_log_delivery.traffic.record_fields, field)]) &&
      aws_cloudwatch_log_delivery.traffic.tags.Stack == var.stack
    )
    error_message = "Traffic logs must support the dashboard without collecting IPs, cookies, query strings or referrers, and deliveries must carry their IAM isolation tag."
  }
}
run "reject_missing_build" {
  command = plan
  variables { content_dir = "../../../.build/missing-site" }
  expect_failures = [aws_s3_bucket.bucket]
}
