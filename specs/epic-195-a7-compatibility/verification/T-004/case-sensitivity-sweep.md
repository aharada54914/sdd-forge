# T-004 Bash-to-PowerShell case-sensitivity sweep

Date: 2026-08-12

## Operator layer

Every PowerShell string comparison corresponding to Bash `[[ ... == ... ]]`,
exact `awk`/`grep`, `jq ==`, or byte comparison uses a `-c` operator:

- exact string equality/inequality: `-ceq` / `-cne`;
- regular-expression matching: `-cmatch` / `-cnotmatch`;
- line-ending replacement and field splitting: `-creplace` / `-csplit`.

The remaining plain `-eq` / `-ne` sites compare integers, counts, exit codes,
or `$null`; case has no semantic role. The only intentionally case-insensitive
comparison is the reserved-vocabulary absence scan, which mirrors Bash
`grep -i` and uses `StringComparison.OrdinalIgnoreCase` explicitly.

Negative evidence: both twins derive the shipped F1 state, create a mis-cased
copy, execute the real envelope validator, and require rejection under
`operator layer rejects a mis-cased shipped state`. The
`operator-case-sensitivity` mutation changes both implementations back to
case-insensitive equality; both are killed in `mutation-proof.log`.

## Cmdlet and language-feature layer

- Template dispatch uses `switch -CaseSensitive`.
- Every `Sort-Object` uses `-CaseSensitive`; arrays use
  `StringComparer.Ordinal`.
- String methods use `StringComparison.Ordinal`, except the documented
  reserved-vocabulary scan above.
- Every `[regex]::Match`, `[regex]::Matches`, and `[regex]::Replace` call names
  `RegexOptions.CultureInvariant` and does not enable `IgnoreCase`.
- The implementation uses no `Select-String`, `Get-ChildItem -Filter` /
  `-Include` / `-Exclude`, wildcard switch, or raw default-culture sort.

Negative evidence: both twins copy the shipped bootstrap skill, mis-case its
real Required Outputs anchor, execute their real extraction path, and require
rejection under `language matching layer rejects a mis-cased shipped anchor`.
The `language-case-sensitivity` mutation makes both extractors insensitive;
both are killed in `mutation-proof.log`.

## Result

Focused Bash and PowerShell runs each pass 40 assertions. The final mutation
run records 116 killed and zero survived, including both layer-specific
mis-cased negatives and the benign corpus-array reorder control.
