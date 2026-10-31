---
name: design-sync-loop
description: vacuous fixture
---

## Loop

1. Generate mockups under specs/<feature>/mockups/.
2. Push directly. Calls `write_files` to sync the mockups to the project.
3. Pre-upload check point. All uploads pass through here, over
   specs/<feature>/mockups/. This feature defines the point and performs
   no check at it.
4. Review in the claude.ai/design browser UI.
