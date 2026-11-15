import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { writeFileSync, symlinkSync } from "node:fs";
import { join } from "node:path";
import { makeTempSddRoot, writeFile } from "./test-helpers.js";
import { guardedArtifactMatches, guardedRead } from "../src/path-guard.js";
import { parseTaskState } from "../src/parsers/tasks.js";
import { getNextSddCommand } from "../src/next-command.js";
import { workflowProfile } from "../src/profile.js";

function liteFixture() {
  const f = makeTempSddRoot("lite-read-model");
  writeFile(f.dir,"AGENTS.md","# Project\n## Project Settings\nspec_profile: lite\n");
  writeFile(f.dir,"specs/example/requirements.md","# Requirements\n");
  writeFile(f.dir,"specs/example/design.md","# Design\n");
  writeFile(f.dir,"specs/example/tasks.md","## T-001 Example\nApproval: Approved\nStatus: Done\n");
  writeFile(f.dir,"reports/implementation/T-001.md","Task ID: T-001\n");
  writeFile(f.dir,"reports/quality-gate/T-001.md","Task ID: T-001\nVERDICT: PASS\n");
  return f;
}

test("legacy Lite Done requires real reports but no Full contract/review headers", () => {
 const f=liteFixture();try {
  const state=parseTaskState(f.root,"example","specs/example/tasks.md");
  assert.ok(state.ok);assert.equal(state.data.verdict,"pass");
  const next=getNextSddCommand(f.root,"example");assert.ok(next.ok);assert.equal(next.data.phase,"done");
  writeFile(f.dir,"reports/quality-gate/T-001.md","Task ID: T-001\nVERDICT: FAIL\n");
  const invalid=parseTaskState(f.root,"example","specs/example/tasks.md");assert.ok(invalid.ok);assert.equal(invalid.data.verdict,"fail");
  assert.equal(getNextSddCommand(f.root,"example").ok,false);
 } finally {f.cleanup();}
});

test("Lite implementation and quality routes use Lite commands; missing implementation fails", () => {
 const f=liteFixture();try {
  for(const [status,command] of [["Planned","/sdd-ship:ship --lite"],["Implementation Complete","/sdd-lite:lite-gate"]]) {
   writeFile(f.dir,"specs/example/tasks.md",`## T-001 Example\nApproval: Approved\nStatus: ${status}\n`);
   const next=getNextSddCommand(f.root,"example");assert.ok(next.ok);assert.ok(next.data.nextCommand.startsWith(command!));
  }
  writeFile(f.dir,"reports/implementation/T-001.md","Task ID: T-002\n");
  assert.equal(getNextSddCommand(f.root,"example").ok,false);
 }finally{f.cleanup();}
});

test("Lite fallback never bypasses present Project Context; ambiguous profile fails",()=>{
 const f=liteFixture();try{
  writeFile(f.dir,"sdd/project-context.yaml","spec_profile: full\n");
  assert.equal(workflowProfile(f.root).ok,false);
  writeFile(f.dir,"AGENTS.md","## Project Settings\nspec_profile: lite\nspec_profile: full\n");
  assert.equal(workflowProfile(f.root).ok,false);
 }finally{f.cleanup();}
});

test("artifact byte hashing supports non-UTF8 files outside content allowlist without exposing content",()=>{
 const f=makeTempSddRoot("artifact-integrity");try{
  const bytes=Buffer.from([0,255,254,128,10]);
  const file=writeFile(f.dir,"evidence/screenshot.bin","");writeFileSync(file,bytes);
  const hash=createHash("sha256").update(bytes).digest("hex");
  assert.deepEqual(guardedArtifactMatches(f.root,"evidence/screenshot.bin",hash),{ok:true,data:true});
  assert.equal(guardedRead(f.root,"evidence/screenshot.bin").ok,false);
  assert.deepEqual(guardedArtifactMatches(f.root,"evidence/screenshot.bin","invalid"),{ok:true,data:false});
  writeFile(f.dir,"evidence/large.bin","x".repeat(2*1024*1024+1));
  const oversized=guardedArtifactMatches(f.root,"evidence/large.bin",hash);
  assert.ok(!oversized.ok);assert.equal(oversized.error.code,"too-large");
  assert.deepEqual(guardedArtifactMatches(f.root,"evidence/screenshot.bin","0".repeat(64)),{ok:true,data:false});
  for(const path of ["../escape","/etc/passwd","evidence/../escape","evidence\\escape"])
   assert.equal(guardedArtifactMatches(f.root,path,hash).ok,false);
  writeFile(f.dir,"evidence/.env","secret");
  assert.equal(guardedArtifactMatches(f.root,"evidence/.env",hash).ok,false);
  symlinkSync("/etc/passwd",join(f.dir,"evidence/outside"));
  assert.equal(guardedArtifactMatches(f.root,"evidence/outside",hash).ok,false);
  symlinkSync(join(f.dir,"evidence/.env"),join(f.dir,"evidence/alias"));
  assert.equal(guardedArtifactMatches(f.root,"evidence/alias",hash).ok,false);
 }finally{f.cleanup();}
});


test("Lite declaration cannot weaken high/critical tasks or choose between duplicate settings",()=>{
 const f=liteFixture();try{
  for(const risk of ["high","critical"]) {
   writeFile(f.dir,"specs/example/tasks.md",`## T-001 Example\nApproval: Approved\nStatus: Done\nRisk: ${risk}\n`);
   const state=parseTaskState(f.root,"example","specs/example/tasks.md");assert.ok(state.ok);assert.equal(state.data.verdict,"fail");
   assert.equal(getNextSddCommand(f.root,"example").ok,false);
  }
  writeFile(f.dir,"AGENTS.md","## Project Settings\nspec_profile: lite\n## Project Settings\nspec_profile: full\n");
  assert.equal(workflowProfile(f.root).ok,false);
 }finally{f.cleanup();}
});
