# Root implementation feedback and inspection

Classification: caller implementation feedback, not independent review or gate.

The caller initially asserted `DeploymentProperties.template` must be an object,
then explicitly corrected that assertion: the actual 2025-04-01 schema has no
object-only restriction and describes JObject **or well-formed JSON string**.
The admitted official snapshot confirms this. T-012 retains its supported exact
JSON-string representation. No invalid-payload finding or remediation is claimed.
The deterministic transport asserts the representation and parses the original
compiled bytes; the native API is not represented as an immediate-only success.

The separate final-admission-deadline observation was investigated with an
advancing-clock test. `red-final-deadline.log` genuinely shows four failures:
prepare policy TTL, apply policy TTL, apply provider expiry and apply preview
expiry all crossed during durable callback publication and still sent a mutation.
The failing case was committed in 09ede219 before its fix. The callback now reads
only the receipt just exclusively published by its own WriteBoundary, retains its
minimum deadline, finishes all owner/graph/source checks and journal publication,
rechecks current binding/preview and the deadline immediately before send.
`green-final-deadline.log` records zero submissions in each expired case.
No imported receipt grants admission; reaching this callback still requires fresh
authenticated GitHub/OIDC/provider admission at every POST/PUT. Root owns any
subsequent independent review or quality verdict.

## Subsequent cross-job replay observation: unresolved

Root identified that an original immutable prepare archive omits later apply
journals. Fresh authenticated run 456 after prior run 123 UNKNOWN and native 404
returns PASS in the real deterministic regression, rather than preserving UNKNOWN.
The separate unavailable/incomplete/excessive-history test also returns PASS at
its first negative assertion. `red-cross-job-replay.log` retains both failures;
commit 1082e961 precedes any fence implementation. No fence implementation has
been made at this handoff. This is implementation feedback, not an independent
verdict. Earlier deadline Green evidence does not establish cross-job safety.
