# Hook activation correction

The original relative-path denial was extracted from this session's cli-stderr.log byte range [1214,1812), after the router error= prefix through the matching patch end. The log separator newline is excluded. No result bytes were normalized or invented. See handshake-native-provenance.json for the SHA-256 and handshake-native-raw-result.txt for the exact bytes.

handshake-native-response.json contains the separate native sdd-codex-host-denial/v1 evidence with the original nonce. No runtime feature metadata was supplied.

The normal verifier returned exit 0 and HOOK_ACTIVE. The exact command and exit are recorded in handshake-native-verifier-run.json; stdout and stderr are preserved in handshake-native-verifier.stdout and handshake-native-verifier.stderr. The original challenge was accepted, so no fresh challenge was needed.

This corrects the earlier CAPABILITY_RUNTIME_UNAVAILABLE conclusion in README.md and handshake-verdict.json. Those files retain historical results from insufficient observation-only evidence. The previous evidence-saving command was blocked because it embedded protected operation text, as recorded in hook-evidence-save-denial.txt. A later attempt to write this correction via a Python heredoc also received an ambiguous-shell-parsing denial; it made no changes. This correction was saved through apply_patch.

Remaining blocker: human review and approval of T-001. Tasks remain Draft and Planned. No implementation or protected-file modification occurred.
