locals {
  files      = fileset(var.content_dir, "**")
  mime_types = { html = "text/html; charset=utf-8", md = "text/markdown; charset=utf-8", css = "text/css; charset=utf-8", js = "text/javascript; charset=utf-8", json = "application/json", xml = "application/xml; charset=utf-8", txt = "text/plain; charset=utf-8", png = "image/png", jpg = "image/jpeg", jpeg = "image/jpeg", gif = "image/gif", svg = "image/svg+xml", ico = "image/x-icon", webp = "image/webp", mp3 = "audio/mpeg", m4a = "audio/mp4", pdf = "application/pdf", woff = "font/woff", woff2 = "font/woff2" }
}
resource "aws_s3_bucket" "bucket" {
  bucket        = var.bucket_name
  force_destroy = false
  lifecycle {
    prevent_destroy = true
    precondition {
      condition     = alltrue([for file in ["index.html", "index.md", "llms.txt"] : fileexists("${var.content_dir}/${file}")])
      error_message = "Build this site before planning or applying Terraform."
    }
  }
}
resource "aws_s3_bucket_public_access_block" "public_access_block" {
  bucket                  = aws_s3_bucket.bucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "ownership" {
  bucket = aws_s3_bucket.bucket.id
  rule { object_ownership = "BucketOwnerEnforced" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "encryption" {
  bucket = aws_s3_bucket.bucket.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "mads-sites-${var.stack}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
resource "aws_cloudfront_function" "routing" {
  name    = "mads-sites-${var.stack}"
  runtime = "cloudfront-js-2.0"
  publish = true
  code    = file(var.routing_file)
}
resource "aws_cloudfront_response_headers_policy" "site" {
  name = "mads-sites-${var.stack}"
  custom_headers_config {
    items {
      header   = "Vary"
      value    = "Accept, Accept-Encoding"
      override = true
    }
    items {
      header   = "Link"
      value    = "</llms.txt>; rel=\"describedby\"; type=\"text/plain\""
      override = true
    }
  }
  security_headers_config {
    content_type_options { override = true }
    frame_options {
      frame_option = "DENY"
      override     = true
    }
    referrer_policy {
      referrer_policy = "strict-origin-when-cross-origin"
      override        = true
    }
    strict_transport_security {
      access_control_max_age_sec = 31536000
      override                   = true
    }
    dynamic "content_security_policy" {
      for_each = var.stack == "blog" ? [] : [1]
      content {
        content_security_policy = "default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'"
        override                = true
      }
    }
  }
}
resource "aws_cloudfront_distribution" "distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases             = var.domains
  price_class         = "PriceClass_All"
  wait_for_deployment = true
  origin {
    domain_name              = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id                = "site-${var.bucket_name}"
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }
  default_cache_behavior {
    target_origin_id           = "site-${var.bucket_name}"
    viewer_protocol_policy     = "redirect-to-https"
    allowed_methods            = ["GET", "HEAD"]
    cached_methods             = ["GET", "HEAD"]
    compress                   = true
    min_ttl                    = 0
    default_ttl                = 60
    max_ttl                    = 300
    response_headers_policy_id = aws_cloudfront_response_headers_policy.site.id
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.routing.arn
    }
  }
  dynamic "custom_error_response" {
    for_each = var.stack == "blog" ? [404] : []
    content {
      error_code            = 404
      response_code         = 404
      response_page_path    = "/404.html"
      error_caching_min_ttl = 0
    }
  }
  restrictions {
    geo_restriction { restriction_type = "none" }
  }
  viewer_certificate {
    acm_certificate_arn      = var.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }
  tags = { Stack = var.stack }
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_policy" "policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = ["s3:GetObject"], Resource = "${aws_s3_bucket.bucket.arn}/*", Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.distribution.arn } } },
    # List permission makes a missing object return 404 rather than masking real access failures as 403.
    { Effect = "Allow", Principal = { Service = "cloudfront.amazonaws.com" }, Action = ["s3:ListBucket"], Resource = aws_s3_bucket.bucket.arn, Condition = { StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.distribution.arn } } },
    { Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.bucket.arn, "${aws_s3_bucket.bucket.arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }
  ] })
  depends_on = [aws_s3_bucket_public_access_block.public_access_block]
}
resource "aws_s3_object" "assets" {
  for_each      = { for file in local.files : file => file if !endswith(file, ".html") }
  bucket        = aws_s3_bucket.bucket.id
  key           = each.key
  source        = "${var.content_dir}/${each.key}"
  source_hash   = filemd5("${var.content_dir}/${each.key}")
  content_type  = lookup(local.mime_types, element(reverse(split(".", each.key)), 0), "application/octet-stream")
  cache_control = "public,max-age=60,must-revalidate"
  depends_on    = [aws_s3_bucket_ownership_controls.ownership, aws_s3_bucket_policy.policy]
}
resource "aws_s3_object" "pages" {
  for_each      = { for file in local.files : file => file if endswith(file, ".html") }
  bucket        = aws_s3_bucket.bucket.id
  key           = each.key
  source        = "${var.content_dir}/${each.key}"
  source_hash   = filemd5("${var.content_dir}/${each.key}")
  content_type  = "text/html; charset=utf-8"
  cache_control = "public,max-age=60,must-revalidate"
  depends_on    = [aws_s3_object.assets, aws_s3_bucket_ownership_controls.ownership, aws_s3_bucket_policy.policy]
}
resource "aws_route53_record" "records" {
  for_each = { for pair in setproduct(var.domains, ["A", "AAAA"]) : "${pair[0]}-${pair[1]}" => pair }
  zone_id  = var.zone_id
  name     = each.value[0]
  type     = each.value[1]
  alias {
    name                   = aws_cloudfront_distribution.distribution.domain_name
    zone_id                = aws_cloudfront_distribution.distribution.hosted_zone_id
    evaluate_target_health = false
  }
  depends_on = [aws_s3_object.pages]
}
output "distribution_id" { value = aws_cloudfront_distribution.distribution.id }
output "distribution_domain" { value = aws_cloudfront_distribution.distribution.domain_name }
output "bucket_name" { value = aws_s3_bucket.bucket.bucket }
