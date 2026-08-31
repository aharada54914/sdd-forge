# WFI-034 protected-gate application

The deterministic hook correctly blocks agents from editing the live review
boundary. `WFI-034.patch` is the human-reviewable candidate for the paired
Bash/PowerShell validators and their launch/report contracts.

From the repository root, a human maintainer can run:

```bash
git apply --check specs/wfi-034-scratch-isolation/human-copy/WFI-034.patch
git apply specs/wfi-034-scratch-isolation/human-copy/WFI-034.patch
```

The patch includes same/ancestor/descendant negative controls in
`tests/review-agent-isolation.tests.sh`. After applying it, run that suite with
Bash and PowerShell available, and only then mark WFI-034 fully applied.
