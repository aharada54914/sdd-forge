#!/usr/bin/env bash
# human-copy-mirror-freshness.tests.sh — WFI-039.
#
# A repository-shared file can be snapshotted in several places at once: one
# copy per specs/*/human-copy/ bundle that ever needed a human to apply it, plus
# any specs/*/drafts/human-copy-candidate/ set. Each existing suite enforces its
# own bundle and is blind to the others, so editing a shared file surfaces the
# mirrors one CI round at a time -- three rounds on PR #305, one mirror each.
#
# This suite does not replace those checks. It adds the one thing none of them
# can do: enumerate EVERY mirror and report EVERY stale one in a single failure.
#
# Classification, applied uniformly to every mirror:
#
#   fresh    staged bytes == live bytes. Nothing to do.
#   stale    staged != live, and staged == origin/main's live. The bundle was
#            already applied and this branch moved the live file without
#            syncing. This is the failure case.
#   pending  staged != live, and staged != origin/main's live. The bundle is a
#            reviewed change still waiting for a human to apply it. Reported for
#            visibility, never failed, and never touched by the sync tool.
#
# The pending/stale distinction is the whole safety story. specs/
# epic-159-pillar-c/human-copy/ stages a role definition at bytes that differ
# from main's live file; a tool treating "staged differs from live" as stale
# would overwrite reviewed human work, and CI would go green because no suite
# enforces byte-identity for that bundle. staged-equals-main is what separates
# the two, and it is not guessable from the file alone.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd -P)"
PASS=0
FAIL=0
PENDING=0

ok()   { printf 'ok: %s\n' "$1";   PASS=$((PASS + 1)); }
bad()  { printf 'not ok: %s\n' "$1" >&2; FAIL=$((FAIL + 1)); }
note() { printf 'pending: %s\n' "$1"; PENDING=$((PENDING + 1)); }

if ! command -v python3 >/dev/null 2>&1; then
    echo "skip - human-copy-mirror-freshness.tests.sh requires python3 (not found)"
    exit 0
fi

# origin/main is the reference for "was this bundle already applied". Without it
# every mirror that differs from live is indistinguishable from pending work, so
# the suite would either fail on legitimate pending bundles or pass vacuously.
# Skip visibly rather than guess.
if ! git -C "$ROOT" rev-parse --verify --quiet origin/main >/dev/null 2>&1; then
    echo "skip - origin/main is not available (shallow clone?); mirror freshness not checked"
    exit 0
fi

REPORT="$(python3 "$ROOT/scripts/human_copy_mirrors.py" "$ROOT")" || { bad "mirror enumeration failed to run"; printf '\nhuman-copy-mirror-freshness.tests.sh: %d passed, %d failed\n' "$PASS" "$FAIL"; exit 1; }

total=$(printf '%s\n' "$REPORT" | grep -c . || true)
[ "$total" -gt 0 ] || bad "enumeration found no mirrors at all -- the walk is broken, not the tree clean"

# Non-vacuity: the enumeration must actually reach the bundles this WFI was
# written about. A walk that silently matched nothing would report a green tree.
for expected_bundle in \
    specs/epic-189-a1-project-context/human-copy \
    specs/epic-190-a2-capability-registry/human-copy \
    specs/epic-191-a3-path-ownership/human-copy \
    specs/epic-136-phase2-gates/human-copy; do
    if printf '%s\n' "$REPORT" | cut -f2 | grep -qx "$expected_bundle"; then
        ok "enumeration reaches $expected_bundle"
    else
        bad "enumeration never reached $expected_bundle -- the walk missed a known bundle"
    fi
done

stale="$(printf '%s\n' "$REPORT" | awk -F'\t' '$1 == "STALE"')"
missing="$(printf '%s\n' "$REPORT" | awk -F'\t' '$1 == "MISSING"')"

while IFS=$'\t' read -r _ bundle rel rule; do
    [ -n "${bundle:-}" ] || continue
    note "$bundle carries un-applied bytes for $rel ($rule) -- awaiting a human apply, left alone"
done < <(printf '%s\n' "$REPORT" | awk -F'\t' '$1 == "PENDING"')

if [ -n "$missing" ]; then
    while IFS=$'\t' read -r _ bundle rel rule; do
        [ -n "${bundle:-}" ] || continue
        bad "$bundle stages $rel ($rule) but the live file does not exist"
    done < <(printf '%s\n' "$missing")
fi

# MANIFEST-STALE is a distinct failure from STALE and neither implies the other.
# A change that rewrites live and staged identically leaves them agreeing while
# the manifest digest silently goes stale -- a branch-wide rename did exactly
# that, and only phase2-guard-invariants caught it, one CI round later.
manifest_stale="$(printf '%s\n' "$REPORT" | awk -F'\t' '$1 == "MANIFEST-STALE"')"
if [ -z "$manifest_stale" ]; then
    ok "every manifest digest matches the staged bytes it describes"
else
    printf 'not ok: manifest digests are stale -- run scripts/sync-human-copy-mirrors.py\n' >&2
    while IFS=$'\t' read -r _ bundle rel _rule; do
        [ -n "${bundle:-}" ] || continue
        printf '    %s  <- %s\n' "$bundle" "$rel" >&2
    done < <(printf '%s\n' "$manifest_stale")
    FAIL=$((FAIL + 1))
fi

if [ -z "$stale" ]; then
    ok "every applied human-copy mirror is byte-identical to live"
else
    printf 'not ok: stale human-copy mirrors -- run scripts/sync-human-copy-mirrors.py\n' >&2
    while IFS=$'\t' read -r _ bundle rel rule; do
        [ -n "${bundle:-}" ] || continue
        printf '    %s  <- %s (%s)\n' "$bundle" "$rel" "$rule" >&2
    done < <(printf '%s\n' "$stale")
    FAIL=$((FAIL + 1))
fi

printf '\n%s: %d passed, %d failed, %d pending (informational)\n' \
    "$(basename "$0")" "$PASS" "$FAIL" "$PENDING"
[ "$FAIL" -eq 0 ] || exit 1
