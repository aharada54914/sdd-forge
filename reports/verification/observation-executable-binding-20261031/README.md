# Executable-permission observation binding

Independent actual task execution reproduced the defect on 46891fc0: a helper
ran successfully at mode 0755. Changing only its mode to 0644 left the old v2
observation valid and projected `passes: true`, while a new run failed with
PermissionError. The original failed-control evidence is retained unchanged.

The independently evaluated working-tree repair emits observation v3 with a
separate executable-permission digest. Source commit fields identify the base;
exact runner/validator hashes identify the evaluated uncommitted implementation.
Changing mode alone now rejects the old success with source-mismatch. A fresh
run records the real failure. Actual child-side input chmod produces a failed
runner-modified-input observation; original-tree chmod during execution prevents
observation publication. Declared output executable bits survive publication
and current v3 validation. V2 remains readable as legacy-source-modes-unbound
and supplies no execution fields. Observation 40 and lifecycle 43 checks passed.

The archive retains evaluation scripts, observations, task inputs, returned
receipts/results and test logs. Temporary execution trees were cleaned; paths
inside historical receipts identify original temporary logs and are not promises
that those removed files still exist. Extract into a new scratch directory and
inspect source paths before replay. The v3 follow-up uses the changed working
implementation, not a claim that its base commit already contains the fix.

The bound permissions are the copied 0111 bits. Full mode/ACL/ownership, arbitrary
dynamic dependencies and changes restored between observations are outside this
check. This does not introduce result caching or OS sandboxing.
