variable "allow_legacy_apply" {
  type = bool
  default = false
}
resource "terraform_data" "retired" {
  lifecycle {
    precondition {
      condition = var.allow_legacy_apply
      error_message = "This root is frozen. See docs/migration.md; never apply it after state ownership has moved."
    }
  }
}
