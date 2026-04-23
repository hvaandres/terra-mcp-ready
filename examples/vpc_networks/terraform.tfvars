###############################################################################
# terraform.tfvars — Single file, JSON-block configuration
#
# Define one block per VPC. The map key IS the VPC name.
###############################################################################

vpc_networks = {

  app-net = {
    description       = "Application VPC (prod)"
    routing_mode      = "GLOBAL"
    allow_ssh         = true
    ssh_source_ranges = ["0.0.0.0/0"] # tighten in production

    subnets = [
      {
        name          = "app-us-central1"
        region        = "us-central1"
        ip_cidr_range = "10.10.0.0/20"
      },
      {
        name          = "app-europe-west1"
        region        = "europe-west1"
        ip_cidr_range = "10.20.0.0/20"
      }
    ]
  }

}
