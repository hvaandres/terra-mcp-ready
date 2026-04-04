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
AZ_MIN="2.60.0"
AZ_REC="2.84.0"
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

# Compare two semver-ish strings. Returns 0 if $1 >= $2.
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

# Check a tool: name, command to get version, installed version, min, recommended
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
bold " terra-mcp-ready — Prerequisites Check"
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

# Azure CLI
AZ_VER=""
if command -v az &>/dev/null; then
  AZ_VER=$(az version --output json 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || echo "")
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
check_tool "Terraform"  "$TF_VER"  "$TF_MIN" "$TF_REC"
check_tool "Azure CLI"  "$AZ_VER"  "$AZ_MIN" "$AZ_REC"
check_tool "jq"         "$JQ_VER"  "$JQ_MIN" "1.7"
check_tool "Git"        "$GIT_VER" "$GIT_MIN" "2.40"
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
# Azure authentication status
# ---------------------------------------------------------------------------

bold "── Azure Authentication ─────────────────────────────────────"

if command -v az &>/dev/null; then
  AZ_ACCOUNT=$(az account show --output json 2>/dev/null) || AZ_ACCOUNT=""
  if [ -n "$AZ_ACCOUNT" ]; then
    AZ_SUB=$(echo "$AZ_ACCOUNT" | jq -r '.name' 2>/dev/null)
    AZ_ID=$(echo "$AZ_ACCOUNT" | jq -r '.id' 2>/dev/null)
    printf "  Logged in     %s\n" "$(green "✓")"
    printf "  Subscription  %s (%s)\n" "$AZ_SUB" "$AZ_ID"
  else
    printf "  Logged in     %s\n" "$(yellow "✗ not authenticated (run: az login)")"
  fi
else
  printf "  Logged in     %s\n" "$(red "✗ Azure CLI not installed")"
fi

echo ""

# ---------------------------------------------------------------------------
# ARM_ environment variables (for CI / plan-based tests)
# ---------------------------------------------------------------------------

bold "── CI Environment Variables ─────────────────────────────────"

arm_vars=(ARM_SUBSCRIPTION_ID ARM_CLIENT_ID ARM_CLIENT_SECRET ARM_TENANT_ID)
arm_set=0
for var in "${arm_vars[@]}"; do
  if [ -n "${!var:-}" ]; then
    printf "  %-25s %s\n" "$var" "$(green "set")"
    arm_set=$((arm_set + 1))
  else
    printf "  %-25s %s\n" "$var" "$(yellow "not set")"
  fi
done

if [ "$arm_set" -eq 0 ]; then
  echo ""
  yellow "  These are optional — only needed for plan-based tests and CI."
  yellow "  Interactive 'az login' is sufficient for local development."
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
