###############################################################################
# Composition example: project → VPC → Compute Instance → Storage Bucket
#
# A single root module that instantiates every module in this repo. You supply
# ONE tfvars file with top-level keys matching each module's variable_name
# (`projects`, `vpc_networks`, `compute_instances`, `storage_buckets`).
#
# Dependency wiring
# -----------------
# If a compute_instance's `network` key matches a VPC created here, this root
# substitutes it with the VPC's self_link so Terraform orders the apply
# correctly. Same idea for `subnetwork` when it's expressed as "<vpc>/<subnet>".
# A `network` value that does NOT match any newly-created VPC is passed through
# unchanged (so you can still say `network = "default"`).
#
# Suggested generator: `./scripts/scaffold_tfvars.sh`. When the scaffolder is
# used with multiple modules in one run, it also writes a combined
# `generated.tfvars.json` at the repo root — that file is the exact shape this
# root expects, so point `-var-file` at it.
###############################################################################

terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "google" {}

###############################################################################
# Projects (optional — leave var.projects = {} to skip)
###############################################################################

module "projects" {
  source   = "../../modules/project"
  projects = var.projects
}

###############################################################################
# VPC networks (optional)
###############################################################################

module "vpc_networks" {
  source       = "../../modules/vpc_network"
  vpc_networks = var.vpc_networks
}

###############################################################################
# Compute instances (network / subnetwork auto-resolved to freshly-created VPCs)
###############################################################################

locals {
  # Map of VPC name → self_link for every VPC created above.
  _created_vpc_selflinks = {
    for name, vpc in module.vpc_networks.vpc_networks : name => vpc.self_link
  }

  # Map of "<vpc>/<subnet>" → self_link for every subnet created above.
  _created_subnet_selflinks = {
    for key, sub in module.vpc_networks.subnets : key => sub.self_link
  }

  # Rewrite each compute_instance entry so `network` / `subnetwork` point at
  # the real self_link when the user referenced an in-this-apply VPC by name.
  _compute_instances_resolved = {
    for vm_name, cfg in var.compute_instances : vm_name => merge(
      cfg,
      # network: substitute only when the value matches a newly-created VPC.
      contains(keys(local._created_vpc_selflinks), try(cfg.network, "")) ? {
        network = local._created_vpc_selflinks[cfg.network]
      } : {},
      # subnetwork: substitute only when it matches a newly-created subnet key
      # (expressed as "<vpc>/<subnet>").
      contains(keys(local._created_subnet_selflinks), try(cfg.subnetwork, "")) ? {
        subnetwork = local._created_subnet_selflinks[cfg.subnetwork]
      } : {},
    )
  }
}

module "compute_instances" {
  source            = "../../modules/compute_instance"
  compute_instances = local._compute_instances_resolved
}

###############################################################################
# Storage buckets (optional)
###############################################################################

module "storage_buckets" {
  source          = "../../modules/storage_bucket"
  storage_buckets = var.storage_buckets
}
