# RT002 → FilesOnly source integration boundary (read-only)

Date: 2026-10-03. This is a source comparison and transfer plan, not activation, a quality-gate verdict, or release evidence. No protected file was changed or canary dispatched in this investigation.

## Exact source state

- FilesOnly checkout `codex/issue423-filesonly-exit-message` is at `49e1602459108fd8ef318b644b51301a3b61d0b1` (`origin/main` at inspection). Its unrelated local edits are `install.sh` and `tests/install.tests.sh`, plus an untracked independent-audit note. The three handshake files are unmodified there.
- RT002 checkout `codex/rt002-host-denial-repair` is at `1e86fb272643e798db4e1ca0c89f0402317a2fc8`. Its merge-base with the FilesOnly head is exactly `49e1602459108fd8ef318b644b51301a3b61d0b1`. `git diff --name-status origin/main...HEAD` in RT002 lists the following three code files and two verification reports only. The approved T-001 task declares these three planned code files and is `Approval: Approved`, `Status: Implementation Complete` (`specs/epic-189-a1-rt002-repair/tasks.md:13-41`).

| Transfer file | FilesOnly SHA-256 | RT002 SHA-256 |
|---|---|---|
| `plugins/sdd-quality-loop/scripts/check-hook-activation-handshake.py` | `d9277ca516fa79b6ef459e0d0505375624a0a9279c32390758a96650985d0064` | `1057d1fcd1a8307c1fe55b961f3b37af2576683887f1c4ec2ce5138065e8fe0d` |
| `tests/check-hook-activation-handshake.tests.sh` | `b90e462f0ec024d971eeaad2d4eb9f9abd949170883885b43ac8b4897563b169` | `0b5417b86553ebe9001f8ac1871930378330e74289adb65eab8c92148855000c` |
| `tests/check-hook-activation-handshake.tests.ps1` | `c16e13129d6f895b6a98e0d517cbdf5de10358e2c5c714cd2d144a8882ab4fb9` | `49b537a37f1dbdab192b53b00147bf20377df9ecfe94283ac21f58c8073706cd` |

Since RT002 is a descendant of this exact FilesOnly base and FilesOnly has no local edits to these three paths, the RT002 three-file diff does not discard a newer main change on those paths. This is a bounded comparison, not permission to overwrite protected files. `git diff --check` on the three-file commit range reported no whitespace error.

## Contract and dependencies

The approved historical entry contract is `reports/verification/hook-recovery-entry-contract-20260909.md`; current RT002 requirements/design and the exact two-envelope matrix are in `specs/epic-189-a1-rt002-repair/{requirements.md,design.md,acceptance-tests.md}`. `tasks.md:59-72` requires both full original-path suites, actual installed-host TEST-089, backup/restoration proof and independent quality gate; `tasks.md:132-142` assigns native Windows/latest-head CI and final integration to dependent Draft T-002. Old evidence cannot establish a fresh FilesOnly source/install instance. The FilesOnly installer stages only tracked local files (`install.sh:774-785,967-985`), so a production distribution also needs the three-file source delta in an actual Git revision; a local working-tree candidate alone is not release proof.

The Python checker is in the protected gate list (`plugins/sdd-quality-loop/scripts/generate-guard-invariants.py:162`). The existing human source adapter `reports/verification/rt002-source-three-file-human-20261003.py` is **not reusable as-is** for FilesOnly: its `SOURCE_ROOT` points at a different checkout, its `CANDIDATE_ROOT` at RT002, and its old SHA-256 values (`bb388...`, `39463...`, `e0d2...`) predate the FilesOnly base (`d927...`, `b90e...`, `c16e...`). Its safety design (regular/non-symlink checks, complete preflight, hash-pinned candidate, backup, post-write readback and mismatch refusal) is reusable as a reviewed pattern only; it has no command-line target/hash parameters. The installed-cache adapter `reports/verification/rt002-installed-118-human-20261003.py` targets a versioned installed cache, not FilesOnly source, and is not a substitute.

The minimal *candidate-script* delta to that preserved source adapter is four constant substitutions only: set `SOURCE_ROOT` to the exact FilesOnly checkout root and replace the three `FileSpec.old_sha256` values with the FilesOnly values in the table. `CANDIDATE_ROOT`, all `FileSpec.new_sha256` values and the guarded preflight/backup/replace logic stay unchanged. This describes a candidate for separate review, not an in-place amendment of the prior application artifact or authorization to run it. No script was generated or executed here.

## Smallest next lawful operation

Prepare a fresh, explicit, hash-pinned human-only three-file source-application candidate scoped to the FilesOnly checkout and the SHA-256 pairs above; independently review the exact script and three-file diff before human application. Do not run the existing adapter with stale constants, copy the checker directly, or touch the unrelated FilesOnly installer edits. Once actual source integration occurs, obtain new instance-specific original-suite/installer/live-host and latest-head evidence under the applicable task/quality-gate contract. T-001 is not `Done`, T-002 is Draft, and this note does not supply either decision.
