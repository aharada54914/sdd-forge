# Formal-verification comparison map

Research question: compare Pstack's formal-verification workflow with formal OSS methods that can inform `verification-first-factory`.

| Claim | Evidence and current state | Application to this branch |
|---|---|---|
| CLM-001: verification should map to code, fail on a broken variant, and disclose bounds | Pstack official skill SRC-001; source quote hash present but original snapshot/quote verification not yet run | Use mapping files that name code functions/actions; run the actual checker; add real negative controls; write a rerunnable skill and sync commit only after review |
| CLM-002: Apalache is useful for bounded symbolic checks and inductive invariants | Official Apalache README SRC-003; quote status unverified; tool documentation acquisition blocked | Keep TLA+ model language/tool separate from checker adapter; label bounded results with length and assumptions; do not turn a bounded pass into an unbounded claim |
| CLM-003: Alloy searches within finite scopes | Official language spec inspected via browser; canonical acquisition blocked (SRC-005); unresolved | Do not adopt Alloy or assert its scope semantics based on this record until source acquisition/quote verification is possible |
| CLM-004: pick checker based on property shape | Inference not assessed | Use transition model checking for event ordering; use AST/property tests for source structure; use SMT/bounded model checking only where bounds answer the question |
| CLM-005: user requested a comparison and practical refactor | Verbatim request retained | Refactor branch verification around runnable commands, actual code mappings, failure controls, and explicit verification limits |

## Comparative conclusion (provisional)

Pstack is a workflow/skill, not a model checker. Its practical discipline complements the OSS tools: TLC explores finite explicit state spaces; Apalache translates TLA+ to SMT-backed symbolic checks and offers bounded checks plus inductive-invariant workflows; Alloy is a distinct relational model finder whose finite-scope limits still need locally admitted source evidence here. Therefore TLA+ remains the current lifecycle-model language while the branch should fix fidelity, checker execution, negative controls, artifacts, and clear bounds before adding another formalism.

This is an implementation hypothesis, not an approved specification amendment or a claim that any one checker proves production code correct.
