###############################################################################
# VPC Networks
#
# Normalizes each entry, then creates:
#   - google_compute_network
#   - google_compute_subnetwork (one per entry in .subnets[])
#   - google_compute_firewall   (when allow_ssh = true — opt-in)
#
# GCP VPCs and subnets don't support labels at the resource level, so the
# flat-keys-become-labels convention doesn't apply here — unknown keys on an
# entry are ignored.
###############################################################################

locals {
  _vpc_reserved_keys = [
    "description",
    "project",
    "routing_mode",
    "mtu",
    "auto_create_subnetworks",
    "delete_default_routes_on_create",
    "subnets",
    "allow_ssh",
    "ssh_source_ranges",
  ]

  _vpcs = {
    for name, cfg in var.vpc_networks : name => {
      description                     = try(cfg.description, "Managed by Terraform")
      project                         = try(cfg.project, "")
      routing_mode                    = try(cfg.routing_mode, "REGIONAL")
      mtu                             = try(cfg.mtu, 1460)
      auto_create_subnetworks         = try(cfg.auto_create_subnetworks, false)
      delete_default_routes_on_create = try(cfg.delete_default_routes_on_create, false)
      subnets                         = try(cfg.subnets, [])
      allow_ssh                       = try(cfg.allow_ssh, false)
      ssh_source_ranges               = try(cfg.ssh_source_ranges, ["0.0.0.0/0"])
    }
  }

  # Flatten subnets into a map keyed by "<vpc>/<subnet>"
  _subnets = {
    for pair in flatten([
      for vpc_name, vpc in local._vpcs : [
        for s in vpc.subnets : {
          key                      = "${vpc_name}/${s.name}"
          vpc_name                 = vpc_name
          name                     = s.name
          region                   = s.region
          ip_cidr_range            = s.ip_cidr_range
          private_ip_google_access = try(s.private_ip_google_access, true)
          project                  = vpc.project
        }
      ]
    ]) : pair.key => pair
  }

  # Only VPCs whose allow_ssh is true get a firewall rule created.
  _ssh_firewalls = {
    for vpc_name, vpc in local._vpcs : vpc_name => vpc if vpc.allow_ssh
  }
}

resource "google_compute_network" "this" {
  for_each = local._vpcs

  name                            = each.key
  description                     = each.value.description
  project                         = each.value.project != "" ? each.value.project : null
  routing_mode                    = each.value.routing_mode
  mtu                             = each.value.mtu
  auto_create_subnetworks         = each.value.auto_create_subnetworks
  delete_default_routes_on_create = each.value.delete_default_routes_on_create
}

resource "google_compute_subnetwork" "this" {
  for_each = local._subnets

  name                     = each.value.name
  network                  = google_compute_network.this[each.value.vpc_name].id
  region                   = each.value.region
  ip_cidr_range            = each.value.ip_cidr_range
  private_ip_google_access = each.value.private_ip_google_access
  project                  = each.value.project != "" ? each.value.project : null
}

###############################################################################
# Optional SSH firewall — created only when allow_ssh = true on the VPC.
# Targets instances tagged with "ssh" so not every VM on the network is exposed.
###############################################################################

resource "google_compute_firewall" "allow_ssh" {
  for_each = local._ssh_firewalls

  name          = "${each.key}-allow-ssh"
  network       = google_compute_network.this[each.key].id
  project       = each.value.project != "" ? each.value.project : null
  description   = "Managed by Terraform — allow inbound SSH on tcp:22 to instances tagged 'ssh'."
  direction     = "INGRESS"
  source_ranges = each.value.ssh_source_ranges
  target_tags   = ["ssh"]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
