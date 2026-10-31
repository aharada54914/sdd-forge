"""Pinned documentation amendment; default is dry-run, never a gate verdict."""
import argparse
import difflib
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path('/Users/jrmag/.codex/worktrees/a8-release-sync-oct01/sdd-forge')
HEAD = '495c88d67af44530687ecea3ce9fb0a90a336539'
FEATURE = 'specs/epic-196-a8-integration/'
BASE = {
    FEATURE+'requirements.md': 'f841443d88b4f58fdbb9e32ee050edf8395f3767ebbc08cc2d9d6be76cb3ac44',
    FEATURE+'design.md': 'c2a30f22f833f9a30ffeff01960d7f5304af262ba9ab4f0b9aad67f75b604cca',
    FEATURE+'acceptance-tests.md': '4d089666d69b5f565c4cd6fd091404e31b15eda063463850a862a816d42797c1',
    FEATURE+'tasks.md': '44b3658c28a1e216239b46a5bd80e58776099e1a4efd7e9e77b0728118634f6b',
    FEATURE+'traceability.md': 'b3ca32a2ce5d22208918f58f17a4f1736492023d78ec91dc40f6633e9d039f61',
    FEATURE+'ux-spec.md': 'c4dfe23795970cdcd3e6afe1bb8bd4cd512b14d638040598722c8b13d416e286',
    FEATURE+'frontend-spec.md': 'c992f19d99797c4189fe013380ba28d86c8b18dd691ddf642c09fbaa7aadfa76',
    FEATURE+'infra-spec.md': '59f2f26bbead2b5b5effa89642b58867f168db602b9c0738a65350a1fa02ae9e',
    FEATURE+'security-spec.md': '45adc9bd1ffcfc1519444ce61a798b7d0f270851e393729b867c853d2aafcbe7',
    'docs/adr/0028-live-host-proof-ed25519-signing.md': '17b6c83d22126ed1095d556a80b3cb14173e4975deee039e5871656ce416186c',
}
COMMON = '''

## AC-016 inventory amendment (2026-10-06; superseding contract)

This dated amendment supersedes this document's prospective references to
`live-host-verification-record/v1` for REQ-003/REQ-006 and AC-015/016/026/028:
new evidence uses `live-host-verification-record/v2` as defined in design.md's
AC-016 inventory amendment. Earlier text/examples describe the retained v1
baseline, not an alternative current schema. Historical records and verdicts
remain unchanged and are not automatically promoted to v2 evidence. No dual
version acceptance path is required. Adoption is not review PASS or live proof.
Existing five semantic cells, required checks, SKIP rules, native evidence,
signer independence, nonce rules and task approval/status remain unchanged.
'''
DETAIL = {
 'requirements.md': '''
AC-016 retains its five consumers per runtime/cell: sdd-bootstrap,
sdd-bootstrap-interviewer, lite-gate, lite-spec, and sdd-ship. The signed record
stores their entry-point names and source citations in `consumer_inventory`;
runtime/cell are inherited from the containing record. AC-015/026/028 require
the complete inventory before discharge. Source availability alone is not
execution proof: the existing operator and independent reviewer confirm actual
exercise against the existing native evidence. Shared captures are permitted;
no additional sessions, canaries or signatures are required.
''',
 'design.md': '''
### Data/API delta

In the existing record example and exact-key schema, change the schema constant
to `live-host-verification-record/v2` and add one required key,
`consumer_inventory`. Its value is null for SKIP (all existing SKIP rules still
apply); otherwise it is an array of exactly five objects. Each object has exactly
three non-empty string keys: `entry_point`, `source_commit`, `source_path`.
The unique, case-sensitive entry-point set and path mapping are:

| entry_point | source_path |
| --- | --- |
| sdd-bootstrap | plugins/sdd-bootstrap/skills/bootstrap/SKILL.md |
| sdd-bootstrap-interviewer | plugins/sdd-bootstrap/skills/sdd-bootstrap-interviewer/SKILL.md |
| lite-gate | plugins/sdd-lite/skills/lite-gate/SKILL.md |
| lite-spec | plugins/sdd-lite/skills/lite-spec/SKILL.md |
| sdd-ship | plugins/sdd-ship/skills/ship/SKILL.md |

Reuse AC-016's source commit and path/blob inventory already held in
`plugins/sdd-review-loop/references/a8-skip-allowlist.json`. Each source_commit
must equal that accepted commit; resolve the Git object for each source_path and
compare its blob ID with the accepted inventory. Reverify the shared source map
and all five objects at review/adoption and when collecting evidence; never
substitute a moving branch tip. Runtime and matrix_cell come from the containing
record. Array order has no semantic meaning (the exact serialized array remains
signed). The validator rejects missing/null/non-array inventory for non-SKIP,
wrong count, duplicate/unknown/missing consumers, unexpected entry keys, wrong
types/path/commit, and unresolved or mismatched Git objects with the existing
ERR_SCHEMA_INVALID diagnostic before aggregate discharge. FAIL remains FAIL.

Storage remains the existing per-cell record; no separate inventory file or
ledger is added. Operator/reviewer verify all five consumers were actually
exercised in the containing record's cell against its existing native evidence,
not merely present in source. A shared transcript is allowed. Unavailable cells
retain expected-unavailability behavior; they do not claim hook interception.

The existing RFC 8785 JCS target removes only operator_signature and
reviewer_signature and therefore signs consumer_inventory without a new signing
mechanism (validate-live-host-proof.py:399-417; fixture signer run_cases.py:187).
Any inventory mutation after signing invalidates the existing signatures.
These source claims must be rechecked against the exact implementation reviewed.
All other v1 fields, raw capture bindings and verification rules carry forward.
No production implementation is deemed complete by this amendment.
''',
 'acceptance-tests.md': '''
TEST-016 is expanded within the existing five semantic-cell fixture set (not a
new live-session matrix). Each cell must cover the complete five named consumers
from design.md and verify: (1) full inventory accepts structurally; (2) absence,
null/non-array, wrong count, each missing consumer, duplicate/unknown names,
unexpected keys, wrong types/path/commit, and unresolved/mismatched source
objects reject before discharge; (3) order-permuted inventory accepts when
properly signed; (4) changing inventory after signing rejects for signature
mismatch; (5) SKIP requires null inventory and retains activation/staleness rules;
(6) FAIL cannot discharge. TEST-015/026/028 retain every existing test obligation
and apply to v2. Fixture success is not proof of actual five-consumer execution;
the existing human-reviewed native evidence remains necessary for live claims.
''',
 'tasks.md': '''
T-005 owns the v2 schema/validator delta and TEST-016 structural/source/signature
negative coverage defined in the amended design and acceptance tests. T-008
populates the same inventory in the existing five cell records and preserves its
ban on agent-created genuine signed evidence. This supersedes T-008's earlier
inventory-shape prose and prospective v1 references, not the five-cell scope or
human attestation boundary. No new tasks, status/approval changes, Done claims,
extra sessions or signing operations are introduced. Rebind affected design and
task inputs through independent review before implementing this delta.
''',
 'traceability.md': '''
REQ-003/REQ-006 -> AC-016 -> design.md AC-016 inventory amendment -> TEST-016
expanded fixture cases -> T-005 validator/negative tests and T-008 cell population.
AC-015/026/028 retain their existing mappings and require the same v2 inventory.
This supersedes earlier source-inventory-only/v1 mappings, not historical status.
Implementation, independent gates and live evidence remain pending.
''',
 'ux-spec.md': '''
No new user interaction or consent is added. Existing live-evidence collection
reports incomplete inventory as a validation failure, not as completed live proof.
''',
 'frontend-spec.md': '''
The existing shared validator and Bash/PowerShell wrappers consume v2. The same
six schema families and existing command surfaces remain; v2 replaces only the
live-host-record version and adds its typed inventory, not a seventh schema.
''',
 'infra-spec.md': '''
The existing five per-cell output locations and capture/signing process remain.
Their v2 records carry the inventory; collection rechecks the existing pinned
source objects. No additional service, session matrix, scheduling or ledger.
''',
 'security-spec.md': '''
B1/B4/B5 apply unchanged to v2. Its inventory is inside the existing two-role JCS
signature target; listing consumers is not proof of live execution. Human review
of genuine native evidence, distinct signers and all nonce controls remain.
''',
 '0028-live-host-proof-ed25519-signing.md': '''
Decision 4's narrow record-signing scope includes the v2 successor described in
the A8 design's AC-016 inventory amendment. Historical context and Proposed
status are retained. Only the two existing signature fields are excluded from
JCS, so the one new inventory field is signed by the existing mechanism. No key,
authority, signature-count or nonce contract change is introduced.
''',
}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def prepare(root=ROOT):
    changes = []
    for rel, expected in BASE.items():
        target = root / rel
        if target.is_symlink() or not target.is_file():
            raise ValueError('Not a regular target: '+rel)
        before = target.read_bytes()
        if digest(before) != expected:
            raise ValueError('Hash mismatch; no application: '+rel)
        after = before + (COMMON+DETAIL[target.name]).encode()
        changes.append((rel, before, after))
    return changes

def apply_changes(changes, root=ROOT):
    backup = Path(tempfile.mkdtemp(prefix='a8-ac016-human-backup-'))
    writes_started = False
    try:
        for rel, before, after in changes:
            dest = backup / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(before)
            if dest.read_bytes() != before:
                raise ValueError('Backup readback mismatch: '+rel)
        print('BACKUP:', backup, flush=True)
        # Recheck all targets after backup, before the first target write.
        if prepare(root) != changes:
            raise ValueError('Candidate changed after backup')
        for rel, before, after in changes:
            target = root / rel
            if target.read_bytes() != before:
                raise ValueError('Target changed during application: '+rel)
            writes_started = True
            target.write_bytes(after)
            if target.read_bytes() != after:
                raise ValueError('Readback mismatch: '+rel)
        for rel, before, after in changes:
            if (root / rel).read_bytes() != after:
                raise ValueError('Final readback mismatch: '+rel)
        print('APPLIED_READBACK_OK: documents only; formal review/implementation/tests/live/CI pending')
    except BaseException:
        state = ('application may be partial. Inspect all ten targets before any retry or scoped recovery'
                 if writes_started else 'no target write attempted')
        print('STOP: backup retained at '+str(backup)+'; '+state+'; do not auto-restore.', flush=True)
        raise

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--emit-candidates', action='store_true')
    parser.add_argument('--apply-human', action='store_true')
    args = parser.parse_args()
    actual = subprocess.check_output(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'], text=True).strip()
    if actual != HEAD:
        raise SystemExit('STOP: owner HEAD changed; re-review candidate')
    changes = prepare()
    for rel, before, after in changes:
        print(f'PIN {rel} before={digest(before)} after={digest(after)}')
    if args.emit_candidates:
        out = Path(tempfile.mkdtemp(prefix='a8-ac016-candidate-'))
        patch = []
        for rel, before, after in changes:
            dest = out / rel
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(after)
            patch.extend(difflib.unified_diff(before.decode().splitlines(True), after.decode().splitlines(True), fromfile='a/'+rel, tofile='b/'+rel))
        (out/'candidate.patch').write_text(''.join(patch))
        print('CANDIDATES:', out)
    if not args.apply_human:
        print('DRY_RUN_OK: originals unchanged; no review/reservation/Git operation')
        return
    apply_changes(changes)

if __name__ == '__main__':
    main()
