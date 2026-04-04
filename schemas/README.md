# Schema Convention

Every module in this repository ships a `schema.json` file alongside its Terraform code.
These schemas follow [JSON Schema draft-07](https://json-schema.org/draft-07/json-schema-release-notes.html) and serve as machine-readable contracts for the module's input variable.

## Purpose

- **MCP servers** can read schemas to understand what configuration a module expects and generate valid `terraform.tfvars` blocks.
- **AI tools** can use schemas to auto-complete, validate, or scaffold infrastructure configurations without parsing HCL.
- **CI pipelines** can validate tfvars input against schemas before running `terraform plan`.

## Convention

Each module's `schema.json` describes the shape of the **map values** — since every module in this repo uses the pattern:

```hcl
variable "<resource_type>s" {
  type = map(object({ ... }))
}
```

The schema describes what goes inside each map entry.

### Required sections

1. **Standard JSON Schema fields** — `$schema`, `title`, `description`, `type`, `properties`, `required`
2. **`_meta` block** — non-standard but expected by tooling:
   - `module_source` — git URL template for sourcing the module
   - `variable_name` — the Terraform variable this schema describes
   - `output_keys` — list of output names the module exports
   - `terraform_version` — version constraint
   - `provider` — provider and version constraint

## Adding a schema for a new module

1. Create `modules/<your_module>/schema.json`
2. Follow an existing schema (e.g. `modules/resource_group/schema.json`) as a template
3. Include all fields from the `type = map(object({...}))` variable definition
4. Mark `required` fields and provide `default` values for optional ones
5. Add the `_meta` block
