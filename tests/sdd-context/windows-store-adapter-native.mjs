import { existsSync } from 'node:fs';
import { prepareWindowsStore } from '../../plugins/sdd-context/windows-store.mjs';

if (process.platform !== 'win32') throw new Error('native Windows required');
const store = process.argv[2];
if (!store) throw new Error('store fixture required');

// A successful fresh create must complete inside the production adapter's
// maximum shared-core allowance; a direct PowerShell call does not test this.
prepareWindowsStore(store, 3000);
if (!existsSync(store)) throw new Error('store was not created');
