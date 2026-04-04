###############################################################################
# terraform.tfvars — Single file, JSON-block configuration
#
# Define one block per resource group. The map key IS the resource group name.
# Only "location" is required; everything else has sensible defaults.
###############################################################################

resource_groups = {

  #---------------------------------------------------------------------------
  # Networking resource group (dev)
  #---------------------------------------------------------------------------
  rg-networking-dev = {
    location = "eastus2"
    tags = {
      Environment = "dev"
      Team        = "platform"
      ManagedBy   = "terraform"
    }
  }

  #---------------------------------------------------------------------------
  # Application resource group (prod, locked)
  #---------------------------------------------------------------------------
  rg-app-prod = {
    location = "westus2"
    tags = {
      Environment = "prod"
      Team        = "app"
      ManagedBy   = "terraform"
    }
    lock = true
  }

  #---------------------------------------------------------------------------
  # Data resource group (minimal — only location required)
  #---------------------------------------------------------------------------
  rg-data-dev = {
    location = "eastus2"
  }

}
