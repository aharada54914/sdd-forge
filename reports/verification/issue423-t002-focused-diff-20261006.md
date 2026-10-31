# Issue 423 T-002 focused tracked diff — 2026-10-06

Base: `3b5c38f08c98f8740d69a7c24ff7ff4a06c56ed9` (owner checkout HEAD). This is the exact output of the command below at preparation time. Untracked artifacts remain separately hash-pinned in the quality input declaration; this diff is not a verdict.

`/usr/bin/git diff --binary HEAD -- plugins/sdd-quality-loop/scripts/validate-capability-registry.py plugins/sdd-quality-loop/scripts/registry_discovery.py specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py install.sh tests/install.tests.sh`

```diff
diff --git a/install.sh b/install.sh
index de98b494..819dc762 100755
--- a/install.sh
+++ b/install.sh
@@ -707,7 +707,7 @@ rollback() {
     fi
 }
 
-trap 'rc=$?; rollback; cleanup; exit $rc' EXIT
+trap 'rc=$?; if [[ $rc -ne 0 ]]; then rollback; fi; cleanup; exit $rc' EXIT
 
 # ---------------------------------------------------------------------------
 # Resolve source
diff --git a/plugins/sdd-quality-loop/scripts/registry_discovery.py b/plugins/sdd-quality-loop/scripts/registry_discovery.py
index 4d9fce5a..d14cda76 100755
--- a/plugins/sdd-quality-loop/scripts/registry_discovery.py
+++ b/plugins/sdd-quality-loop/scripts/registry_discovery.py
@@ -25,11 +25,11 @@ stale/absent fallback):
      merely because the first one it found had a bad version, since doing
      so would itself be a silent, undocumented second resolution path.
 """
-import hashlib
 import json
 import subprocess
 import sys
 from pathlib import Path
+from typing import Any, List, Optional, Tuple
 
 # The exact $id this Epic's own capability-registry.schema.json declares
 # (T-001). The per-artifact version check for the schema file confirms the
@@ -89,16 +89,16 @@ def _git_root_path(filename: str) -> "Path | None":
     return root / "contracts" / filename
 
 
-def _load_json(path: Path):
+def _load_json(path: Path) -> Any:
     with open(path, "r", encoding="utf-8") as fh:
         return json.load(fh)
 
 
-def check_capability_registry(doc) -> bool:
+def check_capability_registry(doc: Any) -> bool:
     return isinstance(doc, dict) and doc.get("schema") == "capability-registry/v1"
 
 
-def check_capability_registry_schema(doc) -> bool:
+def check_capability_registry_schema(doc: Any) -> bool:
     return (
         isinstance(doc, dict)
         and "$schema" in doc
@@ -106,7 +106,7 @@ def check_capability_registry_schema(doc) -> bool:
     )
 
 
-def check_lite_upgrade_reason_catalog(doc) -> bool:
+def check_lite_upgrade_reason_catalog(doc: Any) -> bool:
     return isinstance(doc, dict) and doc.get("schema") == "lite-upgrade-reason-catalog/v1"
 
 
@@ -117,7 +117,7 @@ VERSION_CHECKS = {
 }
 
 
-def _verify(path: Path, filename: str):
+def _verify(path: Path, filename: str) -> Tuple[bool, str]:
     """Returns (ok: bool, detail: str)."""
     check = VERSION_CHECKS.get(filename)
     if check is None:
@@ -171,7 +171,7 @@ def discover_artifact(filename: str) -> Path:
     )
 
 
-def main(argv=None) -> int:
+def main(argv: Optional[List[str]] = None) -> int:
     """CLI mode for this task's own test suite: `registry_discovery.py
     <filename>` resolves and prints the resolved path on success (exit 0),
     or prints the fail-closed diagnostic on stderr (exit 1)."""
diff --git a/plugins/sdd-quality-loop/scripts/validate-capability-registry.py b/plugins/sdd-quality-loop/scripts/validate-capability-registry.py
index a0c09c11..a4ca68d6 100755
--- a/plugins/sdd-quality-loop/scripts/validate-capability-registry.py
+++ b/plugins/sdd-quality-loop/scripts/validate-capability-registry.py
@@ -23,12 +23,13 @@ import argparse
 import json
 import sys
 from pathlib import Path
+from typing import Any, Dict, List, Optional, Tuple
 
 sys.path.insert(0, str(Path(__file__).resolve().parent))
 from registry_discovery import discover_artifact, resolve_git_root, DiscoveryError  # noqa: E402
 
 
-def _emit_stdout(line):
+def _emit_stdout(line: str) -> None:
     """Write one stdout line byte-deterministically (LF on every platform).
 
     Windows text-mode stdout translates \n to \r\n, which breaks the
@@ -47,12 +48,12 @@ def _script_dir() -> Path:
     return Path(__file__).resolve().parent
 
 
-def _load_json(path: Path):
+def _load_json(path: Path) -> Any:
     with open(path, "r", encoding="utf-8") as fh:
         return json.load(fh)
 
 
-def check_a_gate_id_uniqueness(registry, diagnostics):
+def check_a_gate_id_uniqueness(registry: Dict[str, Any], diagnostics: List[str]) -> bool:
     ids = [g.get("id") for g in registry.get("gates", []) if isinstance(g, dict)]
     seen, dups = set(), set()
     for i in ids:
@@ -64,7 +65,7 @@ def check_a_gate_id_uniqueness(registry, diagnostics):
     return not dups
 
 
-def check_i_capability_id_uniqueness(registry, diagnostics):
+def check_i_capability_id_uniqueness(registry: Dict[str, Any], diagnostics: List[str]) -> bool:
     ids = [c.get("id") for c in registry.get("capabilities", []) if isinstance(c, dict)]
     seen, dups = set(), set()
     for i in ids:
@@ -76,7 +77,9 @@ def check_i_capability_id_uniqueness(registry, diagnostics):
     return not dups
 
 
-def check_b_stage_completeness(registry, repo_root, diagnostics):
+def check_b_stage_completeness(
+    registry: Dict[str, Any], repo_root: Path, diagnostics: List[str]
+) -> bool:
     ok = True
     for g in registry.get("gates", []):
         if not isinstance(g, dict) or g.get("stage") != "implementation":
@@ -93,7 +96,7 @@ def check_b_stage_completeness(registry, repo_root, diagnostics):
     return ok
 
 
-def check_e_stage_missing(registry, diagnostics):
+def check_e_stage_missing(registry: Dict[str, Any], diagnostics: List[str]) -> bool:
     """Defense-in-depth: independently re-assert no gates[] entry lacks
     `stage`, exercised against a fixture that bypasses schema validation
     (this validator never invokes the JSON Schema itself, so this
@@ -109,14 +112,14 @@ def check_e_stage_missing(registry, diagnostics):
     return ok
 
 
-def check_d_no_pack_owned_gates(repo_root, diagnostics):
+def check_d_no_pack_owned_gates(repo_root: Path, diagnostics: List[str]) -> bool:
     matches = sorted(repo_root.glob("capability-packs/*/gates.yaml"))
     for m in matches:
         diagnostics.append(f"registry: pack-owns-gate-definition: {m.relative_to(repo_root).as_posix()}")
     return not matches
 
 
-def check_f_referential_integrity(registry, diagnostics):
+def check_f_referential_integrity(registry: Dict[str, Any], diagnostics: List[str]) -> bool:
     gate_ids = {g.get("id") for g in registry.get("gates", []) if isinstance(g, dict)}
     ok = True
     for c in registry.get("capabilities", []):
@@ -129,25 +132,28 @@ def check_f_referential_integrity(registry, diagnostics):
     return ok
 
 
-def _load_provider_terms(repo_root):
+def _load_provider_terms(repo_root: Path) -> List[str]:
     path = repo_root / PROVIDER_TERMS_REL
     doc = _load_json(path)
-    terms = []
+    terms: List[str] = []
     for category_terms in (doc.get("categories") or {}).values():
         terms.extend(category_terms)
     return terms
 
 
-def check_g_provider_name_contamination(registry, provider_terms, diagnostics):
+def check_g_provider_name_contamination(
+    registry: Dict[str, Any], provider_terms: List[str], diagnostics: List[str]
+) -> bool:
     ok = True
     terms_lower = [t.lower() for t in provider_terms]
-    findings = []
+    findings: List[Tuple[str, str]] = []
 
-    def walk(obj, path):
+    def walk(obj: object, path: str) -> None:
         if isinstance(obj, dict):
             for k, v in obj.items():
                 if k in ("credentials", "state_authority"):
                     findings.append((f"{path}.{k}", k))
+                walk(k, f"{path}.{k}")
                 walk(v, f"{path}.{k}")
         elif isinstance(obj, list):
             for idx, v in enumerate(obj):
@@ -165,7 +171,7 @@ def check_g_provider_name_contamination(registry, provider_terms, diagnostics):
     return ok
 
 
-def check_h_catalog_conformance(registry, diagnostics):
+def check_h_catalog_conformance(registry: Dict[str, Any], diagnostics: List[str]) -> bool:
     try:
         catalog_path = discover_artifact("lite-upgrade-reason-catalog.json")
     except DiscoveryError as exc:
@@ -191,7 +197,9 @@ def check_h_catalog_conformance(registry, diagnostics):
     return ok
 
 
-def check_c_unregistered_script(registry, repo_root, diagnostics):
+def check_c_unregistered_script(
+    registry: Dict[str, Any], repo_root: Path, diagnostics: List[str]
+) -> bool:
     """Gate implementation identity (AC-016/AC-017): every check-*.py
     master directly under the sole scan root is referenced by exactly one
     gates[].implementation_ref (symlink-resolved before comparison). A
@@ -208,13 +216,13 @@ def check_c_unregistered_script(registry, repo_root, diagnostics):
     scan_root = repo_root / SCAN_ROOT_REL
     ok = True
 
-    masters = {}  # real-path str -> original Path (for reporting)
+    masters: Dict[str, Path] = {}  # real-path str -> original Path (for reporting)
     if scan_root.is_dir():
         for entry in sorted(scan_root.iterdir()):
             if entry.is_file() and entry.name.startswith("check-") and entry.suffix == ".py":
                 masters[str(entry.resolve())] = entry
 
-    registered_by_real = {}  # real-path str -> [gate id, ...] referencing it
+    registered_by_real: Dict[str, List[str]] = {}  # real-path str -> [gate id, ...] referencing it
     for g in registry.get("gates", []):
         if not isinstance(g, dict):
             continue
@@ -241,8 +249,8 @@ def check_c_unregistered_script(registry, repo_root, diagnostics):
     return ok
 
 
-def run(registry_path: str, repo_root: Path):
-    diagnostics = []
+def run(registry_path: str, repo_root: Path) -> List[str]:
+    diagnostics: List[str] = []
     try:
         registry = _load_json(Path(registry_path))
     except (OSError, json.JSONDecodeError) as exc:
@@ -268,7 +276,7 @@ def run(registry_path: str, repo_root: Path):
     return diagnostics
 
 
-def main(argv=None):
+def main(argv: Optional[List[str]] = None) -> int:
     argv = sys.argv[1:] if argv is None else list(argv)
     parser = argparse.ArgumentParser(description=__doc__)
     parser.add_argument("--registry", required=True, help="path to the capability-registry.json instance to validate")
@@ -288,7 +296,7 @@ def main(argv=None):
     args = parser.parse_args(argv)
 
     if args.repo_root is not None:
-        repo_root = Path(args.repo_root).resolve()
+        repo_root: Optional[Path] = Path(args.repo_root).resolve()
     else:
         repo_root = resolve_git_root()
     if repo_root is None:
diff --git a/specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py b/specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py
index 2c31d1d1..064d801e 100644
--- a/specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py
+++ b/specs/sdd-domain-multitarget/verification/T-002/contract-boundaries.tests.py
@@ -319,6 +319,20 @@ class CapabilityRegistryProviderNeutralityTests(unittest.TestCase):
                         self.assertTrue(any("provider-name-detected" in d and
                                             f".{field}" in d for d in diagnostics), diagnostics)
 
+    def test_provider_keys_in_predicates_are_rejected(self):
+        for boundary in ("trigger", "conditional"):
+            for term in self.provider_terms:
+                for key in (term, f"prefix-{term.upper()}-suffix"):
+                    for value in ({key: True}, {"metadata": {key: False}},
+                                  {"items": [{key: None}]}):
+                        with self.subTest(boundary=boundary, key=key, value=value):
+                            diagnostics = []
+                            self.assertFalse(self.registry_mod.check_g_provider_name_contamination(
+                                self._predicate_registry(value, boundary),
+                                self.provider_terms, diagnostics), diagnostics)
+                            self.assertTrue(any("provider-name-detected" in d and
+                                                f".{key}" in d for d in diagnostics), diagnostics)
+
     def test_provider_neutral_nested_predicate_values_are_accepted(self):
         value = {"metadata": {"name": "durable_workflow", "items": [
             {"replayable": True}, {"credentials_hint": False},
diff --git a/tests/install.tests.sh b/tests/install.tests.sh
index 491a30df..0344cbff 100755
--- a/tests/install.tests.sh
+++ b/tests/install.tests.sh
@@ -377,6 +377,9 @@ invoke_installer_scenario() {
         if [[ $installer_failed -eq 0 ]]; then
             fail "installer should have failed for pattern '${fail_pattern}'"
         fi
+        if [[ "$out" != *"Note: registration failed"* ]]; then
+            fail "real registration failure did not report the retained install"
+        fi
         if [[ ! -f "${install_root}/plugins/sdd-bootstrap/.codex-plugin/plugin.json" ]]; then
             fail "registration failure did not leave the newly placed tree in the install root (pattern '${fail_pattern}')"
         fi
@@ -934,6 +937,8 @@ _m_log="${_m_root}/commands.log"
 _m_lock_dir="${_m_install}.sdd-install.lock"
 _m_orig_path="$PATH"
 _m_orig_codex_home="${SDD_CODEX_HOME:-}"
+_m_stdout="${_m_root}/stdout.log"
+_m_stderr="${_m_root}/stderr.log"
 make_fake_commands "$_m_bin" "$_m_log"
 export PATH="${_m_bin}:${_m_orig_path}"
 export SDD_CODEX_HOME="${_m_root}/codex-home"
@@ -944,7 +949,7 @@ bash "$INSTALLER" \
     --target FilesOnly \
     --skip-plugin-install \
     --skip-agent-install \
-    2>/dev/null || _m_failed=1
+    >"$_m_stdout" 2>"$_m_stderr" || _m_failed=1
 export PATH="$_m_orig_path"
 if [[ -z "$_m_orig_codex_home" ]]; then
     unset SDD_CODEX_HOME
@@ -956,6 +961,14 @@ if [[ $_m_failed -ne 0 ]]; then
     fail "lock scenario (m): successful install failed unexpectedly"
     _m_ok=0
 fi
+if ! grep -Fq 'Plugin registration was skipped because --target=FilesOnly.' "$_m_stdout"; then
+    fail "lock scenario (m): FilesOnly skip message missing"
+    _m_ok=0
+fi
+if grep -Fq 'registration failed' "$_m_stderr"; then
+    fail "lock scenario (m): successful FilesOnly install reported registration failure"
+    _m_ok=0
+fi
 if [[ -d "$_m_lock_dir" ]]; then
     fail "lock scenario (m): lock dir was not cleaned up after successful install"
     _m_ok=0
```
