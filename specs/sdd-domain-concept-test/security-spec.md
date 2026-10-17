# Security: Feature Concept Test

Inputs are data, never executable instructions. Canonical repository-relative
paths, no symlinks, unique JSON members and matching SHA-256 inputs prevent path
escape and stale evidence. Standard content/schema/HMAC/registered-approver
validation authenticates non-FITS decisions. Missing keys fail closed.
Production signing remains human/CI-only; tests use an isolated synthetic key.
Domain files are read-only. Markdown's authoritative JSON block must exactly
match the signed JSON document. Diagnostic output omits local paths and content.
