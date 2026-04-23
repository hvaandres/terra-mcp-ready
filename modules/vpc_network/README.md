# GCP VPC Network Module
Provisions one or more GCP VPC networks (with optional subnets and an opt-in SSH firewall) from a single `map(object)` variable.
## Usage
```hcl
module "vpc_networks" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/vpc_network?ref=v1.0.0"
  vpc_networks = {
    app-net = {
      routing_mode = "GLOBAL"
      subnets = [
        { name = "app-us-central1",  region = "us-central1",  ip_cidr_range = "10.10.0.0/20" },
        { name = "app-europe-west1", region = "europe-west1", ip_cidr_range = "10.20.0.0/20" }
      ]
      allow_ssh         = true
      ssh_source_ranges = ["203.0.113.0/24"]  # your office CIDR
    }
  }
}
```
## Input
| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `description` | `string` | no | `"Managed by Terraform"` | Human-readable description |
| `project` | `string` | no | `""` | Overrides provider default |
| `routing_mode` | `string` | no | `"REGIONAL"` | `REGIONAL` or `GLOBAL` |
| `mtu` | `number` | no | `1460` | 1300–8896 |
| `auto_create_subnetworks` | `bool` | no | `false` | Auto-mode VPC (usually false) |
| `delete_default_routes_on_create` | `bool` | no | `false` | Drop default 0.0.0.0/0 routes |
| `subnets` | `list(object)` | no | `[]` | Nested subnet list |
| `allow_ssh` | `bool` | no | `false` | Opt-in tcp:22 firewall targeting tag `ssh` |
| `ssh_source_ranges` | `list(string)` | no | `["0.0.0.0/0"]` | CIDRs allowed to SSH when `allow_ssh = true` |
Each subnet entry:
| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | `string` | **yes** | — | Subnet name |
| `region` | `string` | **yes** | — | Region for the subnet |
| `ip_cidr_range` | `string` | **yes** | — | Primary CIDR (e.g. `10.10.0.0/20`) |
| `private_ip_google_access` | `bool` | no | `true` | Reach Google APIs privately |
The **map key** is used as the VPC name.
## Outputs
| Name | Description |
|---|---|
| `vpc_networks` | `{ vpc_name => { id, name, self_link } }` |
| `subnets` | `{ "vpc_name/subnet_name" => { id, name, self_link, region, ip_cidr_range } }` |
| `ids` | Shorthand `{ vpc_name => id }` |
## Labels
GCP VPCs and subnets don't support labels at the resource level. Unknown keys on a VPC entry are silently ignored by this module \u2014 apply labels to the resources placed inside the VPC (buckets, compute instances, etc.) instead.
## Firewall behavior (opt-in)
Setting `allow_ssh = true` creates a single `google_compute_firewall` named `<vpc>-allow-ssh`:
- Allows `tcp:22` from `ssh_source_ranges` (default `0.0.0.0/0`)
- Targets instances tagged with `ssh` (so not every VM on the network is exposed)
- Name collides if you set it manually too \u2014 either use the opt-in, or drop the flag and create your own `google_compute_firewall`.
The `compute_instance` module adds `ssh` to its `tags` by default, so enabling `allow_ssh` + deploying a VM to this VPC is enough to reach it over SSH.
## MCP / AI integration
The `schema.json` describes the input contract. Use `_meta.key_spec.regex` to validate map keys, `_meta.reserved_keys` to identify structured fields.
