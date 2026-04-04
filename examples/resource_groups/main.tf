###############################################################################
# Example: Resource Groups via JSON-block tfvars
#
# This shows the consumer pattern — source the module, pass the map variable,
# and define everything in terraform.tfvars.
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
