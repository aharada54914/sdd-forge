import { err, ok, type Result } from "./envelope.js";
import { guardedRead, hasProjectContext } from "./path-guard.js";
import type { SddRoot } from "./root.js";

export type WorkflowProfile = "full" | "lite";

/** Legacy profile selection only. Never infer Lite from missing Full evidence. */
export function workflowProfile(root: SddRoot): Result<WorkflowProfile> {
  const agents = guardedRead(root, "AGENTS.md");
  if (!agents.ok) return agents.error.code === "not-found" ? ok("full") : agents;
  if ((agents.data.contents.match(/^## Project Settings\s*$/gm) ?? []).length > 1) {
    return err("cannot-determine", "Multiple Project Settings sections make profile selection ambiguous.", { rule: "profile-invalid" });
  }
  const settings = /^## Project Settings\s*\r?\n([\s\S]*?)(?=^## |$(?![\s\S]))/m.exec(agents.data.contents)?.[1] ?? "";
  const profiles = [...settings.matchAll(/^spec_profile:\s*(\S+)\s*$/gm)].map(match => match[1]);
  if (profiles.length > 1 || (profiles.length === 1 && !["lite", "full"].includes(profiles[0] ?? ""))) {
    return err("cannot-determine", "Project Settings has an invalid or ambiguous spec_profile.", { rule: "profile-invalid" });
  }
  if (profiles[0] !== "lite") return ok("full");
  if (hasProjectContext(root)) {
    return err("cannot-determine", "Project Context is present; its approved profile must be resolved before using the legacy Lite read model.", { rule: "project-context-profile-unverified" });
  }
  return ok("lite");
}
