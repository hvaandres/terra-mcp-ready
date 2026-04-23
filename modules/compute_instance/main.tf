###############################################################################
# Ubuntu Compute Instances
#
# For each entry in var.compute_instances:
#   1. Generate a random_password (never leaves Terraform state).
#   2. Render a startup script that:
#        - creates the admin user
#        - sets the password
#        - enables PasswordAuthentication in sshd_config
#        - restarts sshd so the change takes effect
#   3. Create the google_compute_instance with the rendered script in metadata.
#
# Labels follow the flat-keys convention: any non-reserved key on the entry
# becomes a label.
###############################################################################

locals {
  _instance_reserved_keys = [
    "machine_type",
    "zone",
    "image",
    "network",
    "subnetwork",
    "project",
    "user",
    "password_length",
    "disk_size_gb",
    "disk_type",
    "tags",
    "labels",
    "allow_stopping_for_update",
  ]

  _instances = {
    for name, cfg in var.compute_instances : name => {
      machine_type              = try(cfg.machine_type, "e2-small")
      zone                      = try(cfg.zone, "")
      image                     = try(cfg.image, "ubuntu-os-cloud/ubuntu-2404-lts-amd64")
      network                   = try(cfg.network, "default")
      subnetwork                = try(cfg.subnetwork, "")
      project                   = try(cfg.project, "")
      user                      = try(cfg.user, "tfadmin")
      password_length           = try(cfg.password_length, 24)
      disk_size_gb              = try(cfg.disk_size_gb, 20)
      disk_type                 = try(cfg.disk_type, "pd-balanced")
      tags                      = try(cfg.tags, ["ssh"])
      allow_stopping_for_update = try(cfg.allow_stopping_for_update, true)
      labels = merge(
        try(cfg.labels, {}),
        { for k, v in cfg : k => tostring(v) if !contains(local._instance_reserved_keys, k) },
      )
    }
  }
}

###############################################################################
# Random password per instance
###############################################################################

resource "random_password" "this" {
  for_each = local._instances

  length           = each.value.password_length
  special          = true
  override_special = "-_" # keep it shell-safe
  min_lower        = 2
  min_upper        = 2
  min_numeric      = 2
  min_special      = 2
  keepers = {
    # Rotate the password if the user changes
    user = each.value.user
  }
}

###############################################################################
# Compute instances
###############################################################################

resource "google_compute_instance" "this" {
  for_each = local._instances

  name         = each.key
  machine_type = each.value.machine_type
  zone         = each.value.zone != "" ? each.value.zone : null
  project      = each.value.project != "" ? each.value.project : null

  tags   = each.value.tags
  labels = each.value.labels

  allow_stopping_for_update = each.value.allow_stopping_for_update

  boot_disk {
    initialize_params {
      image = each.value.image
      size  = each.value.disk_size_gb
      type  = each.value.disk_type
    }
  }

  network_interface {
    network    = each.value.network
    subnetwork = each.value.subnetwork != "" ? each.value.subnetwork : null

    # Ephemeral external IP so SSH works out of the box.
    access_config {}
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh.tftpl", {
    user     = each.value.user
    password = random_password.this[each.key].result
  })
}
