--------------------------- MODULE Reservation ---------------------------
EXTENDS Naturals, FiniteSets
CONSTANT UseLock
Actors == {1, 2}
VARIABLES phase, lock, ledger, accepted
vars == <<phase, lock, ledger, accepted>>
Init == /\ phase = [a \in Actors |-> "acquire"]
        /\ lock = 0 /\ ledger = 0 /\ accepted = {}
Acquire(a) == /\ phase[a] = "acquire"
              /\ IF UseLock THEN lock = 0 ELSE TRUE
              /\ lock' = IF UseLock THEN a ELSE lock
              /\ phase' = [phase EXCEPT ![a] = "check"]
              /\ UNCHANGED <<ledger, accepted>>
Check(a) == /\ phase[a] = "check"
            /\ phase' = [phase EXCEPT ![a] = IF ledger = 0 THEN "publish" ELSE "release"]
            /\ UNCHANGED <<lock, ledger, accepted>>
Publish(a) == /\ phase[a] = "publish"
              /\ ledger' = ledger + 1
              /\ accepted' = accepted \cup {a}
              /\ phase' = [phase EXCEPT ![a] = "release"]
              /\ UNCHANGED lock
Release(a) == /\ phase[a] = "release"
              /\ lock' = IF UseLock THEN 0 ELSE lock
              /\ phase' = [phase EXCEPT ![a] = "done"]
              /\ UNCHANGED <<ledger, accepted>>
Next == \E a \in Actors: Acquire(a) \/ Check(a) \/ Publish(a) \/ Release(a)
Spec == Init /\ [][Next]_vars
OneAccepted == Cardinality(accepted) <= 1
=============================================================================
