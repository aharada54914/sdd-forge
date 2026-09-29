import assert from 'node:assert/strict';
import { after, test } from 'node:test';
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, mkdirSync, readFileSync, realpathSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { performance } from 'node:perf_hooks';
import { validate } from '../../plugins/sdd-context/validation.mjs';

const schemaURL = new URL('../../contracts/sdd-context/schema-v1.schema.json', import.meta.url);
const schema = existsSync(schemaURL) ? JSON.parse(readFileSync(schemaURL, 'utf8')) : undefined;
const types = ["OwnerV1","CursorV1","JournalHeaderV1","JournalRecordV1","DecisionV1","LockV1","RegistryEntryV1","OwnerRegistryV1","OutcomeV1","ProjectionV1","ObservationV1","ReconcileV1","ResumeV1","CleanupV1"];
const expected = {
  "safeInteger": {"type":"integer","minimum":0,"maximum":9007199254740991},
  "positiveInteger": {"type":"integer","minimum":1,"maximum":9007199254740991},
  "opaqueId": {"type":"string","minLength":1},
  "sha256": {"type":"string","pattern":"^[a-f0-9]{64}$"},
  "commitHash": {"type":"string","pattern":"^(?:[a-f0-9]{40}|[a-f0-9]{64})$"},
  "utc": {"type":"string","pattern":"^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}(?:\\.\\d+)?Z$"},
  "coverage": {"enum":["complete","partial","unavailable"]},
  "reasonCode": {"enum":["ok","unsupported","validation-rejected","privacy-rejected","storage-failed","integrity-failed","reconcile-failed","publication-failed","ownership-mismatch","expired","cleanup-failed","budget-exhausted"]},
  "OwnerV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","sddRoot","worktreeRoot","gitDirectory","featureId","host","sessionId"],"properties":{"schemaVersion":{"const":1},"sddRoot":{"type":"string"},"worktreeRoot":{"type":"string"},"gitDirectory":{"type":"string"},"featureId":{"$ref":"#/$defs/opaqueId"},"host":{"enum":["claude","codex"]},"sessionId":{"$ref":"#/$defs/opaqueId"}}},
  "CursorV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","segmentId","sequence","hash"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"segmentId":{"$ref":"#/$defs/opaqueId"},"sequence":{"$ref":"#/$defs/safeInteger"},"hash":{"$ref":"#/$defs/sha256"},"predecessorSessionId":{"$ref":"#/$defs/opaqueId"}}},
  "JournalHeaderV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","segmentId","firstSequence","predecessorHash"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"segmentId":{"$ref":"#/$defs/opaqueId"},"firstSequence":{"$ref":"#/$defs/safeInteger"},"predecessorHash":{"$ref":"#/$defs/sha256"}}},
  "JournalRecordV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","sequence","kind","receivedAtUtc","text","ruleVersion","omission","coverage","previousHash","hash"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"sequence":{"$ref":"#/$defs/safeInteger"},"kind":{"enum":["prompt","final-assistant","observable-transcript","compact-manual","compact-auto","resume"]},"receivedAtUtc":{"$ref":"#/$defs/utc"},"text":{"type":"string"},"ruleVersion":{"const":1},"omission":{"type":"boolean"},"coverage":{"$ref":"#/$defs/coverage"},"previousHash":{"$ref":"#/$defs/sha256"},"hash":{"$ref":"#/$defs/sha256"},"stableEventId":{"$ref":"#/$defs/opaqueId"}}},
  "DecisionV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","id","status","text","doNotReopen","sourceSequences","originalReceipts"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"id":{"$ref":"#/$defs/opaqueId"},"status":{"enum":["accepted","rejected","superseded","constraint","open"]},"text":{"type":"string"},"doNotReopen":{"type":"boolean"},"sourceSequences":{"type":"array","items":{"$ref":"#/$defs/safeInteger"},"minItems":1},"originalReceipts":{"type":"array","items":{"$ref":"#/$defs/utc"},"minItems":1},"materialization":{"$ref":"#/$defs/PathHash"}}},
  "LockV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","nonce","pid","processStartIdentity"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"nonce":{"$ref":"#/$defs/opaqueId"},"pid":{"$ref":"#/$defs/positiveInteger"},"processStartIdentity":{"$ref":"#/$defs/opaqueId"}}},
  "RegistryEntryV1": {"type":"object","additionalProperties":false,"required":["owner","storeRoot","registrationId","schedulerState","checkedAtUtc"],"properties":{"owner":{"$ref":"#/$defs/OwnerV1"},"storeRoot":{"type":"string"},"registrationId":{"$ref":"#/$defs/opaqueId"},"schedulerState":{"enum":["enabled","disabled","failed"]},"checkedAtUtc":{"$ref":"#/$defs/utc"}}},
  "OwnerRegistryV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","entries","maxObservedUtc"],"properties":{"schemaVersion":{"const":1},"entries":{"type":"array","items":{"$ref":"#/$defs/RegistryEntryV1"}},"maxObservedUtc":{"$ref":"#/$defs/utc"}}},
  "ProjectionV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","head","authorityHashes","taskLifecycle","featurePresent","journalCursor","decisions"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"head":{"$ref":"#/$defs/commitHash"},"authorityHashes":{"type":"array","items":{"$ref":"#/$defs/PathHash"}},"taskLifecycle":{"type":"array","items":{"$ref":"../sdd-forge-mcp-tools.v1.schema.json#/$defs/taskEntry"}},"featurePresent":{"type":"boolean"},"journalCursor":{"anyOf":[{"$ref":"#/$defs/CursorV1"},{"type":"null"}]},"decisions":{"type":"array","items":{"$ref":"#/$defs/DecisionV1"}}}},
  "ObservationV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","kind","text","coverage"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"kind":{"enum":["prompt","final-assistant"]},"text":{"type":"string"},"coverage":{"$ref":"#/$defs/coverage"},"stableEventId":{"$ref":"#/$defs/opaqueId"}}},
  "ReconcileV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","kind","coverage"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"kind":{"enum":["observable-transcript","compact-manual","compact-auto"]},"coverage":{"$ref":"#/$defs/coverage"},"records":{"type":"array","items":{"$ref":"#/$defs/ObservationV1"}},"stableEventId":{"$ref":"#/$defs/opaqueId"}},"if":{"properties":{"coverage":{"enum":["complete","partial"]}},"required":["coverage"]},"then":{"required":["records"]}},
  "ResumeV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","owner","kind"],"properties":{"schemaVersion":{"const":1},"owner":{"$ref":"#/$defs/OwnerV1"},"kind":{"const":"resume"},"predecessorSessionId":{"$ref":"#/$defs/opaqueId"}}},
  "CleanupV1": {"type":"object","additionalProperties":false,"required":["schemaVersion","registrationId"],"properties":{"schemaVersion":{"const":1},"registrationId":{"$ref":"#/$defs/opaqueId"}}},
  "PathHash": {"type":"object","additionalProperties":false,"required":["path","sha256"],"properties":{"path":{"type":"string"},"sha256":{"$ref":"#/$defs/sha256"}}},
  "RecoveryEntry": {"type":"object","additionalProperties":false,"required":["sourceSequences","text","omission"],"properties":{"sourceSequences":{"type":"array","items":{"$ref":"#/$defs/safeInteger"},"minItems":1},"text":{"type":"string"},"omission":{"type":"boolean"}}},
  "RecoveryPointer": {"type":"object","additionalProperties":false,"required":["opaqueId","reasonCode"],"properties":{"opaqueId":{"$ref":"#/$defs/opaqueId"},"reasonCode":{"$ref":"#/$defs/reasonCode"}}},
  "OutcomeV1": {"oneOf":[{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission","sequence","synced"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"captured"},"reasonCode":{"const":"ok"},"omission":{"type":"boolean"},"sequence":{"$ref":"#/$defs/safeInteger"},"synced":{"const":true},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"uncaptured-warning"},"reasonCode":{"enum":["unsupported","validation-rejected","privacy-rejected","storage-failed","integrity-failed","reconcile-failed","publication-failed","ownership-mismatch","expired","cleanup-failed","budget-exhausted"]},"omission":{"type":"boolean"},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission","synced","reconciled","integrity","published"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"safe"},"reasonCode":{"const":"ok"},"omission":{"type":"boolean"},"synced":{"const":true},"reconciled":{"const":true},"integrity":{"const":true},"published":{"const":true},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"unsafe"},"reasonCode":{"enum":["unsupported","validation-rejected","privacy-rejected","storage-failed","integrity-failed","reconcile-failed","publication-failed","ownership-mismatch","expired","cleanup-failed","budget-exhausted"]},"omission":{"type":"boolean"},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"unavailable"},"reasonCode":{"enum":["unsupported","validation-rejected","privacy-rejected","storage-failed","integrity-failed","reconcile-failed","publication-failed","ownership-mismatch","expired","cleanup-failed","budget-exhausted"]},"omission":{"type":"boolean"},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission","coverage","entries","pointers"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"recovered"},"reasonCode":{"const":"ok"},"omission":{"type":"boolean"},"coverage":{"$ref":"#/$defs/coverage"},"entries":{"type":"array","items":{"$ref":"#/$defs/RecoveryEntry"}},"pointers":{"type":"array","items":{"$ref":"#/$defs/RecoveryPointer"}},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"no-op"},"reasonCode":{"$ref":"#/$defs/reasonCode"},"omission":{"type":"boolean"},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission","expiredCount","removedCount","completed"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"cleaned"},"reasonCode":{"const":"ok"},"omission":{"type":"boolean"},"expiredCount":{"$ref":"#/$defs/safeInteger"},"removedCount":{"$ref":"#/$defs/safeInteger"},"completed":{"const":true},"diagnostic":{"$ref":"#/$defs/reasonCode"}}},{"type":"object","additionalProperties":false,"required":["schemaVersion","kind","reasonCode","omission"],"properties":{"schemaVersion":{"const":1},"kind":{"const":"cleanup-warning"},"reasonCode":{"enum":["unsupported","validation-rejected","privacy-rejected","storage-failed","integrity-failed","reconcile-failed","publication-failed","ownership-mismatch","expired","cleanup-failed","budget-exhausted"]},"omission":{"type":"boolean"},"diagnostic":{"$ref":"#/$defs/reasonCode"}}}]},
};

function artifact() {
  assert.ok(schema, 'internal contract artifact is absent');
  return schema;
}
function definition(name) {
  assert.ok(artifact().$defs?.[name], 'named contract definition is absent: ' + name);
  return schema.$defs[name];
}

let fixture;
function examples() {
  if (fixture) return fixture;
  const temporary = mkdtempSync(join(tmpdir(), 'sdd-contract-'));
  const root = realpathSync(temporary);
  mkdirSync(join(root, '.sdd', 'context'), { recursive: true });
  writeFileSync(join(root, '.gitignore'), '.sdd/context/**\n');
  const env = { ...process.env };
  for (const key of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_PREFIX']) delete env[key];
  execFileSync('git', ['-C', root, 'init', '-q', '--object-format=sha1'], { env, stdio: 'pipe' });
  const owner = { schemaVersion: 1, sddRoot: root, worktreeRoot: root,
    gitDirectory: realpathSync(join(root, '.git')), featureId: 'contract-fixture', host: 'codex', sessionId: 'synthetic-session' };
  const common = { schemaVersion: 1, owner }, hash = 'a'.repeat(64), utc = '2026-09-29T00:00:00Z';
  const entry = { owner, storeRoot: realpathSync.native(join(root, '.sdd', 'context')), registrationId: 'registration', schedulerState: 'enabled', checkedAtUtc: utc };
  const values = {
    OwnerV1: owner,
    CursorV1: { ...common, segmentId: 'segment', sequence: 0, hash },
    JournalHeaderV1: { ...common, segmentId: 'segment', firstSequence: 0, predecessorHash: hash },
    JournalRecordV1: { ...common, sequence: 0, kind: 'prompt', receivedAtUtc: utc, text: 'ordinary fixture',
      ruleVersion: 1, omission: false, coverage: 'complete', previousHash: hash, hash, stableEventId: 'event' },
    DecisionV1: { ...common, id: 'decision', status: 'accepted', text: 'ordinary fixture', doNotReopen: false,
      sourceSequences: [0], originalReceipts: [utc], materialization: { path: '.sdd/context/planned.json', sha256: hash } },
    LockV1: { ...common, nonce: 'nonce', pid: 1, processStartIdentity: 'start' },
    RegistryEntryV1: entry,
    OwnerRegistryV1: { schemaVersion: 1, entries: [entry], maxObservedUtc: utc },
    ProjectionV1: { ...common, head: 'c'.repeat(40), authorityHashes: [{ path: '.sdd/context/planned.json', sha256: hash }],
      taskLifecycle: [{ id: 'T-001', approval: 'Approved', status: 'Planned', blockersNonEmpty: false }],
      featurePresent: true, journalCursor: null, decisions: [] },
    ObservationV1: { ...common, kind: 'prompt', text: 'ordinary fixture', coverage: 'complete', stableEventId: 'event' },
    ReconcileV1: { ...common, kind: 'compact-manual', coverage: 'partial', records: [], stableEventId: 'event' },
    ResumeV1: { ...common, kind: 'resume' },
    CleanupV1: { schemaVersion: 1, registrationId: 'registration' },
  };
  const outcomeExtras = {
    captured: { sequence: 0, synced: true }, 'uncaptured-warning': {},
    safe: { synced: true, reconciled: true, integrity: true, published: true }, unsafe: {}, unavailable: {},
    recovered: { coverage: 'complete', entries: [{ sourceSequences: [0], text: 'ordinary fixture', omission: false }],
      pointers: [{ opaqueId: 'pointer', reasonCode: 'expired' }] },
    'no-op': {}, cleaned: { expiredCount: 0, removedCount: 0, completed: true }, 'cleanup-warning': {},
  };
  const outcomes = Object.entries(outcomeExtras).map(([kind, fields]) => ({
    schemaVersion: 1, kind, reasonCode: ['captured', 'safe', 'recovered', 'cleaned', 'no-op'].includes(kind) ? 'ok' : 'unsupported',
    omission: false, ...fields, diagnostic: 'ok',
  }));
  fixture = { temporary, root, owner, values, outcomes };
  return fixture;
}
after(() => { if (fixture) rmSync(fixture.temporary, { recursive: true, force: true }); });

function admit(type, value, extra = {}, raw = JSON.stringify(value)) {
  const f = examples();
  return validate(raw, { type, owner: f.owner, plannedPaths: [join(f.root, '.sdd', 'context', 'planned.json')],
    journalEmpty: true, confirmedOwners: [f.owner], deadline: performance.now() + 1000, ...extra });
}
function rejected(type, value, extra = {}, raw) {
  assert.throws(() => admit(type, value, extra, raw), error => {
    assert.equal(error.message, 'validation-rejected');
    assert.equal(error.code, 'validation-rejected');
    assert.equal(error.stack, undefined);
    assert.equal(error.cause, undefined);
    return true;
  });
}
function fieldMismatches(type, value, rules) {
  rejected(type, { ...value, unknownContractField: true });
  for (const field of rules.required) {
    const copy = structuredClone(value);
    delete copy[field];
    rejected(type, copy);
  }
  for (const field of Object.keys(rules.properties)) {
    rejected(type, { ...value, [field]: field === 'journalCursor' ? 0 : null });
  }
}

test('SC-RUNTIME-POSITIVE: current runtime admits every contract fixture before artifact implementation', () => {
  const f = examples();
  for (const [type, value] of Object.entries(f.values)) assert.ok(admit(type, value));
  for (const value of f.outcomes) assert.ok(admit('OutcomeV1', value));
});

test('SC-PRESENT: standard internal schema artifact names every current encoding', () => {
  const contract = artifact();
  assert.equal(contract.$schema, 'https://json-schema.org/draft/2020-12/schema');
  assert.equal(contract.$id, 'https://sdd-forge.dev/contracts/sdd-context/schema-v1.schema.json');
  assert.deepEqual(Object.keys(contract).sort(), ['$comment', '$defs', '$id', '$schema', 'oneOf'].sort());
  assert.deepEqual(Object.keys(contract.$defs).sort(), Object.keys(expected).sort());
  assert.deepEqual(contract.oneOf, types.map(name => ({ $ref: '#/$defs/' + name })));
});

for (const type of types.filter(name => name !== 'OutcomeV1')) {
  test('SC-FIELDS-' + type + ': closed fields match actual runtime admission', () => {
    assert.deepEqual(definition(type), expected[type]);
    const value = examples().values[type];
    assert.ok(admit(type, value));
    fieldMismatches(type, value, expected[type]);
    if (type === 'ReconcileV1') {
      for (const coverage of ['complete', 'partial']) rejected(type, { schemaVersion: 1, owner: value.owner, kind: value.kind, coverage });
      assert.ok(admit(type, { schemaVersion: 1, owner: value.owner, kind: value.kind, coverage: 'unavailable' }));
    }
  });
}

test('SC-SCALARS: exact bounds and enum rules have runtime mismatch counterparts', () => {
  for (const name of ['safeInteger', 'positiveInteger', 'opaqueId', 'sha256', 'commitHash', 'utc', 'coverage', 'reasonCode']) {
    assert.deepEqual(definition(name), expected[name]);
  }
  const v = examples().values;
  for (const sequence of [-1, 0.5, Number.MAX_SAFE_INTEGER + 1, '0']) rejected('CursorV1', { ...v.CursorV1, sequence });
  for (const pid of [0, -1, 0.5, Number.MAX_SAFE_INTEGER + 1]) rejected('LockV1', { ...v.LockV1, pid });
  for (const segmentId of ['', 1]) rejected('CursorV1', { ...v.CursorV1, segmentId });
  rejected('CursorV1', { ...v.CursorV1, hash: 'A'.repeat(64) });
  rejected('JournalRecordV1', { ...v.JournalRecordV1, receivedAtUtc: '2026-09-29T00:00:00+00:00' });
  rejected('ObservationV1', { ...v.ObservationV1, coverage: 'Complete' });
  rejected('OwnerV1', { ...v.OwnerV1, host: 'Codex' });
  rejected('DecisionV1', { ...v.DecisionV1, status: 'Accepted' });
  rejected('RegistryEntryV1', { ...v.RegistryEntryV1, schedulerState: 'Enabled' });
  rejected('ReconcileV1', { ...v.ReconcileV1, kind: 'unknown' });
  rejected('OutcomeV1', { ...examples().outcomes[0], diagnostic: 'unknown' });
});

test('SC-OUTCOME: all nine closed discriminants and flags match the runtime', () => {
  assert.deepEqual(definition('OutcomeV1'), expected.OutcomeV1);
  for (const value of examples().outcomes) {
    const branch = expected.OutcomeV1.oneOf.find(item => item.properties.kind.const === value.kind);
    assert.ok(admit('OutcomeV1', value));
    fieldMismatches('OutcomeV1', value, branch);
    for (const flag of ['synced', 'reconciled', 'integrity', 'published', 'completed']) {
      if (Object.hasOwn(value, flag)) rejected('OutcomeV1', { ...value, [flag]: false });
    }
    if (branch.properties.reasonCode.const === 'ok') rejected('OutcomeV1', { ...value, reasonCode: 'unsupported' });
    else if (value.kind !== 'no-op') rejected('OutcomeV1', { ...value, reasonCode: 'ok' });
  }
});

test('SC-NESTED: shared path/recovery objects are closed and runtime rejects field mismatches', () => {
  for (const name of ['PathHash', 'RecoveryEntry', 'RecoveryPointer']) assert.deepEqual(definition(name), expected[name]);
  const v = examples().values, recovered = examples().outcomes.find(item => item.kind === 'recovered');
  for (const [name, base, make, type] of [
    ['PathHash', v.DecisionV1.materialization, item => ({ ...v.DecisionV1, materialization: item }), 'DecisionV1'],
    ['PathHash', v.ProjectionV1.authorityHashes[0], item => ({ ...v.ProjectionV1, authorityHashes: [item] }), 'ProjectionV1'],
    ['RecoveryEntry', recovered.entries[0], item => ({ ...recovered, entries: [item] }), 'OutcomeV1'],
    ['RecoveryPointer', recovered.pointers[0], item => ({ ...recovered, pointers: [item] }), 'OutcomeV1'],
  ]) {
    rejected(type, make({ ...base, unknownContractField: true }));
    for (const field of expected[name].required) {
      const copy = structuredClone(base); delete copy[field]; rejected(type, make(copy));
      rejected(type, make({ ...base, [field]: null }));
    }
  }
  rejected('DecisionV1', { ...v.DecisionV1, sourceSequences: [] });
  rejected('DecisionV1', { ...v.DecisionV1, originalReceipts: [] });
  rejected('OutcomeV1', { ...recovered, entries: [{ ...recovered.entries[0], sourceSequences: [] }] });
});

test('SC-TASK-REF: taskEntry resolves the existing contract without a copied definition', () => {
  const reference = definition('ProjectionV1').properties.taskLifecycle.items.$ref;
  assert.equal(reference, '../sdd-forge-mcp-tools.v1.schema.json#/$defs/taskEntry');
  assert.equal(Object.hasOwn(artifact().$defs, 'taskEntry'), false);
  const [file, fragment] = reference.split('#');
  const existing = JSON.parse(readFileSync(new URL(file, schemaURL), 'utf8'));
  assert.equal(new URL(file, artifact().$id).href, existing.$id);
  assert.equal(fragment, '/$defs/taskEntry');
  const task = existing.$defs.taskEntry, projection = examples().values.ProjectionV1;
  assert.equal(task.additionalProperties, false);
  for (const field of task.required) {
    const item = structuredClone(projection.taskLifecycle[0]); delete item[field];
    rejected('ProjectionV1', { ...projection, taskLifecycle: [item] });
  }
  rejected('ProjectionV1', { ...projection, taskLifecycle: [{ ...projection.taskLifecycle[0], extra: true }] });
  rejected('ProjectionV1', { ...projection, taskLifecycle: [{ ...projection.taskLifecycle[0], status: 'done' }] });
});

test('SC-LIMITS: schema explicitly separates structural encoding from operational proof', () => {
  const comment = artifact().$comment;
  assert.equal(typeof comment, 'string');
  for (const word of ['Unicode', 'duplicate', 'calendar', 'owner', 'path', 'Git', 'privacy', 'redaction',
    'deadline', 'UTF-8', 'confirmation', 'uniqueness', 'receipt', 'predecessor', 'prepared', 'ObservationV1', 'sync', 'integrity', 'completion']) {
    assert.ok(comment.includes(word), 'missing operational limit: ' + word);
  }
  assert.equal(Object.hasOwn(definition('opaqueId'), 'maxLength'), false);
  assert.equal(Object.hasOwn(definition('utc'), 'format'), false);
});

test('SC-OPERATIONAL: runtime separately rejects structurally encodable unsafe inputs', () => {
  artifact();
  const f = examples(), v = f.values;
  rejected('OwnerV1', { ...v.OwnerV1, featureId: 'other-feature' });
  rejected('CursorV1', { ...v.CursorV1, segmentId: '界'.repeat(342) });
  rejected('ObservationV1', { ...v.ObservationV1, text: String.fromCharCode(0xd800) });
  rejected('OwnerV1', v.OwnerV1, {}, JSON.stringify(v.OwnerV1).replace('"schemaVersion":1', '"schemaVersion":1,"schemaVersion":1'));
  rejected('RegistryEntryV1', { ...v.RegistryEntryV1, checkedAtUtc: '2026-02-30T00:00:00Z' });
  rejected('OwnerRegistryV1', v.OwnerRegistryV1, { confirmedOwners: [] });
  rejected('OwnerRegistryV1', { ...v.OwnerRegistryV1, entries: [v.RegistryEntryV1, { ...v.RegistryEntryV1, registrationId: 'other-registration' }] });
  const other = { ...f.owner, sessionId: 'other-session' };
  rejected('OwnerRegistryV1', { ...v.OwnerRegistryV1, entries: [v.RegistryEntryV1, { ...v.RegistryEntryV1, owner: other }] }, { confirmedOwners: [f.owner, other] });
  rejected('DecisionV1', { ...v.DecisionV1, sourceSequences: [0, 1] });
  rejected('DecisionV1', { ...v.DecisionV1, materialization: { ...v.DecisionV1.materialization, path: '../outside' } });
  rejected('ProjectionV1', { ...v.ProjectionV1, authorityHashes: [v.ProjectionV1.authorityHashes[0], v.ProjectionV1.authorityHashes[0]] });
  rejected('ProjectionV1', { ...v.ProjectionV1, head: 'c'.repeat(64) });
  rejected('ProjectionV1', v.ProjectionV1, { journalEmpty: false });
  for (const type of ['CursorV1', 'ResumeV1']) rejected(type, { ...v[type], predecessorSessionId: 'previous-session' });
  rejected('OwnerV1', v.OwnerV1, { deadline: performance.now() - 1 });
  const recovered = f.outcomes.find(item => item.kind === 'recovered');
  rejected('OutcomeV1', { ...recovered, entries: [{ ...recovered.entries[0], text: 'a'.repeat(8193) }] });
});
