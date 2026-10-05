variable "account_id" { type = string }
variable "region" { type = string }

variable "zone_id" { type = string }
variable "certificate_arn" { type = string }
variable "bucket_name" {
  type    = string
  default = "blog.mads-hartmann.com"
}
