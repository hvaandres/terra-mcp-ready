###############################################################################
# Test Harness — Resource Group Module
#
# Used by scripts/run_tests.sh to validate the module via
# terraform validate and terraform plan -json.
###############################################################################

terraform {
  required_version = ">= 1.5, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "resource_groups" {
  source = "../../modules/resource_group"

  resource_groups = var.resource_groups
}

output "resource_groups" {
  value = module.resource_groups.resource_groups
}

output "ids" {
  value = module.resource_groups.ids
}

output "names" {
  value = module.resource_groups.names
}
