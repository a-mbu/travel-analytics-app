# Output values for reference
output "deployment_id" {
  value       = random_id.suffix.hex
  description = "Unique deployment identifier"
}

output "environment" {
  value       = var.environment
  description = "Deployment environment"
}

output "terraform_output_file" {
  value       = local_file.terraform_output.filename
  description = "Path to generated output file"
}
