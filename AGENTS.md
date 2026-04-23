# AGENTS.md — Guide for MCP Servers and LLMs
This file is the single entry point for AI agents (MCP servers, LLMs, Copilot-style assistants) that want to **consume, generate, validate, or extend** the Terraform modules in this repository. It is written as a contract, not a tutorial — every paragraph describes a rule or a deterministic workflow step so an automated caller can rely on it.
## 1. Repository contract
The repo publishes reusable Terraform modules for **Google Cloud Platform**. Every module follows the same shape so that any tool can treat them uniformly:
- **Single `map(object)` input variable.** Consumers only ever set one variable per module. The map key is the resource's natural identifier (e.g. `project_id`, bucket name). The map value is the per-resource configuration.
- **`type = any` + `locals` normalization.** The Terraform variable is typed `any` so the module can accept two equivalent tfvars shapes — an explicit `labels = {...}` object, or a flat form where any non-reserved key becomes a label. Both compile to the same underlying resource.
- **Every module ships a `schema.json`.** This is the machine-readable contract (JSON Schema draft-07 + a `_meta` extension). Agents MUST read the schema to know what fields exist, which are required, what the enum / default / regex constraints are, and which keys are reserved (not labels).
- **Map-in, map-out outputs.** Every module exposes outputs keyed by the same map keys the consumer provided.
## 2. Discover available modules
Every module directory is `modules/<name>/` and ships a `schema.json`. To enumerate:
```bash
for s in modules/*/schema.json; do
  jq -r '[.title, ._meta.variable_name, ._meta.module_source] | @tsv' "$s"
done
```
The current catalog:
| Module dir | Variable name | Title |
|---|---|---|
| `modules/project` | `projects` | GCP Project Module |
| `modules/storage_bucket` | `storage_buckets` | GCS Storage Bucket Module |
| `modules/vpc_network` | `vpc_networks` | GCP VPC Network Module |
| `modules/compute_instance` | `compute_instances` | GCP Compute Instance Module |

In addition, `examples/composition/` is a root module that consumes ALL modules together and accepts a single tfvars with keys `projects`, `vpc_networks`, `compute_instances`, `storage_buckets`. It auto-rewrites `compute_instances[*].network` and `.subnetwork` to the `self_link` of a same-apply VPC/subnet when the value matches — agents can therefore generate a combined tfvars whose VMs reference newly-created VPCs by name without resorting to remote-state lookups.
## 3. Schema contract
Every `schema.json` is a JSON Schema draft-07 document with this shape:
```
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id":     "terra-mcp-ready/modules/<name>",
  "title":   "<Human-readable title>",
  "description": "...",
  "type": "object",
  "additionalProperties": { "$ref": "#/$defs/<name>_config" },
  "$defs": {
    "<name>_config": {
      "type": "object",
      "properties": { ... },
      "required": [ ... ],
      "additionalProperties": false
    }
  },
  "_meta": {
    "module_source":     "git::https://.../modules/<name>",
    "variable_name":     "<name>s",
    "output_keys":       ["..."],
    "terraform_version": ">= 1.5, < 2.0",
    "provider":          "google ~> 6.0",
    "reserved_keys":     ["location", "project", "..."],
    "key_spec": {
      "label":       "bucket name",
      "regex":       "^[a-z0-9][-a-z0-9_.]{1,61}[a-z0-9]$",
      "description": "...",
      "examples":    ["my-app-assets-dev", "..."]
    }
  }
}
```
Agents MUST treat the `_meta` block as authoritative:
- `variable_name` — the top-level key in the tfvars file.
- `output_keys` — the names of the module's Terraform outputs.
- `reserved_keys` — object keys that are structured fields. **Any key NOT in this list is a label.**
- `key_spec` — the rules for the map key itself (not a property of the value; it's the resource's natural identifier). Validate user-provided map keys against `key_spec.regex`.
## 4. Generate a tfvars.json programmatically
The canonical output format is `.tfvars.json`. Here is the deterministic recipe:
1. Load the schema and extract `variable_name`, `reserved_keys`, `key_spec`.
2. For each resource the user wants, validate its intended map key against `key_spec.regex`. Reject and re-prompt on mismatch.
3. Build a per-resource object:
   - Copy each **reserved** key the user supplied as its typed value (string, bool, number).
   - Copy each **non-reserved** key as a label string (validate against GCP label rules — see §7).
4. Wrap into `{ "<variable_name>": { "<key1>": {...}, "<key2>": {...} } }`.
5. Write the JSON to `<somewhere>.tfvars.json`.
Minimum valid example for `storage_bucket`:
```json
{
  "storage_buckets": {
    "my-bucket-dev": {
      "location": "US",
      "environment": "dev"
    }
  }
}
```
The flat key `environment` is automatically treated as a label by the module because it is not in `_meta.reserved_keys`.
## 5. Validate generated output
Three layers of validation, in order:
1. **JSON well-formedness** — `jq empty <file>` must exit 0.
2. **Schema conformance** — run your own JSON Schema validator against `schema.json` (optional but recommended). Note: labels in the flat form will appear as extra properties; accept them even though `additionalProperties: false` on the schema disallows them. The module's Terraform code is the ultimate validator; the schema describes the **explicit** form.
3. **Terraform validate** — `terraform -chdir=examples/<var_name> validate` catches variable-validation rule violations (regex, enum, range).
4. **Optional plan** — `terraform -chdir=examples/<var_name> plan -var-file=<file>` catches provider-side issues (duplicate names, permission errors, invalid locations).
## 6. Apply / destroy flow
```bash
# From the repo root:
terraform -chdir=examples/<variable_name> plan  -var-file=/abs/path/file.tfvars.json
terraform -chdir=examples/<variable_name> apply -var-file=/abs/path/file.tfvars.json
terraform -chdir=examples/<variable_name> destroy -var-file=/abs/path/file.tfvars.json
```
`-chdir` is a **global** flag and must come before the subcommand.
To save and later apply an exact plan:
```bash
terraform -chdir=examples/<name> plan  -var-file=file.tfvars.json -out=tfplan
terraform -chdir=examples/<name> apply tfplan        # positional; no -var-file
```
To apply MULTIPLE modules in one pass (e.g. VPC + VM + bucket together), target `examples/composition/` and pass a tfvars whose top-level keys combine every module's `variable_name`:
```bash
terraform -chdir=examples/composition plan  -var-file=/abs/path/all.tfvars.json -out=tfplan
terraform -chdir=examples/composition apply tfplan
```
## 7. GCP label rules (summary)
Both label keys and values share the charset `[a-z0-9_-]`. Differences:
| Rule | Key | Value |
|---|---|---|
| Length | 1–63 chars | 0–63 chars (empty allowed) |
| First char | must be a lowercase letter | any allowed char |
| Max per resource | 64 labels total | — |
NOT allowed anywhere: uppercase, spaces, `.`, `@`, `/`, `:`, `+`, `=`, `!`.
Safe substitutions:
- Email `user@example.com` → two labels: `contact_user=user`, `contact_domain=example_com`
- Version `1.2.3` → `version=v1-2-3` or `version=1_2_3`
## 8. Environment variables an agent should set
Before `plan/apply`, export:
| Var | Purpose |
|---|---|
| `GOOGLE_PROJECT` / `GOOGLE_CLOUD_PROJECT` | Default project for the `google` provider |
| `GOOGLE_REGION` | Default region |
| `GOOGLE_ZONE` | Default zone |
| `GOOGLE_APPLICATION_CREDENTIALS` | Optional service-account key path (leave unset to use ADC) |
| `GOOGLE_BILLING_ACCOUNT` | Used by `modules/project` to set each new project's billing |
The repo ships `beginning_journey/setup_env.sh` which writes these to `beginning_journey/.env` — agents can source that file or write it programmatically.
## 9. Interactive helper (for humans; agents can skip)
`scripts/scaffold_tfvars.sh` is a schema-driven interactive tfvars builder. Agents don't need it — they can generate tfvars directly from the schema as described in §4. It exists to guide humans through the same workflow.
## 10. Authoring a new module
To add `modules/<new>/` and keep the contract intact:
### 10.1 Required files
```
modules/<new>/
├── main.tf
├── variables.tf   # variable "<new>s" with type = any
├── outputs.tf     # map-in / map-out
├── versions.tf    # pin terraform + google provider
├── schema.json    # see §3
└── README.md      # usage + label rules section
```
### 10.2 `variables.tf` pattern
```hcl
variable "<new>s" {
  description = "..."
  type        = any
  default     = {}
  validation {
    condition     = alltrue([ for k, _ in var.<new>s : can(regex("<key_regex>", k)) ])
    error_message = "..."
  }
  # More validation {} blocks for enum / range constraints
}
```
### 10.3 `main.tf` pattern — normalize, then create
```hcl
locals {
  _reserved_keys = ["field_a", "field_b", "labels"]
  _items = {
    for k, cfg in var.<new>s : k => {
      field_a = cfg.field_a
      field_b = try(cfg.field_b, "<default>")
      labels  = merge(
        try(cfg.labels, {}),
        { for kk, vv in cfg : kk => tostring(vv) if !contains(local._reserved_keys, kk) },
      )
    }
  }
}
resource "google_<type>" "this" {
  for_each = local._items
  name     = each.key
  # ...map each.value.field_* to provider args...
  labels   = each.value.labels
}
```
### 10.4 `outputs.tf` pattern — always map-in / map-out
```hcl
output "<new>s" {
  description = "Map of <key> to attributes."
  value = {
    for k, r in google_<type>.this : k => {
      id     = r.id
      name   = r.name
      labels = r.effective_labels
    }
  }
}
```
### 10.5 `schema.json` checklist
- `$schema`, `$id`, `title`, `description`, `type: "object"`
- `additionalProperties` → `$ref` to `#/$defs/<new>_config`
- `$defs.<new>_config` with `properties`, `required`, `additionalProperties: false`
- `_meta` with EVERY required field from §3, including `reserved_keys` and `key_spec`
### 10.6 Register the module in tooling
1. Add `examples/<new>s/` with `main.tf`, `variables.tf` (type = any), `outputs.tf`, `terraform.tfvars`.
2. Add `tests/<new>/` with harness + `fixtures/{valid,minimal,empty,invalid_*}.tfvars`.
3. Add directories to the `fmt_dirs` array and the `validate_harness` calls in `scripts/run_tests.sh`.
4. Add a row to the **Module catalog** table in the top-level `README.md`.
5. Re-run `./scripts/run_tests.sh` and confirm all tests pass.
## 11. Exit criteria for an MCP-ready tool built on this repo
A tool/agent using this repo is "correct" if it:
- Lists modules by globbing `modules/*/schema.json` (does not hardcode).
- Reads all required input fields from the schema (not from prose).
- Generates `.tfvars.json` that `jq empty` and `terraform validate` both accept.
- Treats any key not in `_meta.reserved_keys` as a flat label (and validates it against GCP label rules).
- Uses `_meta.variable_name` to name the top-level JSON key and `_meta.key_spec.regex` to validate each map key.
- Never hardcodes module-specific knowledge that is already in the schema.
If all six hold, adding a new module requires zero changes to the tool.
