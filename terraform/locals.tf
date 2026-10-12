locals {
  project_name = "gamevault"
  name_prefix  = "${local.project_name}-${var.environment}"
}