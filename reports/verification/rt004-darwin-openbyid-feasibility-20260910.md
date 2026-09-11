# RT004 Darwin open-by-ID feasibility

Date: 2026-09-10. Read-only source investigation; no implementation PASS.

## Question and evidence

Could opening the object ID returned with an exact directory-entry name
provide the missing mount/firmlink identity bridge?

The inspected Apple XNU revision is
`f6217f891ac0bb64f3d375211650a4c1ff8ca1ea`, resolved through GitHub's commit API.
Its [vfs_syscalls.c](https://github.com/apple-oss-distributions/xnu/blob/f6217f891ac0bb64f3d375211650a4c1ff8ca1ea/bsd/vfs/vfs_syscalls.c#L5437)
permits open-by-ID only for a platform binary or a process carrying the private
`com.apple.private.vfs.open-by-id` entitlement (5437–5447), otherwise returning
EPERM (5488–5489). The implementation resolves an ID to a path (5518–5519),
opens it with expected ID/domain arguments (5533–5534), and retries ERECYCLE
(5538–5546). Thus its name alone is not proof of direct handle acquisition.

These are source observations, not results from executing this API on the
current kernel. No raw syscall, privilege change, entitlement alteration or
alternate executor was attempted. The source revision is pinned because web
rendering and current raw-source line numbering differed during investigation.

## Disposition

Reject this as the ordinary plugin-runtime backend: adding a private Apple
entitlement or depending on a privileged platform executable is not an
acceptable runtime prerequisite. Do not infer a demonstrated race from the
path conversion alone: the implementation also checks identity. Conversely,
that check does not establish the required exact-parent-name binding for this
candidate. No production or DATA candidate file was changed.

The architecture skill's feasibility check eliminated this proposed route.
RT004 remains open. The next investigation must address an API available to
ordinary processes; neither unavailable capability rejection nor observer
140/0 satisfies successful acquisition on supported mount/firmlink paths.
Windows drive/UNC acquisition and original-path regression verification also
remain required. No formal review, CI or merge condition was waived.
