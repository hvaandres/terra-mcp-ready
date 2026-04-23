###############################################################################
# Projects — Input Variable
#
# Consumers define one block per GCP project they need.
# The map key IS the project_id.
###############################################################################

variable "projects" {
  description = <<-EOT
    Map of GCP projects to create.
    Key   = project_id (e.g. "my-app-dev-123")
    Value = configuration object. All fields are optional.

    Known keys: name, folder_id, org_id, billing_account, auto_create_network,
                lock, deletion_policy, labels.
    Any OTHER key/value pair is automatically treated as a label — so you can
    write labels inline without wrapping them in `labels = { ... }`.

    Minimal example:
      projects = {
        my-app-dev-123 = {
          environment = "dev"
          team        = "platform"
        }
      }

    Full example (labels wrapper still supported for backward compat):
      projects = {
        my-app-prod-123 = {
          name            = "My App (Prod)"
          folder_id       = "folders/123456789012"
          billing_account = "0X0X0X-0X0X0X-0X0X0X"
          labels          = { environment = "prod" }
          lock            = true
        }
      }
  EOT

  type    = any
  default = {}

  validation {
    condition = alltrue([
      for project_id, _ in var.projects :
      can(regex("^[a-z][-a-z0-9]{4,28}[a-z0-9]$", project_id))
    ])
    error_message = "Project IDs must be 6-30 characters, start with a lowercase letter, contain only lowercase letters, digits, or hyphens, and cannot end with a hyphen."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.projects :
      !(try(cfg.folder_id, "") != "" && try(cfg.org_id, "") != "")
    ])
    error_message = "A project may specify either folder_id or org_id, but not both."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.projects :
      contains(["DELETE", "PREVENT", "ABANDON"], try(cfg.deletion_policy, "DELETE"))
    ])
    error_message = "deletion_policy (if set) must be one of: DELETE, PREVENT, ABANDON."
  }
}
