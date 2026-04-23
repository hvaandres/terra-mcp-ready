#!/usr/bin/env bash
###############################################################################
# check_prerequisites.sh — Verify that all required tools are installed
#
# Reports installed versions and flags anything missing or outdated.
# Exit code: 0 if all minimum requirements are met, 1 otherwise.
###############################################################################

set -uo pipefail

# ---------------------------------------------------------------------------
# Version requirements
# ---------------------------------------------------------------------------

TF_MIN="1.5.0"
TF_REC="1.14.8"
GCLOUD_MIN="460.0.0"
GCLOUD_REC="490.0.0"
JQ_MIN="1.6"
GIT_MIN="2.30.0"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

green()  { printf "\033[32m%s\033[0m" "$*"; }
red()    { printf "\033[31m%s\033[0m" "$*"; }
yellow() { printf "\033[33m%s\033[0m" "$*"; }
bold()   { printf "\033[1m%s\033[0m" "$*"; }

ISSUES=0

version_gte() {
  local IFS=.
  local i a=($1) b=($2)
  for ((i = 0; i < ${#b[@]}; i++)); do
    local va=${a[i]:-0}
    local vb=${b[i]:-0}
    if ((va > vb)); then return 0; fi
    if ((va < vb)); then return 1; fi
  done
  return 0
}

check_tool() {
  local name="$1" installed="$2" min="$3" rec="$4"

  if [ -z "$installed" ]; then
    printf "  %-14s %s\n" "$name" "$(red "✗ NOT INSTALLED")"
    ISSUES=$((ISSUES + 1))
    return
  fi

  if ! version_gte "$installed" "$min"; then
    printf "  %-14s %-12s  %s  (min: %s, recommended: %s)\n" \
      "$name" "$installed" "$(red "✗ below minimum")" "$min" "$rec"
    ISSUES=$((ISSUES + 1))
    return
  fi

  if ! version_gte "$installed" "$rec"; then
    printf "  %-14s %-12s  %s  (recommended: %s)\n" \
      "$name" "$installed" "$(yellow "⬆ upgrade available")" "$rec"
    return
  fi

  printf "  %-14s %-12s  %s\n" "$name" "$installed" "$(green "✓")"
}

# ---------------------------------------------------------------------------
# Detect versions
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Prerequisites Check (GCP)"
bold "═══════════════════════════════════════════════════════════════"
echo ""

OS="$(uname -s)"
ARCH="$(uname -m)"
printf "  Platform: %s %s\n\n" "$OS" "$ARCH"

# Terraform
TF_VER=""
if command -v terraform &>/dev/null; then
  TF_VER=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || \
           terraform version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
fi

# gcloud
GCLOUD_VER=""
if command -v gcloud &>/dev/null; then
  GCLOUD_VER=$(gcloud version --format=json 2>/dev/null | jq -r '."Google Cloud SDK"' 2>/dev/null || \
               gcloud version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
fi

# jq
JQ_VER=""
if command -v jq &>/dev/null; then
  JQ_VER=$(jq --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' || echo "")
fi

# Git
GIT_VER=""
if command -v git &>/dev/null; then
  GIT_VER=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "")
fi

# Homebrew (macOS only)
BREW_VER=""
if [ "$OS" = "Darwin" ]; then
  if command -v brew &>/dev/null; then
    BREW_VER=$(brew --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' || echo "installed")
  fi
fi

# tfenv (optional)
TFENV=""
if command -v tfenv &>/dev/null; then
  TFENV="installed"
fi

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

bold "── Required Tools ───────────────────────────────────────────"
check_tool "Terraform"  "$TF_VER"     "$TF_MIN"     "$TF_REC"
check_tool "gcloud"     "$GCLOUD_VER" "$GCLOUD_MIN" "$GCLOUD_REC"
check_tool "jq"         "$JQ_VER"     "$JQ_MIN"     "1.7"
check_tool "Git"        "$GIT_VER"    "$GIT_MIN"    "2.40"
echo ""

bold "── Optional Tools ───────────────────────────────────────────"

if [ "$OS" = "Darwin" ]; then
  if [ -n "$BREW_VER" ]; then
    printf "  %-14s %-12s  %s\n" "Homebrew" "$BREW_VER" "$(green "✓")"
  else
    printf "  %-14s %s\n" "Homebrew" "$(yellow "not installed (needed for install_tools.sh on macOS)")"
  fi
fi

if [ -n "$TFENV" ]; then
  printf "  %-14s %-12s  %s\n" "tfenv" "detected" "$(green "✓ (use: tfenv install $TF_REC)")"
else
  printf "  %-14s %s\n" "tfenv" "not installed (optional — manages multiple Terraform versions)"
fi

echo ""

# ---------------------------------------------------------------------------
# GCP authentication status
# ---------------------------------------------------------------------------

bold "── GCP Authentication ───────────────────────────────────────"

if command -v gcloud &>/dev/null; then
  ACTIVE_ACCT=$(gcloud auth list --filter=status:ACTIVE --format="value(account)" 2>/dev/null | head -1)
  if [ -n "$ACTIVE_ACCT" ]; then
    printf "  Active account    %s\n" "$(green "✓ $ACTIVE_ACCT")"
  else
    printf "  Active account    %s\n" "$(yellow "✗ not authenticated (run: gcloud auth login)")"
  fi

  PROJECT=$(gcloud config get-value project 2>/dev/null || true)
  if [ -n "$PROJECT" ] && [ "$PROJECT" != "(unset)" ]; then
    printf "  Default project   %s\n" "$PROJECT"
  else
    printf "  Default project   %s\n" "$(yellow "not set (run: gcloud config set project <id>)")"
  fi

  ADC_PATH="$HOME/.config/gcloud/application_default_credentials.json"
  if [ -f "$ADC_PATH" ]; then
    printf "  ADC file          %s\n" "$(green "✓ $ADC_PATH")"
  elif [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] && [ -f "$GOOGLE_APPLICATION_CREDENTIALS" ]; then
    printf "  ADC file          %s\n" "$(green "✓ $GOOGLE_APPLICATION_CREDENTIALS (from env)")"
  else
    printf "  ADC file          %s\n" "$(yellow "✗ run: gcloud auth application-default login")"
  fi
else
  printf "  Active account    %s\n" "$(red "✗ gcloud not installed")"
fi

echo ""

# ---------------------------------------------------------------------------
# GOOGLE_* environment variables (for CI / plan-based tests)
# ---------------------------------------------------------------------------

bold "── CI Environment Variables ─────────────────────────────────"

gcp_vars=(GOOGLE_APPLICATION_CREDENTIALS GOOGLE_PROJECT GOOGLE_CLOUD_PROJECT GOOGLE_REGION)
gcp_set=0
for var in "${gcp_vars[@]}"; do
  if [ -n "${!var:-}" ]; then
    printf "  %-30s %s\n" "$var" "$(green "set")"
    gcp_set=$((gcp_set + 1))
  else
    printf "  %-30s %s\n" "$var" "$(yellow "not set")"
  fi
done

if [ "$gcp_set" -eq 0 ]; then
  echo ""
  yellow "  These are optional — only needed for plan-based tests and CI."
  yellow "  Interactive 'gcloud auth application-default login' is sufficient for local development."
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
if [ "$ISSUES" -eq 0 ]; then
  green " All minimum requirements met."
  echo ""
  echo " Run ./beginning_journey/install_tools.sh to upgrade to recommended versions."
else
  red " $ISSUES issue(s) found — run ./beginning_journey/install_tools.sh to fix."
fi
bold "═══════════════════════════════════════════════════════════════"

exit "$ISSUES"
