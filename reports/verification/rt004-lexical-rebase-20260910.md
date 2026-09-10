# RT004 lexical DATA candidate rebased after root repair

Status: preparation only; candidate remains incomplete and must not be applied.

The candidate `adr-runtime-lexical-candidate-20260909.patch` previously removed
early root resolution that the isolated POSIX-root patch already removed, and
inserted another stage-dependent root block beside the newly applied block.
Its obsolete root hunks have been removed. The current original root checks,
including root-leaf link rejection and non-impl resolution, are left intact.
Remaining insertion/replacement offsets have been refreshed against originals.

Candidate SHA256:
`87ceef22901e3915d37e502affb23fae6a93858397fb200aa817a9f3c108f399`.

Original SHA256 values, unchanged by this DATA-only edit:

- Bash: `97deb3c9eeec2e8cf3689f547512ad96c6f266a7f28d5875c20d9098a31698b9`
- PowerShell: `b58df1ddfb5ae7d4c8bc31b6a32fe222780b582d529d8759c8d234dd730d2db3`

`rtk proxy git apply --check --unidiff-zero reports/verification/adr-runtime-lexical-candidate-20260909.patch`
exited 0. No apply, copied executable, commit, push or merge was performed.
Applicability is not runtime verification or independent review.

## Main-agent review and next implementation constraints

No new behavior is introduced into original scripts by this rebase. The
following existing candidate defects remain, and prohibit application:

1. `adr_read_bound_file` rejects any parent/child device difference or dirent
   inode mismatch. Its own incomplete-backend comment and ADR-0034 record why
   ordinary macOS mount/firmlink transport cannot be claimed supported.
2. PowerShell `Read-AdrAdmissionSnapshot` still opens a pathname independently
   after path checks. Same-snapshot hash/text processing does not establish
   handle-relative no-follow or exact-name acquisition.
3. Retaining the applied root block preserves current Windows resolution;
   rebase does not implement the proposed raw drive/UNC backend. Syntax checks
   later in the candidate do not supply that missing acquisition guarantee.
4. Downstream consumers and later reads need consistent bound-input handling;
   fixing the eight stationary exact-case tests alone would not complete RT004.

Next: complete the acquisition design/implementation within ADR-0034's bounded
threat scope; independently review the complete candidate before human apply;
then run original-path regressions and formal gates. Preserve all historical
FAIL evidence. The current original admission result remains 52 pass / 8 fail,
not a result of executing this candidate.
