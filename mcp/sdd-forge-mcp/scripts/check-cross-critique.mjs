#!/usr/bin/env node
// Read-only annex validation. Draft-07 cannot compare two sibling numbers.
import { readFileSync } from "node:fs";
import { Ajv } from "ajv";
import addFormats from "ajv-formats";

function check() {
  if (process.argv.length !== 3) return { status: "invalid", reason: "expected-one-annex-path" };
  let annex;
  try { annex = JSON.parse(readFileSync(process.argv[2], "utf8")); }
  catch { return { status: "invalid", reason: "cannot-read-json" }; }
  const schema = JSON.parse(readFileSync(new URL("../../../contracts/cross-critique.v1.schema.json", import.meta.url), "utf8"));
  const ajv = new Ajv({ strict: false });
  addFormats(ajv, ["date-time"]);
  if (!ajv.compile(schema)(annex)) return { status: "invalid", reason: "schema-invalid" };
  for (const [index, verdict] of annex.verdicts.entries()) {
    for (const [citationIndex, citation] of (verdict.basis.citations ?? []).entries()) {
      if (citation.line_end < citation.line_start) {
        return { status: "invalid", reason: "citation-range-reversed", verdict: index, citation: citationIndex };
      }
    }
  }
  return { status: "valid" };
}

let result;
try { result = check(); }
catch { result = { status: "invalid", reason: "validator-unavailable" }; }
process.stdout.write(JSON.stringify(result) + "\n");
process.exitCode = result.status === "valid" ? 0 : 1;
