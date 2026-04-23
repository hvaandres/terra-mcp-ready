#!/usr/bin/env bash
###############################################################################
# run_tests.sh — Test runner for terra-mcp-ready modules (GCP)
#
# Runs offline tests that do NOT require GCP credentials:
#   - terraform fmt check (all modules + examples + test harnesses)
#   - terraform validate (syntax + type checking)
#   - Variable validation (rejects invalid input)
#   - JSON schema validation (every modules/*/schema.json is well-formed)
#
# If GCP credentials are available (GOOGLE_APPLICATION_CREDENTIALS or
# GOOGLE_PROJECT is set), also runs:
#   - terraform plan -json with assertions on planned resources
#
# Usage:
#   ./scripts/run_tests.sh                         # offline tests only
#   GOOGLE_PROJECT=my-proj ./scripts/run_tests.sh  # full suite
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

quiet_run() {
  local output
  output=$("$@" 2>&1)
  local rc=$?
  if [ $rc -ne 0 ]; then
    echo "$output"
  fi
  return $rc
}

has_gcp_creds() {
  [ -n "${GOOGLE_APPLICATION_CREDENTIALS:-}" ] || \
  [ -n "${GOOGLE_PROJECT:-}" ] || \
  [ -n "${GOOGLE_CLOUD_PROJECT:-}" ]
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — Module Test Suite (GCP)"
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
  "$REPO_ROOT/modules/project"
  "$REPO_ROOT/modules/storage_bucket"
  "$REPO_ROOT/modules/vpc_network"
  "$REPO_ROOT/modules/compute_instance"
  "$REPO_ROOT/examples/projects"
  "$REPO_ROOT/examples/storage_buckets"
  "$REPO_ROOT/examples/vpc_networks"
  "$REPO_ROOT/examples/compute_instances"
  "$REPO_ROOT/examples/composition"
  "$REPO_ROOT/tests/project"
  "$REPO_ROOT/tests/storage_bucket"
  "$REPO_ROOT/tests/vpc_network"
  "$REPO_ROOT/tests/compute_instance"
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
# Test 2: terraform validate — each test harness
# ---------------------------------------------------------------------------

bold "── Test: Validate ───────────────────────────────────────────"

validate_harness() {
  local label="$1" dir="$2"

  if ! quiet_run terraform -chdir="$dir" init -backend=false; then
    fail "terraform init ($label)"
    return 1
  fi
  pass "terraform init ($label)"

  if quiet_run terraform -chdir="$dir" validate; then
    pass "validate — $label (empty default)"
  else
    fail "validate — $label (empty default)"
    return 1
  fi

  for fixture in "$dir"/fixtures/*.tfvars; do
    local name
    name=$(basename "$fixture" .tfvars)
    [[ "$name" == invalid_* ]] && continue
    if quiet_run terraform -chdir="$dir" validate; then
      pass "validate — $label/$name"
    else
      fail "validate — $label/$name"
    fi
  done
}

validate_harness "project"          "$REPO_ROOT/tests/project"
validate_harness "storage_bucket"   "$REPO_ROOT/tests/storage_bucket"
validate_harness "vpc_network"      "$REPO_ROOT/tests/vpc_network"
validate_harness "compute_instance" "$REPO_ROOT/tests/compute_instance"

echo ""

# ---------------------------------------------------------------------------
# Test 3: Variable validation — invalid inputs must be rejected
# ---------------------------------------------------------------------------

bold "── Test: Input Validation ───────────────────────────────────"

if has_gcp_creds; then
  for pair in \
    "project:invalid_id:invalid project_id" \
    "storage_bucket:invalid_name:invalid bucket name" \
    "vpc_network:invalid_name:invalid VPC name" \
    "compute_instance:invalid_name:invalid instance name"; do
    mod="${pair%%:*}"; rest="${pair#*:}"; fix="${rest%%:*}"; label="reject ${rest#*:}"
    plan_output=$(terraform -chdir="$REPO_ROOT/tests/$mod" plan \
      -var-file="fixtures/${fix}.tfvars" \
      -input=false -no-color 2>&1) || true
    if echo "$plan_output" | grep -qi "error"; then
      pass "$label"
    else
      fail "$label — expected an error but plan succeeded"
    fi
  done
else
  skip "reject invalid project_id (needs credentials for plan)"
  skip "reject invalid bucket name (needs credentials for plan)"
  skip "reject invalid VPC name (needs credentials for plan)"
  skip "reject invalid instance name (needs credentials for plan)"
fi

echo ""

# ---------------------------------------------------------------------------
# Test 4: JSON schema is well-formed (every module)
# ---------------------------------------------------------------------------

bold "── Test: Schema Validation ──────────────────────────────────"

for schema in "$REPO_ROOT"/modules/*/schema.json; do
  module_dir=$(dirname "$schema")
  module_name=$(basename "$module_dir")

  if jq empty "$schema" > /dev/null 2>&1; then
    pass "$module_name/schema.json is valid JSON"
  else
    fail "$module_name/schema.json is not valid JSON"
    continue
  fi

  for key in '$schema' 'title' 'description' 'type' '$defs' '_meta'; do
    if jq -e ".[\"$key\"]" "$schema" > /dev/null 2>&1; then
      pass "$module_name/schema.json has key: $key"
    else
      fail "$module_name/schema.json missing key: $key"
    fi
  done

  for field in module_source variable_name output_keys terraform_version provider; do
    if jq -e "._meta.$field" "$schema" > /dev/null 2>&1; then
      pass "$module_name/schema.json _meta has: $field"
    else
      fail "$module_name/schema.json _meta missing: $field"
    fi
  done

  expected_var=$(jq -r '._meta.variable_name' "$schema")
  if grep -q "variable \"$expected_var\"" "$module_dir/variables.tf"; then
    pass "$module_name schema _meta.variable_name matches variables.tf"
  else
    fail "$module_name schema _meta.variable_name ('$expected_var') not found in variables.tf"
  fi
done

echo ""

# ---------------------------------------------------------------------------
# Test 5: Plan assertions (requires GCP credentials)
# ---------------------------------------------------------------------------

bold "── Test: Plan Assertions ────────────────────────────────────"

if ! has_gcp_creds; then
  skip "plan assertions (GOOGLE_APPLICATION_CREDENTIALS / GOOGLE_PROJECT not set)"
  echo ""
  yellow "  Set GOOGLE_APPLICATION_CREDENTIALS and GOOGLE_PROJECT (or"
  yellow "  GOOGLE_CLOUD_PROJECT) to run plan-based tests."
else
  PROJ_TEST="$REPO_ROOT/tests/project"

  label="plan project/valid.tfvars"
  if terraform -chdir="$PROJ_TEST" plan \
       -var-file="fixtures/valid.tfvars" \
       -out=tfplan.valid \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$PROJ_TEST" show -json tfplan.valid 2>/dev/null)

    proj_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_project" and .change.actions[] == "create")] | length')
    if [ "$proj_count" -eq 2 ]; then
      pass "$label — 2 projects planned"
    else
      fail "$label — expected 2 projects, got $proj_count"
    fi

    lien_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_resource_manager_lien" and .change.actions[] == "create")] | length')
    if [ "$lien_count" -eq 1 ]; then
      pass "$label — 1 deletion lien planned"
    else
      fail "$label — expected 1 lien, got $lien_count"
    fi

    rm -f "$PROJ_TEST/tfplan.valid"
  else
    fail "$label — terraform plan failed"
  fi

  label="plan project/minimal.tfvars"
  if terraform -chdir="$PROJ_TEST" plan \
       -var-file="fixtures/minimal.tfvars" \
       -out=tfplan.minimal \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$PROJ_TEST" show -json tfplan.minimal 2>/dev/null)

    proj_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_project" and .change.actions[] == "create")] | length')
    if [ "$proj_count" -eq 1 ]; then
      pass "$label — 1 project planned"
    else
      fail "$label — expected 1 project, got $proj_count"
    fi

    lien_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_resource_manager_lien")] | length')
    if [ "$lien_count" -eq 0 ]; then
      pass "$label — 0 liens (lock=false by default)"
    else
      fail "$label — expected 0 liens, got $lien_count"
    fi

    rm -f "$PROJ_TEST/tfplan.minimal"
  else
    fail "$label — terraform plan failed"
  fi

  label="plan project/empty.tfvars"
  if terraform -chdir="$PROJ_TEST" plan \
       -var-file="fixtures/empty.tfvars" \
       -out=tfplan.empty \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$PROJ_TEST" show -json tfplan.empty 2>/dev/null)

    total=$(echo "$PLAN_JSON" | jq '[.resource_changes[]? | select(.change.actions[]? == "create")] | length')
    if [ "${total:-0}" -eq 0 ]; then
      pass "$label — 0 resources planned"
    else
      fail "$label — expected 0 resources, got $total"
    fi

    rm -f "$PROJ_TEST/tfplan.empty"
  else
    fail "$label — terraform plan failed"
  fi

  BUCK_TEST="$REPO_ROOT/tests/storage_bucket"

  label="plan storage_bucket/valid.tfvars"
  if terraform -chdir="$BUCK_TEST" plan \
       -var-file="fixtures/valid.tfvars" \
       -out=tfplan.valid \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$BUCK_TEST" show -json tfplan.valid 2>/dev/null)

    bucket_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_storage_bucket" and .change.actions[] == "create")] | length')
    if [ "$bucket_count" -eq 2 ]; then
      pass "$label — 2 buckets planned"
    else
      fail "$label — expected 2 buckets, got $bucket_count"
    fi

    rm -f "$BUCK_TEST/tfplan.valid"
  else
    fail "$label — terraform plan failed"
  fi

  label="plan storage_bucket/minimal.tfvars"
  if terraform -chdir="$BUCK_TEST" plan \
       -var-file="fixtures/minimal.tfvars" \
       -out=tfplan.minimal \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$BUCK_TEST" show -json tfplan.minimal 2>/dev/null)

    bucket_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_storage_bucket" and .change.actions[] == "create")] | length')
    if [ "$bucket_count" -eq 1 ]; then
      pass "$label — 1 bucket planned"
    else
      fail "$label — expected 1 bucket, got $bucket_count"
    fi

    rm -f "$BUCK_TEST/tfplan.minimal"
  else
    fail "$label — terraform plan failed"
  fi

  label="plan storage_bucket/empty.tfvars"
  if terraform -chdir="$BUCK_TEST" plan \
       -var-file="fixtures/empty.tfvars" \
       -out=tfplan.empty \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$BUCK_TEST" show -json tfplan.empty 2>/dev/null)

    total=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.change.actions[] == "create")] | length')
    if [ "$total" -eq 0 ]; then
      pass "$label — 0 resources planned"
    else
      fail "$label — expected 0 resources, got $total"
    fi

    rm -f "$BUCK_TEST/tfplan.empty"
  else
    fail "$label — terraform plan failed"
  fi

  # ---------- modules/vpc_network ----------
  VPC_TEST="$REPO_ROOT/tests/vpc_network"

  label="plan vpc_network/valid.tfvars"
  if terraform -chdir="$VPC_TEST" plan \
       -var-file="fixtures/valid.tfvars" \
       -out=tfplan.valid \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$VPC_TEST" show -json tfplan.valid 2>/dev/null)

    vpc_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_network" and .change.actions[] == "create")] | length')
    sub_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_subnetwork" and .change.actions[] == "create")] | length')
    fw_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_firewall" and .change.actions[] == "create")] | length')

    [ "$vpc_count" -eq 1 ] && pass "$label — 1 VPC planned"     || fail "$label — expected 1 VPC, got $vpc_count"
    [ "$sub_count" -eq 2 ] && pass "$label — 2 subnets planned" || fail "$label — expected 2 subnets, got $sub_count"
    [ "$fw_count"  -eq 1 ] && pass "$label — 1 firewall planned" || fail "$label — expected 1 firewall, got $fw_count"

    rm -f "$VPC_TEST/tfplan.valid"
  else
    fail "$label — terraform plan failed"
  fi

  label="plan vpc_network/minimal.tfvars"
  if terraform -chdir="$VPC_TEST" plan \
       -var-file="fixtures/minimal.tfvars" \
       -out=tfplan.minimal \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$VPC_TEST" show -json tfplan.minimal 2>/dev/null)
    vpc_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_network" and .change.actions[] == "create")] | length')
    sub_count=$(echo "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_subnetwork")] | length')
    fw_count=$(echo  "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_firewall")] | length')

    [ "$vpc_count" -eq 1 ] && pass "$label — 1 VPC, no subnets, no firewall" || fail "$label — expected 1 VPC, got $vpc_count"
    [ "$sub_count" -eq 0 ] && pass "$label — 0 subnets" || fail "$label — expected 0 subnets, got $sub_count"
    [ "$fw_count"  -eq 0 ] && pass "$label — 0 firewall" || fail "$label — expected 0 firewall, got $fw_count"

    rm -f "$VPC_TEST/tfplan.minimal"
  else
    fail "$label — terraform plan failed"
  fi

  # ---------- modules/compute_instance ----------
  CI_TEST="$REPO_ROOT/tests/compute_instance"

  label="plan compute_instance/valid.tfvars"
  if terraform -chdir="$CI_TEST" plan \
       -var-file="fixtures/valid.tfvars" \
       -out=tfplan.valid \
       -input=false -no-color > /dev/null 2>&1; then

    PLAN_JSON=$(terraform -chdir="$CI_TEST" show -json tfplan.valid 2>/dev/null)
    vm_count=$(echo  "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "google_compute_instance" and .change.actions[] == "create")] | length')
    pw_count=$(echo  "$PLAN_JSON" | jq '[(.resource_changes // [])[] | select(.type == "random_password"         and .change.actions[] == "create")] | length')

    [ "$vm_count" -eq 1 ] && pass "$label — 1 VM planned"              || fail "$label — expected 1 VM, got $vm_count"
    [ "$pw_count" -eq 1 ] && pass "$label — 1 random password planned" || fail "$label — expected 1 random_password, got $pw_count"

    rm -f "$CI_TEST/tfplan.valid"
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

[ "$FAIL" -eq 0 ]
