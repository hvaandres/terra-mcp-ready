###############################################################################
# Example: GCP Projects via JSON-block tfvars
#
# This shows the consumer pattern — source the module, pass the map variable,
# and define everything in terraform.tfvars.
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

module "projects" {
  source = "../../modules/project"

  projects = var.projects
}
