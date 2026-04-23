###############################################################################
# Composition root — outputs
#
# Every module's outputs are re-exported under a namespace matching the
# module name, so consumers can grab anything with a single `terraform output`.
###############################################################################

output "projects" {
  description = "Attributes for each project created."
  value       = module.projects.projects
}

output "vpc_networks" {
  description = "Attributes for each VPC network created."
  value       = module.vpc_networks.vpc_networks
}

output "subnets" {
  description = "Attributes for each subnet created (keyed by \"<vpc>/<subnet>\")."
  value       = module.vpc_networks.subnets
}

output "compute_instances" {
  description = "Attributes for each compute instance created."
  value       = module.compute_instances.instances
}

output "compute_passwords" {
  description = "Generated passwords for each compute instance. SENSITIVE."
  value       = module.compute_instances.passwords
  sensitive   = true
}

output "ssh_commands" {
  description = "Copy-paste SSH commands for each compute instance."
  value       = module.compute_instances.ssh_commands
}

output "storage_buckets" {
  description = "Attributes for each GCS bucket created."
  value       = module.storage_buckets.buckets
}
