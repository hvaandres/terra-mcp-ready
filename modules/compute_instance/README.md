# GCP Compute Instance Module
Provisions one or more Ubuntu GCE instances from a single `map(object)` variable. For each instance:
1. A **random password** is generated at plan time.
2. A startup script creates the admin user, sets its password, grants passwordless `sudo`, and enables `PasswordAuthentication` in `sshd_config`.
3. The VM boots with an ephemeral external IP so you can SSH in immediately (if the network allows it).
## Usage
```hcl
module "compute_instances" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/compute_instance?ref=v1.0.0"
  compute_instances = {
    app-dev-01 = {
      machine_type = "e2-medium"
      zone         = "us-central1-a"
      user         = "tfadmin"
      environment  = "dev"
      team         = "platform"
    }
  }
}
```
The map key becomes the instance name. Nothing else is required \u2014 `machine_type`, `image`, `disk_size_gb`, etc. all fall back to module defaults.
## Input
| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `machine_type` | `string` | no | `"e2-small"` | Machine type |
| `zone` | `string` | no | `""` | Falls back to provider default zone |
| `image` | `string` | no | `"ubuntu-os-cloud/ubuntu-2404-lts-amd64"` | Source image |
| `network` | `string` | no | `"default"` | VPC name or self_link |
| `subnetwork` | `string` | no | `""` | Subnet (optional) |
| `project` | `string` | no | `""` | Overrides provider default |
| `user` | `string` | no | `"tfadmin"` | Admin user created on the VM |
| `password_length` | `number` | no | `24` | 8\u201364 |
| `disk_size_gb` | `number` | no | `20` | 10\u201365536 |
| `disk_type` | `string` | no | `"pd-balanced"` | `pd-standard`/`pd-balanced`/`pd-ssd`/`pd-extreme` |
| `tags` | `list(string)` | no | `["ssh"]` | Network tags (used by firewall rules) |
| `labels` | `map(string)` | no | `{}` | Explicit labels (flat keys also work) |
| `allow_stopping_for_update` | `bool` | no | `true` | Let TF stop the VM to apply certain changes |
Any non-reserved key on an entry becomes a label automatically (flat-keys convention).
## Outputs
| Name | Description |
|---|---|
| `instances` | `{ name => { id, self_link, machine_type, zone, internal_ip, external_ip, user, labels, network_tags } }` |
| `ssh_users` | `{ name => user }` |
| `passwords` | `{ name => password }` \u2014 **sensitive**; see below |
| `ssh_commands` | Copy-paste SSH helper string (per instance) |
## Retrieving the password
The `passwords` output is marked `sensitive = true` so Terraform won't print it by default. To see it:
```bash
terraform -chdir=examples/compute_instances output -raw passwords
# Or for a specific instance (use jq):
terraform -chdir=examples/compute_instances output -json passwords | jq -r '."app-dev-01"'
```
The password also lives in Terraform state. Use a remote backend with encryption at rest in any real deployment.
## SSH access
The startup script enables password auth on the VM, but you still need a firewall rule allowing `tcp:22` to reach it. Two options:
1. **Use the `default` VPC** (`network = "default"`) \u2014 the implicit `default-allow-ssh` rule already exists.
2. **Pair with `modules/vpc_network`** \u2014 set `allow_ssh = true` on the VPC. The compute module's default tag `"ssh"` makes the VPC rule apply automatically.
To SSH in:
```bash
# Get IP + password
IP=$(terraform -chdir=examples/compute_instances output -json instances | jq -r '."app-dev-01".external_ip')
PW=$(terraform -chdir=examples/compute_instances output -json passwords  | jq -r '."app-dev-01"')
# With sshpass (install: brew install hudochenkov/sshpass/sshpass)
sshpass -p "$PW" ssh -o StrictHostKeyChecking=no tfadmin@"$IP"
```
## Security notes
- **Password auth is legacy.** For production, prefer SSH keys via OS Login (`gcloud compute ssh`) or a bastion. This module is a convenience for "give me a box I can log into with a random password fast".
- The password is stored in Terraform state. Use an encrypted remote backend (GCS with CMEK, Terraform Cloud, etc.).
- The opt-in firewall in `modules/vpc_network` defaults `ssh_source_ranges` to `0.0.0.0/0`. **Always narrow this** in production.
## MCP / AI integration
See `schema.json`. `_meta.sensitive_outputs` lists outputs that agents should never echo verbatim.
