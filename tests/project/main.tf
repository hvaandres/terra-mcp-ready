###############################################################################
# Test Harness — GCP Project Module
#
# Used by scripts/run_tests.sh to validate the module via
# terraform validate and terraform plan -json.
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

output "projects" {
  value = module.projects.projects
}

output "ids" {
  value = module.projects.ids
}

output "numbers" {
  value = module.projects.numbers
}
