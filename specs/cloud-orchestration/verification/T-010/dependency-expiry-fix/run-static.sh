#!/usr/bin/env bash
set -uo pipefail
export MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts
files=(plugins/sdd-quality-loop/scripts/cloud_authorization.py plugins/sdd-quality-loop/scripts/cloud_dependencies.py plugins/sdd-azure-cloud/scripts/azure_execution.py plugins/sdd-aws-cloud/scripts/aws_execution.py tests/cloud-orchestration-verification.tests.py specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/run-scoped.py specs/cloud-orchestration/verification/T-010/dependency-expiry-fix/rollback.py)
evidence=specs/cloud-orchestration/verification/T-010/dependency-expiry-fix
printf 'MYPYPATH=%s\n' "$MYPYPATH"
status=0
for tool in ruff mypy; do
 if [[ $tool == ruff ]]; then options=(check --config); else options=(--config-file); fi
 command=(/tmp/cloud-quality-python/bin/python -m "$tool" "${options[@]}" tests/shared-launch-python/pyproject.toml "${files[@]}")
 printf 'COMMAND '; printf '%q ' "${command[@]}"; printf '\n'
 "${command[@]}" > "$evidence/$tool.log" 2>&1
 rc=$?; printf 'EXIT %s %s\n' "$tool" "$rc"; cat "$evidence/$tool.log"
 if [[ $rc != 0 ]]; then status=1; fi
done
exit "$status"
