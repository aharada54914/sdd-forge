import assert from "node:assert/strict";
import type { Client } from "@modelcontextprotocol/client";
import type { Result } from "../../src/envelope.js";
import type { FeatureStateData, ProjectOverviewData } from "../../src/tools/v2.js";
import { getV2DefValidator } from "../core-tools/test-helpers.js";

interface ResourceData {
  sdd_project_overview_data: ProjectOverviewData;
  sdd_feature_state_data: FeatureStateData;
}

/** Check the wire representation as well as the named v2 payload schema. */
export async function readResource<K extends keyof ResourceData>(
  client: Client, uri: string, definition: K,
): Promise<Result<ResourceData[K]>> {
  const { contents } = await client.readResource({ uri });
  assert.equal(contents.length, 1);
  const [content] = contents;
  assert.ok(content && "text" in content);
  assert.equal(content.uri, uri);
  assert.equal(content.mimeType, "application/json");

  const envelope = JSON.parse(content.text) as Result<ResourceData[K]>;
  if (envelope.ok === true) {
    const validate = getV2DefValidator(definition);
    assert.ok(validate(envelope.data), JSON.stringify(validate.errors));
  } else {
    const validate = getV2DefValidator("errorEnvelope");
    assert.ok(validate(envelope), JSON.stringify(validate.errors));
  }
  return envelope;
}
