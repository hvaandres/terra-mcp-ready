# Resource Group Module

Provisions one or more Azure Resource Groups from a single `map(object)` variable.

## Usage

```hcl
module "resource_groups" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/resource_group?ref=v1.0.0"

  resource_groups = {
    rg-networking-dev = {
      location = "eastus2"
      tags     = { Environment = "dev", Team = "platform" }
    }
    rg-app-prod = {
      location = "westus2"
      tags     = { Environment = "prod", Team = "app" }
      lock     = true
    }
  }
}
```

## Input

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `location` | `string` | **yes** | — | Azure region |
| `tags` | `map(string)` | no | `{}` | Tags applied to the resource group |
| `lock` | `bool` | no | `false` | Apply a CanNotDelete management lock |
| `managed_by` | `string` | no | `""` | Resource ID of the managing resource |

The **map key** is used as the resource group name.

## Outputs

| Name | Description |
|------|-------------|
| `resource_groups` | Full map: `{ name => { id, name, location, tags } }` |
| `ids` | Shorthand: `{ name => id }` |
| `names` | Shorthand: `{ name => name }` |

## MCP / AI Integration

The file `schema.json` contains a JSON Schema (draft-07) describing the input contract.
AI tools and MCP servers can read this file to generate valid `terraform.tfvars` blocks without parsing HCL.

## Validation

- Resource group names: 1–90 characters, alphanumeric/hyphens/underscores/periods/parentheses, cannot end with a period.
- Location is validated by the `azurerm` provider at plan time.
