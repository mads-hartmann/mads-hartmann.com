variable "account_id" { type = string }
variable "region" { type = string }

variable "github_owner" { type = string }
variable "github_repository" { type = string }
variable "state_bucket" { type = string }
variable "zone_id" { type = string }
variable "certificate_arn" { type = string }
variable "deploy_enabled" {
  type        = bool
  default     = true
  description = "Allow GitHub Actions to plan and deploy the sites. Set false to pause cloud workflows."
}
variable "oidc_subject_prefix" {
  type        = string
  default     = "repo:mads-hartmann/mads-hartmann.com"
  description = "Set to the actual GitHub OIDC subject prefix if immutable repository IDs are enabled."
}
variable "site_buckets" { type = map(string) }
