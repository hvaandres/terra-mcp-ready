# terra-mcp-ready (Google Cloud)

Reusable Terraform modules for Google Cloud with a **JSON-block configuration model** and **MCP/AI-friendly schemas**.

## The idea

Traditional Terraform consumption requires managing dozens of individual variables spread across multiple `.tfvars` files. This repo flips that: **one `terraform.tfvars` file, one block per resource**. No variables to learn — just the resource objects you need.

```hcl
# This is all a consumer writes — no variables to learn, no files to manage
projects = {
  platform-dev-1234 = {
    name            = "Platform (Dev)"
    folder_id       = "folders/123456789012"
    billing_account = "0X0X0X-0X0X0X-0X0X0X"
    labels          = { environment = "dev", team = "platform" }
  }
  app-prod-1234 = {
    name            = "Application (Prod)"
    folder_id       = "folders/123456789012"
    billing_account = "0X0X0X-0X0X0X-0X0X0X"
    labels          = { environment = "prod", team = "app" }
    lock            = true
  }
}
```

Each module accepts a `map(object({...}))` where the **map key is the resource's natural identifier** (project_id, bucket name, etc.) and the object contains the configuration. Sensible defaults mean you only specify what you need.

## How to consume (from another repo)

```hcl
module "projects" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/project?ref=v1.0.0"

  projects = var.projects
}

module "storage_buckets" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/storage_bucket?ref=v1.0.0"

  storage_buckets = var.storage_buckets
}
```

Then define your `terraform.tfvars` with the blocks you need. That's it.

## MCP / AI integration

Every module ships a `schema.json` ([JSON Schema draft-07](https://json-schema.org/draft-07/json-schema-release-notes.html)) that describes its input contract in a machine-readable format. MCP servers and AI tools can:

1. **Discover** available modules by scanning `modules/*/schema.json`
2. **Read** the schema to understand required/optional fields and defaults
3. **Generate** valid `terraform.tfvars` blocks without parsing HCL
4. **Validate** user input before `terraform plan`

**For agent/LLM/MCP consumers, read [`AGENTS.md`](AGENTS.md) first** — it is the single-page, machine-readable contract for discovery, generation, validation, and authoring. See [`schemas/README.md`](schemas/README.md) for the schema convention.

## Module catalog

| Module | Description | Status |
|--------|-------------|--------|
| [`project`](modules/project/) | GCP Projects with optional deletion liens | ✅ Available |
| [`storage_bucket`](modules/storage_bucket/) | GCS Buckets with versioning, retention, and lifecycle rules | ✅ Available |
| [`vpc_network`](modules/vpc_network/) | VPC networks + nested subnets + opt-in `allow_ssh` firewall | ✅ Available |
| [`compute_instance`](modules/compute_instance/) | Ubuntu 24.04 VMs with a Terraform-generated admin user and random password | ✅ Available |

## Composition example

For end-to-end scenarios where multiple resource types need to be provisioned together (for example, VPC → VM referencing that VPC → bucket in one apply), use [`examples/composition/`](examples/composition/). It wires every module under a single root that accepts one tfvars file whose top-level keys match each module's `variable_name` — the same shape the multi-module mode of [`scripts/scaffold_tfvars.sh`](scripts/scaffold_tfvars.sh) emits.

```bash
# Generate a combined tfvars with the scaffolder (or write it by hand)
./scripts/scaffold_tfvars.sh

# Apply the whole stack at once
terraform -chdir=examples/composition init
terraform -chdir=examples/composition plan -var-file=$PWD/generated.tfvars.json -out=tfplan
terraform -chdir=examples/composition apply tfplan
```

## Repository structure

```
terra-mcp-ready/
├── modules/
│   ├── project/                # GCP Project module
│   │   ├── main.tf
│   │   ├── variables.tf        # Single map(object) input
│   │   ├── outputs.tf          # Standardized map output
│   │   ├── versions.tf
│   │   ├── schema.json         # Machine-readable contract
│   │   └── README.md
│   └── storage_bucket/         # GCS Bucket module (same layout)
├── examples/
│   ├── projects/               # Runnable example with sample tfvars
│   └── storage_buckets/
├── tests/
│   ├── project/
│   └── storage_bucket/
├── schemas/
│   └── README.md               # Schema authoring convention
├── scripts/
│   └── run_tests.sh
├── beginning_journey/          # Environment setup scripts
└── README.md
```

## Design principles

- **Map-in / map-out** — Every module takes a map and returns a map keyed by the same keys.
- **Key = identifier** — The map key is the resource's natural ID (project_id, bucket name). No separate `name` field.
- **Defaults everywhere** — Only truly required fields (like `location` for buckets) are mandatory.
- **Schema-first** — `schema.json` is a first-class deliverable, not an afterthought.
- **Versioned** — Consumers pin to git tags (`?ref=v1.0.0`). Breaking changes bump the major version.

## Versioning

- Semantic versioning via git tags: `v1.0.0`, `v1.1.0`, etc.
- Consumers pin module source refs to a specific tag.
- `versions.tf` in each module constrains Terraform (`>= 1.5, < 2.0`) and providers (`google ~> 6.0`).
- Breaking changes to the variable shape require a major version bump.

## Requirements

| Tool | Version |
|------|--------|
| Terraform | >= 1.5 |
| gcloud CLI | latest |
| google provider | ~> 6.0 |

## Quick start

```bash
# Clone and try the example
git clone https://github.com/<org>/terra-mcp-ready.git
cd terra-mcp-ready/examples/projects

# Login to Google Cloud (for Application Default Credentials)
gcloud auth application-default login
gcloud config set project "<YOUR_PROJECT_ID>"

# Init and plan
terraform init
terraform plan
```
