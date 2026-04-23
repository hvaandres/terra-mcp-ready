output "instances" {
  description = "All instance attributes."
  value       = module.compute_instances.instances
}

output "ssh_users" {
  description = "Admin user created on each VM."
  value       = module.compute_instances.ssh_users
}

output "passwords" {
  description = "Generated random passwords. Retrieve with `terraform output -raw passwords` or `terraform output -json passwords`."
  value       = module.compute_instances.passwords
  sensitive   = true
}

output "ssh_commands" {
  description = "Copy-paste SSH commands per instance."
  value       = module.compute_instances.ssh_commands
}
