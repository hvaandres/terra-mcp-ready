# terra-mcp-ready

Reusable Terraform modules for Azure with a **JSON-block configuration model** and **MCP/AI-friendly schemas**.

## The idea

Traditional Terraform consumption requires managing dozens of individual variables spread across multiple `.tfvars` files. This repo flips that: **one `terraform.tfvars` file, one block per resource**.

```hcl
# This is all a consumer writes — no variables to learn, no files to manage
resource_groups = {
  rg-networking-dev = {
    location = "eastus2"
    tags     = { Environment = "dev", Team = "platform" }
  }
  rg-app-prod = {
    location = "westus2"
    lock     = true
  }
}
```

Each module accepts a `map(object({...}))` where the **map key is the resource name** and the object contains the configuration. Sensible defaults mean you only specify what you need.

## How to consume (from another repo)

```hcl
module "resource_groups" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/resource_group?ref=v1.0.0"

  resource_groups = var.resource_groups
}
```

Then define your `terraform.tfvars` with the blocks you need. That's it.

## MCP / AI integration

Every module ships a `schema.json` ([JSON Schema draft-07](https://json-schema.org/draft-07/json-schema-release-notes.html)) that describes its input contract in a machine-readable format. MCP servers and AI tools can:

1. **Discover** available modules by scanning `modules/*/schema.json`
2. **Read** the schema to understand required/optional fields and defaults
3. **Generate** valid `terraform.tfvars` blocks without parsing HCL
4. **Validate** user input before `terraform plan`

See [`schemas/README.md`](schemas/README.md) for the full convention.

## Module catalog

| Module | Description | Status |
|--------|-------------|--------|
| [`resource_group`](modules/resource_group/) | Azure Resource Groups with optional locks | ✅ Available |

## Repository structure

```
terra-mcp-ready/
├── modules/
│   └── resource_group/        # Each module is self-contained
│       ├── main.tf
│       ├── variables.tf       # Single map(object) input
│       ├── outputs.tf         # Standardized map output
│       ├── versions.tf
│       ├── schema.json        # Machine-readable contract
│       └── README.md
├── examples/
│   └── resource_groups/       # Runnable example with sample tfvars
├── schemas/
│   └── README.md              # Schema authoring convention
└── README.md
```

## Design principles

- **Map-in / map-out** — Every module takes a map and returns a map keyed by the same keys.
- **Key = name** — The map key is the Azure resource name. No separate `name` field.
- **Defaults everywhere** — Only truly required fields (like `location`) are mandatory.
- **Schema-first** — `schema.json` is a first-class deliverable, not an afterthought.
- **Versioned** — Consumers pin to git tags (`?ref=v1.0.0`). Breaking changes bump the major version.

## Versioning

- Semantic versioning via git tags: `v1.0.0`, `v1.1.0`, etc.
- Consumers pin module source refs to a specific tag.
- `versions.tf` in each module constrains Terraform (`>= 1.5, < 2.0`) and providers (`azurerm ~> 4.0`).
- Breaking changes to the variable shape require a major version bump.

## Requirements

| Tool | Version |
|------|--------|
| Terraform | >= 1.5 |
| Azure CLI | latest |
| azurerm provider | ~> 4.0 |

## Quick start

```bash
# Clone and try the example
git clone https://github.com/<org>/terra-mcp-ready.git
cd terra-mcp-ready/examples/resource_groups

# Login to Azure
az login

# Init and plan
terraform init
terraform plan
```
