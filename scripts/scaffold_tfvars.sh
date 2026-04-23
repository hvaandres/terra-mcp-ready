#!/usr/bin/env bash
###############################################################################
# scaffold_tfvars.sh — Interactive tfvars builder (multi-module)
#
# Optional helper. If you don't run this, terraform plan/apply continues to use
# the tfvars file already checked into examples/<module>/.
#
# What it does:
#   1. Lets you pick a module (reads modules/*/schema.json for the list).
#   2. Prompts for one or more resources of that module.
#   3. When you're done with that module, offers to SWITCH to another module
#      so a single run can provision VPCs + VMs + buckets + projects together.
#   4. Any field you leave blank is omitted so the module default applies.
#   5. Collects free-form labels (flat-keys convention — no "labels: {}" wrapping).
#   6. Writes one `generated.tfvars.json` per module into its matching
#      examples/<module>/ dir (so `-var-file` + `-chdir` line up).
#   7. When you used more than one module in a run, also writes a combined
#      reference file at the repo root (or at the path passed via -o).
#   8. Runs `terraform validate` against each module's example dir and prints
#      the exact plan/apply commands to run next.
#
# Usage:
#   ./scripts/scaffold_tfvars.sh                         # fully interactive
#   ./scripts/scaffold_tfvars.sh --module storage_bucket # skip FIRST module prompt
#   ./scripts/scaffold_tfvars.sh -o /tmp/all.tfvars.json # aggregate file path
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
# Banner + discover modules
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Interactive tfvars builder (multi-module)"
bold "═══════════════════════════════════════════════════════════════"
echo ""
dim " Add resources from one OR MULTIPLE modules in a single run."
dim " One generated.tfvars.json is dropped into each examples/<module>/ dir,"
dim " ready for terraform -chdir=<dir> plan/apply."
echo ""

# Discover modules from schema.json presence
modules=()
for schema in "$REPO_ROOT"/modules/*/schema.json; do
  [ -f "$schema" ] || continue
  modules+=("$(basename "$(dirname "$schema")")")
done

[ "${#modules[@]}" -gt 0 ] || die "No modules with schema.json found under $REPO_ROOT/modules."

# Consolidated output: one top-level key per module variable_name.
CONSOLIDATED='{}'
first_iter=1
finish_run=0

# ---------------------------------------------------------------------------
# Outer loop: keep adding modules until the user is done.
# ---------------------------------------------------------------------------

while true; do

# ---------------------------------------------------------------------------
# Step 1: Pick a module (CLI --module honored on FIRST iteration only)
# ---------------------------------------------------------------------------

if [ "$first_iter" -eq 0 ] || [ -z "$MODULE" ]; then
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
first_iter=0

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

  # --------------------------------------------------------------------------
  # Single 3-way "what next?" menu. Replaces the old two-step prompt so the
  # user never has to answer "N" before reaching the module switcher.
  # --------------------------------------------------------------------------
  next_action=""
  while true; do
    echo ""
    bold "  What next?"
    echo "    1) Add ANOTHER resource to the SAME module ($MODULE)"
    echo "    2) Switch to a DIFFERENT module (will show the module picker again)"
    echo "    3) Finish — review and write tfvars"
    prompt "  Choice [1/2/3]" "1"
    case "$REPLY" in
      1|same|s)     next_action="same";   break ;;
      2|switch|d)   next_action="switch"; break ;;
      3|done|finish|f) next_action="done"; break ;;
      *) red "  Invalid choice. Enter 1, 2, or 3." ;;
    esac
  done

  # "same" → keep looping the inner resource loop for this module.
  # "switch" or "done" → exit the inner loop; the outer loop will decide
  # whether to re-pick a module or fall through to the write phase.
  case "$next_action" in
    same)   continue ;;
    switch) break    ;;
    done)   finish_run=1; break ;;
  esac
done

# -----------------------------------------------------------------------------
# Merge this module's entries into the consolidated output. The tri-option
# menu above already told us whether to switch modules or finish; no second
# prompt needed here.
# -----------------------------------------------------------------------------

CONSOLIDATED=$(echo "$CONSOLIDATED" | jq --arg v "$VAR_NAME" --argjson e "$entries" '
  .[$v] = (.[$v] // {}) + $e
')

module_count=$(echo "$CONSOLIDATED" | jq --arg v "$VAR_NAME" '.[$v] | length')
echo ""
green "✓ $VAR_NAME now has $module_count entr$([ "$module_count" = "1" ] && echo y || echo ies) in the consolidated output"

if [ "$finish_run" -eq 1 ]; then
  break
fi

# Force the module picker to show again on the next iteration.
MODULE=""

done  # outer module loop

# ---------------------------------------------------------------------------
# Step 4: Review & write (one tfvars file per module; aggregate at repo root)
# ---------------------------------------------------------------------------

echo ""
bold "── Review (combined) ─────────────────────────────────────────"
echo "$CONSOLIDATED" | jq .
echo ""

if ! echo "$CONSOLIDATED" | jq empty >/dev/null 2>&1; then
  die "Generated JSON is not well-formed (bug)."
fi
green "✓ JSON is well-formed"

# List of variable_names that got entries.
SELECTED_VARS=()
while IFS= read -r _vn; do
  [ -n "$_vn" ] && SELECTED_VARS+=("$_vn")
done < <(echo "$CONSOLIDATED" | jq -r 'keys[]')

if [ "${#SELECTED_VARS[@]}" -eq 0 ]; then
  yellow "No resources were added. Nothing to write."
  exit 0
fi

echo ""
bold "── Writing per-module tfvars files ───────────────────────────"

for vn in "${SELECTED_VARS[@]}"; do
  slice=$(echo "$CONSOLIDATED" | jq --arg vn "$vn" '{($vn): .[$vn]}')
  target_dir="$REPO_ROOT/examples/$vn"

  if [ ! -d "$target_dir" ]; then
    yellow "  No examples/$vn/ dir — skipping tfvars write for $vn."
    continue
  fi

  target="$target_dir/generated.tfvars.json"
  if [ -e "$target" ]; then
    prompt "  $target exists — overwrite? (y/N)" "N"
    case "$REPLY" in
      y|Y|yes|YES) ;;
      *) yellow "  Skipped $target"; continue ;;
    esac
  fi
  echo "$slice" > "$target"
  green "  ✓ Wrote $target"
done

# Aggregate reference file — only when the user selected >1 module OR when
# -o was explicitly provided on the CLI.
if [ "${#SELECTED_VARS[@]}" -gt 1 ] || [ -n "$OUTPUT" ]; then
  aggregate="${OUTPUT:-$REPO_ROOT/generated.tfvars.json}"
  write_it=1
  if [ -e "$aggregate" ]; then
    prompt "  $aggregate exists — overwrite? (y/N)" "N"
    case "$REPLY" in
      y|Y|yes|YES) ;;
      *) yellow "  Skipped $aggregate"; write_it=0 ;;
    esac
  fi
  if [ "$write_it" -eq 1 ]; then
    echo "$CONSOLIDATED" > "$aggregate"
    green "  ✓ Wrote $aggregate (combined reference — not used by terraform directly)"
  fi
fi

# ---------------------------------------------------------------------------
# Step 5: terraform validate per selected module
# ---------------------------------------------------------------------------

echo ""
bold "── Validating modules ────────────────────────────────────────"

validate_failed=0
for vn in "${SELECTED_VARS[@]}"; do
  target_dir="$REPO_ROOT/examples/$vn"
  [ -d "$target_dir" ] || continue

  if [ ! -d "$target_dir/.terraform" ]; then
    echo "  Initializing examples/$vn (one-time)..."
    terraform -chdir="$target_dir" init -backend=false >/dev/null 2>&1 || \
      yellow "  terraform init had warnings; continuing."
  fi

  if terraform -chdir="$target_dir" validate >/dev/null 2>&1; then
    green "  ✓ terraform validate passed on examples/$vn"
  else
    red "  ✗ terraform validate FAILED on examples/$vn"
    terraform -chdir="$target_dir" validate
    validate_failed=1
  fi
done

[ "$validate_failed" -eq 1 ] && exit 1

# ---------------------------------------------------------------------------
# Step 6: Next steps (per module)
# ---------------------------------------------------------------------------

echo ""
bold "── Next ──────────────────────────────────────────────────────"
echo ""
dim "Source your GCP env vars first if you haven't:"
dim "  set -a; . $REPO_ROOT/beginning_journey/.env; set +a"
echo ""

for vn in "${SELECTED_VARS[@]}"; do
  target_dir="$REPO_ROOT/examples/$vn"
  tf="$target_dir/generated.tfvars.json"
  [ -f "$tf" ] || continue
  cyan "  # $vn"
  cyan "  terraform -chdir=$target_dir plan  -var-file=$tf -out=tfplan"
  cyan "  terraform -chdir=$target_dir apply tfplan"
  echo ""
done

if printf '%s\n' "${SELECTED_VARS[@]}" | grep -qx storage_buckets; then
  dim "Tip: export GOOGLE_PROJECT=<your-project-id> so buckets pick up the"
  dim "     default project from the provider without per-bucket 'project'."
fi

if printf '%s\n' "${SELECTED_VARS[@]}" | grep -qx compute_instances; then
  dim "Tip: after apply, retrieve instance passwords with:"
  dim "     terraform -chdir=$REPO_ROOT/examples/compute_instances output -json passwords | jq ."
fi

green "Done."
