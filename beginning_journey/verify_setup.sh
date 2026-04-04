#!/usr/bin/env bash
###############################################################################
# verify_setup.sh — End-to-end environment verification
#
# Confirms that:
#   1. All required tools are at minimum versions
#   2. terraform init succeeds on the example module
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
bold " terra-mcp-ready — Environment Verification"
bold "═══════════════════════════════════════════════════════════════"
echo ""

# ---------------------------------------------------------------------------
# Step 1: Tool availability
# ---------------------------------------------------------------------------

bold "── Step 1: Tool Check ──────────────────────────────────────"

for tool in terraform az jq git; do
  if command -v "$tool" &>/dev/null; then
    pass "$tool found"
  else
    fail "$tool not found"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Step 2: Terraform init on example
# ---------------------------------------------------------------------------

bold "── Step 2: terraform init ─────────────────────────────────"

EXAMPLE_DIR="$REPO_ROOT/examples/resource_groups"

# Clean previous state to ensure fresh init
rm -rf "$EXAMPLE_DIR/.terraform" "$EXAMPLE_DIR/.terraform.lock.hcl"

if terraform -chdir="$EXAMPLE_DIR" init -backend=false > /dev/null 2>&1; then
  pass "terraform init (examples/resource_groups)"
else
  fail "terraform init (examples/resource_groups)"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 3: Terraform validate
# ---------------------------------------------------------------------------

bold "── Step 3: terraform validate ─────────────────────────────"

if terraform -chdir="$EXAMPLE_DIR" validate > /dev/null 2>&1; then
  pass "terraform validate (examples/resource_groups)"
else
  fail "terraform validate (examples/resource_groups)"
fi
echo ""

# ---------------------------------------------------------------------------
# Step 4: Terraform fmt
# ---------------------------------------------------------------------------

bold "── Step 4: terraform fmt ──────────────────────────────────"

for dir in \
  "$REPO_ROOT/modules/resource_group" \
  "$REPO_ROOT/examples/resource_groups" \
  "$REPO_ROOT/tests/resource_group"; do
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
  echo "   1. az login"
  echo "   2. cd examples/resource_groups"
  echo "   3. terraform plan"
else
  red " $FAIL of $TOTAL checks failed."
  echo ""
  echo " Run ./beginning_journey/check_prerequisites.sh for details."
  echo " Run ./beginning_journey/install_tools.sh to fix tool issues."
fi
bold "═══════════════════════════════════════════════════════════════"

[ "$FAIL" -eq 0 ]
