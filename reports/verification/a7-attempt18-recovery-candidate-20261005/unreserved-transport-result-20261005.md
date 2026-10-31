# Unreserved native transport diagnostic

Observed 2026-10-05 08:42 UTC in the owning A7 worktree. This is not a formal review, reservation, approval, or hook-activation proof.

- Native Claude CLI 2.1.289, requested `--model sonnet`, returned `claude-sonnet-5-5`.
- Command: `rtk proxy claude -p --session-id cfb4e9a5-4cdb-44a9-abee-ba0ccf0f8e78 --output-format json --model sonnet --tools "" < reports/verification/a7-attempt18-recovery-candidate-20261005/unreserved-transport-20261005.txt`.
- First execution exit 0, `is_error:false`, `subtype:success`, matching session ID and both requested markers.
- Native transcript contains exactly one human user record. Its content encoded as UTF-8 equals all 1,259 prompt bytes, including the terminal newline. Comparison assertions exited 0.
- Prompt SHA-256: `f4a3cdb33df4430e934bb8bf22a6d5c89e5192f1cf14a437a72a2f68c0d783bc`.
- Native transcript SHA-256 after the collision check: `b689a96b68e6c7cb41d962ded57f08450e57e60199690cb6e5512ded33d48c50`. Private transcript remains local, outside Git.
- Second execution of the same command exited 1: `Error: Session ID cfb4e9a5-4cdb-44a9-abee-ba0ccf0f8e78 is already in use.` No second human turn was appended.

No formal identity was reserved. This diagnostic UUID must never be reused as a reviewer. Protected launch-contract application, formal audit/contract path rebinding, normal precheck and fresh independent reviewers remain required. Historical failures remain unchanged.
