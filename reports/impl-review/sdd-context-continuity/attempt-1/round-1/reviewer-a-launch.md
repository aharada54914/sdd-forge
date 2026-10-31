# Native reviewer A launch

App-server request 17 allocated fresh empty read-only thread/session
`01a0e0eb-c19d-7821-9157-317ad97b0dfb` without parent or shared turns.
The original input verification succeeded. Reservation required an absolute
repository root; the rejected relative-root call appended no reservation.
The absolute-root reservation exited 0 with:

```text
REVIEW_CONTEXT_OK 00c8485b5ab450596571cb7c96ba864d1c5269d39d0643bd3780c1bb88390d2d sequence=1196 previous_record_sha256=365d821bc7a6df563a6615a8e5e5b5a41f3510a6b0b38941197fa69afb5f8047 pre_append_tip_sequence=1195 identity_unique=yes
```

Request 18 then launched the independent review with medium effort.
The native sandbox is readOnly; only the exact bound inputs and shipped role
and boundary instructions were supplied. Launch is not a verdict.
