###############################################################################
# terraform.tfvars — Single file, JSON-block configuration
#
# Map key IS the instance name. Only fields that differ from defaults need to
# be listed. Any non-reserved key (like `environment`, `team`) becomes a label.
###############################################################################

compute_instances = {

  app-dev-01 = {
    machine_type = "e2-small"
    zone         = "us-central1-a"
    user         = "tfadmin"
    environment  = "dev"
    team         = "platform"
  }

}
