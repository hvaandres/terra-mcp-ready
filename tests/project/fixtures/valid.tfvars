projects = {
  test-platform-1234 = {
    name            = "Test Platform"
    folder_id       = "folders/000000000000"
    billing_account = "000000-000000-000000"
    labels = {
      environment = "test"
      team        = "platform"
    }
  }
  test-app-1234 = {
    name            = "Test App"
    folder_id       = "folders/000000000000"
    billing_account = "000000-000000-000000"
    labels = {
      environment = "test"
      team        = "app"
    }
    lock = true
  }
}
