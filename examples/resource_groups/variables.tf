###############################################################################
# Variables — passed through to the module
#
# Consumers only need to fill in terraform.tfvars.
###############################################################################

variable "resource_groups" {
  description = "Map of resource groups to create. See modules/resource_group/README.md for the schema."
  type = map(object({
    location   = string
    tags       = optional(map(string), {})
    lock       = optional(bool, false)
    managed_by = optional(string, "")
  }))
  default = {}
}
