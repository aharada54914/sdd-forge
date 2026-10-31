# A21 round1 launch failure — diagnostic only

The single native non-TTY reviewer A session c933b018-5af0-4c78-b3ba-9a2d14c9d134 consumed reservation sequence1210. CLI exited 0, but the ordinary postflight rejected wrapper.result at validate-nontty-spec-launch.py:196 with JSONDecodeError: Expecting value: line 1 column 1 (char 0). The result contains explanatory text and a Markdown JSON fence; structured_output is absent. No canonical reviewer output or verdict was adopted. B was not reserved or launched.

Preserve all original bytes and the consumed identity. Do not strip fences, substitute another wrapper field, reuse the identity, or resume/replay this turn. The result remains diagnostic-only; transition legality is not established.

Native transcript: /Users/jrmag/.claude/projects/-Users-jrmag--codex-worktrees-a7-t005-intake-sdd-forge/c933b018-5af0-4c78-b3ba-9a2d14c9d134.jsonl
Native SHA-256: 0d8f2b0c66ee6d57081c3ddfb899285e1954b84f352536bc0c48b3fbdc40a0e1
Wrapper SHA-256: fbc34a2ca3712730495471a439924812cdc370c0e12b8299ece8c0c7e5b40673

Detailed immutable-launch diagnostic: reports/verification/a7-attempt21-formal-20261006/transport-failure-analysis.md. Subsequent unreserved probes identified the custom agent tools list omitting StructuredOutput; that later diagnosis does not validate or repair this failed result.
