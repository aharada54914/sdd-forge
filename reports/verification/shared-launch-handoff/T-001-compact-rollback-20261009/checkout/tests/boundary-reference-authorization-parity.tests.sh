#!/usr/bin/env bash
# boundary-reference-authorization-parity.tests.sh — WFI-037: guidance and the
# authorization allowlist must not drift apart again.
#
# The sequence-402 incident and its recurrence (seq 795) happened because the
# boundary reference prescribed a verification whose steps read the identity
# ledger, an artifact `path_is_authorized` grants to NO role. This suite pins
# the reconciled state from both sides:
#  A. every step of the reference's record-chain verification names its
#     evidence source, and none of those sources is a ledger read;
#  B. the allowlist still refuses the ledger (the WFI's rejected alternative —
#     widening it — must stay rejected, or the hash-equality exemption it
#     would force reappears silently);
#  C. both validator twins emit the chain facts that made the ledger read
#     unnecessary, with identical keys;
#  D. all nine role documents carry one identical self-validation prohibition
#     paragraph, so the rule lives where the roles actually read.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DOC="$ROOT/plugins/sdd-review-loop/references/review-context-boundary.md"
VALIDATOR_SH="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.sh"
VALIDATOR_PS1="$ROOT/plugins/sdd-quality-loop/scripts/validate-review-context-set.ps1"

PASS=0
FAIL=0
ok()   { echo "ok: $*";   PASS=$((PASS+1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL+1)); }

for f in "$DOC" "$VALIDATOR_SH" "$VALIDATOR_PS1"; do
    [ -f "$f" ] || { echo "FAIL: missing input ${f#$ROOT/}"; exit 1; }
done

# ---------------------------------------------------------------------------
# A. The record-chain verification block: four numbered steps, each carrying
# an (evidence: ...) source, and every source drawn from what a role actually
# has — the caller-quoted line and its own manifest. A step without a source,
# or a source naming anything else, is the drift this suite exists to catch.
# ---------------------------------------------------------------------------
block="$(awk '/\*\*Verify the record chain/,/^If all four hold/' "$DOC")"
if [ -z "$block" ]; then
    fail "A: the record-chain verification block is gone from the boundary reference"
else
    steps=$(printf '%s\n' "$block" | grep -c '^[0-9]\.')
    if [ "$steps" -ne 4 ]; then
        fail "A: expected 4 numbered verification steps, found $steps"
    else
        ok "A: the verification procedure has exactly 4 steps"
    fi
    tagged=$(printf '%s\n' "$block" | grep -c '(evidence: ')
    if [ "$tagged" -ne 4 ]; then
        fail "A: expected every step to name its evidence source, found $tagged tags"
    else
        ok "A: every step names its evidence source"
    fi
    bad=$(printf '%s\n' "$block" | grep -o '(evidence: [^)]*)' | grep -cv 'caller-quoted line')
    if [ "$bad" -ne 0 ]; then
        fail "A: a step's evidence source is not the caller-quoted line (+ manifest): the reference is prescribing a read a role may not have"
    else
        ok "A: no step's evidence requires anything beyond the quoted line and the manifest"
    fi
    if printf '%s\n' "$block" | grep -qi 'read the ledger\|open the ledger\|hash the ledger'; then
        fail "A: the verification block instructs a ledger read again"
    else
        ok "A: the verification block instructs no ledger read"
    fi
fi

# ---------------------------------------------------------------------------
# B. The allowlist must still refuse the ledger for every role. The check is
# structural on both twins: the path-authorization logic must not name the
# ledger file. (The validator names the ledger elsewhere — as the constant it
# validates and appends to — so the assertion is scoped to the authorization
# functions.)
# ---------------------------------------------------------------------------
auth_sh="$(awk '/^path_is_authorized\(\)/,/^}/' "$VALIDATOR_SH")"
if [ -z "$auth_sh" ]; then
    fail "B: path_is_authorized() not found in the sh validator"
elif printf '%s\n' "$auth_sh" | grep -q 'identity-ledger'; then
    fail "B: the sh allowlist names the identity ledger — the rejected alternative crept in"
else
    ok "B: sh path_is_authorized still refuses the identity ledger"
fi
auth_ps1="$(awk '/function Test-AuthorizedPath/,/^}/' "$VALIDATOR_PS1")"
if [ -z "$auth_ps1" ]; then
    fail "B: Test-AuthorizedPath not found in the ps1 validator"
elif printf '%s\n' "$auth_ps1" | grep -q 'identity-ledger'; then
    fail "B: the ps1 allowlist names the identity ledger — the rejected alternative crept in"
else
    ok "B: ps1 Test-PathIsAuthorized still refuses the identity ledger"
fi

# ---------------------------------------------------------------------------
# C. Both twins emit the same chain-fact keys on the OK line. Static, so it
# runs on hosts without pwsh too; the runtime behaviour is covered by
# review-context-boundary.tests.sh's TEST-RCB cases.
# ---------------------------------------------------------------------------
for key in 'sequence=' 'previous_record_sha256=' 'pre_append_tip_sequence=' 'identity_unique=yes'; do
    sh_has=0; ps1_has=0
    grep -F "REVIEW_CONTEXT_OK" "$VALIDATOR_SH" | grep -Fq "$key" && sh_has=1
    grep -F "REVIEW_CONTEXT_OK" "$VALIDATOR_PS1" | grep -Fq "$key" && ps1_has=1
    if [ "$sh_has" -eq 1 ] && [ "$ps1_has" -eq 1 ]; then
        ok "C: both twins emit $key on the OK line"
    else
        fail "C: OK-line chain fact $key missing (sh=$sh_has ps1=$ps1_has)"
    fi
done

# ---------------------------------------------------------------------------
# D. The nine role documents carry one identical prohibition paragraph. The
# paragraph is extracted by its anchor sentence and byte-compared, so a doc
# that drifts or drops it fails by name.
# ---------------------------------------------------------------------------
ROLE_DOCS="
plugins/sdd-review-loop/agents/spec-reviewer-a.md
plugins/sdd-review-loop/agents/spec-reviewer-b.md
plugins/sdd-review-loop/agents/impl-reviewer-a.md
plugins/sdd-review-loop/agents/impl-reviewer-b.md
plugins/sdd-review-loop/agents/task-reviewer-a.md
plugins/sdd-review-loop/agents/task-reviewer-b.md
plugins/sdd-domain/agents/domain-reviewer-a.md
plugins/sdd-domain/agents/domain-reviewer-b.md
plugins/sdd-quality-loop/agents/evaluator.md
"
reference_para=""
for doc in $ROLE_DOCS; do
    para="$(awk -v RS= '/Never run `validate-review-context-set` against your own manifest/' "$ROOT/$doc")"
    if [ -z "$para" ]; then
        fail "D: $doc lacks the self-validation prohibition paragraph"
        continue
    fi
    if [ -z "$reference_para" ]; then
        reference_para="$para"
        ok "D: $doc carries the prohibition paragraph (reference copy)"
    elif [ "$para" = "$reference_para" ]; then
        ok "D: $doc matches the reference paragraph byte-for-byte"
    else
        fail "D: $doc's prohibition paragraph differs from the reference copy"
    fi
done

echo ""
echo "boundary-reference-authorization-parity.tests.sh: ${PASS} passed, ${FAIL} failed"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
