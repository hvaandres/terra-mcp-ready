vpc_networks = {
  test-app-net = {
    routing_mode = "REGIONAL"
    allow_ssh    = true
    subnets = [
      { name = "test-app-us-central1", region = "us-central1", ip_cidr_range = "10.30.0.0/20" },
      { name = "test-app-europe-west1", region = "europe-west1", ip_cidr_range = "10.40.0.0/20" }
    ]
  }
}
