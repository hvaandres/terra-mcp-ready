###############################################################################
# Resource Groups — Input Variable
#
# Consumers define one block per resource group they need.
# The map key IS the resource group name.
###############################################################################

variable "resource_groups" {
  description = <<-EOT
    Map of resource groups to create.
    Key   = resource group name (e.g. "rg-networking-dev")
    Value = configuration object for that resource group

    Example:
      resource_groups = {
        rg-networking-dev = {
          location = "eastus2"
          tags     = { Environment = "dev" }
        }
        rg-app-prod = {
          location = "westus2"
          tags     = { Environment = "prod" }
          lock     = true
        }
      }
  EOT

  type = map(object({
    location   = string
    tags       = optional(map(string), {})
    lock       = optional(bool, false)
    managed_by = optional(string, "")
  }))

  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.resource_groups :
      can(regex("^[a-zA-Z0-9._()-]{1,90}$", name)) && !endswith(name, ".")
    ])
    error_message = "Resource group names must be 1-90 characters, contain only alphanumerics, hyphens, underscores, periods, or parentheses, and cannot end with a period."
  }
}
