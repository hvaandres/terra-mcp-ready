###############################################################################
# Example: GCS Buckets via JSON-block tfvars
###############################################################################

terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {}

module "storage_buckets" {
  source = "../../modules/storage_bucket"

  storage_buckets = var.storage_buckets
}
