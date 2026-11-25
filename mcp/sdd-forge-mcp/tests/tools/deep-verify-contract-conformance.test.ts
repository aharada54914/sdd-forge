/**
 * AC-015 (REQ-012): the retained evidence readers produce v1 contract envelopes.
 * The v2 registry no longer exposes the v1 tool names.
 *
 * Unlike deep-verify-tool.test.ts (which asserts the ok `evidenceDeepVerifyData`
 * shape *structurally* and only ajv-validates the shared error envelopes), this
 * suite validates the *ok* `evidence_deep_verify` responses — both a passing and
 * a richly-failing bundle — against the full v1 tool-response contract
 * (contracts/sdd-forge-mcp-tools.v1.schema.json) via ajv, exercising the
 * `evidenceDeepVerifyData` oneOf branch that T-007 adds to the contract. It also
 * re-checks the three error envelopes (invalid-input / not-found / cannot-parse)
 * and, for additivity, confirms the other five evidence readers' ok responses
 * still conform after the additive contract change.
 *
 * The ajv validator (`getEnvelopeValidator`) compiles the whole envelope schema
 * with `strict: true` and `additionalProperties: false` throughout, so a
 * response that carries an unexpected field, an out-of-enum status, or a shape
 * matching no `data.oneOf` branch fails validation. Removing the
 * `evidenceDeepVerifyData` branch from the contract therefore turns the two ok
 * deep-verify cases red (they match no branch), which is the T-007 red state.
 *
 * epic-136-phase4-mcp T-002 (issue #131 Finding B-13) additionally hosts
 * TEST-003/TEST-004/TEST-016/TEST-018 here: the top-level `hostRequiredChecks`
 * array's content contract, its verdict-independence, the schema
 * `description`'s literal text, and the two unconditional-presence edge cases.
 */

import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import {
  evidenceCompareToTraceability,
  evidenceDeepVerify,
  evidenceFindMissing,
  evidenceGetBundle,
  evidenceSummarizeContractChecks,
  evidenceValidatePaths,
} from "../../src/tools/evidence.js";
import { writeFile } from "../test-helpers.js";
import {
  findSddForgeRepoRoot,
  getEnvelopeValidator,
  seedDemoFixture,
} from "../evidence/test-helpers.js";
import { seedDeepVerifyRepo } from "./deep-verify-helpers.js";

/** Asserts a parsed envelope conforms to the v1 contract, surfacing ajv errors. */
function assertConforms(envelope: unknown, label: string): void {
  const validate = getEnvelopeValidator();
  const valid = validate(envelope);
  assert.ok(
    valid,
    `${label} does not conform to the v1 contract: ${JSON.stringify(validate.errors)}`,
  );
}

/** The two host-deferred checks, in the order `evidenceDeepVerify` emits them. */
const HOST_REQUIRED_CHECK_IDS = ["git-commit-ancestry", "signature-verification"] as const;

interface HostRequiredCheckShape {
  check: string;
  verified: boolean;
  note: string;
}

/**
 * A structural view of the ok `evidenceDeepVerifyData` payload. Deliberately
 * structural (and `hostRequiredChecks` deliberately optional) so this file
 * compiles both BEFORE the field exists in `src/` — the TDD red stage, where
 * the assertions below must fail at RUNTIME rather than at `tsc` time — and
 * after.
 */
interface DeepVerifyOkShape {
  verdict: string;
  failures: string[];
  artifacts: Array<{ status: string }>;
  invariants: {
    artifactsDigest: { status: string };
    specRevision: { status: string };
    gitCommit: { shapeValid: boolean; reason: string };
    crossBindings: Array<{ status: string }>;
  };
  signature: { present: boolean; note: string };
  hostRequiredChecks?: HostRequiredCheckShape[];
}

/** Unwraps an ok envelope's `data`, failing loudly on an error envelope. */
function okData(envelope: unknown, label: string): DeepVerifyOkShape {
  const parsed = envelope as { ok: boolean; data?: DeepVerifyOkShape };
  assert.equal(parsed.ok, true, `${label} is not an ok envelope`);
  const data = parsed.data;
  if (data === undefined) {
    assert.fail(`${label} carries no data`);
  }
  return data;
}

/**
 * TEST-003 / TEST-018 (AC-003 / AC-018): the top-level `hostRequiredChecks`
 * content contract. Each `note` is asserted EQUAL to the SAME response's own
 * nested `invariants.gitCommit.reason` / `signature.note` value rather than to
 * a hand-copied literal, so a future reword of either underlying string cannot
 * silently drift the promoted copy (design.md Risks' drift mitigation).
 */
function assertHostRequiredChecks(data: DeepVerifyOkShape, label: string): void {
  const checks = data.hostRequiredChecks;
  if (!Array.isArray(checks)) {
    assert.fail(`${label}: hostRequiredChecks is absent or not an array`);
  }
  assert.equal(checks.length, 2, `${label}: hostRequiredChecks must have exactly 2 entries`);
  assert.deepEqual(
    checks.map((entry) => entry.check),
    [...HOST_REQUIRED_CHECK_IDS],
    `${label}: hostRequiredChecks check ids`,
  );
  const [ancestry, signatureCheck] = checks;
  if (ancestry === undefined || signatureCheck === undefined) {
    assert.fail(`${label}: hostRequiredChecks is missing an entry`);
  }
  for (const entry of [ancestry, signatureCheck]) {
    assert.equal(entry.verified, false, `${label}: ${entry.check}.verified must be false`);
    assert.equal(typeof entry.note, "string", `${label}: ${entry.check}.note must be a string`);
    assert.ok(entry.note.length > 0, `${label}: ${entry.check}.note must be non-empty`);
  }
  assert.equal(
    ancestry.note,
    data.invariants.gitCommit.reason,
    `${label}: git-commit-ancestry note must be the response's own invariants.gitCommit.reason`,
  );
  assert.equal(
    signatureCheck.note,
    data.signature.note,
    `${label}: signature-verification note must be the response's own signature.note`,
  );
}

/**
 * TEST-004 (AC-004): recomputes the verdict from ONLY the pre-existing inputs
 * BL-005 names — artifacts / artifactsDigest / specRevision /
 * gitCommit.shapeValid / crossBindings. `hostRequiredChecks` is deliberately
 * not consulted.
 */
function verdictFromPreExistingInputsOnly(data: DeepVerifyOkShape): "pass" | "fail" {
  const allSatisfied =
    data.artifacts.every((artifact) => artifact.status === "match") &&
    data.invariants.artifactsDigest.status === "match" &&
    data.invariants.specRevision.status === "match" &&
    data.invariants.gitCommit.shapeValid &&
    data.invariants.crossBindings.every((binding) => binding.status === "match");
  return allSatisfied ? "pass" : "fail";
}

/** Applies the same multi-dimension tamper the fail-verdict fixture uses. */
function tamperForFailVerdict(fx: ReturnType<typeof seedDeepVerifyRepo>): void {
  const bundle = fx.baseBundle();
  bundle.spec_revision = "deadbeef";
  bundle.git_commit = "not-a-valid-40-hex-commit";
  (bundle.artifacts as Array<Record<string, unknown>>).push(
    { path: "specs/demo/does-not-exist.md", sha256: "f".repeat(64) },
    { path: fx.artifactRel, sha256: "zz-not-hex" },
  );
  fx.writeBundle(bundle);
  writeFile(fx.dir, fx.artifactRel, `${fx.artifactContents}TAMPER\n`);
}

test("AC-015: a passing evidence_deep_verify response conforms to the v1 contract (ajv)", () => {
  const fx = seedDeepVerifyRepo("dv-conformance-pass");
  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);

    assert.equal(envelope.ok, true);
    assert.equal(envelope.data.verdict, "pass");
    assertConforms(envelope, "passing evidence_deep_verify envelope");
    // TEST-003 (AC-003): the pass-verdict half of the always-present assertion.
    assertHostRequiredChecks(
      okData(envelope, "passing evidence_deep_verify envelope"),
      "pass-verdict fixture",
    );
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-015: a failing evidence_deep_verify response (mixed statuses) conforms to the v1 contract (ajv)", () => {
  const fx = seedDeepVerifyRepo("dv-conformance-fail");
  const bundle = fx.baseBundle();
  // Drive as many contract-branch shapes as possible in one response:
  //  - specRevision mismatch (recorded non-empty, no spec files -> computed "")
  //  - gitCommit shapeValid=false (not 40-hex)
  //  - a `missing` artifact (valid 64-hex recorded sha, path absent on disk)
  //  - an `invalid-recorded-sha` artifact (recorded sha not 64-hex)
  //  - a `mismatch` artifact (baseline artifact tampered on disk after write)
  bundle.spec_revision = "deadbeef";
  bundle.git_commit = "not-a-valid-40-hex-commit";
  (bundle.artifacts as Array<Record<string, unknown>>).push(
    { path: "specs/demo/does-not-exist.md", sha256: "f".repeat(64) },
    { path: fx.artifactRel, sha256: "zz-not-hex" },
  );
  fx.writeBundle(bundle);
  // Tamper the on-disk baseline artifact so its recorded (valid) sha mismatches.
  writeFile(fx.dir, fx.artifactRel, `${fx.artifactContents}TAMPER\n`);

  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);

    assert.equal(envelope.ok, true);
    const data = envelope.data;
    assert.equal(data.verdict, "fail");
    assert.ok(data.failures.length > 0);
    const statuses = new Set(data.artifacts.map((a) => a.status));
    assert.ok(statuses.has("mismatch"));
    assert.ok(statuses.has("missing"));
    assert.ok(statuses.has("invalid-recorded-sha"));
    assertConforms(envelope, "failing evidence_deep_verify envelope");
    // TEST-003 (AC-003): the fail-verdict half of the always-present assertion.
    assertHostRequiredChecks(
      okData(envelope, "failing evidence_deep_verify envelope"),
      "fail-verdict fixture",
    );
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-015: an invalid-input error envelope conforms to the v1 contract (ajv)", () => {
  const fx = seedDeepVerifyRepo("dv-conformance-invalid-input");
  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, "not-a-task-id");

    assertConforms(envelope, "invalid-input error envelope");
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "invalid-input");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-015: a not-found error envelope conforms to the v1 contract (ajv)", () => {
  const fx = seedDeepVerifyRepo("dv-conformance-not-found");
  try {
    // Valid taskId shape, but no <T-999>.evidence.json exists in the fixture.
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, "T-999");

    assertConforms(envelope, "not-found error envelope");
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "not-found");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("AC-015: a cannot-parse error envelope conforms to the v1 contract (ajv)", () => {
  const fx = seedDeepVerifyRepo("dv-conformance-cannot-parse");
  // Overwrite the consistent bundle with invalid JSON before reading it.
  writeFile(fx.dir, fx.bundleRel, "{ this is not valid json");
  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);

    assertConforms(envelope, "cannot-parse error envelope");
    assert.equal(envelope.ok, false);
    assert.equal(envelope.error.code, "cannot-parse");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("TEST-004 (AC-004): hostRequiredChecks never affects verdict — pass and fail fixtures", () => {
  const passFx = seedDeepVerifyRepo("dv-host-checks-verdict-pass");
  const failFx = seedDeepVerifyRepo("dv-host-checks-verdict-fail");
  tamperForFailVerdict(failFx);

  try {
    const passData = okData(
      evidenceDeepVerify(passFx.tempRoot.root, passFx.feature, passFx.taskId),
      "pass-verdict envelope",
    );
    const failData = okData(
      evidenceDeepVerify(failFx.tempRoot.root, failFx.feature, failFx.taskId),
      "fail-verdict envelope",
    );

    // 1. Both verdicts are fully explained by the pre-existing inputs alone.
    assert.equal(passData.verdict, "pass");
    assert.equal(failData.verdict, "fail");
    assert.equal(
      passData.verdict,
      verdictFromPreExistingInputsOnly(passData),
      "pass verdict is not reproduced by the pre-existing inputs alone",
    );
    assert.equal(
      failData.verdict,
      verdictFromPreExistingInputsOnly(failData),
      "fail verdict is not reproduced by the pre-existing inputs alone",
    );

    // 2. The byte-unchanged formula `failures.length === 0 ? "pass" : "fail"`.
    assert.equal(passData.verdict, passData.failures.length === 0 ? "pass" : "fail");
    assert.equal(failData.verdict, failData.failures.length === 0 ? "pass" : "fail");

    // 3. hostRequiredChecks is present, 2-entry and all-`verified: false` in
    //    BOTH — so an always-false host check moves the verdict in neither
    //    direction (it neither forces a fail nor rescues a fail).
    assertHostRequiredChecks(passData, "pass-verdict fixture (verdict independence)");
    assertHostRequiredChecks(failData, "fail-verdict fixture (verdict independence)");

    // 4. The field's CONTENT genuinely varies across the two fixtures (the
    //    fail fixture's git_commit is not 40-hex, so its ancestry note differs)
    //    while the verdict stays fully determined by the inputs above.
    const passChecks = passData.hostRequiredChecks ?? [];
    const failChecks = failData.hostRequiredChecks ?? [];
    assert.notEqual(
      passChecks[0]?.note,
      failChecks[0]?.note,
      "the two fixtures were expected to differ in hostRequiredChecks content",
    );

    // 5. No failure entry is produced by, or mentions, the new field.
    for (const entry of [...passData.failures, ...failData.failures]) {
      assert.ok(
        !entry.includes("hostRequiredChecks") && !entry.includes("host-required"),
        `failures[] must never be built from hostRequiredChecks, got: ${entry}`,
      );
    }
  } finally {
    passFx.tempRoot.cleanup();
    failFx.tempRoot.cleanup();
  }
});

test("TEST-018a (AC-018): a bundle with no signature block still carries both hostRequiredChecks", () => {
  const fx = seedDeepVerifyRepo("dv-host-checks-no-signature");
  const bundle = fx.baseBundle();
  // Explicitly assert the sub-case's precondition at fixture level: no
  // `signature` block at all, so `echoSignature` reports `present: false`.
  delete bundle.signature;
  fx.writeBundle(bundle);

  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    const data = okData(envelope, "no-signature envelope");
    assert.equal(data.signature.present, false, "sub-case precondition: signature.present is false");
    assertConforms(envelope, "no-signature evidence_deep_verify envelope");
    assertHostRequiredChecks(data, "TEST-018a no-signature fixture");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("TEST-018b (AC-018): a bundle whose git_commit is not 40-hex still carries both hostRequiredChecks", () => {
  const fx = seedDeepVerifyRepo("dv-host-checks-bad-git-commit");
  const bundle = fx.baseBundle();
  bundle.git_commit = "not-40-hex";
  fx.writeBundle(bundle);

  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    const data = okData(envelope, "bad-git-commit envelope");
    assert.equal(
      data.invariants.gitCommit.shapeValid,
      false,
      "sub-case precondition: gitCommit.shapeValid is false",
    );
    assertConforms(envelope, "bad-git-commit evidence_deep_verify envelope");
    assertHostRequiredChecks(data, "TEST-018b bad-git-commit fixture");
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("TEST-009 leg (AC-009): the schema requires hostRequiredChecks and pins its nested shape", () => {
  const repoRoot = findSddForgeRepoRoot();
  const schema = JSON.parse(
    readFileSync(join(repoRoot, "contracts", "sdd-forge-mcp-tools.v1.schema.json"), "utf-8"),
  ) as {
    $id: string;
    $defs: {
      evidenceDeepVerifyData: {
        additionalProperties: boolean;
        required: string[];
        properties: Record<string, Record<string, unknown>>;
      };
    };
  };

  assert.equal(schema.$id, "https://sdd-forge.dev/contracts/sdd-forge-mcp-tools.v1.schema.json");
  const def = schema.$defs.evidenceDeepVerifyData;
  assert.equal(def.additionalProperties, false);
  assert.deepEqual(def.required, [
    "kind",
    "feature",
    "taskId",
    "verdict",
    "artifacts",
    "invariants",
    "signature",
    "hostRequiredChecks",
    "failures",
  ]);

  const property = def.properties.hostRequiredChecks;
  assert.ok(property, "hostRequiredChecks property is absent from the schema");
  assert.equal(property.type, "array");
  const items = property.items as {
    type: string;
    additionalProperties: boolean;
    required: string[];
    properties: { check: { enum: string[] }; verified: { const: unknown }; note: { type: string } };
  };
  assert.equal(items.type, "object");
  assert.equal(items.additionalProperties, false);
  assert.deepEqual(items.required, ["check", "verified", "note"]);
  assert.deepEqual(items.properties.check.enum, [...HOST_REQUIRED_CHECK_IDS]);
  assert.equal(items.properties.verified.const, false);
  assert.equal(items.properties.note.type, "string");
});

test("TEST-009 leg (AC-009): an ok deep-verify envelope omitting hostRequiredChecks FAILS ajv validation", () => {
  const fx = seedDeepVerifyRepo("dv-host-checks-ajv-omission");
  try {
    const envelope = evidenceDeepVerify(fx.tempRoot.root, fx.feature, fx.taskId);
    const validate = getEnvelopeValidator();
    assert.equal(validate(envelope), true, "the real response must validate");

    const stripped = JSON.parse(JSON.stringify(envelope)) as {
      data: Record<string, unknown>;
    };
    delete stripped.data.hostRequiredChecks;
    assert.equal(
      validate(stripped),
      false,
      "an envelope omitting hostRequiredChecks must FAIL validation once the field is required",
    );
  } finally {
    fx.tempRoot.cleanup();
  }
});

test("TEST-016 (AC-016): the schema description is verbatim requirements.md's CONFIRMED literal", () => {
  const repoRoot = findSddForgeRepoRoot();

  // The single normative source (tasks.md Global Constraints; design.md's own
  // NORMATIVE-SOURCE note): requirements.md's Field Definitions blockquote for
  // `hostRequiredChecks`. Extracted here rather than re-typed, so this
  // assertion cannot drift from the spec by a transcription error.
  const requirementsLines = readFileSync(
    join(repoRoot, "specs", "epic-136-phase4-mcp", "requirements.md"),
    "utf-8",
  ).split("\n");
  const anchor = requirementsLines.findIndex((line) =>
    line.includes("`hostRequiredChecks` (REQ-002)"),
  );
  assert.ok(anchor >= 0, "requirements.md Field Definitions entry for hostRequiredChecks not found");
  let cursor = anchor;
  while (cursor < requirementsLines.length && !/^\s*>\s/.test(requirementsLines[cursor] ?? "")) {
    cursor += 1;
  }
  const quoted: string[] = [];
  while (cursor < requirementsLines.length && /^\s*>\s?/.test(requirementsLines[cursor] ?? "")) {
    quoted.push((requirementsLines[cursor] ?? "").replace(/^\s*>\s?/, "").trim());
    cursor += 1;
  }
  const confirmedLiteral = quoted.join(" ");

  // Guard against a vacuous `includes("")` pass if the extraction ever breaks.
  assert.ok(quoted.length >= 10, `expected a multi-line blockquote, got ${quoted.length} lines`);
  assert.ok(confirmedLiteral.length > 500, "extracted literal is implausibly short");
  assert.ok(
    confirmedLiteral.startsWith("Checks this tool cannot verify in-process:"),
    "extracted literal does not start with the CONFIRMED opening sentence",
  );
  assert.ok(
    confirmedLiteral.endsWith("Never affects verdict."),
    "extracted literal does not end with the CONFIRMED closing sentence",
  );

  const schema = JSON.parse(
    readFileSync(join(repoRoot, "contracts", "sdd-forge-mcp-tools.v1.schema.json"), "utf-8"),
  ) as {
    $defs: {
      evidenceDeepVerifyData: {
        properties: { hostRequiredChecks?: { description?: string } };
      };
    };
  };
  const description =
    schema.$defs.evidenceDeepVerifyData.properties.hostRequiredChecks?.description;
  assert.equal(
    typeof description,
    "string",
    "$defs.evidenceDeepVerifyData.properties.hostRequiredChecks.description is absent",
  );
  assert.ok(
    (description ?? "").includes(confirmedLiteral),
    "the schema description does not contain requirements.md's CONFIRMED literal verbatim\n" +
      `--- expected (requirements.md) ---\n${confirmedLiteral}\n` +
      `--- actual (schema) ---\n${description}`,
  );

  // The policy sentence issue #131 asked for, named explicitly so a silent
  // truncation of the literal is not merely a length change.
  assert.ok(
    (description ?? "").includes(
      "Policy: for risk: critical tasks, both checks MUST be separately confirmed via host-side verification",
    ),
  );
  assert.ok((description ?? "").includes("Never affects verdict."));
});

test("AC-015 additivity: five retained evidence readers return their expected v1 contract kinds", () => {
  const tempRoot = seedDemoFixture("dv-conformance-existing");
  try {
    const root = tempRoot.root;
    const results = [
      ["evidence-bundle", evidenceGetBundle(root, "demo", "T-001")],
      ["evidence-paths", evidenceValidatePaths(root, "demo", "T-001")],
      ["evidence-missing", evidenceFindMissing(root, "demo", "T-001")],
      ["contract-checks", evidenceSummarizeContractChecks(root, "demo", "T-001")],
      ["traceability-comparison", evidenceCompareToTraceability(root, "demo")],
    ] as const;
    for (const [kind, envelope] of results) {
      assert.equal(envelope.ok, true, kind);
      assert.equal(envelope.data.kind, kind);
      assertConforms(envelope, kind);
    }
  } finally {
    tempRoot.cleanup();
  }
});
