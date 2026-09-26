# Acceptance Tests: A1 RT002 bounded repair

All rows are Planned for this feature. Existing assertions are reused, not new PASS claims. `H` means both original suites `tests/check-hook-activation-handshake.tests.sh` and `.ps1`, using the repository verifier at its original path. `U64/U62/U63/U61/U65` mean that exit plus `CAPABILITY_RUNTIME_UNAVAILABLE` and its documented reason; `C71` means exit 71 / `SENTINEL_CLEANUP_UNCONFIRMED` / capability unavailable. The precise reusable assertions are indexed in `investigation.md`.

| Acceptance Criterion | Requirement | Test ID | Test Type | Test Target | Status |
|---|---|---|---|---|---|
| AC-001 | REQ-001 | TEST-001 | integration | H: exact five-field Codex record → 0 / HOOK_ACTIVE | Planned |
| AC-002 | REQ-002 | TEST-002 | integration | H: unknown schema with legacy success fields → U64 in each of the three runtime adapters | Planned |
| AC-002 | REQ-002 | TEST-003 | integration | H: null schema with legacy success fields → U64 in all adapters, same control flow as TEST-002 | Planned |
| AC-002 | REQ-002 | TEST-004 | integration | H: boolean true schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-005 | integration | H: boolean false schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-006 | integration | H: numeric schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-007 | integration | H: array schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-008 | integration | H: object schema → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-009 | integration | H: known selector on otherwise valid legacy field shapes → U64 in all adapters | Planned |
| AC-002 | REQ-002 | TEST-010 | integration | H: missing schema in new record → U65; missing metadata is not proof of disabled configuration | Planned |
| AC-002 | REQ-002 | TEST-011 | integration | H: missing runtime → U64 | Planned |
| AC-002 | REQ-002 | TEST-012 | integration | H: missing nonce → U64 | Planned |
| AC-002 | REQ-002 | TEST-013 | integration | H: missing executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-014 | integration | H: missing raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-015 | integration | H: null executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-016 | integration | H: string executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-017 | integration | H: true executed → U63 | Planned |
| AC-002 | REQ-002 | TEST-018 | integration | H: numeric 0 executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-019 | integration | H: numeric 1 executed → U64 | Planned |
| AC-002 | REQ-002 | TEST-020 | integration | H: recorded Claude / CLI Codex → U64 | Planned |
| AC-002 | REQ-002 | TEST-021 | integration | H: recorded Copilot / CLI Codex → U64 | Planned |
| AC-002 | REQ-002 | TEST-022 | integration | H: recorded Codex / CLI Claude → U64 | Planned |
| AC-002 | REQ-002 | TEST-023 | integration | H: recorded Codex / CLI Copilot → U64 | Planned |
| AC-002 | REQ-002 | TEST-024 | integration | H: both runtimes Claude with legacy success fields → U64 | Planned |
| AC-002 | REQ-002 | TEST-025 | integration | H: both runtimes Copilot with legacy success fields → U64 | Planned |
| AC-002 | REQ-002 | TEST-026 | integration | H: extra plugin_hooks_enabled true → U64 | Planned |
| AC-002 | REQ-002 | TEST-027 | integration | H: extra plugin_hooks_enabled false → U64 | Planned |
| AC-002 | REQ-002 | TEST-028 | integration | H: extra denied_by_plugin_hooks true → U64 | Planned |
| AC-002 | REQ-002 | TEST-029 | integration | H: extra denied_by_plugin_hooks false → U64 | Planned |
| AC-002 | REQ-002 | TEST-030 | integration | H: arbitrary extra key → U64; other flag types reuse this key-set rejection and existing flag mutation loop | Planned |
| AC-002 | REQ-002 | TEST-031 | integration | H: null raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-032 | integration | H: boolean raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-033 | integration | H: numeric raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-034 | integration | H: array raw_result → U64 | Planned |
| AC-002 | REQ-002 | TEST-035 | integration | H: object raw_result → U64 | Planned |
| AC-003 | REQ-002 | TEST-036 | integration | H: well-formed outer nonce mismatch → U62 | Planned |
| AC-003 | REQ-002 | TEST-037 | integration | H: well-formed echoed nonce mismatch → U62 | Planned |
| AC-003 | REQ-002 | TEST-038 | integration | H: uppercase nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-039 | integration | H: short nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-040 | integration | H: long nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-041 | integration | H: nonhex nonce, outer-only and self-consistent triple → U64 | Planned |
| AC-003 | REQ-002 | TEST-042 | integration | H: null outer nonce → U64 | Planned |
| AC-003 | REQ-002 | TEST-043 | integration | H: numeric outer nonce → U64 | Planned |
| AC-003 | REQ-002 | TEST-044 | integration | H: prefixed raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-045 | integration | H: quoted raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-046 | integration | H: suffixed raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-047 | integration | H: truncated raw response → U64 | Planned |
| AC-003 | REQ-002 | TEST-048 | integration | H: changed English guard text → U64 | Planned |
| AC-003 | REQ-002 | TEST-049 | integration | H: changed Japanese guard text → U64 | Planned |
| AC-003 | REQ-002 | TEST-050 | integration | H: changed guard case → U64 | Planned |
| AC-003 | REQ-002 | TEST-051 | integration | H: other target → U64 | Planned |
| AC-003 | REQ-002 | TEST-052 | integration | H: target case variant → U64 | Planned |
| AC-003 | REQ-002 | TEST-053 | integration | H: extra operation → U64 | Planned |
| AC-003 | REQ-002 | TEST-054 | integration | H: old empty-line patch → U64 | Planned |
| AC-003 | REQ-002 | TEST-055 | integration | H: trailing newline → U64 | Planned |
| AC-003 | REQ-002 | TEST-056 | integration | H: leading newline → U64 | Planned |
| AC-003 | REQ-002 | TEST-057 | integration | H: CRLF substitution → U64 | Planned |
| AC-004 | REQ-003 | TEST-058 | integration | H: legacy Claude success → 0 / HOOK_ACTIVE | Planned |
| AC-004 | REQ-003 | TEST-059 | integration | H: legacy Copilot success → 0 / HOOK_ACTIVE | Planned |
| AC-004 | REQ-003 | TEST-060 | integration | H: legacy Codex success → 0 / HOOK_ACTIVE | Planned |
| AC-002, AC-004 | REQ-002, REQ-003 | TEST-061 | integration | H: malformed/truncated response JSON → U61 | Planned |
| AC-004 | REQ-003 | TEST-062 | integration | H: duplicate schema → U61 | Planned |
| AC-004 | REQ-003 | TEST-063 | integration | H: duplicate runtime → U61 | Planned |
| AC-004 | REQ-003 | TEST-064 | integration | H: duplicate nonce → U61 | Planned |
| AC-004 | REQ-003 | TEST-065 | integration | H: duplicate executed → U61 | Planned |
| AC-004 | REQ-003 | TEST-066 | integration | H: duplicate raw_result → U61 | Planned |
| AC-004 | REQ-003 | TEST-067 | integration | H: nested response duplicate → U61 | Planned |
| AC-004 | REQ-003 | TEST-068 | integration | H: response executed true then false → U61 | Planned |
| AC-004 | REQ-003 | TEST-069 | integration | H: response executed false then true → U61 | Planned |
| AC-004 | REQ-003 | TEST-070 | integration | H: cleanup executed true then false → C71 | Planned |
| AC-004 | REQ-003 | TEST-071 | integration | H: cleanup executed false then true → C71 | Planned |
| AC-004 | REQ-003 | TEST-072 | integration | H: nested cleanup duplicate → C71 | Planned |
| AC-004 | REQ-003 | TEST-073 | integration | H: no-schema legacy response duplicate → U61 | Planned |
| AC-004 | REQ-003 | TEST-074 | integration | H: valid cleanup → 0 / confirmed, capability unavailable | Planned |
| AC-004 | REQ-003 | TEST-075 | integration | H: missing cleanup evidence → 70 / unconfirmed | Planned |
| AC-004 | REQ-003 | TEST-076 | integration | H: executed false cleanup → 72 / unconfirmed | Planned |
| AC-004 | REQ-003 | TEST-077 | integration | H: stale cleanup nonce → 62 / unconfirmed | Planned |
| AC-004 | REQ-003 | TEST-078 | integration | H: malformed cleanup JSON or nonboolean executed → 71 / unconfirmed; existing legacy cases retained | Planned |
| AC-004 | REQ-003 | TEST-079 | integration | H: adding response schema to otherwise valid cleanup does not select response adapter; same confirmed result as TEST-074 (direct assertion pending) | Planned |
| AC-004 | REQ-003 | TEST-080 | integration | H: adding unknown schema to refused cleanup does not select response adapter; same 72 as TEST-076 (direct assertion pending) | Planned |
| AC-004, AC-005 | REQ-003, REQ-004 | TEST-081 | integration | H: stale regular sentinel warns and emits fresh challenge; file unchanged | Planned |
| AC-004, AC-005 | REQ-003, REQ-004 | TEST-082 | integration | H: stale dangling symlink warns without following/modifying it | Planned |
| AC-005 | REQ-004 | TEST-083 | integration | H: challenge Codex patch equals normative bytes and embedded nonce equals generated nonce | Planned |
| AC-005 | REQ-004 | TEST-084 | integration | H: complete emitted Claude template equals unchanged Write/path/empty-content object (direct assertion pending) | Planned |
| AC-005 | REQ-004 | TEST-085 | integration | H: complete emitted Copilot template equals unchanged Write/path/empty-content object (direct assertion pending) | Planned |
| AC-004, AC-005 | REQ-003, REQ-004 | TEST-086 | integration | H: original non-mutation fixtures preserve sentinel and approval sidecars through emit/verify/cleanup | Planned |
| AC-006 | REQ-005 | TEST-087 | review | New feature's independent spec/design/task PASS; approval and activation prerequisites retained; old feature/task/verdicts unchanged | Planned |
| AC-006 | REQ-005 | TEST-088 | integration | Both original-path suites locally and native Windows CI pass at recorded source hashes; latest-head mandatory CI all successful | Planned |
| AC-006 | REQ-005 | TEST-089 | live | Installed candidate hash → fresh challenge → one actual native dispatch → unchanged response → original installed verifier HOOK_ACTIVE; no fixture substitution | Planned |

Existing full suites also retain legacy CLI misuse, cleanup and stale-start negatives beyond the representative compatibility rows above. Their preservation is checked by diff review plus running the full original suites, not selective counts. A new implementation mismatch gets a focused RED before its fix; missing direct assertions for already-correct behavior are acceptance-first additions, not invented historical RED.
