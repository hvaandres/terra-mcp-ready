#!/usr/bin/env bash
###############################################################################
# install_tools.sh — Install or upgrade all required tools
#
# Supports:
#   - macOS  (Homebrew)
#   - Linux  (apt or yum, with HashiCorp + Google Cloud SDK repos)
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
bold " terra-mcp-ready — Tool Installer (GCP)"
bold "═══════════════════════════════════════════════════════════════"
echo ""
echo "  Platform: $OS $(uname -m)"
$DRY_RUN && yellow "  Mode: DRY RUN (no changes will be made)"
echo ""

# ---------------------------------------------------------------------------
# macOS — Homebrew
# ---------------------------------------------------------------------------

if [ "$OS" = "Darwin" ]; then

  if ! command -v brew &>/dev/null; then
    bold "── Installing Homebrew ──────────────────────────────────────"
    run_cmd '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
  fi

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

  # Google Cloud SDK
  bold "── Google Cloud SDK (gcloud) ───────────────────────────────"
  if command -v gcloud &>/dev/null; then
    CURRENT=$(gcloud version --format=json 2>/dev/null | jq -r '."Google Cloud SDK"' 2>/dev/null || echo "unknown")
    echo "  Current: $CURRENT"
    run_cmd "brew upgrade --cask google-cloud-sdk 2>/dev/null || brew install --cask google-cloud-sdk"
  else
    echo "  Not installed — installing..."
    run_cmd "brew install --cask google-cloud-sdk"
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

  # Git
  bold "── Git ─────────────────────────────────────────────────────"
  CURRENT=$(git --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  echo "  Current: $CURRENT"
  run_cmd "brew upgrade git 2>/dev/null || true"
  echo ""

# ---------------------------------------------------------------------------
# Linux — apt or yum
# ---------------------------------------------------------------------------

elif [ "$OS" = "Linux" ]; then

  if command -v apt-get &>/dev/null; then
    PKG="apt"
  elif command -v yum &>/dev/null; then
    PKG="yum"
  else
    red "  Unsupported Linux package manager. Install tools manually."
    exit 1
  fi

  bold "── Adding HashiCorp + Google Cloud SDK repositories ────────"
  if [ "$PKG" = "apt" ]; then
    run_cmd "sudo apt-get update -qq"
    run_cmd "sudo apt-get install -y -qq gnupg software-properties-common curl apt-transport-https ca-certificates"

    run_cmd 'curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg 2>/dev/null'
    run_cmd 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list'

    run_cmd 'curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg 2>/dev/null'
    run_cmd 'echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list'

    run_cmd "sudo apt-get update -qq"
  else
    run_cmd "sudo yum install -y yum-utils"
    run_cmd "sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo"

    run_cmd 'sudo tee /etc/yum.repos.d/google-cloud-sdk.repo > /dev/null <<EOF
[google-cloud-cli]
name=Google Cloud CLI
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF'
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

  # gcloud
  bold "── Google Cloud SDK (gcloud) ───────────────────────────────"
  if [ "$PKG" = "apt" ]; then
    run_cmd "sudo apt-get install -y google-cloud-cli"
  else
    run_cmd "sudo yum install -y google-cloud-cli"
  fi
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
  echo "  - Terraform >= 1.14.8    (https://developer.hashicorp.com/terraform/downloads)"
  echo "  - Google Cloud CLI       (https://cloud.google.com/sdk/docs/install)"
  echo "  - jq >= 1.6              (https://jqlang.github.io/jq/download/)"
  echo "  - Git >= 2.30            (https://git-scm.com/downloads)"
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
  echo "  gcloud    : $(gcloud version --format=json 2>/dev/null | jq -r '."Google Cloud SDK"' 2>/dev/null || echo 'not found')"
  echo "  jq        : $(jq --version 2>/dev/null || echo 'not found')"
  echo "  Git       : $(git --version 2>/dev/null || echo 'not found')"
  echo ""
  green "Done. Run ./beginning_journey/verify_setup.sh to validate your environment."
else
  echo ""
  yellow "  Dry run complete — no changes were made."
fi
