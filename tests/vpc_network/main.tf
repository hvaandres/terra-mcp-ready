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

module "vpc_networks" {
  source = "../../modules/vpc_network"

  vpc_networks = var.vpc_networks
}

output "vpc_networks" {
  value = module.vpc_networks.vpc_networks
}

output "subnets" {
  value = module.vpc_networks.subnets
}
