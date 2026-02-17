# Generate a random suffix for unique resource names
resource "random_id" "suffix" {
  byte_length = 4
}

# Create a local file to simulate infrastructure provisioning
resource "local_file" "terraform_output" {
  filename = "${path.module}/terraform-output.txt"
  content  = <<-EOT
    # Travel Analytics - Terraform Output
    # Stage 1: Local infrastructure simulation

    Project: ${var.project_name}
    Environment: ${var.environment}
    Deployment ID: ${random_id.suffix.hex}
    Generated: ${timestamp()}

    This file simulates infrastructure provisioning.
    Stage 2 will create actual cloud resources:
    - VPC and networking
    - RDS PostgreSQL
    - S3 buckets for data lake
    - ECR repositories
    - EKS clusters
  EOT
}
