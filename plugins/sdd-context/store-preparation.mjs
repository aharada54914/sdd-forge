import { closeSync, constants, fstatSync, lstatSync, mkdirSync, openSync, realpathSync } from 'node:fs';
import { join } from 'node:path';
import { performance } from 'node:perf_hooks';
import { validate } from './validation.mjs';

// Empty new POSIX directory only; no chmod, data, existing-store repair or ACL claim.
// These path/identity checks do not establish concurrent ancestor-race immunity.
export function prepareStore(source, trusted) {
  try {
    if (trusted?.type !== 'OwnerV1' || typeof process.getuid !== 'function' ||
      typeof process.geteuid !== 'function' || !Number.isInteger(constants.O_DIRECTORY) ||
      !Number.isInteger(constants.O_NOFOLLOW)) throw new Error();
    validate(source, trusted);
    const require = condition => {
      if (!condition || performance.now() >= trusted.deadline) throw new Error();
    };
    const uid = process.getuid(); require(process.geteuid() === uid);
    const root = realpathSync(trusted.owner.worktreeRoot);
    const parentPath = join(root, '.sdd');
    const parent = realpathSync(parentPath);
    const before = lstatSync(parent);
    require(before.isDirectory() && before.uid === uid);
    const storePath = join(parentPath, 'context');
    const store = join(parent, 'context');
    require(realpathSync(parentPath) === parent);
    mkdirSync(storePath, { mode: 0o700 }); // Exclusive: an existing target is never changed.
    const created = lstatSync(storePath);
    require(created.isDirectory() && created.uid === uid && (created.mode & 0o777) === 0o700);
    require(realpathSync(storePath) === store);
    const descriptor = openSync(store, constants.O_RDONLY | constants.O_DIRECTORY | constants.O_NOFOLLOW);
    try {
      const opened = fstatSync(descriptor);
      const after = lstatSync(storePath);
      const parentAfter = lstatSync(parent);
      require(opened.isDirectory() && opened.uid === uid && (opened.mode & 0o777) === 0o700);
      require(after.isDirectory() && after.uid === uid && (after.mode & 0o777) === 0o700);
      require(opened.dev === created.dev && opened.ino === created.ino &&
        after.dev === opened.dev && after.ino === opened.ino);
      require(parentAfter.uid === uid && parentAfter.dev === before.dev && parentAfter.ino === before.ino);
      require(realpathSync(parentPath) === parent && realpathSync(storePath) === store);
    } finally { closeSync(descriptor); }
    return validate(source, trusted);
  } catch {
    const error = new Error('validation-rejected');
    delete error.stack;
    error.code = 'validation-rejected';
    throw error;
  }
}
