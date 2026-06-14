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

# Check if ruleset already exists by name
echo "Checking for existing ruleset '$RULESET_NAME'..."
existing_id=$(gh api "repos/${GITHUB_REPOSITORY}/rulesets" \
  -q ".[] | select(.name == \"${RULESET_NAME}\") | .id" 2>/dev/null || echo "")

if [ -n "$existing_id" ]; then
  echo "Found existing ruleset ID $existing_id. Updating..."
  if gh api -X PUT "repos/${GITHUB_REPOSITORY}/rulesets/${existing_id}" --input "$RULESET_FILE" 2>&1; then
    echo "Successfully updated branch protection ruleset."
    exit 0
  else
    handle_api_error
  fi
else
  echo "No existing ruleset found. Creating new..."
  if gh api -X POST "repos/${GITHUB_REPOSITORY}/rulesets" --input "$RULESET_FILE" 2>&1; then
    echo "Successfully created branch protection ruleset."
    exit 0
  else
    handle_api_error
  fi
fi
