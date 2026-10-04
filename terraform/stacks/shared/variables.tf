variable "account_id" { type = string }
variable "region" { type = string }

variable "certificate_domain" {
  type    = string
  default = "mads-hartmann.com"
}
variable "certificate_alternative_names" {
  type    = set(string)
  default = ["*.mads-hartmann.com"]
}
