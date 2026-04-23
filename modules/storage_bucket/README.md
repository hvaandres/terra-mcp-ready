# GCS Storage Bucket Module

Provisions one or more Google Cloud Storage buckets from a single `map(object)` variable.

## Usage

```hcl
module "storage_buckets" {
  source = "git::https://github.com/<org>/terra-mcp-ready.git//modules/storage_bucket?ref=v1.0.0"

  storage_buckets = {
    my-app-assets-dev = {
      location      = "US"
      storage_class = "STANDARD"
      labels        = { environment = "dev", team = "platform" }
    }
    my-app-backups-prod = {
      location           = "us-central1"
      storage_class      = "NEARLINE"
      versioning         = true
      retention_days     = 30
      lifecycle_age_days = 365
      labels             = { environment = "prod", team = "app" }
    }
  }
}
```

## Input

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `location` | `string` | **yes** | — | Multi-region (`US`), dual-region, or region (`us-central1`) |
| `project` | `string` | no | `""` | Overrides the provider's default project |
| `storage_class` | `string` | no | `"STANDARD"` | One of `STANDARD`, `NEARLINE`, `COLDLINE`, `ARCHIVE` |
| `force_destroy` | `bool` | no | `false` | Allow destroy even if bucket has objects |
| `uniform_bucket_level_access` | `bool` | no | `true` | Disable ACLs, use IAM only |
| `versioning` | `bool` | no | `false` | Enable object versioning |
| `labels` | `map(string)` | no | `{}` | Bucket labels |
| `retention_days` | `number` | no | `0` | Retention policy (days); 0 disables |
| `lifecycle_age_days` | `number` | no | `0` | Lifecycle delete rule (days); 0 disables |

The **map key** is used as the bucket name (must be globally unique).

## Outputs

| Name | Description |
|------|-------------|
| `buckets` | Full map: `{ name => { id, name, url, self_link, location, labels } }` |
| `names` | Shorthand: `{ name => name }` |
| `urls` | Shorthand: `{ name => gs:// URL }` |

## MCP / AI Integration

The file `schema.json` contains a JSON Schema (draft-07) describing the input contract.
AI tools and MCP servers can read this file to generate valid `terraform.tfvars` blocks without parsing HCL.

## Validation

- Bucket names: 3–63 characters, lowercase alphanumeric / hyphens / underscores / periods, must start and end with letter or digit.
- `storage_class` must be one of `STANDARD`, `NEARLINE`, `COLDLINE`, `ARCHIVE`.
- `retention_days` and `lifecycle_age_days` must be non-negative.
## Label rules (GCP)
Labels (either in the `labels = { ... }` map or as flat keys next to `location`) must follow Google Cloud's label restrictions. Invalid labels are rejected by GCP at `terraform apply` time with `Error 400`, so it's worth knowing the rules up front.
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
app_version=v1-2-3
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
| Name `GDG` | `owner=gdg` (lowercase) |
