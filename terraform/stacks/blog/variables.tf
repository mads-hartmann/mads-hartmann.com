variable "account_id" { type = string }
variable "region" { type = string }

variable "zone_id" { type = string }
variable "certificate_arn" { type = string }
variable "bucket_name" {
  type    = string
  default = "blog.mads-hartmann.com"
}
variable "publish_dns" {
  type    = bool
  default = true
}
variable "legacy_oai_arn" {
  type        = string
  default     = null
  description = "Keep the old OAI allowed until the imported distribution has fully deployed OAC."
}

variable "use_oac" {
  type        = bool
  default     = true
  description = "Set false for the first adoption apply, with legacy_oai_arn set, then switch to true."
}
