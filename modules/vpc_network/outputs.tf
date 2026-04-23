###############################################################################
# Outputs — map-in / map-out
###############################################################################

output "vpc_networks" {
  description = "Map of VPC name to its attributes."
  value = {
    for name, net in google_compute_network.this : name => {
      id        = net.id
      name      = net.name
      self_link = net.self_link
    }
  }
}

output "subnets" {
  description = "Map of \"<vpc>/<subnet>\" to subnet attributes."
  value = {
    for key, sub in google_compute_subnetwork.this : key => {
      id            = sub.id
      name          = sub.name
      self_link     = sub.self_link
      region        = sub.region
      ip_cidr_range = sub.ip_cidr_range
    }
  }
}

output "ids" {
  description = "Map of VPC name to its fully-qualified resource ID (convenience shorthand)."
  value = {
    for name, net in google_compute_network.this : name => net.id
  }
}
