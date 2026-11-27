Task ID: T-007
Feature: verification-first-factory
Run ID: ff373264-88f8-405a-be3d-8055d4623f5e
VERDICT: NEEDS_WORK
Critical: 0
Major: 1
Minor: 0

- **VERDICT**: NEEDS_WORK

# Independent quality gate for T-007

Evaluators verified all 26 admitted hashes at `a2d447828766bd77ca9637d3e21ead3717cb7e41`. G1/G2/G5 were reviewed by `ff373264-88f8-405a-be3d-8055d4623f5e` (ledger 1239) and G3/G4 by `0d5c10eb-1be2-43c3-9f2b-94da99baaa02` (ledger 1240). Machine execution `b339313d-90a1-492b-b29d-86888f496fbd` returned PASS.

G1 and G3 NEEDS_WORK. Two independent evaluators reproduced the same change-list error without running an attack. A deleted package.json passes the built-in secret scan while the dependency-name scan returns UNREADABLE_MANIFEST/2. Both require an error for present unreadable inputs. The task touches both built-ins through the public gate, so a normal package removal incorrectly fails CI (RT-20261126-007).
G2 reviewed the task delta and recorded CLEAN spec drift. The broad historical diff also includes the README release heading from upstream v2.1.5. G4 PASS. G5 N/A for UI/domain; the bootstrap design output includes the requested fields.
Native adapter qualifications, the machine suite (16/16) and the historical related suite (74/74) are distinct from independent execution. The evaluators checked safe Socket response fixtures, directory/read error handling and the deleted-manifest case. Non-checks include authenticated cloud execution and live red-team testing. The evaluators did not independently verify the candidate-hosted scanner jobs from the sealed input. Host receipts for the repaired source must be available to the next round.
