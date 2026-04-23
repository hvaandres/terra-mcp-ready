###############################################################################
# terraform.tfvars — Single file, JSON-block configuration
#
# Define one block per GCS bucket. The map key IS the bucket name
# (must be globally unique across all of GCS). Only `location` is required.
###############################################################################

storage_buckets = {

  #---------------------------------------------------------------------------
  # Public web assets — standard class, multi-region
  #---------------------------------------------------------------------------
  terra-mcp-example-assets-dev = {
    location      = "US"
    storage_class = "STANDARD"
    labels = {
      environment = "dev"
      team        = "platform"
    }
  }

  #---------------------------------------------------------------------------
  # Production backups — nearline, versioned, with retention + lifecycle
  #---------------------------------------------------------------------------
  terra-mcp-example-backups-prod = {
    location           = "us-central1"
    storage_class      = "NEARLINE"
    versioning         = true
    retention_days     = 30
    lifecycle_age_days = 365
    labels = {
      environment = "prod"
      team        = "app"
    }
  }

  #---------------------------------------------------------------------------
  # Archive — coldest tier, minimal config
  #---------------------------------------------------------------------------
  terra-mcp-example-archive-prod = {
    location      = "US"
    storage_class = "ARCHIVE"
  }

}
