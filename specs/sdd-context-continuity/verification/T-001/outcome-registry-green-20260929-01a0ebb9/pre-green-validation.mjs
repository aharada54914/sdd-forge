import { execFileSync } from 'node:child_process';
import { closeSync, constants, fstatSync, lstatSync, openSync, realpathSync } from 'node:fs';
import { dirname, isAbsolute, join, relative, resolve, sep } from 'node:path';
import { performance } from 'node:perf_hooks';
import taskContract from '../../contracts/sdd-forge-mcp-tools.v1.schema.json' with { type: 'json' };
import { parseJson } from './json-admission.mjs';
import { redact } from './privacy.mjs';

// This entrance prepares in-memory values only; it never creates or writes a store.
// Later persistence must revalidate at use and derive its own closed journal record.
export function validate(source, trusted) {
  try {
    const started = performance.now();
    const deadline = trusted?.deadline;
    const check = () => {
      if (!Number.isFinite(deadline) || deadline > started + 1000 || performance.now() >= deadline) throw new Error();
    };
    check();
    const value = parseJson(source, deadline);
    const require = condition => { check(); if (!condition) throw new Error(); };
    const string = item => require(typeof item === 'string' && item.isWellFormed());
    const opaque = item => { string(item); require(item.length > 0 && Buffer.byteLength(item) <= 1024); };
    const integer = item => require(Number.isSafeInteger(item) && item >= 0);
    const boolean = item => require(typeof item === 'boolean');
    const hash = item => { string(item); require(/^[a-f0-9]{64}$/.test(item)); };
    const enumeration = (item, choices) => require(choices.includes(item));
    function closed(item, required, optional = []) {
      require(item !== null && typeof item === 'object' && !Array.isArray(item));
      for (const key of required) require(Object.hasOwn(item, key));
      for (const key of Object.keys(item)) require(required.includes(key) || optional.includes(key));
    }
    function array(item, visit) {
      require(Array.isArray(item));
      for (const entry of item) { check(); visit(entry); }
    }
    function utc(item) {
      string(item);
      require(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/.test(item));
      const parsed = new Date(item);
      require(Number.isFinite(parsed.getTime()) && parsed.toISOString().slice(0, 19) === item.slice(0, 19));
    }
    const ownerFields = ['schemaVersion', 'sddRoot', 'worktreeRoot', 'gitDirectory', 'featureId', 'host', 'sessionId'];
    closed(trusted.owner, ownerFields);
    require(trusted.owner.schemaVersion === 1);
    const canonical = item => { string(item); check(); const path = realpathSync(item); check(); return path; };
    const root = canonical(trusted.owner.worktreeRoot);
    const sddRoot = canonical(trusted.owner.sddRoot);
    const gitDirectory = canonical(trusted.owner.gitDirectory);
    opaque(trusted.owner.featureId); opaque(trusted.owner.sessionId);
    enumeration(trusted.owner.host, ['claude', 'codex']);
    function inside(base, target) {
      const path = relative(base, target);
      return path === '' || (!isAbsolute(path) && path !== '..' && !path.startsWith('..' + sep));
    }
    require(inside(root, sddRoot));
    // Resolve an absent leaf through its nearest existing ancestor, without creating it.
    function resolvePath(item) {
      string(item); require(item.length > 0 && !item.includes('\0'));
      const logical = resolve(root, item);
      require(inside(root, logical));
      let parent = logical;
      const missing = [];
      while (true) {
        check();
        try { lstatSync(parent); break; }
        catch (error) {
          if (error.code !== 'ENOENT') throw error;
          const next = dirname(parent); require(next !== parent);
          missing.unshift(relative(next, parent)); parent = next;
        }
      }
      const path = join(canonical(parent), ...missing);
      require(inside(root, path));
      return path;
    }
    function owner(item) {
      closed(item, ownerFields); require(item.schemaVersion === 1);
      for (const [key, expected] of [['sddRoot', sddRoot], ['worktreeRoot', root], ['gitDirectory', gitDirectory]]) {
        require(canonical(item[key]) === expected);
      }
      opaque(item.featureId); opaque(item.sessionId);
      enumeration(item.host, ['claude', 'codex']);
      for (const key of ['featureId', 'host', 'sessionId']) require(item[key] === trusted.owner[key]);
    }
    function cursor(item) {
      closed(item, ['schemaVersion', 'owner', 'segmentId', 'sequence', 'hash'], ['predecessorSessionId']);
      require(item.schemaVersion === 1); owner(item.owner); opaque(item.segmentId); integer(item.sequence); hash(item.hash);
      // Cross-session relationship proof belongs to T-003; presence alone grants none.
      require(!Object.hasOwn(item, 'predecessorSessionId'));
    }
    function taskEntry(item) {
      const definitions = taskContract.$defs;
      const schema = definitions.taskEntry;
      closed(item, schema.required, Object.keys(schema.properties).filter(key => !schema.required.includes(key)));
      for (const [key, entry] of Object.entries(item)) {
        let rule = schema.properties[key];
        if (rule.$ref) rule = definitions[rule.$ref.slice('#/$defs/'.length)];
        if (rule.type === 'string') string(entry);
        if (rule.type === 'boolean') boolean(entry);
        if (rule.pattern) require(new RegExp(rule.pattern).test(entry));
        if (rule.enum) enumeration(entry, rule.enum);
      }
    }
    const texts = [];
    function decision(item) {
      closed(item, ['schemaVersion', 'owner', 'id', 'status', 'text', 'doNotReopen', 'sourceSequences', 'originalReceipts'], ['materialization']);
      require(item.schemaVersion === 1); owner(item.owner); opaque(item.id);
      enumeration(item.status, ['accepted', 'rejected', 'superseded', 'constraint', 'open']);
      string(item.text); boolean(item.doNotReopen); texts.push(item);
      array(item.sourceSequences, integer); array(item.originalReceipts, utc);
      require(item.sourceSequences.length > 0 && item.sourceSequences.length === item.originalReceipts.length);
      if (Object.hasOwn(item, 'materialization')) {
        closed(item.materialization, ['path', 'sha256']); resolvePath(item.materialization.path); hash(item.materialization.sha256);
      }
    }
    function observation(item) {
      closed(item, ['schemaVersion', 'owner', 'kind', 'text', 'coverage'], ['stableEventId']);
      require(item.schemaVersion === 1); owner(item.owner);
      enumeration(item.kind, ['prompt', 'final-assistant']);
      enumeration(item.coverage, ['complete', 'partial', 'unavailable']);
      string(item.text); texts.push(item);
      if (Object.hasOwn(item, 'stableEventId')) opaque(item.stableEventId);
    }
    switch (trusted.type) {
      case 'OwnerV1': owner(value); break;
      case 'CursorV1': cursor(value); break;
      case 'JournalHeaderV1':
        closed(value, ['schemaVersion', 'owner', 'segmentId', 'firstSequence', 'predecessorHash']);
        require(value.schemaVersion === 1); owner(value.owner); opaque(value.segmentId); integer(value.firstSequence); hash(value.predecessorHash);
        break;
      case 'JournalRecordV1':
        closed(value, ['schemaVersion', 'owner', 'sequence', 'kind', 'receivedAtUtc', 'text', 'ruleVersion', 'omission', 'coverage', 'previousHash', 'hash'], ['stableEventId']);
        require(value.schemaVersion === 1); owner(value.owner); integer(value.sequence);
        enumeration(value.kind, ['prompt', 'final-assistant', 'observable-transcript', 'compact-manual', 'compact-auto', 'resume']);
        utc(value.receivedAtUtc); string(value.text); require(value.ruleVersion === 1); boolean(value.omission);
        enumeration(value.coverage, ['complete', 'partial', 'unavailable']);
        hash(value.previousHash); hash(value.hash);
        if (Object.hasOwn(value, 'stableEventId')) opaque(value.stableEventId);
        require(redact(value.text, deadline).text === value.text);
        break;
      case 'DecisionV1': decision(value); break;
      case 'LockV1':
        closed(value, ['schemaVersion', 'owner', 'nonce', 'pid', 'processStartIdentity']);
        require(value.schemaVersion === 1); owner(value.owner); opaque(value.nonce); opaque(value.processStartIdentity);
        integer(value.pid); require(value.pid > 0);
        break;
      case 'RegistryEntryV1':
        closed(value, ['owner', 'storeRoot', 'registrationId', 'schedulerState', 'checkedAtUtc']);
        owner(value.owner); opaque(value.registrationId);
        enumeration(value.schedulerState, ['enabled', 'disabled', 'failed']); utc(value.checkedAtUtc);
        break;
      case 'ProjectionV1': {
        closed(value, ['schemaVersion', 'owner', 'head', 'authorityHashes', 'taskLifecycle', 'featurePresent', 'journalCursor', 'decisions']);
        require(value.schemaVersion === 1); owner(value.owner); string(value.head); boolean(value.featurePresent);
        const paths = new Set();
        array(value.authorityHashes, entry => {
          closed(entry, ['path', 'sha256']); string(entry.path); hash(entry.sha256);
          require(!paths.has(entry.path)); paths.add(entry.path); resolvePath(entry.path);
        });
        array(value.taskLifecycle, taskEntry);
        boolean(trusted.journalEmpty);
        if (value.journalCursor === null) require(trusted.journalEmpty);
        else cursor(value.journalCursor);
        array(value.decisions, decision);
        break;
      }
      case 'ObservationV1': observation(value); break;
      case 'ReconcileV1':
        closed(value, ['schemaVersion', 'owner', 'kind', 'coverage'], ['records', 'stableEventId']);
        require(value.schemaVersion === 1); owner(value.owner);
        enumeration(value.kind, ['observable-transcript', 'compact-manual', 'compact-auto']);
        enumeration(value.coverage, ['complete', 'partial', 'unavailable']);
        if (Object.hasOwn(value, 'stableEventId')) opaque(value.stableEventId);
        require(value.coverage === 'unavailable' || Object.hasOwn(value, 'records'));
        if (Object.hasOwn(value, 'records')) array(value.records, observation);
        break;
      case 'ResumeV1':
        closed(value, ['schemaVersion', 'owner', 'kind'], ['predecessorSessionId']);
        require(value.schemaVersion === 1); owner(value.owner); require(value.kind === 'resume');
        require(!Object.hasOwn(value, 'predecessorSessionId'));
        break;
      case 'CleanupV1':
        closed(value, ['schemaVersion', 'registrationId']);
        require(value.schemaVersion === 1); opaque(value.registrationId);
        break;
      default: throw new Error(); // Undefined/unimplemented contracts fail closed.
    }
    const env = { ...process.env };
    for (const key of ['GIT_DIR', 'GIT_WORK_TREE', 'GIT_COMMON_DIR', 'GIT_INDEX_FILE', 'GIT_PREFIX']) delete env[key];
    function git(...args) {
      check();
      const output = execFileSync('rtk', ['proxy', 'git', '-C', root, ...args], {
        encoding: 'utf8', env, timeout: Math.max(1, Math.floor(deadline - performance.now())),
        maxBuffer: 65536, stdio: ['ignore', 'pipe', 'pipe'],
      });
      check(); return output;
    }
    function paths() {
      require(canonical(git('rev-parse', '--show-toplevel').trim()) === root);
      require(canonical(git('rev-parse', '--absolute-git-dir').trim()) === gitDirectory);
      const store = resolvePath(join(root, '.sdd', 'context'));
      if (trusted.type === 'RegistryEntryV1') require(value.storeRoot === store);
      require(Array.isArray(trusted.plannedPaths) && trusted.plannedPaths.length > 0);
      for (const item of trusted.plannedPaths) {
        const target = resolvePath(item);
        require(target !== store && inside(store, target));
        for (const path of new Set([resolve(root, item), target])) {
          git('check-ignore', '--quiet', '--no-index', '--', relative(root, path));
          require(git('ls-files', '-z', '--', relative(root, path)).length === 0);
        }
        let before;
        try { before = lstatSync(target); }
        catch (error) { if (error.code !== 'ENOENT') throw error; }
        if (before) {
          require(before.isFile());
          const descriptor = openSync(target, constants.O_RDONLY | (constants.O_NOFOLLOW ?? 0) | (constants.O_NONBLOCK ?? 0));
          try {
            const opened = fstatSync(descriptor);
            const after = lstatSync(target);
            require(opened.isFile() && opened.dev === before.dev && opened.ino === before.ino &&
              after.dev === opened.dev && after.ino === opened.ino && resolvePath(item) === target);
          } finally { closeSync(descriptor); }
        }
      }
      check();
    }
    paths();
    if (trusted.type === 'ProjectionV1') {
      const format = git('rev-parse', '--show-object-format=storage').trim();
      require(format === 'sha1' || format === 'sha256');
      require((format === 'sha1' ? /^[a-f0-9]{40}$/ : /^[a-f0-9]{64}$/).test(value.head));
    }
    for (const item of texts) {
      const result = redact(item.text, deadline);
      item.text = result.text;
      // Observation preparation carries rule/omission evidence for T-002; it is
      // an in-memory prepared value, not a persisted ObservationV1 extension.
      if (trusted.type === 'ObservationV1') Object.assign(item, result);
    }
    paths(); // Recheck immediately before exposing the prepared result.
    check(); return value;
  } catch {
    const error = new Error('validation-rejected');
    delete error.stack;
    error.code = 'validation-rejected';
    throw error;
  }
}
