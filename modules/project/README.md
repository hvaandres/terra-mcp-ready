# GCP Project Module

Provisions one or more Google Cloud Projects from a single `map(object)` variable.

## Usage

```hcl
module "projects" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/project?ref=v1.0.0"

  projects = {
    my-app-dev-123 = {
      name            = "My App (Dev)"
      folder_id       = "folders/123456789012"
      billing_account = "0X0X0X-0X0X0X-0X0X0X"
      labels          = { environment = "dev", team = "platform" }
    }
    my-app-prod-123 = {
      name            = "My App (Prod)"
      folder_id       = "folders/123456789012"
      billing_account = "0X0X0X-0X0X0X-0X0X0X"
      labels          = { environment = "prod", team = "app" }
      lock            = true
    }
  }
}
```

## Input

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `name` | `string` | no | `""` | Display name; falls back to the project_id |
| `folder_id` | `string` | no | `""` | Parent folder (`folders/NNN`); mutually exclusive with `org_id` |
| `org_id` | `string` | no | `""` | Parent organization ID; mutually exclusive with `folder_id` |
| `billing_account` | `string` | no | `""` | Billing account for the project |
| `labels` | `map(string)` | no | `{}` | Project labels |
| `auto_create_network` | `bool` | no | `false` | Create the default VPC network |
| `lock` | `bool` | no | `false` | Attach a deletion lien |
| `deletion_policy` | `string` | no | `"DELETE"` | One of `DELETE`, `PREVENT`, `ABANDON` |

The **map key** is used as the `project_id`.

## Outputs

| Name | Description |
|------|-------------|
| `projects` | Full map: `{ project_id => { id, project_id, number, name, labels } }` |
| `ids` | Shorthand: `{ project_id => fully-qualified resource id }` |
| `numbers` | Shorthand: `{ project_id => numeric project number }` |

## MCP / AI Integration

The file `schema.json` contains a JSON Schema (draft-07) describing the input contract.
AI tools and MCP servers can read this file to generate valid `terraform.tfvars` blocks without parsing HCL.

## Validation

- Project IDs: 6–30 characters, lowercase letter first, lowercase letters / digits / hyphens, cannot end with a hyphen.
- A project may specify either `folder_id` or `org_id`, but not both.
- `deletion_policy` must be one of `DELETE`, `PREVENT`, `ABANDON`.
## Label rules (GCP)
Labels (either in `labels = { ... }` or as flat keys on the entry) must follow Google Cloud's label restrictions. Invalid labels are rejected by GCP at `terraform apply` time with `Error 400`.
| Rule | Key | Value |
|---|---|---|
| Length | 1–63 chars | 0–63 chars (empty OK) |
| Charset | lowercase `a–z`, digits `0–9`, `-`, `_` | same |
| First char | must be a lowercase letter | any of the above |
| Max per resource | 64 labels total | — |
### ✓ Allowed
```
environment=prod
team=platform
owner=aharo
cost_center=eng-1234
managed_by=terraform
```
### ✗ Rejected
| Input | Reason |
|---|---|
| `Environment=prod` | uppercase in key |
| `environment=Prod` | uppercase in value |
| `contact=user@example.com` | `@` and `.` forbidden |
| `version=1.2.3` | `.` forbidden |
| `team=a/b` | `/` forbidden |
| `1st-team=prod` | key must start with a letter |
| `owner=Alan Haro` | space + uppercase |
### Safe substitutions
| You want | Store as |
|---|---|
| Email `user@example.com` | `contact_user=user`, `contact_domain=example_com` |
| Version `1.2.3` | `version=v1-2-3` or `version=1_2_3` |
| Date `2026-04-23` | `created=2026-04-23` (hyphens are fine) |
