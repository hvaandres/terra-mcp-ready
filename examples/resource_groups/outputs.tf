output "resource_groups" {
  description = "All resource group attributes."
  value       = module.resource_groups.resource_groups
}

output "resource_group_ids" {
  description = "Resource group IDs."
  value       = module.resource_groups.ids
}
