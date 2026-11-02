# Two bounded Codex guidance probes

The rubric in `protocol.json` was written before either model call. Both native
`verify-codex` executions used existing authentication, `gpt-6-astra`, a read-only
sandbox, a 180-second outer bound and separate fixtures. Exactly two calls ran.
The evaluator inspected completed tool commands and returned source bytes in
`evidence.zip`, not just the models' claims. `result.json` records fixture hashes,
commands, answers and actual token usage.

The documentation-only fixture read its README and policy, did not look up the
repository coding index and did not demand analyzers. The source-development
fixture read the coding index, Python/common rules and source file; it identified
shell concatenation and option boundaries, failure propagation, resource bounds
and encoding. Neither executed checks, changed files or granted Done. All six
predeclared criteria were observed in these two runs.

The source case read **all of common.md**, despite the goal of minimal contextual
lookup. Relevant rule selection in its answer succeeded, but economical section
selection did not. This observation is retained rather than treating the run as
complete instruction adherence.

This is a current-policy acceptance probe, not a before/after or blinded model
comparison. The prompt explicitly requested the local policy, so spontaneous
installed-plugin discovery is untested. Parent workspace instructions were also
read. These two cases do not establish all hosts, all models, actual Full/Lite
state transitions or independent review. No remote resource was changed.

`../timeout-child.json` separately records an actual Linux TypeScript 7.0.2 API
child after forced parent timeout: the child exited and appeared as a zombie,
not a running orphan. PID1 had not reaped it when observed. This resolves the
running-descendant question for that Linux stdio case only; it does not establish
Windows named-pipe cleanup or a universal process-tree guarantee.
