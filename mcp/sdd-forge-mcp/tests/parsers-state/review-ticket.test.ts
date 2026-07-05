/**
 * T-003: review ticket parser tests — `docs/review-tickets/RT-*.yml`.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { listReviewTickets, parseReviewTicket } from "../../src/parsers/review-ticket.js";
import { makeTempSddRoot, writeFile } from "../test-helpers.js";
import { makeRealRepoRoot } from "./test-helpers.js";

test("real repo: RT-20260623-001.yml parses into the reviewTicketsData entry shape", () => {
  const root = makeRealRepoRoot();
  const result = parseReviewTicket(root, "docs/review-tickets/RT-20260623-001.yml");
  assert.equal(result.ok, true);
  if (!result.ok) return;
  assert.equal(result.data.ticketId, "RT-20260623-001");
  assert.ok(result.data.status.length > 0);
  assert.ok(result.data.severity.length > 0);
  assert.equal(result.data.file, "docs/review-tickets/RT-20260623-001.yml");
  // target.feature / target.task are present in the real ticket.
  assert.equal(result.data.feature, "claude-workflow-compatibility");
  assert.equal(result.data.task, "T-002");
  assert.ok(result.data.summary !== undefined && result.data.summary.length > 0);
});

test("real repo: listReviewTickets finds at least one ticket and no failures", () => {
  const root = makeRealRepoRoot();
  const scan = listReviewTickets(root);
  assert.ok(scan.tickets.length >= 1, `expected >= 1 review ticket, got ${scan.tickets.length}`);
  assert.deepEqual(scan.failures, []);
  for (const ticket of scan.tickets) {
    assert.match(ticket.ticketId, /^RT-[0-9]{8}-[0-9]{3}$/);
    assert.ok(ticket.file.endsWith(".yml") || ticket.file.endsWith(".yaml"));
  }
});

test("synthetic: well-formed ticket parses all optional fields", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-pass");
  try {
    const yml = [
      "ticket_id: RT-20260701-001",
      "status: open",
      "severity: minor",
      "type: spec-gap",
      "target:",
      "  feature: demo-feature",
      "  task: T-009",
      "summary: something small",
      "",
    ].join("\n");
    writeFile(root.path, "docs/review-tickets/RT-20260701-001.yml", yml);

    const result = parseReviewTicket(root, "docs/review-tickets/RT-20260701-001.yml");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.deepEqual(result.data, {
      ticketId: "RT-20260701-001",
      status: "open",
      severity: "minor",
      type: "spec-gap",
      feature: "demo-feature",
      task: "T-009",
      summary: "something small",
      file: "docs/review-tickets/RT-20260701-001.yml",
    });
  } finally {
    cleanup();
  }
});

test("synthetic: minimal ticket (only required fields) parses without optional keys", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-minimal");
  try {
    const yml = ["ticket_id: RT-20260701-002", "status: resolved", "severity: major", ""].join(
      "\n",
    );
    writeFile(root.path, "docs/review-tickets/RT-20260701-002.yml", yml);

    const result = parseReviewTicket(root, "docs/review-tickets/RT-20260701-002.yml");
    assert.equal(result.ok, true);
    if (!result.ok) return;
    assert.equal(result.data.ticketId, "RT-20260701-002");
    assert.equal(result.data.type, undefined);
    assert.equal(result.data.feature, undefined);
    assert.equal(result.data.task, undefined);
    assert.equal(result.data.summary, undefined);
  } finally {
    cleanup();
  }
});

test("cannot-parse: invalid YAML syntax", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-bad-yaml");
  try {
    const badYml = ["ticket_id: RT-20260701-003", "status: [unterminated", ""].join("\n");
    writeFile(root.path, "docs/review-tickets/RT-20260701-003.yml", badYml);

    const result = parseReviewTicket(root, "docs/review-tickets/RT-20260701-003.yml");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.file, "docs/review-tickets/RT-20260701-003.yml");
  } finally {
    cleanup();
  }
});

test("cannot-parse: missing required fields", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-missing-fields");
  try {
    const yml = ["summary: no ticket_id or status or severity here", ""].join("\n");
    writeFile(root.path, "docs/review-tickets/RT-20260701-004.yml", yml);

    const result = parseReviewTicket(root, "docs/review-tickets/RT-20260701-004.yml");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.match(result.error.message, /ticket_id/);
    assert.match(result.error.message, /status/);
    assert.match(result.error.message, /severity/);
  } finally {
    cleanup();
  }
});

test("cannot-parse: ticket_id does not match RT-YYYYMMDD-NNN", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-bad-id-shape");
  try {
    const yml = ["ticket_id: RT-bad-id", "status: open", "severity: minor", ""].join("\n");
    writeFile(root.path, "docs/review-tickets/RT-weird.yml", yml);

    const result = parseReviewTicket(root, "docs/review-tickets/RT-weird.yml");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.rule, "ticket-id-shape");
  } finally {
    cleanup();
  }
});

test("cannot-parse: YAML document is a scalar, not a mapping", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-not-mapping");
  try {
    writeFile(root.path, "docs/review-tickets/RT-20260701-005.yml", "just a string\n");

    const result = parseReviewTicket(root, "docs/review-tickets/RT-20260701-005.yml");
    assert.equal(result.ok, false);
    if (result.ok) return;
    assert.equal(result.error.code, "cannot-parse");
    assert.equal(result.error.details?.rule, "not-a-mapping");
  } finally {
    cleanup();
  }
});

test("listReviewTickets ignores non-yml files (e.g. .gitkeep) and reports per-file failures", () => {
  const { root, cleanup } = makeTempSddRoot("review-ticket-scan-mixed");
  try {
    writeFile(root.path, "docs/review-tickets/.gitkeep", "");
    writeFile(
      root.path,
      "docs/review-tickets/RT-20260701-010.yml",
      ["ticket_id: RT-20260701-010", "status: open", "severity: critical", ""].join("\n"),
    );
    writeFile(root.path, "docs/review-tickets/RT-broken.yml", "status: [unterminated\n");

    const scan = listReviewTickets(root);
    assert.equal(scan.tickets.length, 1);
    assert.equal(scan.tickets[0]?.ticketId, "RT-20260701-010");
    assert.equal(scan.failures.length, 1);
    assert.equal(scan.failures[0]?.file, "docs/review-tickets/RT-broken.yml");
  } finally {
    cleanup();
  }
});
