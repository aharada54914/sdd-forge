# CI Command Detection

Detect available commands in this order.

## JavaScript / TypeScript

- package.json scripts:
  - lint
  - typecheck
  - test
  - test:unit
  - test:integration
  - test:e2e
  - build
  - api:lint

## Python

- pyproject.toml
- Makefile
- justfile
- pytest
- ruff
- mypy
- pyright

## Fallback

If no commands are detected, create a report explaining what is missing.
Do not invent commands that are not present.
