###############################################################################
# GCP Projects
#
# Accepts two tfvars shapes and normalizes them:
#   1. Explicit:  { name = "X", labels = { env = "dev" } }
#   2. Flat:      { name = "X", env = "dev" }   # any non-reserved key
#                                                 # becomes a label
###############################################################################

locals {
  _project_reserved_keys = [
    "name",
    "folder_id",
    "org_id",
    "billing_account",
    "auto_create_network",
    "lock",
    "deletion_policy",
    "labels",
  ]

  _projects = {
    for project_id, cfg in var.projects : project_id => {
      name                = try(cfg.name, "")
      folder_id           = try(cfg.folder_id, "")
      org_id              = try(cfg.org_id, "")
      billing_account     = try(cfg.billing_account, "")
      auto_create_network = try(cfg.auto_create_network, false)
      lock                = try(cfg.lock, false)
      deletion_policy     = try(cfg.deletion_policy, "DELETE")
      labels = merge(
        try(cfg.labels, {}),
        { for k, v in cfg : k => tostring(v) if !contains(local._project_reserved_keys, k) },
      )
    }
  }
}

resource "google_project" "this" {
  for_each = local._projects

  project_id          = each.key
  name                = each.value.name != "" ? each.value.name : each.key
  folder_id           = each.value.folder_id != "" ? each.value.folder_id : null
  org_id              = each.value.org_id != "" ? each.value.org_id : null
  billing_account     = each.value.billing_account != "" ? each.value.billing_account : null
  labels              = each.value.labels
  auto_create_network = each.value.auto_create_network
  deletion_policy     = each.value.deletion_policy
}

###############################################################################
# Project Liens — Conditional on lock = true
#
# A lien blocks project deletion until the lien is removed.
###############################################################################

resource "google_resource_manager_lien" "this" {
  for_each = {
    for project_id, project in local._projects : project_id => project if project.lock
  }

  parent       = "projects/${google_project.this[each.key].number}"
  restrictions = ["resourcemanager.projects.delete"]
  origin       = "terraform-managed"
  reason       = "Managed by Terraform — do not delete."
}
