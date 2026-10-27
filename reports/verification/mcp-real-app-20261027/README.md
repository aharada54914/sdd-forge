# Real sdd-forge MCP pilot

The user selected sdd-forge MCP as the real application on 2026-10-26 UTC.
The protocol was saved before starting the six native MCP sessions. Each
alternating baseline/candidate pair used the same real repository tree at
`4271e1c5`, same six requests and the actual source bundles from main `0535c3c1`
and candidate `4271e1c5`. Each server ran over stdio in a read-only filesystem/PID
namespace, without network. No synthetic tasks or asserted PASS responses were
substituted. All 36 actual calls completed with identical structured results;
tracked source state was unchanged.

The selected task is to determine the next allowed step for
`project-skill-observation`, then compare the completed `sdd-forge-mcp` feature.
The real replies say spec-review for the former (requirements/design Pending,
no formal task file) and done for the latter (11 Approved/Done tasks). These are
observations of product state, not a requirement that development itself adopt
the product workflow. A failed `get_task_state` for the missing formal task file
is retained as returned, not converted into approval.

Total session median: main 12.672 s, candidate 1.034 s, three trials each.
This local paired workload includes the already integrated report-lookup reuse;
it is not a whole-lifecycle speedup, p95 estimate, model evaluation or human
time saving. Preliminary attempts failed before any MCP tool call because of
collector buffer/runtime mount configuration; final settings and all actual
native responses are retained. The reproduction script uses new, fixed output
paths and recorded revisions, not a new product runner.

`review.html` is a self-contained, offline comparison of raw results and a thin
summary/provenance display over these same native replies. It is a snapshot
prototype, not a newly deployed live MCP frontend. Its four questions and local
JSON export record observed interaction time, feature changes, evidence opens,
answers and a user choice/reason. The export is unverified client data with no
approval or adoption authority. The owner has been asked to operate both
displays; human results remain pending. A single user's repeated exposure is
not an independent UX sample.

Seven automated browser controls passed, including source expansion, all four
task answers, missing-reason rejection and JSON export. They are explicitly
automation, not human evaluation. Managed Chromium blocked file navigation;
the exact local HTML bytes were tested using `set_content`, without changing
browser policy. `preview.png` is from that control.
