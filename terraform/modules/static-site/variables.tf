variable "stack" { type = string }
variable "bucket_name" { type = string }
variable "domains" { type = set(string) }
variable "zone_id" { type = string }
variable "certificate_arn" { type = string }
variable "content_dir" { type = string }
variable "routing_file" { type = string }
variable "publish_dns" { type = bool }
variable "legacy_oai_arn" { type = string }

variable "use_oac" {
  type        = bool
  default     = true
  description = "Set false for the first adoption apply, with legacy_oai_arn set, then switch to true."
}
