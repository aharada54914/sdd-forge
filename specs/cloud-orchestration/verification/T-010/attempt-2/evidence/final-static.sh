#!/usr/bin/env bash
set -u
export MYPYPATH=plugins/sdd-quality-loop/scripts:plugins/sdd-azure-cloud/scripts:plugins/sdd-aws-cloud/scripts
files=(
 plugins/sdd-quality-loop/scripts/cloud_dependencies.py
 plugins/sdd-quality-loop/scripts/cloud_authorization.py
 plugins/sdd-azure-cloud/scripts/azure_governed.py
 plugins/sdd-aws-cloud/scripts/aws_governed.py
 tests/cloud-orchestration-verification.tests.py
 specs/cloud-orchestration/verification/T-010/attempt-2/evidence/run-scoped.py
 specs/cloud-orchestration/verification/T-010/attempt-2/evidence/rollback-experiment.py
)
evidence=specs/cloud-orchestration/verification/T-010/attempt-2/evidence
printf 'MYPYPATH=%s\n' "$MYPYPATH"
printf 'RUFF COMMAND /tmp/cloud-quality-python/bin/python -m ruff check --config tests/shared-launch-python/pyproject.toml'; printf ' %s' "${files[@]}"; printf '\n'
/tmp/cloud-quality-python/bin/python -m ruff check --config tests/shared-launch-python/pyproject.toml "${files[@]}" > "$evidence/completed-ruff.log" 2>&1
result=$?; printf 'RUFF EXIT %s\n' "$result"; cat "$evidence/completed-ruff.log"
printf 'MYPY COMMAND /tmp/cloud-quality-python/bin/python -m mypy --config-file tests/shared-launch-python/pyproject.toml'; printf ' %s' "${files[@]}"; printf '\n'
/tmp/cloud-quality-python/bin/python -m mypy --config-file tests/shared-launch-python/pyproject.toml "${files[@]}" > "$evidence/completed-mypy.log" 2>&1
result=$?; printf 'MYPY EXIT %s\n' "$result"; cat "$evidence/completed-mypy.log"
