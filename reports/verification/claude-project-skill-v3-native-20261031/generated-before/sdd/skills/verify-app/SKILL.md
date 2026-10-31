---
name: verify-app
description: Execute the isolated synthetic note check and read its owner observation.
---
Run exactly this command once:

python3 /workspace/scratch/sdd-forge-main-integration/plugins/sdd-bootstrap/scripts/project-skill.py run --root /tmp/tmpcd66g9fd --name verify-app --check smoke --task-input-manifest /tmp/tmpcd66g9fd/task-input.json

Then read the generated observation JSON and report its schema, outcome, and stdout text. Do not edit source or seals, do not call models or network, and do not interpret this synthetic check as full product approval.
