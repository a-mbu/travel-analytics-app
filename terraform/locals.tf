# Local variables
locals {
  name_prefix = "${var.project_name}-${var.environment}"

  # Tags for all resources
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Stage       = "1"
  }
}
