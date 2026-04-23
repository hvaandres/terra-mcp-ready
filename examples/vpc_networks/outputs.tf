output "vpc_networks" {
  description = "All VPC attributes."
  value       = module.vpc_networks.vpc_networks
}

output "subnets" {
  description = "All subnet attributes keyed by vpc/subnet."
  value       = module.vpc_networks.subnets
}

output "vpc_ids" {
  description = "Map of VPC name to its resource id."
  value       = module.vpc_networks.ids
}
