resource_groups = {
  rg-test-networking = {
    location = "eastus2"
    tags = {
      Environment = "test"
      Team        = "platform"
    }
  }
  rg-test-app = {
    location = "westus2"
    tags = {
      Environment = "test"
      Team        = "app"
    }
    lock = true
  }
}
