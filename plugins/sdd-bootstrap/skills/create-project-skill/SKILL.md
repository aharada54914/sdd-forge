---
name: create-project-skill
description: Create a repository-specific verification, diagnosis, migration or maintenance procedure from real source and observed user paths.
user-invocable: false
disable-model-invocation: false
---

# Create a project skill

Use on an explicit request to preserve a project procedure. The profile is
`verification`, `diagnosis`, `migration`, or `maintenance`; all profiles share the
manifest and execution observation contract. Reuse an existing skill before
adding one. This procedure owns executable methods, never task approval, required
checks or Done state.

1. Identify the user's actual entry points from README, scripts, routes and tests.
   Record file:line evidence for surface, launch, drive, observe and isolate.
   Preserve existing project commands and user-written instructions. Use only
   supplied conversation history or history from this workspace.
2. Work under `sdd/skills/<name>/`. Write `SKILL.md` with name/description and
   Trigger, Preconditions, Inputs, Allowed effects, Launch, Doctor, Drive,
   Evidence, Cleanup, Helpers and Limits. Diagnosis may delegate to an existing
   tool; migration must specify dry-run and rollback. Documentation-only steps
   are valid drafts, but cannot obtain execution proof from prose alone.
3. Map the main 3–5 user features in `features/README.md`, one linked file per
   feature. Each feature file declares `Check ID: <manifest-check-id>` and is linked
   by filename from the index. Include user entry, seed/auth, actions, observable expected state,
   evidence and failure conditions. Distinguish not-run from unreachable. A port
   or PID is not readiness: doctor must check usable application state.
4. Put executable helpers and referenced procedure files inside the skill closure.
   Use a fresh data directory/CLI invocation and the real public entry point;
   never substitute internal setters. A helper must perform launch, readiness,
   drive, observation and cleanup, including failure paths. Shared devices have
   one owner; use parallelism only with independent state. Retain evidence outside
   disposable state. No product repair or wider write is authorized by creation.
5. Seal the completed files with the installed bootstrap helper:

   ```sh
   python3 "<installed-root>/plugins/sdd-bootstrap/scripts/project-skill.py" seal --root . --name verify-app --runtime python3 --entry helpers/verify.py --check application-smoke
   ```

   This produces `skill-manifest.json` and returns **draft**. Generation never
   means validated. Existing manifests are not silently overwritten: inspect the
   proposed file diff and retain user extensions before explicitly resealing.
6. Execute one feature from empty data with the installed `project-skill.py run --root . --name
   verify-app --check application-smoke --input path/to/admitted-source --timeout
   60`. Each `--input` is an explicit regular source file copied into the temporary
   execution root. Supply every required dependency; missing prerequisites are
   blocked, not product failures. Retain the returned receipt, stdout/stderr,
   observation and cleanup outcome. Trial mode binds the skill closure only and
   cannot become task evidence. Temporary-directory isolation is not an OS sandbox;
   execute only the authorized project code with the intended host permissions.
7. Report exactly which features passed, failed, were unavailable or untried.
   Confirm retained evidence exists after cleanup. A successful initial feature
   does not validate the entire map. Keep source/watch references and the rerun
   command with the skill. For a changed procedure use `maintain-project-skill`.

Documentation-only procedures use the same sealing command with `--document-only`
instead of `--runtime` / `--entry` (and without `--requires`). This emits
`project-skill-manifest/v2` with `method: document`, null runtime/entry and empty
args/requires. `SKILL.md` and references remain a closed, hashed source set.
Generation is draft; `run` returns `not-run / procedure-not-executable`, starts no
subprocess and grants no execution evidence. `maintain` stays blocked until the
procedure has an actual executable demonstration. Native projection/discovery
only proves access to the procedure, not performance of its steps. Handwritten
files are preserved and closure changes require explicit resealing. Ordinary
command sealing continues to emit compatible v1 manifests; v2 command manifests
retain the same runtime/entry requirements.

Task-mode execution uses an already admitted task-input manifest and declared
output roots via `--task-input-manifest`; the passive validator does not establish
that admission. The existing Full/Lite owners still consume and judge evidence.
The local runner uses a dedicated Linux child-subreaper supervisor to reap owned
descendants, including detached children. macOS and Windows execution return
not-run until their process-tree ownership backends are verified. Task mode
requires a declared directory covering the whole run evidence directory, and
initially empty declared product output roots. Raw logs and receipts are created
exclusively; existing task evidence is immutable.

Optional host wrappers are generated by `project-skill.py project --root . --name
verify-app --host claude` (also `codex`, `copilot`). `--check` detects drift. User
edits are a conflict. Generated wrappers do not establish native host support:
record actual discovery, invocation and result reading separately for each host.
Claude wrappers preserve canonical frontmatter. Restrictive invocation or required
model/tool controls on other hosts are blocked until their semantics are verified;
wrappers never silently broaden invocation rights.

Projection frontmatter accepts plain unquoted mapping keys and literal boolean
invocation flags. Quoted keys, YAML merges and unsupported flag encodings are
blocked rather than interpreted with weaker host restrictions.
