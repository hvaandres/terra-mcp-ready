#!/usr/bin/env bash
###############################################################################
# scan_secrets.sh — Scan the repo for things you probably don't want to commit
#
# Only inspects files that git would actually publish:
#   - tracked files (git ls-files)
#   - untracked files NOT matched by .gitignore
# Ignored files (terraform.tfstate, beginning_journey/.env, plan-*, service-
# account keys, etc.) are skipped by design.
#
# Exit codes:
#   0  — no findings (or only low-severity INFO findings)
#   1  — at least one HIGH-severity finding (blocks commit when used as a hook)
#   2  — invocation error
#
# Usage:
#   ./scripts/scan_secrets.sh              # report only
#   ./scripts/scan_secrets.sh --strict     # exit non-zero on any WARN too
#
# Install as a pre-commit hook:
#   ln -sf ../../scripts/scan_secrets.sh .git/hooks/pre-commit
###############################################################################

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

STRICT=false
[ "${1:-}" = "--strict" ] && STRICT=true

# ---------------------------------------------------------------------------
# Colors
# ---------------------------------------------------------------------------

green()  { printf "\033[32m%s\033[0m\n" "$*"; }
red()    { printf "\033[31m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
bold()   { printf "\033[1m%s\033[0m\n" "$*"; }
dim()    { printf "\033[2m%s\033[0m\n" "$*"; }

HIGH=0
WARN=0
INFO=0

hit_high() { red   "  [HIGH] $1"; HIGH=$((HIGH + 1)); }
hit_warn() { yellow "  [WARN] $1"; WARN=$((WARN + 1)); }
hit_info() { dim   "  [INFO] $1"; INFO=$((INFO + 1)); }

# ---------------------------------------------------------------------------
# Build the list of files that would be committed
# ---------------------------------------------------------------------------

# Exclude the scanner itself so its pattern strings don't self-match.
FILES=$(
  { git ls-files; git ls-files --others --exclude-standard; } \
  | sort -u \
  | grep -v '^scripts/scan_secrets\.sh$'
)
if [ -z "$FILES" ]; then
  echo "No files to scan."
  exit 0
fi

# Helper: grep all scannable files for an ERE pattern and label each hit
scan() {
  local severity="$1" label="$2" pattern="$3"
  local out
  out=$(printf '%s\n' "$FILES" | xargs -I{} grep -HnE "$pattern" {} 2>/dev/null || true)
  if [ -n "$out" ]; then
    while IFS= read -r line; do
      "hit_${severity}" "$label: $line"
    done <<< "$out"
  fi
}

scan_fixed() {
  local severity="$1" label="$2" pattern="$3"
  local out
  out=$(printf '%s\n' "$FILES" | xargs -I{} grep -HnF -- "$pattern" {} 2>/dev/null || true)
  if [ -n "$out" ]; then
    while IFS= read -r line; do
      "hit_${severity}" "$label: $line"
    done <<< "$out"
  fi
}

bold "═══════════════════════════════════════════════════════════════"
bold " terra-mcp-ready — pre-commit secret scan"
bold "═══════════════════════════════════════════════════════════════"
echo ""
dim "Scanning $(printf '%s\n' "$FILES" | wc -l | tr -d ' ') files…"
echo ""

# ---------------------------------------------------------------------------
# HIGH severity — almost always a real leak
# ---------------------------------------------------------------------------

bold "── High-severity patterns ───────────────────────────────────"

scan_fixed high "Private key header" "BEGIN RSA PRIVATE KEY"
scan_fixed high "Private key header" "BEGIN PRIVATE KEY"
scan_fixed high "Private key header" "BEGIN OPENSSH PRIVATE KEY"
scan_fixed high "Private key header" "BEGIN EC PRIVATE KEY"
scan_fixed high "Private key header" "BEGIN PGP PRIVATE KEY BLOCK"

scan high "Google service-account JSON" '"type"\s*:\s*"service_account"'
scan high "Google API key"              'AIza[0-9A-Za-z_-]{35}'
scan high "GCP OAuth refresh token"     '1//[0-9A-Za-z_-]{30,}'
scan high "AWS access key ID"           'AKIA[0-9A-Z]{16}'
scan high "AWS secret key"              'aws(.{0,20})?(secret|key)[^A-Za-z0-9]+[A-Za-z0-9/+=]{40}'
scan high "Azure storage key"           'DefaultEndpointsProtocol=https;AccountName='
scan high "Slack bot token"             'xox[baprs]-[A-Za-z0-9-]{10,}'
scan high "GitHub token"                'ghp_[A-Za-z0-9]{36,}'
scan high "Generic 'password=' in code" '(password|passwd|pwd)\s*[:=]\s*["'"'"'][^"'"'"']{4,}["'"'"']'

[ "$HIGH" -eq 0 ] && green "  ✓ No high-severity findings."
echo ""

# ---------------------------------------------------------------------------
# WARN — probably fine but worth a look
# ---------------------------------------------------------------------------

bold "── Likely-sensitive patterns ────────────────────────────────"

scan warn "GCP billing account ID (non-placeholder)" '\b(0[1-9A-F]|[1-9A-F][0-9A-F])[0-9A-F]{4}-[0-9A-F]{6}-[0-9A-F]{6}\b'
# Email addresses excluding common placeholder domains
scan warn "Real-looking email address"  '[A-Za-z0-9._%+-]+@(?!(example|test|localhost)\.)[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
scan warn "bearer / auth header token"  '(authorization|bearer)\s*[:=]\s*["'"'"']?[A-Za-z0-9._~/+=-]{20,}'
scan warn "JSON Web Token (JWT)"        'eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+'

[ "$WARN" -eq 0 ] && green "  ✓ No warnings."
echo ""

# ---------------------------------------------------------------------------
# INFO — PII you may or may not want in docs
# ---------------------------------------------------------------------------

bold "── Informational (personal identifiers, GCP IDs) ────────────"

scan info "GCP project-id format (may be your project)" '\b[a-z][-a-z0-9]{4,28}[a-z0-9]\b' || true

[ "$INFO" -eq 0 ] && green "  ✓ No informational hits."
echo ""

# ---------------------------------------------------------------------------
# Sanity: verify the usual-suspect files are actually ignored
# ---------------------------------------------------------------------------

bold "── .gitignore sanity checks ─────────────────────────────────"

must_ignore=(
  "beginning_journey/.env"
  "examples/storage_buckets/terraform.tfstate"
  "examples/projects/terraform.tfstate"
  "examples/storage_buckets/generated.tfvars.json"
  "examples/projects/generated.tfvars.json"
  "examples/storage_buckets/plan-2026"
  "some-credentials.json"
  "my-sa-key.json"
)
for f in "${must_ignore[@]}"; do
  if git check-ignore -q "$f" 2>/dev/null; then
    green "  ✓ $f (ignored)"
  else
    # Only an issue if the file actually exists
    if [ -e "$f" ]; then
      hit_high "$f EXISTS but is NOT gitignored"
    else
      dim "    $f (pattern covered; file not present)"
    fi
  fi
done
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

bold "═══════════════════════════════════════════════════════════════"
printf " Findings: %s | %s | %s\n" \
  "$(red "$HIGH high")" \
  "$(yellow "$WARN warn")" \
  "$(dim "$INFO info")"
bold "═══════════════════════════════════════════════════════════════"

if [ "$HIGH" -gt 0 ]; then
  exit 1
fi
if $STRICT && [ "$WARN" -gt 0 ]; then
  exit 1
fi
exit 0
