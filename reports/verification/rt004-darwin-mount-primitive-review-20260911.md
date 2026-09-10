# RT004: Darwin descriptor mount metadata primitive

Status: independent static review completed for one helper only; full candidate
is incomplete and must not be applied as a completed acquisition repair.

Candidate: `reports/verification/adr-runtime-lexical-candidate-20260909.patch`
SHA256: `250314936870c8f843579a435e0b61bd2696d0424b851623977c777607bcf13b`.

The candidate adds `darwin_mount(fd)` using explicit `fstatfs64` over a held
descriptor. Its mismatch branch classifies a Darwin mount crossing and still
rejects it. There is no authorization fallback and no new accepted crossing.

Independent reviewer `/root/rt004_check_contract_review` inspected this helper
read-only and found no mandatory correction. Types, array lengths, size 2168,
fsid offset 48 and extended-flags offset 2136 match the installed SDK's
`sys/mount.h:105–123` and its fsid_t/uid_t definitions. The function signature
matches the SDK declaration at line 444; the reviewer also checked exports.
Unsupported ABI, missing symbol, syscall failure and empty, unterminated or
non-ASCII filesystem type are rejected. No pathname fallback is present.

The primary agent separately inspected the SDK layout and declaration.
`git apply --check --unidiff-zero` exited 0 against the current worktree;
`git diff --check` exited 0. Neither command applied or executed the candidate.

Returned fsid, owner and flags are observations, not authority. The subsequent
root/Data and filesystem-enforcement predicates must reject unsupported values
and establish the complete held-object association. Permission/ACL stability,
authenticated firmlink mapping, physical/logical identity binding, consistent
PowerShell acquisition and native Windows support remain unfinished.

This is not a formal SDD PASS, runtime verification, resolution of the eight
wrong-case failures, recovery activation, CI success or merge authorization.
No new human application is requested for this incomplete candidate.
