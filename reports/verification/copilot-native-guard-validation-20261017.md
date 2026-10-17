# Copilot native guard validation

## Defect and repair

Native Copilot `preToolUse` supplies `apply_patch.toolArgs` as raw patch text.
The previous JSON-object-only normalization rejected valid source patches. The
native `task` delegation call was also rejected before a child could start.
All three guard runtimes now normalize the observed native patch and delegation
forms into the existing canonical payload and execute the shared protection checks.
Malformed, empty, ambiguous, batched, and unknown native calls still fail closed.
Read calls may inspect protected files.

The native patch envelope requires one Begin/End pair and an initial file
operation. The patch executor remains responsible for hunk validity. Native
`task` currently accepts the observed object (or JSON object string) with exactly
five nonempty string fields: `description`, `agent_type`, `name`, `mode`, and
`prompt`. Prompt text remains data; allowing delegation does not approve the
child's tool calls.

Independent review also found two existing canonical patch gaps exposed by the
new native route. `Move to` now checks the destination as well as the source;
renames into approval-bearing documents or agent-role files are denied because
unchanged source content can introduce approval without added lines. Ordinary
source renames remain allowed. Patch additions to `design.md` now use the same
review-verdict checks as file writes, combining added and retained context lines
so multiline status fields cannot bypass validation.

## Verification

- Before the normalization fix, the initial 17-case native regression set had
  three failures in every runtime: ordinary Add, ordinary Update, and task
  delegation. The remaining 14 denial cases passed. After the fix all 17 passed.
- The expanded shared corpus covers source patching, protected paths, sentinel,
  sudo flag, task approval, ambiguous and malformed arguments, protected-file
  reads, context-only renames, review-verdict PASS/FAIL/missing, and multiline
  status fields. JavaScript, Python, and PowerShell must agree on the decision
  and successful Copilot JSON-response exit status. These are synthetic payload
  tests, separate from the native host runs below.
- Local results: the full three-runtime parity suite passed 121/121 scenarios;
  the final additional malformed array-tool-name regression passed separately
  in all three runtimes (122 distinct scenarios total). The JavaScript/Python
  parity suite passed 148/148. JavaScript syntax, Python compilation, mirror
  freshness, and whitespace checks passed. Focused native development checks
  passed 38/38 before the final extra type-validation case.
- Actual Copilot native tool events confirmed source Add and Update succeeded
  with matching resulting file contents. A primary sentinel patch was denied
  by the protection gate. Native task delegation started a child, whose sentinel
  patch was also denied; the child call was linked to the parent task call and
  the sentinel remained absent. Raw host logs are retained privately.

This report records development validation. It does not claim post-merge CI or
remaining host/runtime evidence that was not executed.

## Native read-tool follow-up

A further actual-host probe found that native `bash` (`command`, optional
`description`) and `glob` (`pattern`, optional `path`) were rejected as malformed
before the shared read/write checks. The three runtimes now normalize those
observed tools. Shell commands still traverse the existing protection rules;
this does not grant an unconditional shell exemption.

Using Copilot Auto, with actual model `gpt-6-luna`, the same isolated protocol
attempted `cat`, `grep` through native `bash`, and native `glob`. Before the fix
all three native calls were denied as malformed. After the fix all three
completed successfully and their actual results contained the expected fixture
text or filename. The dedicated `grep` tool was not exposed by this model, so
the observed search evidence is specifically the shell command. Raw native
events and hook input/output records remain private.

The full three-runtime parity suite passed 141/141 scenarios, including native
read access, malformed argument rejection, protected shell writes, approval
writes, and mixed read/write commands. Python compilation, JavaScript syntax,
and whitespace checks passed. Unknown native tools remain rejected.

## Capture documentation provenance

The current native evidence envelope and tool-selection procedure are documented
in [Copilot native handshake capture](../../plugins/sdd-quality-loop/references/copilot-native-handshake.md).
These implementation instructions supplement transport capture; they do not
change A8's signed live-host proof requirements or its acceptance classifications.
The historically reviewed A8 design is retained at its reviewed content, and its
review contracts and recorded approval hashes remain unchanged. This separation
avoids attributing later host-adapter documentation to an earlier design review.

The A8 workflow-state check failed on the appended design section before this
relocation and passed afterward in both Bash and PowerShell. The native handshake
contract suite also passed all four tests. No historical review record was rewritten.
