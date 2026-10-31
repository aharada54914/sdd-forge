# Codex generated project skill: bounded native observation

Source commit: b3b997ed8af44d4d8f1fc94d07e94ee006f32f81. Protocol was written before the one native model invocation. Source hashes are retained in protocol.json/result.json. Existing verify-codex profile and configured model were used without a model override, after the user completed official login.

Observed: native discovery of the product-generated wrapper; model reads wrapper and canonical skill; exactly one documented runner execution; owner observation project-verification-observation/v3 with passed/exit 0; model reads owner JSON/stdout and accurately reports native-v3-owner-check-ok. Native exec exit 0 in 10.96 seconds. Removing the projection made the evaluated skill absent, and the temporary fixture was removed.

The independent collector subsequently refused current-input validation with runtime-changed. The only differing runtime metadata field was variables_sha256; runtime_path and toolchain matched. Environment values were not logged. This separate cross-environment projection is NOT a pass. No separate validator command ran inside the native model turn.

Evidence.zip contains exact generated fixture files and owner reports, selected actual completed command/answer events, and discovery records filtered to the evaluated skill. Selection metadata pins the original transcript/discovery bytes; unrelated installed skill metadata and event/session IDs are omitted. Commands, their outputs and model answer are retained without rewriting. Earlier failed authentication attempts remain separate and are not reclassified.

Excluded: authentication files, profile/config files, app-server debug logs, environment values, unrelated skill listings. A bounded pattern scan checked private keys, bearer tokens, common API/GitHub token formats, JWTs and email addresses without printing candidate values. This is not an assertion that arbitrary secret formats can be detected automatically.

Scope: this synthetic fixture establishes the Codex discovery/invocation/result-reading/removal path, not Claude or Copilot invocation, full app acceptance, or automatic approval. This packet is historical evidence, not a command to rerun against its now-deleted temporary path.

archive-index.json pins all retained files except itself and SHA256SUMS; it also lists ZIP member sizes/digests. SHA256SUMS pins the index and README as well as the remaining top-level packet files; it intentionally excludes itself.
