# A8 post-update live revalidation

Head: `8fdfdb6ff84c4d0a4d4fc1ffb065e318cf5132d4`.

Copilot plugin enumeration reports enabled quality-loop 1.18.0 loaded from its local marketplace. Installed Python guard SHA-256 `dd791f28d1f247c404197e3dbcc2960a664b18f4bc324fc1b967fbc4ee03e448` equals the owner-worktree candidate; installed JS SHA-256 is `fa3cc8cad5661f8fbc6ee313fd8982762392adb3f08dd2ed13c736f985ccab0f`. This verifies installed bytes, not all native protection decisions.

The unchanged candidate handoff driver (SHA-256 `285e0a41a6dea3188d65aa7268af5244dae7d5abc23653736cfde2cf84be452f`) ran with live opt-in, Copilot Auto, and the current app-bundled Codex executable. The former app executable location failed the prerequisite check before any model invocation; the executable was then located at its current app-bundle path. No alias or protection bypass was used.

Live result: **exit 1**. Claude producer, Codex consumer and Codex producer passed the driver's hash/marker assertions. Copilot successfully read both fixture files without the prior malformed-payload refusal. It then reported that no file-writing tool was available; the required output file was absent. The driver had requested `--available-tools=view,create` and permission for the single output path. The log contains no attempted create call, so this run does not establish a guard rejection of creation, nor prove that creation is supported by the selected model/tool configuration.

## Follow-up: model-specific write tool

GitHub's [CLI reference](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-command-reference) documents that some models use `apply_patch` instead of `edit/create`. The initial Auto session selected `gpt-6-luna`. A bounded diagnostic reused the two generated fixture inputs and exposed `view,create,apply_patch`, retaining hooks, disabled builtin MCPs, and write permission for only the original output path. Both reads succeeded. The model attempted `apply_patch` twice (absolute then relative output path); both were denied by the native preToolUse hook with `malformed hook payload`. No output file exists. CLI exit 0 is therefore **not** a successful handoff.

Local session evidence: `e31b07fe-3c47-4814-8407-561b026093a1`. Its tool execution events contain a raw patch string as the `apply_patch` arguments. These are host events, not a claim that hook stdin was directly captured. The installed Python normalization at lines 1882–1904 accepts only dictionary arguments carrying a path, followed by `view` or `create`; it does not admit this tool. This establishes a remaining native write incompatibility in addition to the driver's incomplete tool allowlist. No rejection was bypassed. Supporting a write tool must route through all existing patch protection checks, not grant a generic allow. Exact output bytes (including newline behavior) still require a new successful live run after repair.

Copilot CLI reports version 1.0.90. Raw host logs remain local and unpublished. No complete trace was emitted. AC-003/AC-004 remain unverified; native write-denial/canary proof, candidate adoption, formal review and merge remain pending. Next diagnostic is the effective Copilot write-tool schema/availability, without broadening filesystem permissions or disabling hooks. No task status, review verdict, reservation, commit, push or merge was changed.

## Independent candidate safety review

The inert adapter patch (SHA-256 `64f0eb4b298b65f257d94f543ce6f415c97411107d12126b499a0869073e4292`) is **not ready for adoption**. Static review by `copilot_candidate_review` found that routing native calls to the existing patch path also exposes unresolved protection gaps:

- Python guard lines 1937–1964 and JS lines 1892–1925 inspect Add/Update/Delete source paths but not `*** Move to:` destinations.
- Python `_patch_increases`, `_wfi_patch_increases`, and `_second_approval_patch_increases` (lines 632–657, 710–728, 870–888), and their JS counterparts, aggregate additions/removals across files; a removal in another file can cancel an approval addition.
- The implementation-review status guard only handles edit/write/multiedit (Python line 203; JS line 1725), not the proposed patch route.

These are static findings, not executed bypass demonstrations. The actual Copilot hook stdin shape is still unobserved; host tool-event arguments alone do not establish it. No protected implementation was modified or tested through an alternate route. Adoption and another live handoff require a repaired protection path and its focused regressions first; the current candidate must not be used as the human-application batch.

## Disposition of the older uncommitted driver candidate

The checkout at `1f2f5041e3956ad8cd560a1956d08fc9c23f667f` still contains three uncommitted test changes: both handoff drivers remove the available-tools allowlist and add shell/url denials, while the CLI-contract tests require that removal. These changes are absent from this PR's current head. They were inspected and preserved, not adopted or discarded.

Removing the tool allowlist does not repair the observed native apply_patch rejection. The narrower diagnostic above already exposed apply_patch and still failed. The older candidate also continues to assert only the second nonce, so it does not resolve the recorded AC-004 two-contribution gap. Offline fixture success cannot establish either native compatibility or preservation of the tool exposure boundary. Keep the candidate separate; repair and verify the specific supported native write route before changing the drivers' tool contract. No new live invocation or formal verdict was produced by this audit.
