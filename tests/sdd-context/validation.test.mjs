import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, realpathSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { performance } from 'node:perf_hooks';
import test, { after } from 'node:test';

// Fixed contract for the single T-001 entrance; no admission substitute.
// validate(rawJSON, trustedContext) returns the validated/redacted object only.
// trustedContext is core-owned, never copied from request fields.
const subject = new URL('../../plugins/sdd-context/validation.mjs', import.meta.url);
const validate = existsSync(subject) ? (await import(subject.href)).validate : undefined;
const scratch = realpathSync(mkdtempSync(join(tmpdir(), 'sdd-context-validation-')));
after(() => rmSync(scratch, { recursive: true, force: true }));
function git(root, ...args) {
  const env = { ...process.env };
  // Keep fixture commits/index/object storage isolated from repository-selection env.
  for (const key of Object.keys(env)) if (key.startsWith('GIT_')) delete env[key];
  Object.assign(env, { GIT_AUTHOR_NAME: 'SDD fixture', GIT_AUTHOR_EMAIL: 'fixture@example.invalid',
    GIT_COMMITTER_NAME: 'SDD fixture', GIT_COMMITTER_EMAIL: 'fixture@example.invalid' });
  const result = spawnSync('rtk', ['proxy', 'git', '-C', root, ...args], { encoding: 'utf8', env });
  assert.equal(result.error, undefined, 'fixture Git executor unavailable');
  assert.equal(result.status, 0, `fixture Git setup failed: ${result.stderr}`);
  return result.stdout;
}
function fixture(name, ignored = true, objectFormat = 'sha1') {
  const root = join(scratch, name);
  mkdirSync(root);
  git(root, 'init', '--quiet', `--object-format=${objectFormat}`);
  mkdirSync(join(root, 'specs', 'fixture-feature'), { recursive: true });
  mkdirSync(join(root, '.sdd', 'context'), { recursive: true });
  writeFileSync(join(root, '.gitignore'), ignored ? '.sdd/context/**\n' : '');
  const owner = { schemaVersion: 1, sddRoot: root, worktreeRoot: root,
    gitDirectory: realpathSync(join(root, '.git')), featureId: 'fixture-feature',
    host: 'codex', sessionId: 'fixture-session' };
  return { root, owner, target: join(root, '.sdd', 'context', 'prepared.json') };
}
function commitFixture(f) {
  git(f.root, '-c', 'commit.gpgsign=false', 'commit', '--quiet', '--allow-empty', '-m', 'synthetic fixture');
  return git(f.root, 'rev-parse', '--verify', 'HEAD').trim();
}
const normal = fixture('normal', true, 'sha256');
const normalHead = commitFixture(normal);
const sha1 = fixture('sha1');
const sha1Head = commitFixture(sha1);
const unsupportedGit = fixture('unsupported-format', true, 'sha256');
const unsupportedHead = commitFixture(unsupportedGit);
git(unsupportedGit.root, 'config', 'extensions.objectFormat', 'unsupported');
const missingIgnore = fixture('missing-ignore', false);
const negatedIgnore = fixture('negated-ignore');
writeFileSync(join(negatedIgnore.root, '.gitignore'), '.sdd/context/**\n!.sdd/context/prepared.json\n');
const tracked = fixture('tracked');
writeFileSync(tracked.target, 'fixture');
git(tracked.root, 'add', '--force', '.sdd/context/prepared.json');
const brokenGit = fixture('broken-git');
rmSync(join(brokenGit.root, '.git'), { recursive: true });
const outside = join(scratch, 'outside');
mkdirSync(outside);
symlinkSync(outside, join(normal.root, '.sdd', 'context', 'escape'));

const hash = 'a'.repeat(64);
const task = { id: 'T-001', approval: 'Approved', status: 'In Progress', blockersNonEmpty: false };
const cursor = () => ({ schemaVersion: 1, owner: { ...normal.owner }, segmentId: 'segment', sequence: 0, hash });
const projection = () => ({ schemaVersion: 1, owner: { ...normal.owner }, head: normalHead,
  authorityHashes: [{ path: 'specs/fixture-feature/tasks.md', sha256: hash }],
  taskLifecycle: [{ ...task }], featurePresent: true, journalCursor: null, decisions: [] });
const observation = owner => ({ schemaVersion: 1, owner: { ...owner }, kind: 'prompt', text: 'ordinary text', coverage: 'complete' });
function context(type, f = normal, extra = {}) {
  return { type, owner: { ...f.owner }, plannedPaths: [f.target], journalEmpty: true,
    deadline: performance.now() + 1000, ...extra };
}
const admit = (value, type = 'ProjectionV1', extra = {}) => validate(JSON.stringify(value), context(type, normal, extra));
function rejected(value, type = 'ProjectionV1', f = normal, extra = {}, raw = false) {
  const forwarded = [];
  let caught;
  try { forwarded.push(validate(raw ? value : JSON.stringify(value), context(type, f, extra))); }
  catch (error) { caught = error; }
  assert.equal(forwarded.length, 0, 'rejected input returned an in-memory writable result');
  assert.ok(caught instanceof Error, 'expected content-free rejection');
  assert.deepEqual(Object.keys(caught), ['code']);
  assert.match(caught.code, /^[a-z][a-z-]*$/);
  assert.equal(caught.message, caught.code);
  assert.equal(caught.stack, undefined);
  assert.equal(caught.cause, undefined);
}
function check(name, body) {
  test(name, () => {
    assert.equal(typeof validate, 'function', 'shared validate API is not implemented');
    body();
  });
}

test('fixture control: real Git ignore and tracked states are distinct', () => {
  assert.ok(git(normal.root, 'check-ignore', '--no-index', normal.target).trim());
  assert.equal(git(tracked.root, 'ls-files', '--', tracked.target).trim(), '.sdd/context/prepared.json');
});
check('VALIDATION-API: one real shared entrance exists', () => {});
check('PROJECTION-VALID: approved empty-journal shape returns the validated object', () => {
  assert.deepEqual(admit(projection()), projection());
});
check('ID-1024: ASCII and multibyte opaque IDs accept exactly 1024 UTF-8 bytes', () => {
  for (const id of ['x'.repeat(1024), '🙂'.repeat(256)]) {
    const value = projection(); value.journalCursor = { ...cursor(), segmentId: id };
    assert.equal(admit(value, 'ProjectionV1', { journalEmpty: false }).journalCursor.segmentId, id);
  }
});
check('ID-INVALID: empty, 1025-byte and malformed Unicode opaque IDs reject', () => {
  for (const id of ['', 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    const value = projection(); value.journalCursor = { ...cursor(), segmentId: id };
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
});
check('HASH-VALID: distinct authority paths may share a hash', () => {
  const value = projection(); value.authorityHashes.push({ path: 'specs/fixture-feature/design.md', sha256: hash });
  assert.deepEqual(admit(value).authorityHashes, value.authorityHashes);
});
check('HASH-CLOSED: every authority entry requires path/sha256 and forbids extra fields', () => {
  for (const entry of [{ sha256: hash }, { path: 'p' }, { path: 'p', sha256: hash, extra: true }, { path: 1, sha256: hash }]) {
    const value = projection(); value.authorityHashes = [entry]; rejected(value);
  }
});
check('HASH-DUPLICATE: duplicate authority paths reject even with identical hashes', () => {
  const value = projection(); value.authorityHashes.push({ ...value.authorityHashes[0] }); rejected(value);
});
check('HASH-FORMAT: authority digests reject uppercase, wrong size and non-hex', () => {
  for (const digest of ['A'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64)]) {
    const value = projection(); value.authorityHashes[0].sha256 = digest; rejected(value);
  }
});
check('TASK-VALID: existing taskEntry optional fields and lifecycle enums accept', () => {
  for (const status of ['Planned', 'In Progress', 'Blocked', 'Implementation Complete', 'Done']) {
    const value = projection(); value.taskLifecycle = [{ ...task, status, approvalAnnotation: 'human',
      risk: 'high', requiredWorkflow: 'tdd', secondApproval: 'pending' }];
    assert.deepEqual(admit(value).taskLifecycle, value.taskLifecycle);
  }
});
check('TASK-CLOSED: required fields, field types and taskStateData-only extensions reject', () => {
  for (const field of Object.keys(task)) {
    const value = projection(); delete value.taskLifecycle[0][field]; rejected(value);
  }
  for (const change of [{ tasksFile: 'tasks.md' }, { failures: [] }, { extra: true }, { blockersNonEmpty: 'false' },
    { id: 'T-one' }, { approvalAnnotation: false }, { requiredWorkflow: [] }, { secondApproval: 1 }]) {
    const value = projection(); Object.assign(value.taskLifecycle[0], change); rejected(value);
  }
});
check('TASK-ENUM: invalid approval/status/risk values reject', () => {
  for (const change of [{ approval: 'approved' }, { status: 'done' }, { risk: 'High' }]) {
    const value = projection(); Object.assign(value.taskLifecycle[0], change); rejected(value);
  }
});
check('CURSOR-NULL: nonempty journal forbids a null cursor', () => {
  rejected(projection(), 'ProjectionV1', normal, { journalEmpty: false });
});
check('CURSOR-VALID: closed owned cursor accepts for a nonempty journal', () => {
  const value = projection(); value.journalCursor = cursor();
  assert.deepEqual(admit(value, 'ProjectionV1', { journalEmpty: false }).journalCursor, value.journalCursor);
});
check('CURSOR-CLOSED: each required field, safe sequence, hash and content extensions are checked', () => {
  for (const field of Object.keys(cursor())) {
    const value = projection(); value.journalCursor = cursor(); delete value.journalCursor[field];
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
  for (const change of [{ schemaVersion: 2 }, { sequence: -1 }, { sequence: 0.5 },
    { sequence: Number.MAX_SAFE_INTEGER + 1 }, { hash: 'bad' }, { text: 'foreign content' }]) {
    const value = projection(); value.journalCursor = { ...cursor(), ...change };
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
});
check('OWNER-MISMATCH: repository/worktree/Git directory/feature/host/session cannot self-authorize', () => {
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory', 'featureId', 'host', 'sessionId']) {
    const value = observation(normal.owner); value.owner[field] = field === 'host' ? 'claude' : 'foreign';
    rejected(value, 'ObservationV1');
  }
});
check('CURSOR-FOREIGN: foreign owner and unproven predecessor session reject', () => {
  for (const change of [{ owner: { ...normal.owner, sessionId: 'foreign' } }, { predecessorSessionId: 'unproven' }]) {
    const value = projection(); value.journalCursor = { ...cursor(), ...change };
    rejected(value, 'ProjectionV1', normal, { journalEmpty: false });
  }
});
check('SCHEMA-CLOSED: projection/owner version, required fields and unknown keys reject', () => {
  for (const field of Object.keys(projection())) { const value = projection(); delete value[field]; rejected(value); }
  for (const field of Object.keys(normal.owner)) { const value = projection(); delete value.owner[field]; rejected(value); }
  for (const change of [{ schemaVersion: 2 }, { featurePresent: 'true' }, { taskLifecycle: {} }, { decisions: {} }, { extra: true }]) {
    const value = { ...projection(), ...change }; rejected(value);
  }
  const value = projection(); value.owner.extra = true; rejected(value);
});
check('JSON-DUPLICATE: duplicate decoded fields reject through the same entrance', () => {
  const source = JSON.stringify(observation(normal.owner)).replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1');
  rejected(source, 'ObservationV1', normal, {}, true);
});
check('REQUEST-AUTHORITY: caller cannot supply receipt/sequence/expiry/path/budget/lifecycle', () => {
  for (const field of ['receivedAtUtc', 'sequence', 'expiry', 'plannedPaths', 'deadline', 'taskLifecycle']) {
    const value = observation(normal.owner); value[field] = 'caller'; rejected(value, 'ObservationV1');
  }
});
check('IGNORE-MISSING: non-ignored content target rejects', () => rejected(observation(missingIgnore.owner), 'ObservationV1', missingIgnore));
check('IGNORE-NEGATED: effective negation rejects', () => rejected(observation(negatedIgnore.owner), 'ObservationV1', negatedIgnore));
check('TRACKED: ignored but tracked content target rejects', () => rejected(observation(tracked.owner), 'ObservationV1', tracked));
check('GIT-ERROR: unreadable Git ownership cannot be treated as safe', () => rejected(observation(brokenGit.owner), 'ObservationV1', brokenGit));
check('PATH-ESCAPE: direct foreign, traversal and symlink targets reject', () => {
  for (const target of [join(outside, 'payload.json'), `${normal.root}/.sdd/context/../../foreign.json`,
    join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
    rejected(observation(normal.owner), 'ObservationV1', normal, { plannedPaths: [target] });
  }
});
check('HASH-PATH: authority membership cannot authorize foreign/escaping paths', () => {
  for (const path of [join(outside, 'tasks.md'), '../../foreign/tasks.md']) {
    const value = projection(); value.authorityHashes = [{ path, sha256: hash }]; rejected(value);
  }
});
check('REDACTION: admitted text is redacted before the in-memory result', () => {
  const value = observation(normal.owner);
  const credential = ['synthetic', 'credential'].join('-');
  value.text = `${['pass', 'word'].join('')}=${credential}`;
  const result = admit(value, 'ObservationV1');
  assert.equal(JSON.stringify(result).includes(credential), false);
  assert.equal(result.text.includes(['RE', 'DACTED'].join('')), true);
  assert.equal(['captured', 'safe'].includes(result.kind), false, 'validation claimed durable success');
});
check('DEADLINE: exhausted shared trusted budget rejects without a result', () => {
  rejected(observation(normal.owner), 'ObservationV1', normal, { deadline: performance.now() - 1 });
});

// Git OIDs are not the SHA-256 integrity-digest contract. Both fixtures use real
// Git commits; admission still does not establish current-HEAD freshness (T-003).
const headFixtures = [
  { format: 'sha1', f: sha1, head: sha1Head, other: normalHead, hint: 'sha256', size: 40 },
  { format: 'sha256', f: normal, head: normalHead, other: sha1Head, hint: 'sha1', size: 64 },
];
function withHead(f, head) { return { ...projection(), owner: { ...f.owner }, head }; }
test('HEAD-FIXTURE: real Git storage format and committed HEAD are observed', () => {
  for (const { format, f, head, size } of headFixtures) {
    assert.equal(git(f.root, 'rev-parse', '--show-object-format=storage').trim(), format);
    assert.equal(git(f.root, 'rev-parse', '--verify', 'HEAD').trim(), head);
    assert.equal(head.length, size);
    assert.match(head, /^[a-f0-9]+$/);
  }
  console.log(`Git fixture OIDs: sha1=${sha1Head}; sha256=${normalHead}`);
});
for (const { format, f, head, other, hint, size } of headFixtures) {
  check(`HEAD-VALID-${format}: real storage-format OID accepts despite a contradictory hint`, () => {
    const value = withHead(f, head);
    assert.deepEqual(validate(JSON.stringify(value), context('ProjectionV1', f, { objectFormat: hint })), value);
  });
  check(`HEAD-WRONG-FORMAT-${format}: another repository format cannot select the rule`, () => {
    rejected(withHead(f, other), 'ProjectionV1', f, { objectFormat: hint });
  });
  check(`HEAD-MALFORMED-${format}: abbreviated/overlong, uppercase and non-hex OIDs reject`, () => {
    for (const invalid of [head.slice(0, size - 1), head + '0', head.toUpperCase(), 'g' + head.slice(1)]) {
      rejected(withHead(f, invalid), 'ProjectionV1', f);
    }
  });
}
check('HEAD-CALLER-FORMAT: request cannot supply object-format authority', () => {
  const value = projection(); value.objectFormat = 'sha256'; rejected(value);
});
check('HEAD-UNSUPPORTED-GIT: real unsupported format configuration fails closed', () => {
  rejected(withHead(unsupportedGit, unsupportedHead), 'ProjectionV1', unsupportedGit);
});

// Reconcile admission uses the same real Git fixtures and shared entrance.
const reconcile = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  kind: 'observable-transcript', coverage: 'complete', records: [observation(owner)] });
test('RECONCILE-FIXTURE: valid owner/observation reaches the shared Git/path boundary', () => {
  for (const f of [normal, sha1]) {
    assert.deepEqual(validate(JSON.stringify(f.owner), context('OwnerV1', f)), f.owner);
    const result = validate(JSON.stringify(observation(f.owner)), context('ObservationV1', f));
    assert.deepEqual(result.owner, f.owner);
    assert.equal(result.text, 'ordinary text');
    assert.equal(existsSync(f.target), false, 'admission created a store file');
  }
});
for (const kind of ['observable-transcript', 'compact-manual', 'compact-auto']) {
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    check(`RECONCILE-VALID-${kind}-${coverage}: declared request and nested Observation enums accept`, () => {
      const value = { ...reconcile(), kind, coverage, stableEventId: 'reconcile-event' };
      value.records = ['prompt', 'final-assistant'].flatMap(kind =>
        ['complete', 'partial', 'unavailable'].map(coverage =>
          ({ ...observation(normal.owner), kind, coverage, stableEventId: 'observation-event' })));
      assert.deepEqual(admit(value, 'ReconcileV1'), value);
    });
  }
}
for (const coverage of ['complete', 'partial', 'unavailable']) {
  check(`RECONCILE-EMPTY-${coverage}: records has no invented nonempty requirement`, () => {
    const value = { ...reconcile(), coverage, records: [] };
    assert.deepEqual(admit(value, 'ReconcileV1'), value);
  });
}
check('RECONCILE-UNAVAILABLE: absent optional records accepts', () => {
  const value = { ...reconcile(), coverage: 'unavailable' }; delete value.records;
  assert.deepEqual(admit(value, 'ReconcileV1'), value);
});
for (const coverage of ['complete', 'partial']) {
  check(`RECONCILE-REQUIRED-${coverage}: missing records rejects`, () => {
    const value = { ...reconcile(), coverage }; delete value.records;
    rejected(value, 'ReconcileV1');
  });
}
check('RECONCILE-CLOSED: required fields, version, types and unknown keys reject', () => {
  for (const field of ['schemaVersion', 'owner', 'kind', 'coverage']) {
    const value = reconcile(); delete value[field]; rejected(value, 'ReconcileV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { owner: null }, { owner: [] },
    { kind: 1 }, { coverage: false }, { extra: true }]) {
    rejected({ ...reconcile(), ...change }, 'ReconcileV1');
  }
  for (const value of [null, [], 1]) rejected(value, 'ReconcileV1');
});
check('RECONCILE-ENUM: unrelated kinds and case variants reject', () => {
  for (const kind of ['prompt', 'final-assistant', 'resume', 'Compact-auto', '']) {
    rejected({ ...reconcile(), kind }, 'ReconcileV1');
  }
  for (const coverage of ['Complete', 'unknown', '']) rejected({ ...reconcile(), coverage }, 'ReconcileV1');
});
check('RECONCILE-RECORDS: present records is always an Observation array', () => {
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    for (const records of [null, {}, 'records', [null], [[]], [1]]) {
      rejected({ ...reconcile(), coverage, records }, 'ReconcileV1');
    }
  }
});
check('RECONCILE-OBSERVATION-CLOSED: every nested required field, type and enum is checked', () => {
  for (const field of Object.keys(observation(normal.owner))) {
    const value = reconcile(); delete value.records[0][field]; rejected(value, 'ReconcileV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { owner: null }, { owner: [] },
    { kind: 'observable-transcript' }, { kind: 'Prompt' }, { kind: 1 }, { coverage: 'Complete' },
    { coverage: null }, { text: 1 }, { text: null }, { text: '\ud800' }, { extra: true }]) {
    const value = reconcile(); Object.assign(value.records[0], change); rejected(value, 'ReconcileV1');
  }
});
check('RECONCILE-OWNER: outer and nested owners cannot self-authorize', () => {
  for (const nested of [false, true]) {
    for (const field of Object.keys(normal.owner)) {
      const value = reconcile(); const owner = nested ? value.records[0].owner : value.owner;
      delete owner[field]; rejected(value, 'ReconcileV1');
    }
    for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory', 'featureId', 'host', 'sessionId']) {
      const value = reconcile(); const owner = nested ? value.records[0].owner : value.owner;
      owner[field] = field === 'host' ? 'claude' : 'foreign'; rejected(value, 'ReconcileV1');
    }
    for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
      const value = reconcile(); Object.assign(nested ? value.records[0].owner : value.owner, change);
      rejected(value, 'ReconcileV1');
    }
  }
});
check('RECONCILE-ID-1024: outer and nested IDs accept the existing UTF-8 boundary', () => {
  for (const id of ['x'.repeat(1024), '🙂'.repeat(256)]) {
    const value = reconcile(); value.stableEventId = id; value.records[0].stableEventId = id;
    const result = admit(value, 'ReconcileV1');
    assert.equal(result.stableEventId, id); assert.equal(result.records[0].stableEventId, id);
  }
});
check('RECONCILE-ID-INVALID: outer and nested ID types/Unicode/byte limits reject', () => {
  for (const nested of [false, true]) {
    for (const id of ['', null, 1, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
      const value = reconcile(); (nested ? value.records[0] : value).stableEventId = id;
      rejected(value, 'ReconcileV1');
    }
  }
});
check('RECONCILE-REDACTION: every nested text is prepared before returning any output', () => {
  const credential = ['synthetic', 'credential'].join('-');
  for (const coverage of ['complete', 'partial', 'unavailable']) {
    const value = { ...reconcile(), coverage };
    value.records[0].text = `${['pass', 'word'].join('')}=${credential}`;
    value.records.push({ ...observation(normal.owner), kind: 'final-assistant',
      text: `${['Author', 'ization'].join('')}: Bearer ${credential}` }, observation(normal.owner));
    const result = admit(value, 'ReconcileV1');
    assert.equal(JSON.stringify(result).includes(credential), false);
    for (const record of result.records.slice(0, 2)) assert.ok(record.text.includes(['RE', 'DACTED'].join('')));
    assert.equal(result.records[2].text, 'ordinary text');
    assert.equal(value.records[0].text.includes(credential), true, 'caller input was mutated');
    assert.equal(existsSync(normal.target), false, 'admission claimed persistence');
  }
});
check('RECONCILE-AUTHORITY: outer and nested receipt/path/budget/lifecycle fields reject', () => {
  for (const nested of [false, true]) {
    for (const field of ['receivedAtUtc', 'sequence', 'expiry', 'plannedPaths', 'deadline', 'budget',
      'taskLifecycle', 'storeRoot', 'host', 'eventKind', 'transcriptLocator', 'omission', 'ruleVersion']) {
      const value = reconcile(); (nested ? value.records[0] : value)[field] = 'caller';
      rejected(value, 'ReconcileV1');
    }
  }
});
check('RECONCILE-JSON: malformed, decoded-duplicate and surrogate input rejects', () => {
  const source = JSON.stringify(reconcile());
  for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1'),
    source.replace('"text":"ordinary text"', '"text":"ordinary text","te\\u0078t":"duplicate"'), undefined]) {
    rejected(raw, 'ReconcileV1', normal, {}, true);
  }
});
check('RECONCILE-DEADLINE: exhausted original trusted budget returns no result', () => {
  rejected(reconcile(), 'ReconcileV1', normal, { deadline: performance.now() - 1 });
});
check('RECONCILE-PATH: missing/negated ignore, tracked target and Git error fail closed', () => {
  for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) {
    rejected(reconcile(f.owner), 'ReconcileV1', f);
  }
  for (const target of [join(outside, 'payload.json'), `${normal.root}/.sdd/context/../../foreign.json`,
    join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
    rejected(reconcile(), 'ReconcileV1', normal, { plannedPaths: [target] });
  }
});
check('RECONCILE-UNKNOWN-TYPE: request spelling cannot open an unknown trusted contract', () => {
  for (const type of ['ReconcileV2', 'reconcilev1', 'unknown', '', null, 1]) rejected(reconcile(), type);
});

const resume = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner }, kind: 'resume' });
const cleanup = (registrationId = 'registration') => ({ schemaVersion: 1, registrationId });
check('RESUME-VALID: same-owner request without predecessor returns only the input', () => {
  const value = resume();
  assert.deepEqual(admit(value, 'ResumeV1'), value);
  assert.equal(existsSync(normal.target), false, 'admission created a store file');
});
for (const [label, id] of [['1-BYTE', 'x'], ['1024-ASCII', 'x'.repeat(1024)], ['1024-UTF8', '🙂'.repeat(256)]]) {
  check(`CLEANUP-VALID-${label}: bounded opaque ID returns only the input without cleanup`, () => {
    const value = cleanup(id);
    assert.deepEqual(admit(value, 'CleanupV1'), value);
    assert.equal(existsSync(normal.target), false, 'admission created a store file');
    assert.equal(existsSync(tracked.target), true, 'admission deleted a store file');
  });
}
check('RESUME-CLEANUP-CLOSED: required fields, object types, version and extra keys reject', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    for (const field of Object.keys(make())) {
      const value = make(); delete value[field]; rejected(value, type);
    }
    for (const value of [null, [], 'request', 1]) rejected(value, type);
    for (const schemaVersion of [0, 2, '1', null]) rejected({ ...make(), schemaVersion }, type);
    rejected({ ...make(), extra: true }, type);
  }
});
check('RESUME-KIND: only the exact resume discriminant and an object owner are valid', () => {
  for (const kind of ['Resume', 'prompt', '', null, 1]) rejected({ ...resume(), kind }, 'ResumeV1');
  for (const owner of [null, [], 'owner', 1]) rejected({ ...resume(), owner }, 'ResumeV1');
});
check('RESUME-OWNER: closed owner cannot authorize a foreign path, feature, host or session', () => {
  for (const field of Object.keys(normal.owner)) {
    const value = resume(); delete value.owner[field]; rejected(value, 'ResumeV1');
  }
  for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) {
    const value = resume(); value.owner[field] = sha1.owner[field]; rejected(value, 'ResumeV1');
  }
  for (const field of ['featureId', 'host', 'sessionId']) {
    const value = resume(); value.owner[field] = field === 'host' ? 'claude' : 'foreign';
    rejected(value, 'ResumeV1');
  }
  for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
    const value = resume(); Object.assign(value.owner, change); rejected(value, 'ResumeV1');
  }
});
check('RESUME-PREDECESSOR: even a plausible ID cannot supply independent relationship proof', () => {
  for (const predecessorSessionId of [normal.owner.sessionId, 'foreign-session', 'x'.repeat(1024),
    '', 'x'.repeat(1025), null, 1, '\ud800']) {
    rejected({ ...resume(), predecessorSessionId }, 'ResumeV1');
  }
});
check('CLEANUP-ID-INVALID: ID type, Unicode and UTF-8 byte overflow reject', () => {
  for (const id of ['', null, 1, false, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    rejected(cleanup(id), 'CleanupV1');
  }
});
check('RESUME-CLEANUP-AUTHORITY: caller receipt/path/time/budget/lifecycle fields reject', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    for (const field of ['receivedAtUtc', 'sequence', 'expiry', 'path', 'cleanupPaths', 'plannedPaths',
      'deadline', 'budget', 'taskLifecycle', 'storeRoot', 'checkedAtUtc', 'completed']) {
      rejected({ ...make(), [field]: 'caller' }, type);
    }
  }
  rejected({ ...cleanup(), owner: { ...normal.owner } }, 'CleanupV1');
  rejected({ ...cleanup(), kind: 'cleanup' }, 'CleanupV1');
});
check('RESUME-CLEANUP-JSON: malformed and decoded-duplicate fields reject', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    const source = JSON.stringify(make());
    for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1',
      '"schemaVersion":1,"schema\\u0056ersion":1')]) rejected(raw, type, normal, {}, true);
  }
});
check('RESUME-CLEANUP-DEADLINE: the original exhausted trusted budget returns no result', () => {
  for (const [type, make] of [['ResumeV1', resume], ['CleanupV1', cleanup]]) {
    rejected(make(), type, normal, { deadline: performance.now() - 1 });
  }
});
check('RESUME-CLEANUP-PATH: existing ignore/tracked/Git/escape rejections remain required', () => {
  for (const type of ['ResumeV1', 'CleanupV1']) {
    for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) {
      rejected(type === 'ResumeV1' ? resume(f.owner) : cleanup(), type, f);
    }
    for (const target of [join(outside, 'payload.json'), `${normal.root}/.sdd/context/../../foreign.json`,
      join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
      rejected(type === 'ResumeV1' ? resume() : cleanup(), type, normal, { plannedPaths: [target] });
    }
  }
});

const header = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  segmentId: 'segment', firstSequence: 0, predecessorHash: hash });
const singleDecision = (owner = normal.owner) => ({ schemaVersion: 1, owner: { ...owner },
  id: 'decision', status: 'accepted', text: 'ordinary text', doNotReopen: false,
  sourceSequences: [0], originalReceipts: ['2026-09-29T00:00:00Z'] });
check('HEADER-VALID: bounded segment and safe sequence admit only a non-null hash header', () => {
  for (const segmentId of ['x', 'x'.repeat(1024), '🙂'.repeat(256)]) {
    for (const firstSequence of [0, Number.MAX_SAFE_INTEGER]) {
      const value = { ...header(), segmentId, firstSequence };
      assert.deepEqual(admit(value, 'JournalHeaderV1'), value);
    }
  }
  assert.equal(existsSync(normal.target), false, 'header admission created a store file');
});
check('HEADER-FIELDS: opaque segment, safe sequence and non-null lowercase digest are required', () => {
  for (const segmentId of ['', null, 1, [], {}, 'x'.repeat(1025), '🙂'.repeat(256) + 'x', '\ud800']) {
    rejected({ ...header(), segmentId }, 'JournalHeaderV1');
  }
  for (const firstSequence of [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, '0', null]) {
    rejected({ ...header(), firstSequence }, 'JournalHeaderV1');
  }
  for (const predecessorHash of [null, 1, 'A'.repeat(64), 'a'.repeat(63), 'a'.repeat(65), 'g'.repeat(64)]) {
    rejected({ ...header(), predecessorHash }, 'JournalHeaderV1');
  }
});
check('DECISION-VALID: standalone status variants retain corresponding source references', () => {
  for (const status of ['accepted', 'rejected', 'superseded', 'constraint', 'open']) {
    const value = { ...singleDecision(), status };
    assert.deepEqual(admit(value, 'DecisionV1'), value);
  }
  assert.equal(existsSync(normal.target), false, 'decision admission created a store file');
});
check('DECISION-REDACTION: standalone text is redacted with optional owned materialization', () => {
  const credential = ['synthetic', 'decision', 'credential'].join('-');
  const value = { ...singleDecision(), id: '🙂'.repeat(256), doNotReopen: true,
    text: ['pass', 'word'].join('') + '=' + credential,
    sourceSequences: [0, Number.MAX_SAFE_INTEGER],
    originalReceipts: ['2026-09-29T00:00:00Z', '2026-09-29T00:00:01Z'],
    materialization: { path: '.sdd/context/decision.md', sha256: hash } };
  const result = admit(value, 'DecisionV1');
  assert.equal(JSON.stringify(result).includes(credential), false);
  assert.equal(result.text.includes(['RE', 'DACTED'].join('')), true);
  assert.deepEqual(result, { ...value, text: result.text });
  assert.equal(existsSync(join(normal.root, value.materialization.path)), false,
    'decision admission wrote materialization');
});
check('DECISION-FIELDS: ID/status/text/boolean and corresponding nonempty references are checked', () => {
  for (const change of [{ id: '' }, { id: 1 }, { id: 'x'.repeat(1025) }, { id: '\ud800' },
    { status: 'Accepted' }, { status: 'unknown' }, { text: null }, { text: 1 }, { text: '\ud800' },
    { doNotReopen: 'true' }, { doNotReopen: 1 }, { sourceSequences: {} }, { sourceSequences: [] },
    { sourceSequences: [-1] }, { sourceSequences: [0.5] },
    { sourceSequences: [Number.MAX_SAFE_INTEGER + 1] }, { sourceSequences: ['0'] },
    { sourceSequences: [0, 1] }, { originalReceipts: {} }, { originalReceipts: [] },
    { originalReceipts: ['2026-09-29T00:00:00Z', '2026-09-29T00:00:01Z'] },
    { originalReceipts: [1] }, { originalReceipts: ['2026-02-30T00:00:00Z'] },
    { originalReceipts: ['2026-09-29T00:00:00+01:00'] }]) {
    rejected({ ...singleDecision(), ...change }, 'DecisionV1');
  }
});
check('DECISION-MATERIALIZATION: optional reference is closed, owned and uses an integrity digest', () => {
  for (const materialization of [null, [], {}, { path: 'p' }, { sha256: hash },
    { path: 'p', sha256: hash, extra: true }, { path: 1, sha256: hash },
    { path: '', sha256: hash }, { path: join(outside, 'decision.md'), sha256: hash },
    { path: '../../decision.md', sha256: hash },
    { path: '.sdd/context/escape/decision.md', sha256: hash },
    { path: 'p', sha256: 'A'.repeat(64) }, { path: 'p', sha256: 'a'.repeat(63) },
    { path: 'p', sha256: 'g'.repeat(64) }, { path: 'p', sha256: null }]) {
    rejected({ ...singleDecision(), materialization }, 'DecisionV1');
  }
});
check('HEADER-DECISION-CLOSED: every required field, type, version and extra key is checked', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    for (const field of Object.keys(make())) {
      const value = make(); delete value[field]; rejected(value, type);
    }
    for (const value of [null, [], 'entity', 1]) rejected(value, type);
    for (const schemaVersion of [0, 2, '1', null]) rejected({ ...make(), schemaVersion }, type);
    for (const field of ['extra', 'synced', 'kind', 'deadline', 'plannedPaths']) {
      rejected({ ...make(), [field]: true }, type);
    }
  }
});
check('HEADER-DECISION-OWNER: closed owner independently rejects every foreign tuple component', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    for (const owner of [null, [], 'owner', 1]) rejected({ ...make(), owner }, type);
    for (const field of Object.keys(normal.owner)) {
      const value = make(); delete value.owner[field]; rejected(value, type);
    }
    for (const field of ['sddRoot', 'worktreeRoot', 'gitDirectory']) {
      const value = make(); value.owner[field] = sha1.owner[field]; rejected(value, type);
    }
    for (const field of ['featureId', 'host', 'sessionId']) {
      const value = make(); value.owner[field] = field === 'host' ? 'claude' : 'foreign'; rejected(value, type);
    }
    for (const change of [{ schemaVersion: 2 }, { schemaVersion: '1' }, { extra: true }]) {
      const value = make(); Object.assign(value.owner, change); rejected(value, type);
    }
  }
});
check('HEADER-DECISION-JSON: malformed and decoded-duplicate keys return no result', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    const source = JSON.stringify(make());
    for (const raw of [source.slice(0, -1), source.replace('"schemaVersion":1',
      '"schemaVersion":1,"schema\\u0056ersion":1')]) rejected(raw, type, normal, {}, true);
  }
});
check('HEADER-DECISION-DEADLINE: an exhausted original trusted budget rejects', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    rejected(make(), type, normal, { deadline: performance.now() - 1 });
  }
});
check('HEADER-DECISION-PATH: shared ignore/tracked/Git and escaping path controls remain required', () => {
  for (const [type, make] of [['JournalHeaderV1', header], ['DecisionV1', singleDecision]]) {
    for (const f of [missingIgnore, negatedIgnore, tracked, brokenGit]) rejected(make(f.owner), type, f);
    for (const target of [join(outside, 'payload.json'), normal.root + '/.sdd/context/../../foreign.json',
      join(normal.root, '.sdd', 'context', 'escape', 'payload.json')]) {
      rejected(make(), type, normal, { plannedPaths: [target] });
    }
  }
});
check('LOCK-UNSUPPORTED: absent approved PID type/range cannot authorize lock admission', () => {
  for (const pid of [null, 0, 1, '1', Number.MAX_SAFE_INTEGER, {}, []]) {
    rejected({ schemaVersion: 1, owner: { ...normal.owner }, nonce: 'nonce',
      pid, processStartIdentity: 'process-start' }, 'LockV1');
  }
});
