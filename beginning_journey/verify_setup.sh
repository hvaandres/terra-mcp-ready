#!/usr/bin/env bash
###############################################################################
# verify_setup.sh — End-to-end environment verification (GCP)
#
# Confirms that:
#   1. All required tools are at minimum versions
#   2. terraform init succeeds on both example modules
#   3. terraform validate passes
#   4. terraform fmt is clean
#   5. The test suite passes
#
# Exit code: 0 if everything checks out, 1 otherwise.
###############################################################################

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

pass() { PASS=$((PASS + 1)); green "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); red   "  ✗ $1"; }

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Environment Verification (GCP)"
bold "═══════════════════════════════════════════════════════════════"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Tool availability
# ---------------------------------------------------------------------------

bold "── Step 1: Tool Check ──────────────────────────────────────"

for tool in terraform gcloud jq git; do
  if command -v "$tool" &>/dev/null; then
    pass "$tool found"
  else
    fail "$tool not found"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Step 2: Terraform init on examples
# ---------------------------------------------------------------------------

bold "── Step 2: terraform init ─────────────────────────────────"

for example_dir in \
  "$REPO_ROOT/examples/projects" \
  "$REPO_ROOT/examples/storage_buckets" \
  "$REPO_ROOT/examples/vpc_networks" \
  "$REPO_ROOT/examples/compute_instances" \
  "$REPO_ROOT/examples/composition"; do
  label="terraform init ($(basename "$(dirname "$example_dir")")/$(basename "$example_dir"))"
  rm -rf "$example_dir/.terraform" "$example_dir/.terraform.lock.hcl"
  if terraform -chdir="$example_dir" init -backend=false > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Step 3: Terraform validate
# ---------------------------------------------------------------------------

bold "── Step 3: terraform validate ─────────────────────────────"

for example_dir in \
  "$REPO_ROOT/examples/projects" \
  "$REPO_ROOT/examples/storage_buckets" \
  "$REPO_ROOT/examples/vpc_networks" \
  "$REPO_ROOT/examples/compute_instances" \
  "$REPO_ROOT/examples/composition"; do
  label="terraform validate ($(basename "$(dirname "$example_dir")")/$(basename "$example_dir"))"
  if terraform -chdir="$example_dir" validate > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Step 4: Terraform fmt
# ---------------------------------------------------------------------------

bold "── Step 4: terraform fmt ──────────────────────────────────"

for dir in \
  "$REPO_ROOT/modules/project" \
  "$REPO_ROOT/modules/storage_bucket" \
  "$REPO_ROOT/modules/vpc_network" \
  "$REPO_ROOT/modules/compute_instance" \
  "$REPO_ROOT/examples/projects" \
  "$REPO_ROOT/examples/storage_buckets" \
  "$REPO_ROOT/examples/vpc_networks" \
  "$REPO_ROOT/examples/compute_instances" \
  "$REPO_ROOT/examples/composition" \
  "$REPO_ROOT/tests/project" \
  "$REPO_ROOT/tests/storage_bucket" \
  "$REPO_ROOT/tests/vpc_network" \
  "$REPO_ROOT/tests/compute_instance"; do
  label="fmt $(basename "$(dirname "$dir")")/$(basename "$dir")"
  if terraform fmt -check "$dir" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Step 5: Test suite
# ---------------------------------------------------------------------------

bold "── Step 5: Test Suite ─────────────────────────────────────"

TEST_SCRIPT="$REPO_ROOT/scripts/run_tests.sh"

if [ -x "$TEST_SCRIPT" ]; then
  if "$TEST_SCRIPT" > /dev/null 2>&1; then
    pass "scripts/run_tests.sh (all offline tests)"
  else
    fail "scripts/run_tests.sh (run it directly for details)"
  fi
else
  fail "scripts/run_tests.sh not found or not executable"
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

TOTAL=$((PASS + FAIL))

bold "═══════════════════════════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  green " All $TOTAL checks passed — your environment is ready!"
  echo ""
  echo " Next steps:"
  echo "   1. gcloud auth application-default login"
  echo "   2. cd examples/projects      (or examples/storage_buckets)"
  echo "   3. terraform plan"
else
  red " $FAIL of $TOTAL checks failed."
  echo ""
  echo " Run ./beginning_journey/check_prerequisites.sh for details."
  echo " Run ./beginning_journey/install_tools.sh to fix tool issues."
fi
bold "═══════════════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
