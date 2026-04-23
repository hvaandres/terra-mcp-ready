###############################################################################
# VPC Networks — Input Variable
###############################################################################

variable "vpc_networks" {
  description = <<-EOT
    Map of GCP VPC networks to create.
    Key   = VPC name (1–63 chars, lowercase letter first, hyphens OK).
    Value = configuration object.

    Known keys:
      description, project, routing_mode, mtu,
      auto_create_subnetworks, delete_default_routes_on_create,
      subnets, allow_ssh, ssh_source_ranges.

    GCP VPCs/subnets do not support labels, so unknown keys are ignored.

    Minimal example:
      vpc_networks = {
        app-net = {
          subnets = [
            { name = "app-us-central1", region = "us-central1", ip_cidr_range = "10.10.0.0/20" }
          ]
        }
      }

    Example with SSH firewall enabled:
      vpc_networks = {
        app-net = {
          routing_mode      = "GLOBAL"
          allow_ssh         = true
          ssh_source_ranges = ["203.0.113.0/24"]  # restrict to your IP range
          subnets = [
            { name = "app-us-central1", region = "us-central1", ip_cidr_range = "10.10.0.0/20" },
            { name = "app-europe-west1", region = "europe-west1", ip_cidr_range = "10.20.0.0/20" }
          ]
        }
      }
  EOT

  type    = any
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.vpc_networks :
      can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", name))
    ])
    error_message = "VPC names must be 1-63 characters, start with a lowercase letter, and contain only lowercase letters, digits, or hyphens."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.vpc_networks :
      contains(["REGIONAL", "GLOBAL"], try(cfg.routing_mode, "REGIONAL"))
    ])
    error_message = "routing_mode must be REGIONAL or GLOBAL."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.vpc_networks :
      try(cfg.mtu, 1460) >= 1300 && try(cfg.mtu, 1460) <= 8896
    ])
    error_message = "mtu must be between 1300 and 8896."
  }
}
