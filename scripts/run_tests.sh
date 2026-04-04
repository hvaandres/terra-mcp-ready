#!/usr/bin/env bash
###############################################################################
# run_tests.sh — Test runner for terra-mcp-ready modules
#
# Runs offline tests that do NOT require Azure credentials:
#   - terraform fmt check (all modules + examples)
#   - terraform validate (syntax + type checking)
#   - Variable validation (rejects invalid input)
#   - JSON schema validation (schema.json is well-formed)
#
# If Azure credentials are available (ARM_SUBSCRIPTION_ID is set), also runs:
#   - terraform plan -json with assertions on planned resources
#
# Usage:
#   ./scripts/run_tests.sh              # offline tests only
#   ARM_SUBSCRIPTION_ID=xxx ./scripts/run_tests.sh  # full suite
#
# Requirements: terraform, jq
###############################################################################

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0
SKIP=0

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }

pass() { PASS=$((PASS + 1)); green "  ✓ $1"; }
fail() { FAIL=$((FAIL + 1)); red   "  ✗ $1"; }
skip() { SKIP=$((SKIP + 1)); yellow "  ⊘ $1 (skipped)"; }

# Run a command; return 0 on success, 1 on failure. Captures stderr.
quiet_run() {
  local output
  output=$("$@" 2>&1)
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "$output"
  fi
  return $rc
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Module Test Suite"
bold "═══════════════════════════════════════════════════════════════"
echo ""
echo "Repo root : $REPO_ROOT"
echo "Terraform : $(terraform version -json | jq -r '.terraform_version')"
echo "jq        : $(jq --version)"
echo ""

# ---------------------------------------------------------------------------
# Test 1: terraform fmt — all .tf files
# ---------------------------------------------------------------------------

bold "── Test: Formatting ──────────────────────────────────────────"

fmt_dirs=(
  "$REPO_ROOT/modules/resource_group"
  "$REPO_ROOT/examples/resource_groups"
  "$REPO_ROOT/tests/resource_group"
)

for dir in "${fmt_dirs[@]}"; do
  label="fmt $(basename "$(dirname "$dir")")/$(basename "$dir")"
  if terraform fmt -check -diff "$dir" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Test 2: terraform validate — module + example + test harness
# ---------------------------------------------------------------------------

bold "── Test: Validate ───────────────────────────────────────────"

TEST_DIR="$REPO_ROOT/tests/resource_group"

# Init the test harness (needed for validate)
if ! quiet_run terraform -chdir="$TEST_DIR" init -backend=false; then
  fail "terraform init (test harness)"
  bold "Cannot continue without init — aborting validate tests."
else
  pass "terraform init (test harness)"

  # Validate with no vars (empty default)
  if quiet_run terraform -chdir="$TEST_DIR" validate; then
    pass "validate — default (empty map)"
  else
    fail "validate — default (empty map)"
  fi

  # Validate with each valid fixture
  for fixture in "$TEST_DIR/fixtures/valid.tfvars" \
                 "$TEST_DIR/fixtures/minimal.tfvars" \
                 "$TEST_DIR/fixtures/empty.tfvars"; do
    label="validate — $(basename "$fixture" .tfvars)"
    if quiet_run terraform -chdir="$TEST_DIR" validate; then
      pass "$label"
    else
      fail "$label"
    fi
  done
fi

echo ""

# ---------------------------------------------------------------------------
# Test 3: Variable validation — invalid inputs must be rejected
# ---------------------------------------------------------------------------

bold "── Test: Input Validation ───────────────────────────────────"

# Plan with invalid name should fail at the variable validation stage.
# We use plan instead of validate because custom validations run at plan time.
if [ -n "${ARM_SUBSCRIPTION_ID:-}" ]; then
  label="reject invalid name (ends with period)"
  plan_output=$(terraform -chdir="$TEST_DIR" plan \
    -var-file="fixtures/invalid_name.tfvars" \
    -input=false -no-color 2>&1) || true

  if echo "$plan_output" | grep -qi "error"; then
    pass "$label"
  else
    fail "$label — expected an error but plan succeeded"
  fi
else
  skip "reject invalid name (needs credentials for plan)"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 4: JSON schema is well-formed
# ---------------------------------------------------------------------------

bold "── Test: Schema Validation ──────────────────────────────────"

SCHEMA="$REPO_ROOT/modules/resource_group/schema.json"

# Is it valid JSON?
if jq empty "$SCHEMA" > /dev/null 2>&1; then
  pass "schema.json is valid JSON"
else
  fail "schema.json is not valid JSON"
fi

# Has required top-level keys?
for key in '$schema' 'title' 'description' 'type' '$defs' '_meta'; do
  if jq -e ".[\"$key\"]" "$SCHEMA" > /dev/null 2>&1; then
    pass "schema.json has key: $key"
  else
    fail "schema.json missing key: $key"
  fi
done

# _meta has required fields?
for field in module_source variable_name output_keys terraform_version provider; do
  if jq -e "._meta.$field" "$SCHEMA" > /dev/null 2>&1; then
    pass "schema.json _meta has: $field"
  else
    fail "schema.json _meta missing: $field"
  fi
done

# variable_name matches actual TF variable
expected_var=$(jq -r '._meta.variable_name' "$SCHEMA")
if grep -q "variable \"$expected_var\"" "$REPO_ROOT/modules/resource_group/variables.tf"; then
  pass "schema _meta.variable_name matches variables.tf"
else
  fail "schema _meta.variable_name ('$expected_var') not found in variables.tf"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 5: Plan assertions (requires Azure credentials)
# ---------------------------------------------------------------------------

bold "── Test: Plan Assertions ────────────────────────────────────"

if [ -z "${ARM_SUBSCRIPTION_ID:-}" ]; then
  skip "plan assertions (ARM_SUBSCRIPTION_ID not set)"
  echo ""
  yellow "  Set ARM_SUBSCRIPTION_ID, ARM_CLIENT_ID, ARM_CLIENT_SECRET,"
  yellow "  and ARM_TENANT_ID to run plan-based tests."
else
  # --- valid.tfvars: 2 RGs + 1 lock ---
  label="plan valid.tfvars"
  if terraform -chdir="$TEST_DIR" plan \
       -var-file="fixtures/valid.tfvars" \
       -out=tfplan.valid \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$TEST_DIR" show -json tfplan.valid 2>/dev/null)

    # Count planned resource_group creates
    rg_count=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.type == "azurerm_resource_group" and .change.actions[] == "create")] | length')
    if [ "$rg_count" -eq 2 ]; then
      pass "$label — 2 resource groups planned"
    else
      fail "$label — expected 2 resource groups, got $rg_count"
    fi

    # Count planned locks
    lock_count=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.type == "azurerm_management_lock" and .change.actions[] == "create")] | length')
    if [ "$lock_count" -eq 1 ]; then
      pass "$label — 1 management lock planned"
    else
      fail "$label — expected 1 lock, got $lock_count"
    fi

    # Verify resource names
    rg_names=$(echo "$PLAN_JSON" | jq -r '[.resource_changes[] | select(.type == "azurerm_resource_group") | .change.after.name] | sort | join(",")')
    if [ "$rg_names" = "rg-test-app,rg-test-networking" ]; then
      pass "$label — correct resource group names"
    else
      fail "$label — expected 'rg-test-app,rg-test-networking', got '$rg_names'"
    fi

    rm -f "$TEST_DIR/tfplan.valid"
  else
    fail "$label — terraform plan failed"
  fi

  # --- minimal.tfvars: 1 RG, 0 locks ---
  label="plan minimal.tfvars"
  if terraform -chdir="$TEST_DIR" plan \
       -var-file="fixtures/minimal.tfvars" \
       -out=tfplan.minimal \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$TEST_DIR" show -json tfplan.minimal 2>/dev/null)

    rg_count=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.type == "azurerm_resource_group" and .change.actions[] == "create")] | length')
    if [ "$rg_count" -eq 1 ]; then
      pass "$label — 1 resource group planned"
    else
      fail "$label — expected 1 resource group, got $rg_count"
    fi

    lock_count=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.type == "azurerm_management_lock")] | length')
    if [ "$lock_count" -eq 0 ]; then
      pass "$label — 0 locks (lock=false by default)"
    else
      fail "$label — expected 0 locks, got $lock_count"
    fi

    rm -f "$TEST_DIR/tfplan.minimal"
  else
    fail "$label — terraform plan failed"
  fi

  # --- empty.tfvars: 0 resources ---
  label="plan empty.tfvars"
  if terraform -chdir="$TEST_DIR" plan \
       -var-file="fixtures/empty.tfvars" \
       -out=tfplan.empty \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$TEST_DIR" show -json tfplan.empty 2>/dev/null)

    total=$(echo "$PLAN_JSON" | jq '[.resource_changes[] | select(.change.actions[] == "create")] | length')
    if [ "$total" -eq 0 ]; then
      pass "$label — 0 resources planned"
    else
      fail "$label — expected 0 resources, got $total"
    fi

    rm -f "$TEST_DIR/tfplan.empty"
  else
    fail "$label — terraform plan failed"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
TOTAL=$((PASS + FAIL + SKIP))
echo " Results: $TOTAL tests | $(green "$PASS passed") | $(red "$FAIL failed") | $(yellow "$SKIP skipped")"
bold "═══════════════════════════════════════════════════════════════"

# Exit with failure if any test failed
[ "$FAIL" -eq 0 ]
