# T-003 regression input closure audit (2026-10-04)

Status: candidate handoff only. No implementer or reviewer launched, no identity reserved, no RED/GREEN or regression verdict.

## Evidence chain

- The three admitted POSIX wrappers dispatch to the corresponding Python drivers at wrapper lines 15/18: `tests/resolve-project-context-{cli,match,block}.tests.sh` -> `tests/resolve-project-context-{cli,match,block}-check.py`.
- CLI imports the block driver (`cli-check.py:41-48`), reads its CLI fixture directory (`:35,97-102`), checks staged resolver .py/.sh/.ps1 (`:138`) and tests/run-all.sh/.ps1 registration (`:147-150`).
- Match imports the block driver (`match-check.py:72-80`), loads staged resolver .py/.sh/.ps1 (`:1717,1774,1798-1809`), validates Facet Manifest with the real validator (`:74,119-130`), reads its fixture directory at multiple cases and tests/run-all.sh/.ps1 (`:1822-1825`).
- Block defines the shared staged path under `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts` (`block-check.py:146-156`), copies those three files into isolated repositories (`:1492-1496`), invokes `resolver-evidence-schema-check.py` (`:156`), copies the five real dependency scripts and governing contracts (`:424-477`), and checks tests/run-all.sh/.ps1 (`:4735-4738`). Its cases also consume the block/projection fixture directories (`:147-148,1505-1519`).
- Fixture directories contain dynamic case-name lookups and overlays. The candidate enumerates **every regular file in only those four named fixture subtrees**, not the full 278-file capability-resolver fixture root: CLI 2, match 17, block 101, projection 5 = 125. This is a bounded static closure for those wrappers; no unrelated fixture subtree is admitted.

## Delta from stopped 38-input attempt

Candidate: `task-input-manifest-c43e18b9f2a7.json`, SHA-256 `db63572c8057802f1afb56773666fdb57394eb1585da74b937b771d0859f868a`, 179 inputs = prior 38 + 141. The exact path-and-hash inventory is the manifest, not this prose.

The 16 added direct files are:

- 3 Python drivers: `tests/resolve-project-context-{cli,match,block}-check.py`;
- 3 versioned staged resolver files: `specs/epic-193-a5-capability-resolver/human-copy/plugins/sdd-quality-loop/scripts/resolve-project-context.{py,sh,ps1}`;
- 2 suite-index files: `tests/run-all.{sh,ps1}`;
- 1 schema test helper: `tests/resolver-evidence-schema-check.py`;
- 3 governing contracts: `contracts/lite-upgrade-reason-catalog.json`, `contracts/context-projection.schema.json`, `contracts/capability-summary.schema.json`;
- 1 provider vocabulary: `plugins/sdd-quality-loop/references/provider-terms.json`;
- 3 real dependency scripts: `plugins/sdd-quality-loop/scripts/{resolve-component-paths,evaluate-predicate,validate-capability-registry}.py`.

The prior 38 already admit `canonicalize-sdd-yaml.py`, `generate-registry-digest.py`, `registry_discovery.py`, `validate-facet-manifest.py`, the existing Facet/Resolver/Project-Context/Registry schemas, three shell wrappers, and the T-003 design/contract inputs. The four named fixture subtrees add 125 path+SHA rows.

## Mechanical checks

- `prepare-task-snapshot.sh --manifest ...c43e18b9f2a7.json --repo-root <owner> --snapshot-root .../snapshot-c43e18b9f2a7`: exit 0, `TASK_INPUT_OK`.
- `validate-task-input-manifest.sh --manifest ...c43e18b9f2a7.json --snapshot-root .../snapshot-c43e18b9f2a7 --expected-task T-003`: exit 0, `TASK_INPUT_OK`.
- `validate-task-input-manifest.sh --batch ...c43e18b9f2a7.json`: exit 0, `TASK_INPUT_OK`.
- The manifest contains each of the 125 enumerated fixture files and all 16 direct dependencies; no duplicate path or input/output overlap was accepted by the validator.

This proves the listed static input closure and snapshot integrity, **not** that the broad regression suites pass or that no runtime-generated path is needed. Before any launch, revalidate the manifest/snapshot against current owner files and check the intended quality-gate skill output SHA in the candidate addendum. The task remains `Blocked`; only the orchestrator may change shared status after deciding to resume. No protected checker, frozen spec, reservation, review status, or implementation output changed here.
