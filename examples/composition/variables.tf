###############################################################################
# Composition root — variables
#
# Each variable is a direct passthrough to the matching module. `type = any`
# so the consumer tfvars can use the flat-keys-become-labels convention.
# `default = {}` on every one means you can opt out of any module simply by
# not providing its key in the tfvars.
###############################################################################

variable "projects" {
  description = "Map of GCP projects to create. See modules/project/README.md."
  type        = any
  default     = {}
}

variable "vpc_networks" {
  description = "Map of GCP VPC networks to create. See modules/vpc_network/README.md."
  type        = any
  default     = {}
}

variable "compute_instances" {
  description = <<-EOT
    Map of Compute Engine VMs to create. See modules/compute_instance/README.md.
    If `network` or `subnetwork` on an entry matches a VPC/subnet defined in
    var.vpc_networks, this root substitutes the string with the resource's
    self_link so the VPC is created before the VM.
  EOT
  type        = any
  default     = {}
}

variable "storage_buckets" {
  description = "Map of GCS buckets to create. See modules/storage_bucket/README.md."
  type        = any
  default     = {}
}
