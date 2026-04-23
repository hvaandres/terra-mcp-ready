###############################################################################
# Composition example — sample tfvars
#
# One VPC + subnet, one Ubuntu VM on that VPC/subnet, and one GCS bucket.
# Project is intentionally omitted — we assume you already have one and that
# GOOGLE_PROJECT / provider project config points at it.
###############################################################################

vpc_networks = {
  app-net = {
    description       = "Composition example VPC"
    routing_mode      = "REGIONAL"
    allow_ssh         = true
    ssh_source_ranges = ["0.0.0.0/0"] # narrow to your IP in real use
    subnets = [
      { name = "app-us-central1", region = "us-central1", ip_cidr_range = "10.40.0.0/20" },
    ]
    environment = "demo"
    owner       = "composition-example"
  }
}

compute_instances = {
  app-vm-01 = {
    machine_type    = "e2-small"
    zone            = "us-central1-a"
    network         = "app-net"                 # auto-resolved to the VPC above
    subnetwork      = "app-net/app-us-central1" # "<vpc>/<subnet>" → self_link
    user            = "tfadmin"
    password_length = 24
    tags            = ["ssh"]
    environment     = "demo"
    owner           = "composition-example"
  }
}

storage_buckets = {
  composition-demo-bucket-change-me = {
    location    = "US"
    environment = "demo"
    owner       = "composition-example"
  }
}
