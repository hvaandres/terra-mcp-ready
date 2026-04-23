compute_instances = {
  test-app-01 = {
    machine_type = "e2-small"
    zone         = "us-central1-a"
    user         = "tfadmin"
    environment  = "test"
    team         = "platform"
  }
}
