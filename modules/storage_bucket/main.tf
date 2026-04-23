###############################################################################
# GCS Buckets
#
# Accepts two tfvars shapes and normalizes them:
#   1. Explicit:  { location = "US", labels = { env = "dev" } }
#   2. Flat:      { location = "US", env = "dev" }   # any non-reserved key
#                                                     # becomes a label
###############################################################################

locals {
  _bucket_reserved_keys = [
    "location",
    "project",
    "storage_class",
    "force_destroy",
    "uniform_bucket_level_access",
    "versioning",
    "retention_days",
    "lifecycle_age_days",
    "labels",
  ]

  _buckets = {
    for name, cfg in var.storage_buckets : name => {
      location                    = cfg.location
      project                     = try(cfg.project, "")
      storage_class               = try(cfg.storage_class, "STANDARD")
      force_destroy               = try(cfg.force_destroy, false)
      uniform_bucket_level_access = try(cfg.uniform_bucket_level_access, true)
      versioning                  = try(cfg.versioning, false)
      retention_days              = try(cfg.retention_days, 0)
      lifecycle_age_days          = try(cfg.lifecycle_age_days, 0)
      labels = merge(
        try(cfg.labels, {}),
        { for k, v in cfg : k => tostring(v) if !contains(local._bucket_reserved_keys, k) },
      )
    }
  }
}

resource "google_storage_bucket" "this" {
  for_each = local._buckets

  name          = each.key
  location      = each.value.location
  project       = each.value.project != "" ? each.value.project : null
  storage_class = each.value.storage_class
  force_destroy = each.value.force_destroy
  labels        = each.value.labels

  uniform_bucket_level_access = each.value.uniform_bucket_level_access

  versioning {
    enabled = each.value.versioning
  }

  dynamic "retention_policy" {
    for_each = each.value.retention_days > 0 ? [1] : []
    content {
      retention_period = each.value.retention_days * 24 * 60 * 60
    }
  }

  dynamic "lifecycle_rule" {
    for_each = each.value.lifecycle_age_days > 0 ? [1] : []
    content {
      action {
        type = "Delete"
      }
      condition {
        age = each.value.lifecycle_age_days
      }
    }
  }
}
