#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "$0")/.." && pwd -P)"
exec python3 -B "$repository_root/tests/release-readiness.tests.py" ReleaseReadiness.test_repository_release_validation
