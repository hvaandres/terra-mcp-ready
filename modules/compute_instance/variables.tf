###############################################################################
# Compute Instances — Input Variable
###############################################################################

variable "compute_instances" {
  description = <<-EOT
    Map of Ubuntu compute instances to create.
    Key   = instance name (1–63 chars, lowercase letter first, hyphens OK).
    Value = configuration object.

    Reserved keys (everything else on the object becomes a label):
      machine_type, zone, image, network, subnetwork, project,
      user, password_length, disk_size_gb, disk_type,
      tags, labels, allow_stopping_for_update.

    Minimal example:
      compute_instances = {
        app-dev-01 = {
          zone = "us-central1-a"
        }
      }

    Fuller example (flat labels):
      compute_instances = {
        app-dev-01 = {
          machine_type    = "e2-medium"
          zone            = "us-central1-a"
          image           = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
          network         = "app-net"
          subnetwork      = "app-us-central1"
          user            = "tfadmin"
          password_length = 32
          disk_size_gb    = 30
          tags            = ["ssh", "web"]
          environment     = "dev"
          team            = "platform"
        }
      }
  EOT

  type    = any
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.compute_instances :
      can(regex("^[a-z]([-a-z0-9]{0,61}[a-z0-9])?$", name))
    ])
    error_message = "Instance names must be 1-63 characters, start with a lowercase letter, and contain only lowercase letters, digits, or hyphens."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.compute_instances :
      try(cfg.password_length, 24) >= 8 && try(cfg.password_length, 24) <= 64
    ])
    error_message = "password_length must be between 8 and 64."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.compute_instances :
      try(cfg.disk_size_gb, 20) >= 10 && try(cfg.disk_size_gb, 20) <= 65536
    ])
    error_message = "disk_size_gb must be between 10 and 65536."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.compute_instances :
      contains(["pd-standard", "pd-balanced", "pd-ssd", "pd-extreme"], try(cfg.disk_type, "pd-balanced"))
    ])
    error_message = "disk_type must be one of: pd-standard, pd-balanced, pd-ssd, pd-extreme."
  }
}
