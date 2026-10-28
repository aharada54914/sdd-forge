# Research evidence contract

`contracts/research-evidence.schema.json` and the matching quality-plugin copy
define source, claim, citation and storage metadata for
`research-evidence/v1`. Use the installed quality plugin's validator:

```sh
python3 "<installed-root>/plugins/sdd-quality-loop/scripts/validate-research-evidence.py" \
  --file specs/FEATURE/research/records/research-evidence.json --repo-root .
```

Use `--previous` when validating an earlier record's append-only history.
Validation reports the scope actually checked and does not fetch sources,
verify real-world truth, grant storage rights, approve tasks or pass a quality
gate. Keep unlicensed originals out of the repository. The source-acquisition,
original-quote comparison and review-integration workflows remain separate
follow-up work.
