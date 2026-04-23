###############################################################################
# Storage Buckets — Input Variable
#
# Consumers define one block per GCS bucket they need.
# The map key IS the globally unique bucket name.
###############################################################################

variable "storage_buckets" {
  description = <<-EOT
    Map of GCS buckets to create.
    Key   = bucket name (must be globally unique)
    Value = configuration object. The only required field is `location`.

    Known keys: location, project, storage_class, force_destroy,
                uniform_bucket_level_access, versioning, retention_days,
                lifecycle_age_days, labels.
    Any OTHER key/value pair is automatically treated as a label — so you can
    write labels inline without wrapping them in `labels = { ... }`.

    Minimal example:
      storage_buckets = {
        my-app-assets-dev = {
          location    = "US"
          environment = "dev"
          team        = "platform"
        }
      }

    Full example (labels wrapper still supported for backward compat):
      storage_buckets = {
        my-app-backups-prod = {
          location           = "us-central1"
          storage_class      = "NEARLINE"
          versioning         = true
          retention_days     = 30
          lifecycle_age_days = 365
          labels             = { environment = "prod" }
        }
      }
  EOT

  type    = any
  default = {}

  validation {
    condition = alltrue([
      for name, _ in var.storage_buckets :
      can(regex("^[a-z0-9][-a-z0-9_.]{1,61}[a-z0-9]$", name))
    ])
    error_message = "Bucket names must be 3-63 characters, start and end with a lowercase letter or digit, and contain only lowercase letters, digits, hyphens, underscores, or periods."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.storage_buckets : can(cfg.location) && cfg.location != ""
    ])
    error_message = "Every bucket must specify a non-empty `location`."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.storage_buckets :
      contains(["STANDARD", "NEARLINE", "COLDLINE", "ARCHIVE"], try(cfg.storage_class, "STANDARD"))
    ])
    error_message = "storage_class (if set) must be one of: STANDARD, NEARLINE, COLDLINE, ARCHIVE."
  }

  validation {
    condition = alltrue([
      for _, cfg in var.storage_buckets :
      (try(cfg.retention_days, 0) >= 0) && (try(cfg.lifecycle_age_days, 0) >= 0)
    ])
    error_message = "retention_days and lifecycle_age_days must be non-negative."
  }
}
