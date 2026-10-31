# Native reviewer B launch

Native app-server request 15 allocated empty read-only thread/session
`01a0e0e2-c1c9-7b80-a7a3-a7e3d62832d1` without parent turns.
Original validator exited 0 before request 16 launched review turn
`01a0e0e3-2c84-7611-8fc6-c71df7de4c47`:

```text
REVIEW_CONTEXT_OK 365d821bc7a6df563a6615a8e5e5b5a41f3510a6b0b38941197fa69afb5f8047 sequence=1195 previous_record_sha256=3fdc97fd3dba625d367740d92d302c5d14236860bd3f541e5c2ee14883ea0570 pre_append_tip_sequence=1194 identity_unique=yes
```

The reviewer received the reserved inputs, original receipt, shipped role and
boundary contract, plus only the canonical A check summary, not raw A output.
Actual completed native output is retained in reviewer-b.json.
