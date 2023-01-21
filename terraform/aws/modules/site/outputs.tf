output "distribution_id" {
  value       = aws_cloudfront_distribution.distribution.id
  description = "The CloudFront distribution ID"
}

output "access_key" {
  value       = aws_iam_access_key.access_key
  description = "Access key for the deploy user assosiated with the site"
}
