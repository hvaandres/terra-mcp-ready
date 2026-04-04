#!/usr/bin/env bash
###############################################################################
# install_tools.sh — Install or upgrade all required tools
#
# Supports:
#   - macOS  (Homebrew)
#   - Linux  (apt or yum, with HashiCorp repo for Terraform)
#
# Usage:
#   ./beginning_journey/install_tools.sh
#   ./beginning_journey/install_tools.sh --dry-run   # show what would happen
###############################################################################

set -uo pipefail

DRY_RUN=false
[ "${1:-}" = "--dry-run" ] && DRY_RUN=true

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

run_cmd() {
  if $DRY_RUN; then
    yellow "  [dry-run] $*"
  else
    echo "  → $*"
    eval "$@"
  fi
}

OS="$(uname -s)"

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Tool Installer"
bold "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Platform: $OS $(uname -m)"
$DRY_RUN && yellow "  Mode: DRY RUN (no changes will be made)"
echo ""

# ---------------------------------------------------------------------------
# macOS — Homebrew
# ---------------------------------------------------------------------------

if [ "$OS" = "Darwin" ]; then

  # Ensure Homebrew is present
  if ! command -v brew &>/dev/null; then
    bold "── Installing Homebrew ──────────────────────────────────────"
    run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
  fi

  # Tap HashiCorp
  bold "── Configuring HashiCorp tap ────────────────────────────────"
  run_cmd "brew tap hashicorp/tap"
  echo ""

  # Terraform
  bold "── Terraform ───────────────────────────────────────────────"
  if command -v terraform &>/dev/null; then
    CURRENT=$(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || echo "unknown")
    echo "  Current: $CURRENT"
    run_cmd "brew upgrade hashicorp/tap/terraform 2>/dev/null || brew install hashicorp/tap/terraform"
  else
    echo "  Not installed — installing..."
    run_cmd "brew install hashicorp/tap/terraform"
  fi
  echo ""

  # Azure CLI
  bold "── Azure CLI ───────────────────────────────────────────────"
  if command -v az &>/dev/null; then
    CURRENT=$(az version --output json 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || echo "unknown")
    echo "  Current: $CURRENT"
    run_cmd "brew upgrade azure-cli 2>/dev/null || brew install azure-cli"
  else
    echo "  Not installed — installing..."
    run_cmd "brew install azure-cli"
  fi
  echo ""

  # jq
  bold "── jq ──────────────────────────────────────────────────────"
  if command -v jq &>/dev/null; then
    echo "  Current: $(jq --version 2>/dev/null)"
    run_cmd "brew upgrade jq 2>/dev/null || true"
  else
    echo "  Not installed — installing..."
    run_cmd "brew install jq"
  fi
  echo ""

  # Git (macOS ships git, but Homebrew has a newer version)
  bold "── Git ─────────────────────────────────────────────────────"
  CURRENT=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "  Current: $CURRENT"
  run_cmd "brew upgrade git 2>/dev/null || true"
  echo ""

# ---------------------------------------------------------------------------
# Linux — apt or yum
# ---------------------------------------------------------------------------

elif [ "$OS" = "Linux" ]; then

  # Detect package manager
  if command -v apt-get &>/dev/null; then
    PKG="apt"
  elif command -v yum &>/dev/null; then
    PKG="yum"
  else
    red "  Unsupported Linux package manager. Install tools manually."
    exit 1
  fi

  bold "── Adding HashiCorp repository ─────────────────────────────"
  if [ "$PKG" = "apt" ]; then
    run_cmd "sudo apt-get update -qq"
    run_cmd "sudo apt-get install -y -qq gnupg software-properties-common curl"
    run_cmd 'curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null'
    run_cmd 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'
    run_cmd "sudo apt-get update -qq"
  else
    run_cmd "sudo yum install -y yum-utils"
    run_cmd "sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo"
  fi
  echo ""

  # Terraform
  bold "── Terraform ───────────────────────────────────────────────"
  if [ "$PKG" = "apt" ]; then
    run_cmd "sudo apt-get install -y terraform"
  else
    run_cmd "sudo yum install -y terraform"
  fi
  echo ""

  # Azure CLI
  bold "── Azure CLI ───────────────────────────────────────────────"
  run_cmd "curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash"
  echo ""

  # jq
  bold "── jq ──────────────────────────────────────────────────────"
  if [ "$PKG" = "apt" ]; then
    run_cmd "sudo apt-get install -y jq"
  else
    run_cmd "sudo yum install -y jq"
  fi
  echo ""

  # Git
  bold "── Git ─────────────────────────────────────────────────────"
  if [ "$PKG" = "apt" ]; then
    run_cmd "sudo apt-get install -y git"
  else
    run_cmd "sudo yum install -y git"
  fi
  echo ""

else
  red "Unsupported OS: $OS"
  echo "Please install the following manually:"
  echo "  - Terraform >= 1.14.8  (https://developer.hashicorp.com/terraform/downloads)"
  echo "  - Azure CLI >= 2.84.0  (https://learn.microsoft.com/cli/azure/install-azure-cli)"
  echo "  - jq >= 1.6            (https://jqlang.github.io/jq/download/)"
  echo "  - Git >= 2.30          (https://git-scm.com/downloads)"
  exit 1
fi

# ---------------------------------------------------------------------------
# Post-install verification
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " Installed versions"
bold "═══════════════════════════════════════════════════════════════"

if ! $DRY_RUN; then
  echo ""
  echo "  Terraform : $(terraform version -json 2>/dev/null | jq -r '.terraform_version' 2>/dev/null || terraform version 2>/dev/null | head -1)"
  echo "  Azure CLI : $(az version --output json 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || echo 'not found')"
  echo "  jq        : $(jq --version 2>/dev/null || echo 'not found')"
  echo "  Git       : $(git --version 2>/dev/null || echo 'not found')"
  echo ""
  green "Done. Run ./beginning_journey/verify_setup.sh to validate your environment."
else
  echo ""
  yellow "  Dry run complete — no changes were made."
fi
