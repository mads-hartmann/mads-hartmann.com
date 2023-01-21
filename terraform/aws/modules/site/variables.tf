variable "domain" {
  type        = string
  description = "The fully qualified domain name"
}

variable "acm_certificate_arn" {
  type        = string
  description = "The ARN of the ACM managed SSL certificate to use"
}

variable "route53_zone_id" {
  type        = string
  description = "The Zone ID to create the DNS record in"
}

variable "enable_waf" {
  type = bool
  description = "If true it will create a WAF and associate it with the CF distribution"
}