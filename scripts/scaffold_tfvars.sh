#!/usr/bin/env bash
###############################################################################
# scaffold_tfvars.sh — Interactive tfvars builder
#
# Optional helper. If you don't run this, terraform plan/apply continues to use
# the tfvars file already checked into examples/<module>/.
#
# What it does:
#   1. Asks which module you want (reads modules/*/schema.json for the list).
#   2. Reads that module's schema to know the fields and defaults.
#   3. Prompts for one or more resource blocks, field-by-field.
#   4. Any field you leave blank is omitted so the module default applies.
#   5. Collects free-form labels (flat-keys convention — no "labels: {}" wrapping).
#   6. Assembles a valid .tfvars.json, validates the JSON, and writes it.
#   7. Prints the exact `terraform plan -var-file=...` command to run next.
#
# Usage:
#   ./scripts/scaffold_tfvars.sh                         # fully interactive
#   ./scripts/scaffold_tfvars.sh --module storage_bucket # skip module prompt
#   ./scripts/scaffold_tfvars.sh -m project -o /tmp/p.tfvars.json
###############################################################################

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# ---------------------------------------------------------------------------
# CLI args
# ---------------------------------------------------------------------------

MODULE=""
OUTPUT=""

while [ $# -gt 0 ]; do
  case "$1" in
    -m|--module) MODULE="$2"; shift 2 ;;
    -o|--output) OUTPUT="$2"; shift 2 ;;
    -h|--help)
      grep -E "^#" "$0" | sed 's/^# \{0,1\}//;s/^#//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
cyan()   { printf "\033[36m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
dim()    { printf "\033[2m%s\033[0m\n" "$*"; }

prompt() {
  # prompt "label" "default" → sets REPLY
  local label="$1" default="${2:-}" line
  if [ -n "$default" ]; then
    read -r -p "$label [$default]: " line || exit 1
  else
    read -r -p "$label: " line || exit 1
  fi
  REPLY="${line:-$default}"
}

die() { red "$*"; exit 1; }

command -v jq >/dev/null 2>&1 || die "jq is required. Install it first."

# ---------------------------------------------------------------------------
# Step 1: Pick a module
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Interactive tfvars builder"
bold "═══════════════════════════════════════════════════════════════"
echo ""

# Discover modules from schema.json presence
modules=()
for schema in "$REPO_ROOT"/modules/*/schema.json; do
  [ -f "$schema" ] || continue
  modules+=("$(basename "$(dirname "$schema")")")
done

[ "${#modules[@]}" -gt 0 ] || die "No modules with schema.json found under $REPO_ROOT/modules."

if [ -z "$MODULE" ]; then
  cyan "Available modules:"
  for i in "${!modules[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${modules[$i]}"
  done
  prompt "Pick one" "1"
  idx=$((REPLY - 1))
  if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#modules[@]}" ]; then
    die "Invalid selection."
  fi
  MODULE="${modules[$idx]}"
fi

SCHEMA="$REPO_ROOT/modules/$MODULE/schema.json"
[ -f "$SCHEMA" ] || die "schema.json not found at $SCHEMA"

green "Using module: $MODULE"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Parse the schema
# ---------------------------------------------------------------------------

VAR_NAME=$(jq -r '._meta.variable_name' "$SCHEMA")
DEFS_REF=$(jq -r '.additionalProperties["$ref"] // empty' "$SCHEMA")
DEFS_KEY="${DEFS_REF##*/}"

if [ -z "$DEFS_KEY" ]; then
  die "Could not resolve per-entry schema (expected additionalProperties.\$ref → #/\$defs/...)."
fi

# Pull the per-module key spec (regex, label, examples, description).
KEY_LABEL=$(jq -r '._meta.key_spec.label // "name"' "$SCHEMA")
KEY_REGEX=$(jq -r '._meta.key_spec.regex // ""' "$SCHEMA")
KEY_DESC=$(jq  -r '._meta.key_spec.description // ""' "$SCHEMA")
KEY_EXAMPLES=$(jq -r '._meta.key_spec.examples // [] | join(", ")' "$SCHEMA")

# Produce TSV lines. Because bash `read` with IFS=tab collapses consecutive
# tabs, we replace empty fields with the sentinel __EMPTY__ and strip it back
# out inside the loop.
FIELD_TSV=$(
  jq -r --arg k "$DEFS_KEY" '
    def nz: if . == "" then "__EMPTY__" else . end;
    (.["$defs"][$k].required // []) as $req
    | .["$defs"][$k].properties
    | to_entries[]
    | [
        .key,
        ((.value.type // "string") | nz),
        (([.key] | inside($req)) | tostring),
        ((.value.default // "") | tostring | nz),
        ((.value.enum // []) | map(tostring) | join(" ") | nz),
        ((.value.description // "") | gsub("\t"; " ") | nz)
      ]
    | @tsv
  ' "$SCHEMA"
)

# Load TSV lines into an array so the prompt loop below doesn't redirect stdin.
FIELD_LINES=()
while IFS= read -r _line; do
  [ -n "$_line" ] && FIELD_LINES+=("$_line")
done <<< "$FIELD_TSV"

# ---------------------------------------------------------------------------
# Step 3: Loop over resources
# ---------------------------------------------------------------------------

bold "── Add resources ─────────────────────────────────────────────"
echo "The map key is the resource's natural ID (project_id, bucket name, etc.)."
echo "Leave any optional field blank to accept the module default."
echo ""

entries='{}'
resource_count=0

while true; do
  resource_count=$((resource_count + 1))
  echo ""
  cyan "Resource #$resource_count"

  # Resource key (module-specific: project_id, bucket name, etc.)
  if [ -n "$KEY_DESC" ]; then
    dim "  $KEY_DESC"
  fi
  if [ -n "$KEY_EXAMPLES" ]; then
    dim "  examples: $KEY_EXAMPLES"
  fi

  while true; do
    prompt "  $KEY_LABEL"
    if [ -z "$REPLY" ]; then
      red "  $KEY_LABEL cannot be empty."
      continue
    fi
    if [ -n "$KEY_REGEX" ] && ! printf '%s' "$REPLY" | grep -qE "$KEY_REGEX"; then
      red "  '$REPLY' is not a valid $KEY_LABEL."
      [ -n "$KEY_DESC" ] && red "  $KEY_DESC"
      continue
    fi
    RES_KEY="$REPLY"
    break
  done

  # Build entry JSON by iterating schema fields
  entry='{}'

  for _field_line in "${FIELD_LINES[@]}"; do
    IFS=$'\t' read -r f_name f_type f_required f_default f_enum f_desc <<< "$_field_line"
    # Strip the __EMPTY__ sentinel so downstream checks see a real empty string.
    [ "$f_default" = "__EMPTY__" ] && f_default=""
    [ "$f_enum" = "__EMPTY__" ]    && f_enum=""
    [ "$f_desc" = "__EMPTY__" ]    && f_desc=""
    [ -z "$f_name" ] && continue
    # Skip object-typed fields (e.g. labels) — covered by the flat-keys prompt below.
    [ "$f_type" = "object" ] && continue
    [ "$f_type" = "array" ] && continue

    # Build hint
    hint=""
    if [ -n "$f_enum" ]; then
      hint=" ${f_enum// /|}"
    fi
    if [ "$f_required" = "true" ]; then
      hint="$hint (REQUIRED)"
    fi

    # Auto-suggest defaults from live environment where it makes sense
    suggest="$f_default"
    if [ "$f_name" = "project" ] && [ -z "$suggest" ]; then
      # Default to GOOGLE_PROJECT env var or gcloud's current project
      suggest="${GOOGLE_PROJECT:-${GOOGLE_CLOUD_PROJECT:-$(gcloud config get-value project 2>/dev/null || true)}}"
    fi

    # Show description once above prompt (dim)
    if [ -n "$f_desc" ]; then
      dim "    ($f_desc)"
    fi
    label="    $f_name [$f_type$hint]"

    while true; do
      prompt "$label" "$suggest"

      # Required fields must get a value
      if [ -z "$REPLY" ] && [ "$f_required" = "true" ]; then
        red "    $f_name is required."
        continue
      fi

      # If blank and not required → skip
      [ -z "$REPLY" ] && break

      # Enum validation
      if [ -n "$f_enum" ]; then
        # Space-separated list of allowed values
        ok=0
        for allowed_val in $f_enum; do
          [ "$allowed_val" = "$REPLY" ] && ok=1 && break
        done
        if [ "$ok" -eq 0 ]; then
          red "    Must be one of: ${f_enum// /|}"
          continue
        fi
      fi

      # Type coercion when building JSON
      case "$f_type" in
        boolean)
          case "$REPLY" in
            true|1|y|yes)  entry=$(echo "$entry" | jq --arg k "$f_name" '. + {($k): true}') ;;
            false|0|n|no)  entry=$(echo "$entry" | jq --arg k "$f_name" '. + {($k): false}') ;;
            *) red "    Boolean must be true/false."; continue ;;
          esac
          ;;
        number|integer)
          if ! [[ "$REPLY" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
            red "    Must be a number."
            continue
          fi
          entry=$(echo "$entry" | jq --arg k "$f_name" --argjson v "$REPLY" '. + {($k): $v}')
          ;;
        *)
          entry=$(echo "$entry" | jq --arg k "$f_name" --arg v "$REPLY" '. + {($k): $v}')
          ;;
      esac
      break
    done
  done

  # Extra labels (flat-keys style — they are NOT wrapped under "labels")
  #
  # GCP label rules (keys and values share the same charset):
  #   key   : start with lowercase letter; then [a-z0-9_-]; max 63 chars
  #   value : [a-z0-9_-]; 0–63 chars (empty allowed)
  #   NOT allowed: uppercase, spaces, '.', '@', '/', ':', '+', '=', '!', etc.
  echo ""
  echo "    Extra labels (flat keys, no wrapping)."
  echo "    ✓ allowed    : environment=prod   owner=aharo   cost_center=eng-1234"
  echo "    ✗ rejected   : owner=Alan (uppercase)     contact=a@b.dev ('@' and '.')"
  echo "                    team=a/b ('/')            version=1.2.3 ('.')"
  echo "    Tip: split emails into two labels (contact_user=aharo, contact_domain=aharo_dev)."
  echo "    Format: key=value. Blank line to finish."
  while true; do
    read -r -p "      > " lkv
    [ -z "$lkv" ] && break
    if ! [[ "$lkv" == *"="* ]]; then
      red "      Missing '=' separator."
      continue
    fi
    lk="${lkv%%=*}"
    lv="${lkv#*=}"
    if ! [[ "$lk" =~ ^[a-z][a-z0-9_-]{0,62}$ ]]; then
      red "      Invalid label key '$lk'. Must start with a lowercase letter; then lowercase letters, digits, '_' or '-'; max 63 chars."
      continue
    fi
    if ! [[ "$lv" =~ ^[a-z0-9_-]{0,63}$ ]]; then
      red "      Invalid label value '$lv'. Allowed: lowercase letters, digits, '_', '-'; max 63 chars. (No '@', '.', or uppercase.)"
      continue
    fi
    # Reject if the key is a reserved schema field name (would otherwise
    # clobber the structured field).
    if echo "$FIELD_TSV" | awk -F'\t' -v k="$lk" '$1==k{found=1} END{exit !found}'; then
      red "      '$lk' is a reserved field name for this module; use the prompt above instead."
      continue
    fi
    entry=$(echo "$entry" | jq --arg k "$lk" --arg v "$lv" '. + {($k): $v}')
  done

  # Merge into entries
  entries=$(echo "$entries" | jq --arg k "$RES_KEY" --argjson v "$entry" '. + {($k): $v}')

  echo ""
  prompt "Add another resource? (y/N)" "N"
  case "$REPLY" in
    y|Y|yes|YES) ;;
    *) break ;;
  esac
done

# ---------------------------------------------------------------------------
# Step 4: Assemble and validate
# ---------------------------------------------------------------------------

FINAL_JSON=$(echo "$entries" | jq --arg var "$VAR_NAME" '{($var): .}')

echo ""
bold "── Review ────────────────────────────────────────────────────"
echo "$FINAL_JSON" | jq .
echo ""

# Validate JSON
if ! echo "$FINAL_JSON" | jq empty >/dev/null 2>&1; then
  die "Generated JSON is not well-formed (bug)."
fi
green "✓ JSON is well-formed"

# Default output location based on module
case "$VAR_NAME" in
  projects)        DEFAULT_DIR="$REPO_ROOT/examples/projects" ;;
  storage_buckets) DEFAULT_DIR="$REPO_ROOT/examples/storage_buckets" ;;
  *)               DEFAULT_DIR="$REPO_ROOT" ;;
esac

if [ -z "$OUTPUT" ]; then
  prompt "Output path" "$DEFAULT_DIR/generated.tfvars.json"
  OUTPUT="$REPLY"
fi

if [ -e "$OUTPUT" ]; then
  prompt "$OUTPUT exists — overwrite? (y/N)" "N"
  case "$REPLY" in
    y|Y|yes|YES) ;;
    *) die "Aborted; existing file preserved." ;;
  esac
fi

echo "$FINAL_JSON" > "$OUTPUT"
green "✓ Wrote $OUTPUT"

# ---------------------------------------------------------------------------
# Step 5: Module-level validation (terraform validate against example dir)
# ---------------------------------------------------------------------------

echo ""
bold "── Validating module ─────────────────────────────────────────"

VALIDATE_DIR=""
case "$VAR_NAME" in
  projects)        VALIDATE_DIR="$REPO_ROOT/examples/projects" ;;
  storage_buckets) VALIDATE_DIR="$REPO_ROOT/examples/storage_buckets" ;;
esac

if [ -n "$VALIDATE_DIR" ] && [ -d "$VALIDATE_DIR" ]; then
  if [ ! -d "$VALIDATE_DIR/.terraform" ]; then
    echo "  Initializing $VALIDATE_DIR (one-time)..."
    terraform -chdir="$VALIDATE_DIR" init -backend=false >/dev/null 2>&1 || \
      yellow "  terraform init had warnings; continuing."
  fi

  if terraform -chdir="$VALIDATE_DIR" validate >/dev/null 2>&1; then
    green "✓ terraform validate passed on $(basename "$VALIDATE_DIR")"
  else
    red "✗ terraform validate FAILED on $(basename "$VALIDATE_DIR")"
    terraform -chdir="$VALIDATE_DIR" validate
    exit 1
  fi
else
  yellow "  No matching example dir for var '$VAR_NAME'; skipped terraform validate."
fi

# ---------------------------------------------------------------------------
# Step 6: Next steps
# ---------------------------------------------------------------------------

echo ""
bold "── Next ──────────────────────────────────────────────────────"
echo ""
if [ -n "$VALIDATE_DIR" ]; then
  cyan "  terraform -chdir=$VALIDATE_DIR plan -var-file=$OUTPUT"
  cyan "  terraform -chdir=$VALIDATE_DIR apply -var-file=$OUTPUT"
  echo ""
  if [ "$VAR_NAME" = "storage_buckets" ]; then
    dim "  Tip: export GOOGLE_PROJECT=<your-project-id> so buckets pick up the"
    dim "       default project from the provider without per-bucket 'project'."
  fi
fi
echo ""
green "Done."
