variable "account_id" { type = string }
variable "region" { type = string }

variable "certificate_domain" {
  type    = string
  default = "*.mads-hartmann.com"
}
variable "certificate_alternative_names" {
  type    = set(string)
  default = ["mads-hartmann.com"]
}
variable "legacy_certificate_validation_method" {
  type        = string
  default     = "EMAIL"
  description = "Match the imported certificate; new site certificates always use DNS."
  validation {
    condition     = contains(["EMAIL", "DNS"], var.legacy_certificate_validation_method)
    error_message = "The imported certificate must use EMAIL or DNS validation."
  }
}
