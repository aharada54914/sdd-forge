# ADR 0001: Local standard library server and SQLite

Status: Proposed
Date: 2026-11-07

Use Python standard-library HTTP/SQLite and plain browser assets to satisfy local disposable operation and minimal runtime dependencies. Commit mutations before success and restart with same explicit database path. No multi-user service, hosted availability or automated backup. Verify real browser CRUD, process restart and negative boundary tests before Done.
