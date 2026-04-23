###############################################################################
# Outputs — map-in / map-out
#
# `passwords` is marked sensitive; retrieve with:
#   terraform -chdir=examples/compute_instances output -raw passwords
###############################################################################

output "instances" {
  description = "Map of instance name to attributes."
  value = {
    for name, vm in google_compute_instance.this : name => {
      id           = vm.id
      name         = vm.name
      self_link    = vm.self_link
      machine_type = vm.machine_type
      zone         = vm.zone
      internal_ip  = try(vm.network_interface[0].network_ip, null)
      external_ip  = try(vm.network_interface[0].access_config[0].nat_ip, null)
      user         = local._instances[name].user
      labels       = vm.effective_labels
      network_tags = vm.tags
    }
  }
}

output "ssh_users" {
  description = "Map of instance name to the SSH user created on the VM."
  value = {
    for name, cfg in local._instances : name => cfg.user
  }
}

output "passwords" {
  description = "Map of instance name to the generated SSH password. SENSITIVE: retrieve with `terraform output -raw passwords`."
  value = {
    for name, p in random_password.this : name => p.result
  }
  sensitive = true
}

output "ssh_commands" {
  description = "Copy-paste SSH commands. Requires sshpass for password login: `brew install hudochenkov/sshpass/sshpass`."
  value = {
    for name, vm in google_compute_instance.this : name =>
    format(
      "sshpass -p '<run: terraform output -raw passwords>' ssh -o StrictHostKeyChecking=no %s@%s",
      local._instances[name].user,
      try(vm.network_interface[0].access_config[0].nat_ip, "<no-external-ip>")
    )
  }
}
