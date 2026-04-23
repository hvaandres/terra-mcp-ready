storage_buckets = {
  terra-mcp-test-assets = {
    location      = "US"
    storage_class = "STANDARD"
    labels = {
      environment = "test"
      team        = "platform"
    }
  }
  terra-mcp-test-backups = {
    location           = "us-central1"
    storage_class      = "NEARLINE"
    versioning         = true
    retention_days     = 7
    lifecycle_age_days = 90
    labels = {
      environment = "test"
      team        = "app"
    }
  }
}
