#!/usr/bin/env bash
###############################################################################
# setup_env.sh — Interactive GCP auth/env configurator
#
# Collects the values Terraform + gcloud need, then writes them to
# beginning_journey/.env in "export KEY=value" form so you can `source` it in
# any shell.
#
# Values collected:
#   GOOGLE_PROJECT                  — default project for the google provider
#   GOOGLE_REGION                   — default region (e.g. us-central1)
#   GOOGLE_ZONE                     — default zone  (e.g. us-central1-a)
#   GOOGLE_APPLICATION_CREDENTIALS  — optional path to a SA key JSON
#                                     (leave empty to use ADC from
#                                     `gcloud auth application-default login`)
#   GOOGLE_BILLING_ACCOUNT          — optional; for the project module
#
# Default source precedence (best match wins):
#   1. value already set in your current shell
#   2. value from beginning_journey/.env (previously saved)
#   3. value from `gcloud config` (where it makes sense)
#   4. empty
#
# Usage:
#   ./beginning_journey/setup_env.sh              # interactive prompts
#   ./beginning_journey/setup_env.sh --quiet      # skip prompts, auto-discover
#   ./beginning_journey/setup_env.sh --refresh    # re-prompt even if .env
#
#   # Then in every shell where you want the vars:
#   source beginning_journey/.env
###############################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# ---------------------------------------------------------------------------
# Flags
# ---------------------------------------------------------------------------

QUIET=false
while [ $# -gt 0 ]; do
  case "$1" in
    -q|--quiet)   QUIET=true; shift ;;
    -r|--refresh) shift ;;   # kept for clarity; re-prompting is the default
    -h|--help)
      grep -E "^#" "$0" | sed 's/^# \{0,1\}//;s/^#//'
      exit 0
      ;;
    *) echo "Unknown flag: $1" >&2; exit 2 ;;
  esac
done

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
cyan()   { printf "\033[36m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
dim()    { printf "\033[2m%s\033[0m\n" "$*"; }

# ---------------------------------------------------------------------------
# Load existing .env (so re-runs show prior choices as defaults)
# ---------------------------------------------------------------------------

# shellcheck disable=SC1090
[ -f "$ENV_FILE" ] && source "$ENV_FILE" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

gcloud_cfg() {
  # gcloud_cfg <section.property> — returns value or empty if unset
  local v
  v=$(gcloud config get-value "$1" 2>/dev/null || true)
  [ "$v" = "(unset)" ] && v=""
  printf '%s' "$v"
}

prompt_var() {
  # prompt_var VAR "Description" "suggested_default"
  local var_name="$1" desc="$2" suggest="${3:-}"
  local current="${!var_name:-}"
  local default="${current:-$suggest}"

  if $QUIET; then
    # In quiet mode, just adopt the discovered default silently.
    printf -v "$var_name" '%s' "$default"
    return
  fi

  dim "  $desc"
  if [ -n "$default" ]; then
    read -r -p "  $var_name [$default]: " line
  else
    read -r -p "  $var_name: " line
  fi
  printf -v "$var_name" '%s' "${line:-$default}"
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — GCP environment setup"
bold "═══════════════════════════════════════════════════════════════"
echo ""

if ! command -v gcloud >/dev/null 2>&1; then
  yellow "gcloud CLI not found — defaults from gcloud config won't be available."
  yellow "(Run ./beginning_journey/install_tools.sh if you haven't yet.)"
fi

# Show the currently active gcloud account (if any), for context
if command -v gcloud >/dev/null 2>&1; then
  active=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  [ -n "$active" ] && dim "  Active gcloud account: $active"
  echo ""
fi

# ---------------------------------------------------------------------------
# Gather values
# ---------------------------------------------------------------------------

# GOOGLE_PROJECT
prompt_var GOOGLE_PROJECT \
  "GCP project_id to use as the provider default." \
  "$(gcloud_cfg core/project)"

# GOOGLE_REGION
prompt_var GOOGLE_REGION \
  "Default region (e.g. us-central1, us-east1, europe-west1)." \
  "$(gcloud_cfg compute/region)"

# GOOGLE_ZONE
prompt_var GOOGLE_ZONE \
  "Default zone inside the region (e.g. us-central1-a)." \
  "$(gcloud_cfg compute/zone)"

# GOOGLE_APPLICATION_CREDENTIALS (optional)
prompt_var GOOGLE_APPLICATION_CREDENTIALS \
  "Path to a service-account key JSON. Leave empty to use ADC from 'gcloud auth application-default login'." \
  ""

# GOOGLE_BILLING_ACCOUNT (optional — for projects module)
if command -v gcloud >/dev/null 2>&1; then
  first_open_billing=$(gcloud billing accounts list --filter=open=true --format="value(ACCOUNT_ID)" 2>/dev/null | head -1)
else
  first_open_billing=""
fi
prompt_var GOOGLE_BILLING_ACCOUNT \
  "Billing account ID (used by modules/project). Leave empty if not creating projects." \
  "$first_open_billing"

# ---------------------------------------------------------------------------
# Sanity checks
# ---------------------------------------------------------------------------

echo ""
if [ -z "$GOOGLE_PROJECT" ]; then
  yellow "Warning: GOOGLE_PROJECT is empty. Most Terraform operations against"
  yellow "         modules/storage_bucket will fail without it."
fi

if [ -n "$GOOGLE_APPLICATION_CREDENTIALS" ] && [ ! -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
  yellow "Warning: $GOOGLE_APPLICATION_CREDENTIALS does not exist."
  yellow "         Either fix the path or leave this empty and use ADC:"
  yellow "           gcloud auth application-default login"
fi

# ---------------------------------------------------------------------------
# Write .env
# ---------------------------------------------------------------------------

# Portable helper: emit "export KEY=quoted-value" only if the value is non-empty
emit() {
  local key="$1" val="${2:-}"
  if [ -n "$val" ]; then
    # Escape any embedded single-quotes safely.
    local escaped="${val//\'/\'\\\'\'}"
    printf "export %s='%s'\n" "$key" "$escaped"
  else
    printf "# %s (unset)\n" "$key"
  fi
}

{
  echo "# terra-mcp-ready — generated by beginning_journey/setup_env.sh"
  echo "# $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "# Source this file into your shell:  source beginning_journey/.env"
  echo ""
  emit GOOGLE_PROJECT                 "$GOOGLE_PROJECT"
  emit GOOGLE_CLOUD_PROJECT           "$GOOGLE_PROJECT"
  emit GOOGLE_REGION                  "$GOOGLE_REGION"
  emit GOOGLE_ZONE                    "$GOOGLE_ZONE"
  emit GOOGLE_APPLICATION_CREDENTIALS "$GOOGLE_APPLICATION_CREDENTIALS"
  emit GOOGLE_BILLING_ACCOUNT         "$GOOGLE_BILLING_ACCOUNT"
} > "$ENV_FILE"

chmod 600 "$ENV_FILE"

green "✓ Wrote $ENV_FILE"
echo ""
bold "── Next ──────────────────────────────────────────────────────"
cyan "  source beginning_journey/.env"
echo ""
dim "  The file is gitignored. To see what's in it:"
dim "    cat beginning_journey/.env"
echo ""
dim "  To re-run interactively later:  ./beginning_journey/setup_env.sh"
dim "  To auto-discover non-interactively: ./beginning_journey/setup_env.sh --quiet"
