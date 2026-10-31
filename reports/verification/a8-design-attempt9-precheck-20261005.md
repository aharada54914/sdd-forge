# A8 amended design: new precheck

2026-10-05. Executed in this owner checkout:

`rtk proxy bash plugins/sdd-review-loop/scripts/impl-review-precheck.sh epic-196-a8-integration 9 1 --provenance-rereview`

Observed exit 0. The new precheck is
`reports/impl-review/epic-196-a8-integration/attempt-9/round-1/precheck-result.json`.
It binds design SHA-256
`6485d5585fd37fe9ce298b295168ad2304d6dec6a1c7dc768bf76bbebf8c1aa3`
and ADR 0035 SHA-256
`50cf6c313940ccfa182cc8632d59215430183957e6e0ea02d6d064c934109923`.
Input-set SHA-256:
`27e91ac570c6f151287d22bf61164e930b12f5d494d490499e91c08e78dca74a`.

The previous Passed field is historical, not a verdict for these amended bytes.
No reviewer identity was reserved by this operation. Independent review,
task-stage rebinding, driver application, behavioral and live-host verification,
CI and merge remain pending. Attempt 8 and its consumed identities remain intact.
