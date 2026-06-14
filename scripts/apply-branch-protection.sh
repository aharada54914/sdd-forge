#!/bin/sh
# apply-branch-protection.sh — Apply GitHub branch protection ruleset via gh API.
#
# Usage:
#   ./scripts/apply-branch-protection.sh [--dry-run]
#
# Behavior:
#   - Reads .github/rulesets/main.json
#   - Attempts to apply ruleset via gh API POST /repos/{owner}/{repo}/rulesets
#   - If gh API fails due to free tier or permission issues, prints clear MANUAL steps
#   - Dry-run mode prints what would be executed without making changes
#
# Requirements:
#   - gh CLI installed and authenticated
#   - GITHUB_REPOSITORY set (auto in GitHub Actions; else set manually)
#   - .github/rulesets/main.json present
#
# Exit codes:
#   0 = ruleset applied or manual steps printed
#   1 = missing dependencies or invalid input

set -eu

DRY_RUN=0

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

# Print manual fallback steps when the gh API call fails (free tier / no admin).
# Defined before first use: under `set -eu` a function called before its
# definition aborts the script with "command not found", which would swallow
# the fallback entirely.
handle_api_error() {
  echo ""
  echo "GitHub API call failed. This may be due to:"
  echo "  1. Free tier plan (rulesets require GitHub Team or Enterprise)"
  echo "  2. Insufficient permissions (need 'admin' role)"
  echo "  3. Rate limiting"
  echo ""
  echo "MANUAL FALLBACK STEPS:"
  echo "  1. Open https://github.com/${GITHUB_REPOSITORY}/settings/rules"
  echo "  2. Click 'New branch ruleset'"
  echo "  3. Name: 'Protect main branch'"
  echo "  4. Target: 'Apply to the default branch'"
  echo "  5. Enable the following rules:"
  echo "     - Require a pull request before merging (1 approval, dismiss stale reviews)"
  echo "     - Require status checks to pass:"
  echo "       . test (windows-latest)"
  echo "       . test (macos-latest)"
  echo "       . test (ubuntu-latest)"
  echo "       . required-checks"
  echo "     - Require branches to be up to date before merge"
  echo "     - Block force pushes"
  echo "     - Block deletions"
  echo "  6. Create ruleset"
  echo ""
  exit 0
}

# Validate prerequisites
if ! command -v gh >/dev/null 2>&1; then
  echo "Error: gh CLI not found. Install from https://cli.github.com/" >&2
  exit 1
fi

if [ -z "${GITHUB_REPOSITORY:-}" ]; then
  echo "Error: GITHUB_REPOSITORY not set. Export GITHUB_REPOSITORY=owner/repo" >&2
  exit 1
fi

RULESET_FILE=".github/rulesets/main.json"
if [ ! -f "$RULESET_FILE" ]; then
  echo "Error: Ruleset file not found: $RULESET_FILE" >&2
  exit 1
fi

# Validate JSON
if ! python3 -c "import json; json.load(open('$RULESET_FILE'))" 2>/dev/null; then
  echo "Error: Invalid JSON in $RULESET_FILE" >&2
  exit 1
fi

# Extract ruleset name from JSON
RULESET_NAME=$(python3 -c "import json; print(json.load(open('$RULESET_FILE')).get('name', 'Protect main branch'))")

echo "Applying branch protection ruleset '$RULESET_NAME' to ${GITHUB_REPOSITORY}..."

if [ "$DRY_RUN" = 1 ]; then
  echo "[DRY RUN] Would execute:"
  echo "  gh api -X POST repos/${GITHUB_REPOSITORY}/rulesets --input ${RULESET_FILE}"
  exit 0
fi

# Check if a ruleset with this name already exists.
#
# The rulesets LIST API (GET .../rulesets) returns a JSON ARRAY on success, but
# on repos where rulesets are unavailable (e.g. GitHub Free + private) it
# returns an error OBJECT instead, e.g.:
#   {"message":"Upgrade to GitHub Pro ...","documentation_url":"...","status":"403"}
# and `gh api` prints that body to stdout while exiting non-zero. We must NOT
# mistake that object for a ruleset record. Previously the inline `-q` filter +
# `|| echo ""` captured the whole error JSON as the "existing id", producing a
# malformed PUT URL (repos/.../rulesets/%7B%22message%22... -> "unsupported
# protocol scheme"). So: only mine an id when the call SUCCEEDS *and* the body
# is a JSON array with no top-level API error. Otherwise fall through to the
# create (POST) attempt, which surfaces the MANUAL FALLBACK steps on failure.
echo "Checking for existing ruleset '$RULESET_NAME'..."
existing_id=""
if rulesets_json=$(gh api "repos/${GITHUB_REPOSITORY}/rulesets" 2>/dev/null); then
  existing_id=$(
    printf '%s' "$rulesets_json" | python3 -c '
import json, sys

name = sys.argv[1]
try:
    data = json.load(sys.stdin)
except Exception:
    sys.exit(0)

# A successful list is a JSON array. An API error is an object carrying
# "status"/"message". Treat anything that is not a plain array as "no existing
# ruleset" so we fall through to create / manual fallback instead of building a
# bogus update URL out of an error payload.
if not isinstance(data, list):
    sys.exit(0)

for rs in data:
    if isinstance(rs, dict) and rs.get("name") == name:
        print(rs.get("id", ""))
        break
' "$RULESET_NAME" 2>/dev/null || echo ""
  )
fi

if [ -n "$existing_id" ]; then
  echo "Found existing ruleset ID $existing_id. Updating..."
  if gh api -X PUT "repos/${GITHUB_REPOSITORY}/rulesets/${existing_id}" --input "$RULESET_FILE" 2>&1; then
    echo "Successfully updated branch protection ruleset."
    exit 0
  else
    handle_api_error
  fi
else
  echo "No existing ruleset found (or rulesets unavailable). Creating new..."
  if gh api -X POST "repos/${GITHUB_REPOSITORY}/rulesets" --input "$RULESET_FILE" 2>&1; then
    echo "Successfully created branch protection ruleset."
    exit 0
  else
    handle_api_error
  fi
fi
