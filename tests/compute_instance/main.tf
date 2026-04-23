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

output "instances" {
  value = module.compute_instances.instances
}

output "ssh_users" {
  value = module.compute_instances.ssh_users
}

output "passwords" {
  value     = module.compute_instances.passwords
  sensitive = true
}
