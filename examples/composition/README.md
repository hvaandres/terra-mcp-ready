# Composition example
A single Terraform root that chains every module in this repo:
```
modules/project  →  modules/vpc_network  →  modules/compute_instance
                                        \
                                         → modules/storage_bucket
```
This is the best place to start when you want multiple resource types created
in **one** `terraform apply` with their inter-dependencies wired up for you.
## What this root does
- Instantiates all four modules under a single root (`examples/composition/`).
- Accepts one tfvars file with the top-level keys
  `projects`, `vpc_networks`, `compute_instances`, `storage_buckets` —
  the same shape the scaffolder emits in multi-module mode.
- **Auto-resolves compute instance networking**: if a VM's `network` matches a
  VPC in `vpc_networks`, the root rewrites it to that VPC's `self_link` so
  Terraform schedules the VPC first. The same holds for `subnetwork` when
  you write it as `"<vpc>/<subnet>"`.
- Any module you don't want is simply omitted from the tfvars (every
  top-level variable defaults to `{}`).
## Generate a tfvars with the scaffolder
```bash
./scripts/scaffold_tfvars.sh
# pick module #4 (vpc_network) → add a VPC
# → "Add resources from a DIFFERENT module?" → Y
# pick module #1 (compute_instance) → add a VM referencing the VPC by name
# → "Add resources from a DIFFERENT module?" → Y
# pick module #3 (storage_bucket) → add a bucket
# → N
```
Outputs:
- `examples/composition/generated.tfvars.json` — **not written automatically today**; use the combined reference file at the repo root, or copy from the per-module slices.
- `generated.tfvars.json` at the repo root — the combined reference, with the exact top-level shape this root consumes.
Point `-var-file` at the combined file:
```bash
terraform -chdir=examples/composition init
terraform -chdir=examples/composition plan \
  -var-file=$PWD/generated.tfvars.json \
  -out=tfplan
terraform -chdir=examples/composition apply tfplan
```
> If you prefer a checked-in sample, the provided `terraform.tfvars` gives you
> a VPC + VM + bucket combo that exercises the self_link wiring. Run without
> `-var-file` to use it.
## Dependency wiring — the short version
The compute instance module accepts `network` / `subnetwork` as either a name
or a self_link. The root rewrites names to self_links only when they match a
resource you are creating right now:
```hcl
contains(keys(local._created_vpc_selflinks), try(cfg.network, ""))
  ? { network = local._created_vpc_selflinks[cfg.network] }
  : {}
```
Unmatched values pass through, so `network = "default"` keeps working for VMs
on the auto-created default network.
## Outputs
- `projects`, `vpc_networks`, `subnets`, `compute_instances`, `storage_buckets`
  — full attribute maps from each module.
- `compute_passwords` — sensitive; retrieve with
  `terraform -chdir=examples/composition output -json compute_passwords`.
- `ssh_commands` — copy-paste SSH commands per instance.
## Requirements
- Every API used must be enabled on the target GCP project:
  - `compute.googleapis.com` (VPC + VM)
  - `storage.googleapis.com` (bucket) — on by default
  - `cloudresourcemanager.googleapis.com` (projects module) — on by default
- Quota for VMs/networks in the target project/region.
- `GOOGLE_PROJECT` / `GOOGLE_REGION` / `GOOGLE_ZONE` env vars set, or
  `gcloud config` configured. See `beginning_journey/setup_env.sh`.
## Destroy
```bash
terraform -chdir=examples/composition destroy -auto-approve
```
