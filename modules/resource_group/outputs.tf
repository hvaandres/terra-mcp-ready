###############################################################################
# Outputs — Standardized map-in / map-out pattern
#
# Every module in this repo returns a map keyed by the same keys the consumer
# provided, making it straightforward to reference downstream.
###############################################################################

output "resource_groups" {
  description = "Map of resource group name to its attributes."
  value = {
    for name, rg in azurerm_resource_group.this : name => {
      id       = rg.id
      name     = rg.name
      location = rg.location
      tags     = rg.tags
    }
  }
}

output "ids" {
  description = "Map of resource group name to its resource ID (convenience shorthand)."
  value = {
    for name, rg in azurerm_resource_group.this : name => rg.id
  }
}

output "names" {
  description = "Map of resource group name to its name (useful for chaining)."
  value = {
    for name, rg in azurerm_resource_group.this : name => rg.name
  }
}
