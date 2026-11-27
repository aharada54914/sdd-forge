------------------------- MODULE TaskLockMutation -------------------------
EXTENDS Naturals, FiniteSets
CONSTANT
    \* @type: Bool;
    CheckPeers
Workers == {"w1", "w2", "w3"}
VARIABLE
    \* @type: Str -> Str;
    phase

Init == phase = [w \in Workers |-> "idle"]
Move(w, target) == phase' = [phase EXCEPT ![w] = target]
Announce(w) == /\ phase[w] = "idle"
               /\ Move(w, "announced")
Enter(w) == /\ phase[w] = "announced"
            /\ ~CheckPeers \/ \A p \in Workers \ {w} : phase[p] \in {"idle", "dead"}
            /\ Move(w, "editing")
Withdraw(w) == /\ phase[w] \in {"announced", "editing"}
               /\ Move(w, "idle")
Crash(w) == /\ phase[w] \in {"announced", "editing"}
            /\ Move(w, "dead")
Reap(w) == /\ phase[w] = "dead"
           /\ Move(w, "idle")

Next == \E w \in Workers : Announce(w) \/ Enter(w) \/ Withdraw(w) \/ Crash(w) \/ Reap(w)
Spec == Init /\ [][Next]_phase
OneWriter == Cardinality({w \in Workers : phase[w] = "editing"}) <= 1
===========================================================================
