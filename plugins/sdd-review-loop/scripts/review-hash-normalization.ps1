# Shared status-line hash recipe for the impl and task prechecks.
# Stage-specific field selection and task-plan normalization remain in callers.
function Get-ReviewedHash([string]$Path, [string]$StatusField, [string]$ReviewedStatus) {
  $content = [IO.File]::ReadAllText($Path)
  $normalized = [Text.RegularExpressions.Regex]::Replace(
    $content,
    "(?m)^$([Text.RegularExpressions.Regex]::Escape($StatusField)):[^\r\n]*(\r?)$",
    "${StatusField}: $ReviewedStatus`$1"
  )
  return [Convert]::ToHexString(
    [Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($normalized))
  ).ToLower()
}
