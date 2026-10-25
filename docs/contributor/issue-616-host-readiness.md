# #616 host-input / issuer readiness

## 2026-10-25 development correction

The development session is not required to use the plugin's approval or reviewer
adoption workflow. Those mechanisms are product behavior under development, not
authorization gates on this repair. The missing issuer below is a runtime trust
boundary, independent of those internal workflow states.

The `sdd-sudo` skill now removes the exception that could be read as permitting
agent token mutation after explicit invocation. Its quick start no longer claims
that typing a command enables sudo on an unverified host. Critical second approval
is explicitly retained. The fallback Python HMAC example now sends the exact
five-field message without the extra newline introduced by a Bash here-string.

Current checks found Codex CLI 0.159.2, no callable host attestation/issuer tool,
and no human-prompt issuer registration in the bundled hook manifests. `claude`
and `copilot` were not on PATH; the historical Claude binary path below no longer
exists in this workspace. These observations do not prove that other installations
lack such capabilities. No key/token was inspected or changed and no host support
is claimed. Existing sudo mutation and static signature tests passed; actual
enable/status/off, replay revocation and human-event provenance remain unverified.

Read-only assessment on 2026-10-22, repository HEAD `8818e33e4ab283c00efcc79b23e2570d164aba21`, using local pstack-how. Scope: source tracing, existing CLI version/help, and public documentation retrieval. No inference/model calls, sudo enable/status/off, key/token/credential/ledger access, hook installation, native prompt-event replay, source edits or approvals.

**Finding:** existing code verifies HMAC sudo tokens and blocks agent mutation; it does not implement the requested authenticated host-input issuer. Native prompt hooks are documented for the CLIs, but none of the inspected interfaces proves both human origin and isolation of issuance authority from an agent. No host can be marked #616 complete from this investigation.

## Host matrix

| Host | Observed installed/runtime evidence | Documented input boundary | Current #616 status / exact missing proof |
|---|---|---|---|
| ChatGPT Work, this conversation | The cloud session exposes tools and user messages, with unrestricted execution permissions. The `/workspace` instructions explicitly separate Work skill references from native CLI plugin/hook registration. | No callable authenticated human-input handler, issuer capability or native input-attestation endpoint was identified in the current tools/session contract. A rendered user message is usable as task instruction; it is not automatically a signed issuer receipt. | **No demonstrated issuer route in this session.** Local Codex/Claude installation does not establish Work event delivery or key isolation. Work support is unverified, not a claim that all Work deployments lack hooks. |
| Codex CLI | `/opt/codex/bin/codex --version`: **0.159.2**. `--help` exposes interactive prompt, exec, queue and hook-trust options. No hook or prompt was executed. | Public hooks docs describe `UserPromptSubmit` with `prompt`, `turn_id`, shared `session_id`, `cwd`, `hook_event_name`; commands receive JSON on stdin. Subagent hooks use the parent session ID. | **Candidate event surface only.** Existing SDD manifest registers only `PreToolUse`. Need actual direct-chat and slash event shape/order on this version, origin distinction from programmatic submissions, an authenticated issuer boundary unavailable to agent tool calls, and revocation/replay evidence. Hook trust is permission to run code, not proof of a human request. |
| Claude Code | Existing binary `/workspace/.tools/claude-code/node_modules/@anthropic-ai/claude-code-linux-x64/claude --version`: **2.1.303** (not on this shell's default PATH). | Current docs describe `UserPromptSubmit`, common `prompt_id`/`session_id`, and `UserPromptExpansion` with `expansion_type`, `command_name`, `command_args`, `command_source`, original `prompt`. Pasted text may arrive expanded with `<pasted_content>` markers. | **Candidate event surface only.** Existing SDD manifest registers only `PreToolUse`. Raw input and slash expansion must be distinguished/deduplicated; prompt/session IDs alone are not authentication. Need real event evidence and protected issuer authority. No Claude inference was invoked. |
| GitHub Copilot CLI | `copilot` and `github-copilot` not on PATH; no installed version established. This is not proof that no binary exists anywhere. | Current docs describe `userPromptSubmitted` / `UserPromptSubmit` with `sessionId`/`session_id`, timestamp, cwd, prompt. Config-file command/HTTP hook output is dropped for this event; `modifiedPrompt` is SDK-programmatic-only. | **Not locally established.** Existing SDD manifest registers only `preToolUse`. Version/runtime acquisition and native input/slash behavior are prerequisites; then the same issuer isolation/provenance checks. A command-hook stdout banner cannot be assumed visible from this API. |

The documentation is current online documentation retrieved 2026-10-22, not proof that every described event exists in the installed versions. In particular, no actual human enable/status/off or slash event was observed. Exact physical-typing versus pasted-input provenance may not be retained by a prompt-string API; that distinction cannot be reconstructed reliably with regex alone. A strict whole-message command grammar can reject quotes/code blocks/explanations but cannot certify the origin of a bare copied string when the host supplies only text.

## Existing source boundary

- `plugins/sdd-quality-loop/hooks/{hooks.json,claude-hooks.json,copilot-hooks.json}`: only tool-time enforcement is wired. No `UserPromptSubmit`, `UserPromptExpansion`, `userPromptSubmitted`, native `/sdd-sudo` dispatcher or issuer is registered there.
- `plugins/sdd-quality-loop/skills/sdd-sudo/SKILL.md:105-112`: human/external-CLI token creation outside agent tool surface; unconditional agent mutation prohibition. Lines 213-214 contradict this by saying “unless the human explicitly invoked this skill”. This is a real documentation inconsistency for #616 to reconcile, not an authorization exception.
- `plugins/sdd-quality-loop/scripts/sdd-hook-guard.py:2007-2031`: checks `AGENT_STOP` before reading stdin/PAYLOAD. Lines 2140-2165 deny token creation/edit/deletion independent of sudo. Bash dispatcher `sdd-hook-guard.sh:34-39` forwards stdin via PAYLOAD; this is an enforcement payload transport, not authenticated human issuance.
- Same Python guard `:410-435,454-548`: resolves a signing key, checks regular-file/symlink behavior, required fields, nonce syntax, epoch bounds/max 24h, canonical repo binding, HMAC. It does **not** validate a human-event signature, request/session identity or a consumed nonce/revocation history. The current nonce is signed data and a syntax check, not an event replay-deduplication mechanism. HMAC+TTL alone does not prevent reintroducing a still-valid same-repo token after off.
- `plugins/sdd-quality-loop/references/sudo-mode-policy.md:178-188` acknowledges key-read and shared-session residual risk. “Outside the repo” and file mode 600 do not separate a key from an agent running as the same UID; this session's unrestricted filesystem model supplies no independent isolation proof. No real key location/access was inspected.
- `sdd-hook-guard.py:839+` independently protects `Second Approval: Approved`; sudo is not authorization to bypass this, deterministic gates, WFI approval, `requires_human_decision`, ADR-level human judgment or `AGENT_STOP`.
- Existing regression anchors: catalog entries for `tests/sdd-sudo-guard-mutation.tests.py`, `tests/phase2-sudo-signature-static.tests.sh`, and `tests/phase2-sudo-signature.tests.ps1`. These support legacy guard contracts, not unimplemented live issuer acceptance. No tests requiring real token state were run here.

## Smallest next prerequisite

Before implementing an issuer adapter, establish **one actual host-owned input/issuance capability** whose contract distinguishes authorized human commands from model/programmatic/replayed input and whose signing/issuance authority the agent cannot access. Obtain the provider/native-host documentation or capability evidence for that boundary, then use a harmless, nonissuing native event observation in an isolated user session to establish raw chat/slash ordering and request/session IDs. A same-UID local hook plus `human: true`, stdin, hook trust or a secret readable by that UID does not satisfy it.

No such protected capability was demonstrated in the current environment. This is a specific missing host capability/evidence prerequisite, not a reason to ask again for general implementation permission. Do not silently add a local signing service or weaken the guard to claim support. Until the boundary is available, the current documented fallback is a human-operated external action outside the agent tool surface; label it as fallback, not completion of the requested no-extra-step chat/slash workflow. Actual fallback commands were deliberately not executed or generated here.

## Formal-review author provenance is separate

Sudo cannot register authors/reviewers or create review independence. `plugins/sdd-quality-loop/scripts/initialize-review-identity.py:44-79,89-112` is an existing narrowly supported registration route: original native Copilot `session.start`, correct producer/version/session directory and cwd, a fresh project with no existing identity ledger or prior review/implementation history. It is not a Claude/Codex/Work adapter and cannot append the current author to the existing #614 worktree history. Public prompt-hook `session_id` fields are useful correlation data, not a substitute for this native provenance contract.

`launch-impl-review.py`'s admitted Claude UUID/preflight route reserves and validates **new reviewer** contexts. It does not retrospectively register the author or invoking Work session. `issue-live-host-nonce.py` is for hook-activation proof challenges, not sudo issuance or author registration. No legitimate general registration route for the missing current #614 author/invoker was identified in this inspected surface. Use a truthfully labeled independent content pre-review if needed; it cannot set formal Passed/Approved.

## Public sources / reproducibility

Retrieved 2026-10-22 (floating docs; exact runtime behavior remains untested):

- OpenAI hooks: https://developers.openai.com/codex/hooks/ redirected to https://learn.chatgpt.com/docs/hooks — `UserPromptSubmit`, common fields, stdin and hook trust. Local text snapshot: SHA-256 `34787aa0d6525426b8f6db0e6bc3f5441d5718ac42c5649d9c43f09e1c826f11` (local text snapshot, not redistributed).
- Anthropic hooks: https://code.claude.com/docs/en/hooks — `UserPromptSubmit input`, `UserPromptExpansion input`, common `prompt_id`. Snapshot: SHA-256 `43661743d9d5ec56dc314b8261fb8a7d00aaa32400f450371e6807b7aaa91ab2` (local text snapshot, not redistributed).
- GitHub hooks: https://docs.github.com/en/copilot/reference/hooks-reference (configuration URL redirected here) — `userPromptSubmitted`, runtime-specific output behavior. Snapshot: SHA-256 `1dc55620a80eeb75cf9106311ea9d00061abdcfa176f19693ac0156cb390302f` (local text snapshot, not redistributed).

Unverified: native direct-chat/slash events, authenticated human-origin proof, key/issuer isolation, enable/status/off/replay/AGENT_STOP end-to-end behavior, and author-registration recovery. No support cell is reported as PASS.
