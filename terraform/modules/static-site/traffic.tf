# CloudFront standard logging v2 is configured through the us-east-1 Logs API,
# independently of the region hosting the site's S3 bucket.
resource "aws_cloudwatch_log_group" "traffic" {
  region            = "us-east-1"
  tags              = { Stack = var.stack }
  name              = "mads-sites-${var.stack}-access"
  retention_in_days = 30
  log_group_class   = "STANDARD"
}

resource "aws_cloudwatch_log_delivery_source" "traffic" {
  region       = "us-east-1"
  tags         = { Stack = var.stack }
  name         = "mads-sites-${var.stack}"
  log_type     = "ACCESS_LOGS"
  resource_arn = aws_cloudfront_distribution.distribution.arn
}

resource "aws_cloudwatch_log_delivery_destination" "traffic" {
  region        = "us-east-1"
  tags          = { Stack = var.stack }
  name          = "mads-sites-${var.stack}"
  output_format = "json"
  delivery_destination_configuration {
    destination_resource_arn = aws_cloudwatch_log_group.traffic.arn
  }
}

# The kernel installs the log-delivery resource policy before CI enables logging.
# Select only the fields used for traffic analysis; omit IPs, cookies, referrers
# and query strings. This covers cache hits as well as origin requests.
resource "aws_cloudwatch_log_delivery" "traffic" {
  region                   = "us-east-1"
  tags                     = { Stack = var.stack }
  delivery_source_name     = aws_cloudwatch_log_delivery_source.traffic.name
  delivery_destination_arn = aws_cloudwatch_log_delivery_destination.traffic.arn
  record_fields = [
    "date", "time", "cs-method", "x-host-header", "cs-uri-stem", "sc-status",
    "cs(User-Agent)", "sc-content-type", "sc-bytes", "time-taken", "x-edge-result-type",
  ]
}
