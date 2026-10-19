# Workload exemption diagnosis and preflight

Cycle 3 evaluator found that non-Boolean continue-on-error values silently remove required workload from the full inventory. The same predicate tests both job and step settings, so both levels require coverage. The legacy workflow_coverage function proves only positively established suite execution and does not produce full obligations; leave that distinct conservative behavior unchanged.

Correction: full inventory accepts only literal Boolean continue-on-error values. Missing/false keeps work; literal true retains the existing best-effort exemption. Expressions and malformed types reject the plan rather than guessing their truth value. Both settings are validated before a true setting can exempt work. The CLI must return its existing structured input-invalid error and publish no partial plan or condition outputs. No wire/schema, requirement, workflow, or architecture change.

Persisted fields: obligations[].id/job/step and groups map to full workflow workload; the direct inventory test mutates both levels and requires rejection for every unproven exemption. CLI output/condition paths map to a successful complete inventory; the CLI test requires exit 2 and no files for an unsupported expression. These tests run Red before the product fix.
