# RT004 acquisition: independent review and API elimination

Scope: RT-20260908-004. Advisory design evidence only; no formal PASS.

The existing independent reviewer `rt004_snapshot_static_review` reviewed
ADR-0034, both live validators and the lexical DATA candidate on 2026-09-11.
It found no complete reusable safe initial-acquisition helper. Bash's
`read_precheck_content` retains bytes only after a pathname open; PowerShell's
`ReadAllBytes` follows separately performed path checks. The old candidate's
POSIX reader handles ordinary entries but rejects mount boundaries; its
PowerShell reader still separates checks from open. No production changes
were authorized by this advisory outcome.

The minimum reviewed interface is a held acquisition context plus a relative
authorized path returning private bytes, their hash and opened identity.
Precheck acquisition precedes schema dispatch. Design and declared ADRs use
the same transport and retained bytes. Every error precedes ledger mutation.
The review does not require detecting all intervening content edits and does
not establish that a Darwin ACL bridge is the necessary solution.

## Primary-source check: bulk attributes are not the missing bridge

Apple's [getattrlistbulk manual](https://raw.githubusercontent.com/apple-oss-distributions/xnu/main/bsd/man/man2/getattrlistbulk.2),
retrieved 2026-09-11, lines 167–183, explicitly distinguishes mount-point
attributes from mounted-root attributes, and firmlink attributes from target
attributes. The bulk call returns the former; obtaining target attributes
requires another call. Thus replacing `scandir` with this API does not by
itself associate the target opened across a mount/firmlink with the source
directory-entry identity. This is an inference from the documented semantics,
not a native runtime experiment or proof that no other API can help.

Do not implement a bulk-attribute replacement on the assumption it removes
the identity-domain mismatch. Do not add a generic mismatch fallback or reject
normal macOS root/Data paths as a substitute for supporting them.

Next implementation prerequisite: select and independently verify a concrete
boundary-association mechanism. Ordinary mutable descendants keep exact-name,
held-parent, no-follow and regular-leaf checks. Windows drive/UNC acquisition
and native evidence remain required. Existing JSON/path/history successes and
the full-suite 348/64 failure baseline remain unchanged.
