###############################################################################
# terraform.tfvars — Single file, JSON-block configuration
#
# Define one block per GCP project. The map key IS the project_id.
# Replace the folder_id and billing_account placeholders before `terraform apply`.
###############################################################################

projects = {

  #---------------------------------------------------------------------------
  # Platform project (dev)
  #---------------------------------------------------------------------------
  platform-dev-1234 = {
    name            = "Platform (Dev)"
    folder_id       = "folders/123456789012"
    billing_account = "0X0X0X-0X0X0X-0X0X0X"
    labels = {
      environment = "dev"
      team        = "platform"
      managed_by  = "terraform"
    }
  }

  #---------------------------------------------------------------------------
  # Application project (prod, locked)
  #---------------------------------------------------------------------------
  app-prod-1234 = {
    name            = "Application (Prod)"
    folder_id       = "folders/123456789012"
    billing_account = "0X0X0X-0X0X0X-0X0X0X"
    labels = {
      environment = "prod"
      team        = "app"
      managed_by  = "terraform"
    }
    lock = true
  }

  #---------------------------------------------------------------------------
  # Data project (minimal — only billing required for real use)
  #---------------------------------------------------------------------------
  data-dev-1234 = {
    billing_account = "0X0X0X-0X0X0X-0X0X0X"
  }

}
