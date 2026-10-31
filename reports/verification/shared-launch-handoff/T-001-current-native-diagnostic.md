# T-001 current-byte native diagnostic

Owner: shared-review-launch-integration. Command: `rtk proxy python3 -B plugins/sdd-review-loop/scripts/probe-nontty-review.py reports/review-context/T-001-current-unreserved-diagnostic-source.json`.
Session: `a1f32b44-04e4-4778-90de-0155a59ff55e`. Exit: 0. No reservation was performed.

Observed assertions: admitted input reads executed; five guard-admitted paths read; seven ordered hashes verified; source invocation read; outside read and chained Bash rejected by PreToolUse; existing-session collision rejected. The first Bash retry was observed. These are diagnostic assertions, not a formal verdict or installed-hook activation proof.

| Binding | SHA-256 |
|---|---|
| Source invocation | 717536e5a3c14646d874fd037f3279aa2dfef612a63a3220b4af6b6dda66fd5c |
| Policy | c816de089abbf57d09dd5999ce8d993aad76528cac6adef504f6e8c5c180953c |
| Guard | 0a3d9961c53d01520a37fc41bf86ef7a7e5e6cc3254d427789b6115634e1369b |
| Transcript | 19906eb19e9422819c4b84146fe4ad4af94dfcd15725b5e1de2facf1f2980004 |

The diagnostic printed `rate_limited: true`, but its detector searches for the substring `429` anywhere in output. Read-only inspection of 149 transcript records found 34 such substring occurrences, zero rate-limit events, zero rate-limit phrases and no structured errors. This flag alone does not establish a service limit. The successful native assertions above do not depend on that flag.

Current-byte rollback, formal quality evaluation, exact-head CI and merge remain separate requirements.
