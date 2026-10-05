variable "stack" { type = string }
variable "bucket_name" { type = string }
variable "domains" { type = set(string) }
variable "zone_id" { type = string }
variable "certificate_arn" { type = string }
variable "content_dir" { type = string }
variable "routing_file" { type = string }
