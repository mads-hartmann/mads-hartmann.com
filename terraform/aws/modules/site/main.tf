locals {
  # Origin ID for the CloudFront distribution.
  s3_origin_id = "site-${var.domain}"

  # Some attributes can't have . in the name, so in those cases we'll use this instead. Example:
  #
  #   example.mads-hartmann.com
  #
  # becomes:
  #
  #   example-mads-hartmann-com
  #
  hyphened_domain = replace(var.domain, ".", "-")

  # Path to zip files for the lambda@edge functions.
  lambda_origin_request_zip_path  = "${path.module}/lambda/origin-request.js.zip"
  lambda_origin_response_zip_path = "${path.module}/lambda/origin-response.js.zip"

  # Common tags to apply to resources - useful for grouping expenses in the cost explorer.
  tags = {
    Name    = var.domain
    Project = var.domain
  }
}

#
# S3 bucket for hosting the static files
#

resource "aws_s3_bucket" "bucket" {
  bucket = var.domain
  acl    = "private"

  tags = local.tags

  # We don't need versioning - the contents of the bucket are already
  # stored in git, so adding versioning just adds extra cost and complexity.
  versioning {
    enabled = false
  }
}

#
# Ensure the bucket it completely private.
#
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket = aws_s3_bucket.bucket.id

  # Disallow updating the ACLs to public for the bucket or objects in it
  block_public_acls = true

  # If the bucket or any objects in it were already public, disallow public access anyway.
  ignore_public_acls = true

  # Disallow setting the bucket policy if the specified bucket policy allows public access
  block_public_policy = true

  # Even if the bucket is public, only allow access to it from AWS service principals and
  # authorized users
  restrict_public_buckets = true
}

# Give our CloudFront distribution access using an origin access identity
# which we give read-only access to the bucket below
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = data.aws_iam_policy_document.readonly.json
}

data "aws_iam_policy_document" "readonly" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.bucket.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

#
# CloudFront distribution for caching
#

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "Read-only access to the S3 bucket from CloudFront"
}

resource "aws_cloudfront_distribution" "distribution" {

  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = local.s3_origin_id
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  # Use the firewell we've created if enable_waf is set to true
  web_acl_id = var.enable_waf ? aws_wafv2_web_acl.web_acl[0].arn : null

  enabled         = true
  is_ipv6_enabled = true

  comment = "Distribution for ${var.domain}"

  tags = local.tags

  # CloudFront assigns a domain name to each distribution, such as d111111abcdef8.cloudfront.net
  # If you want to use a custom domain like example.mads-hartmann.com you have let CloudFront know
  # which ones.
  #
  # You still have to create the DNS record, this just tells CloudFront what domain you expect
  # to use.
  #
  # See official docs for more information:
  # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/CNAMEs.html
  #
  aliases = [var.domain]

  # No restrictions - the site should be available everywhere
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # For requests to the root of the URL, e.g.
  #
  # example.mads-hartmann.com/
  #
  # we return the contents of
  #
  # example.mads-hartmann/index.html
  #
  # This doesn't apply to subdirectories, e.g.
  #
  # example.mads-hartmann.com/subdirectory
  #
  # Does _not_ serve the contents of
  #
  # example.mads-hartmann.com/subdirectory/index.html
  #
  # To make that work, we use the Lambda@edge, see the lambda_function_association below.
  #
  default_root_object = "index.html"


  # Show a custom 403 page
  #
  # If the WAF blocks a request we want to show a custom 403 page.
  #
  # This can be triggered by not sending a user-agent: curl --user-agent '' https://example.mads-hartmann.com
  #
  # TODO: This assumes that there is a 403.html page in the bucket, so perhaps
  #       we should make this an input variable instead.
  custom_error_response {
    error_code            = 403
    response_code         = 403
    error_caching_min_ttl = 0
    response_page_path    = "/403.html"
  }

  # Show a custom 404 page
  #
  # TODO: This assumes that there is a 404.html page in the bucket, so perhaps
  #       we should make this an input variable instead.
  custom_error_response {
    error_code            = 404
    response_code         = 404
    error_caching_min_ttl = 0
    response_page_path    = "/404.html"
  }

  default_cache_behavior {
    # As were just serving static content, there's no reason to allow
    # DELETE, PUT, POST, PATCH
    allowed_methods = ["GET", "HEAD", "OPTIONS"]

    # We only cache GET and HEAD
    cached_methods = ["GET", "HEAD"]

    target_origin_id = local.s3_origin_id

    # Invoke the lambda function before CloudFront forwards requests to the origin (origin-request)
    # The lambda takes care of re-writing requests to use /index.html for subdirectories.
    lambda_function_association {
      event_type   = "origin-request"
      lambda_arn   = aws_lambda_function.origin_request.qualified_arn
      include_body = false
    }

    # Invoke the lambda function after CloudFront has gotten a response from the origin (origin-response)
    # The lambda takes care of turning 403s into 404s. S3 will return 403 if the object doesn't exist.
    lambda_function_association {
      event_type   = "origin-response"
      lambda_arn   = aws_lambda_function.origin_response.qualified_arn
      include_body = false
    }

    forwarded_values {
      # Don't forward query strings to the origin.
      # As this distribution is just serving static sites we don't need the query string.
      # Leaving it out means people can't bust the cache by appending query strings to requests.
      query_string = false

      cookies {
        # Same for cookies
        forward = "none"
      }
    }

    # I use HTTPS for all my sites.
    viewer_protocol_policy = "redirect-to-https"

    # Setting the TTL for the distribtuion.
    #
    # I have explictily set the TTL to be the default values that CloudFront uses.
    # I have put them in explicitly as you might wan to temporarily set all of
    # them to 0 if you're debugging the Lambda@Edge function.
    #
    # The TTL can be configured for individual objects by setting `cache-control` and `expires`
    # when uploading files to the bucket. If you don't specify one it will use default_ttf. If
    # you do specify one CloudFront will override with the min/max below if you don't stay within
    # the range.
    #
    min_ttl     = 0        # 0 seconds
    default_ttl = 86400    # 1 day
    max_ttl     = 31536000 # 1 year
  }

  # Enable all edge locations.
  # My sites are so low traffic that this really won't make a difference in my bill
  price_class = "PriceClass_All"

  # Use the SSL certificate provided.
  viewer_certificate {
    acm_certificate_arn = var.acm_certificate_arn
    # Only accept HTTPS connections from viewers that support SNI (server name indication)
    # This is recommended by AWS.
    ssl_support_method = "sni-only"
  }
}

#
# Routing - Lambda
#

# Create an IAM role and grant Lambda and Lambda@Edge the permission to
# assume the role.
resource "aws_iam_role" "lambda" {
  name        = "${local.hyphened_domain}-lambda-role"
  description = "Role for ${local.hyphened_domain}"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "edgelambda.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

# Assign policies to the role.
resource "aws_iam_role_policy" "log_policy" {
  name = "${local.hyphened_domain}-lambda-log-policy"
  role = aws_iam_role.lambda.id

  #
  # For the log groups:
  # In a nutshell, these are the permissions that the function needs to create the necessary
  # CloudWatch log group and log stream, and to put the log events so that the function is
  # able to write logs when it executes.
  #
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:CreateLogGroup"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

# Create a zip archive for the lambda source code
data "archive_file" "origin_request_lambda" {
  type        = "zip"
  output_path = local.lambda_origin_request_zip_path
  source_file = "${path.module}/lambda/origin-request.js"
}

data "archive_file" "origin_response_lambda" {
  type        = "zip"
  output_path = local.lambda_origin_response_zip_path
  source_file = "${path.module}/lambda/origin-response.js"
}

# Create the origin-request lambda@edge function.
resource "aws_lambda_function" "origin_request" {
  filename         = local.lambda_origin_request_zip_path
  source_code_hash = data.archive_file.origin_request_lambda.output_base64sha256

  function_name = "${local.hyphened_domain}-origin-request"
  handler       = "origin-request.handler"

  # The role we want to Lambda to assume (its execution role)
  role = aws_iam_role.lambda.arn

  # It seems that CloudFront needs the lambda to be versioned.
  publish = true

  runtime = "nodejs12.x"

  tags = local.tags
}

# Create the origin-response lambda@edge function.
resource "aws_lambda_function" "origin_response" {
  filename         = local.lambda_origin_response_zip_path
  source_code_hash = data.archive_file.origin_response_lambda.output_base64sha256

  function_name = "${local.hyphened_domain}-origin-response"
  handler       = "origin-response.handler"

  # The role we want to Lambda to assume (its execution role)
  role = aws_iam_role.lambda.arn

  # It seems that CloudFront needs the lambda to be versioned.
  publish = true

  runtime = "nodejs12.x"

  tags = local.tags
}

#
# Firewall - WAF
#

resource "aws_wafv2_web_acl" "web_acl" {
  count = var.enable_waf ? 1 : 0
  name        = local.hyphened_domain
  description = "WAF for ${var.domain}"
  scope       = "CLOUDFRONT"

  # By default we want to allow all requests
  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WAF-${local.hyphened_domain}"
    sampled_requests_enabled   = true
  }

  # Block IP addresses that have identified as malicious actors and bots by Amazon threat intelligence.
  #
  # > The Amazon IP reputation list rule group contains rules that are based on Amazon internal
  # > threat intelligence. This is useful if you would like to block IP addresses typically
  # > associated with bots or other threats.
  #
  # https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html#aws-managed-rule-groups-ip-rep
  #
  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.hyphened_domain}-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  # Block common explots:
  #
  # > The 'Core rule set (CRS)' rule group contains rules that are generally applicable to web applications.
  # > This provides protection against exploitation of a wide range of vulnerabilities, including high risk and
  # > commonly occurring vulnerabilities described in OWASP publications.
  #
  # https://docs.aws.amazon.com/waf/latest/developerguide/aws-managed-rule-groups-list.html#aws-managed-rule-groups-baseline
  #
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 2

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.hyphened_domain}-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  # Block any IP that sends more than 600 requests per 5 minutes (2 req/sec) for a proloned duration
  # (TODO: How long do you have to keep sending them for it to block?)
  #
  # This only counts request where the x-forwarded-for header isn't set. This is to avoid
  # accidentially blocking requests that are coming from a proxy.
  #
  # We have a seaprate rule for blocking based on x-forwarded-for below.
  #
  rule {
    name     = "rate-limit-src-ip-600"
    priority = 3

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 600
        aggregate_key_type = "IP"
        scope_down_statement {
          not_statement {
            statement {
              size_constraint_statement {
                comparison_operator = "GT"
                size                = 0
                field_to_match {
                  single_header {
                    name = "x-forwarded-for"
                  }
                }
                text_transformation {
                  priority = 0
                  type     = "NONE"
                }
              }
            }
          }
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.hyphened_domain}-rate-limit-src-ip-600"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "rate-limit-xff-ip-600"
    priority = 4

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 600
        aggregate_key_type = "FORWARDED_IP"
        forwarded_ip_config {
          header_name       = "X-Forwarded-For"
          fallback_behavior = "MATCH"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${local.hyphened_domain}-rate-limit-xff-ip-600"
      sampled_requests_enabled   = true
    }
  }

}

#
# DNS - Route53
#

resource "aws_route53_record" "records" {

  for_each = toset(["A", "AAAA"])

  zone_id = var.route53_zone_id
  name    = var.domain
  type    = each.value

  # We're using an alias record which are like CNAME records, but they can be
  # assigned to top-level domains like mads-hartmann.com
  #
  # See official docs for more information
  # https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/resource-record-sets-choosing-alias-non-alias.html
  #
  alias {
    name    = aws_cloudfront_distribution.distribution.domain_name
    zone_id = aws_cloudfront_distribution.distribution.hosted_zone_id

    # We're using Simple Routing, e.g. not weighted, failover, geolocation or any
    # of the more advanced features, so we don't need to evaluate the target health.
    evaluate_target_health = false
  }
}

#
# IAM User for scripting deploys
#
# The user is granted permissions to create/update and delete objects in the bucket
# and invalidate the CloudFront cache.
#
# ListBucket is needed when you use the sync command.
#

resource "aws_iam_user" "deploy" {
  name = "${local.hyphened_domain}-deploy"
  tags = local.tags
}

resource "aws_iam_user_policy" "policy" {
  name = "${local.hyphened_domain}-policy"
  user = aws_iam_user.deploy.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.bucket.arn}/*"
    },
    {
      "Action": [
        "s3:ListBucket"
      ],
      "Effect": "Allow",
      "Resource": "${aws_s3_bucket.bucket.arn}"
    },
    {
      "Action": [
        "cloudfront:CreateInvalidation"
      ],
      "Effect": "Allow",
      "Resource": "${aws_cloudfront_distribution.distribution.arn}"
    }
  ]
}
EOF
}

# Generate an access key for the user so we get programmatic access.
resource "aws_iam_access_key" "access_key" {
  user = aws_iam_user.deploy.name
}
