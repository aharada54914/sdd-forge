# Collector and CI fixture follow-up

These logs cover the prospective TDD collector (21 tests), exact historical/live
mirror classification (135 checks), mirror freshness in Bash/PowerShell, and the
capability registry fixture (28 checks each in Bash/PowerShell). Native Windows
and macOS behavior remains subject to hosted CI; local PowerShell runs on Linux.

Collector integration uses real subprocesses for Red/Green and the CLI handoff.
Its critical signing test uses explicitly synthetic other checks, review and key;
it demonstrates the existing dirty/clean/signature sequence, not actual review
or task acceptance. Independent review reproduced admission replacement, secret
inheritance, runtime substitution, and widened output grants; repaired boundaries
rejected all four. No frozen source evidence was rewritten.

Hosted predecessor run 40192305692 exposed stale mirror registration and a missing
source-evidence entry in the clean registry fixture; these local receipts verify
the fixes. They do not claim that predecessor CI passed or replace final-head CI.
