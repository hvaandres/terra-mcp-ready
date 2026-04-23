###############################################################################
# Example: Ubuntu Compute Instances via JSON-block tfvars
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

module "compute_instances" {
  source = "../../modules/compute_instance"

  compute_instances = var.compute_instances
}
