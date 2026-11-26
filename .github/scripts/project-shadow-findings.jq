# Validate both complete scanner documents before projecting finding locations.
def sha: type == "string" and test("^[a-f0-9]{40}\\z");
def seconds: type == "number" and . >= 0 and floor == .;
def line: type == "number" and . >= 1 and floor == .;
def rule: type == "string" and test("^[a-zA-Z0-9_.-]+\\z");
def filepath:
  type == "string" and index("\u0000") == null
  and (ltrimstr("./") | length > 0 and (split("/") | all(.[]; . != "" and . != "." and . != "..")));

def optional_column($key):
  if (has($key) | not) then {}
  elif (.[$key] | line) then {column: .[$key]}
  else error("invalid finding column") end;

# v8.30.1 path-only rules leave all coordinates zero. Full redaction inserts
# REDACTED between every character of Match when the captured secret is empty.
def path_only:
  [.StartLine, .EndLine, .StartColumn, .EndColumn] == [0, 0, 0, 0]
  and (("file detected: " + .File) as $message |
    .Match == $message or .Match == ("REDACTED" + ($message | split("") | join("REDACTED")) + "REDACTED"));

def leak_location:
  if type != "object" or (.Commit | sha | not) or (.RuleID | rule | not) or (.File | filepath | not)
  then error("invalid Gitleaks finding location") end
  | {rule: .RuleID, commit: .Commit, path: .File, line: .StartLine}
    + (if (.StartLine | line) then optional_column("StartColumn")
       elif path_only then {location: "file"}
       else error("invalid Gitleaks position") end);

def sast_location:
  if type == "object" and (.check_id | rule) and (.path | filepath)
      and (.start | type == "object") and (.start.line | line)
  then {rule: .check_id, path, line: .start.line} + (.start | optional_column("col"))
  else error("invalid Semgrep finding location") end;

if (($base | sha) and ($head | sha) and ($gitleaks_seconds | seconds) and ($semgrep_seconds | seconds) | not)
then error("invalid scan revision or duration") end
| if ($leaks | length) != 1 or ($leaks[0] | type) != "array"
  then error("expected one Gitleaks findings array") end
| if (($status == 0 and ($leaks[0] | length) == 0) or ($status == 42 and ($leaks[0] | length) > 0) | not)
  then error("Gitleaks status disagrees with findings count") end
| if ($sast | length) != 1 or ($sast[0] | type) != "object"
    or ($sast[0].results | type) != "array" or $sast[0].errors != []
  then error("expected one completed Semgrep report without errors") end
| {base: $base, head: $head, gitleaks_seconds: $gitleaks_seconds, semgrep_seconds: $semgrep_seconds,
   gitleaks: ($leaks[0] | map(leak_location)), semgrep: ($sast[0].results | map(sast_location))}
