--------------------------- MODULE TaskLock ---------------------------
EXTENDS Naturals, FiniteSets
CONSTANT UseAtomicLock
Owners == {"w1", "w2"}
VARIABLES holder, leaseActive, holders

vars == <<holder, leaseActive, holders>>

Init ==
    /\ holder = "none"
    /\ leaseActive = FALSE
    /\ holders = {}

Acquire(o) ==
    /\ o \notin holders
    /\ IF UseAtomicLock THEN holder = "none" ELSE TRUE
    /\ holder' = o
    /\ leaseActive' = TRUE
    /\ holders' = holders \cup {o}

Renew(o) ==
    /\ holder = o
    /\ leaseActive' = TRUE
    /\ UNCHANGED <<holder, holders>>

Expire ==
    /\ holder /= "none"
    /\ leaseActive = TRUE
    /\ leaseActive' = FALSE
    /\ UNCHANGED <<holder, holders>>

ReclaimStale(o) ==
    /\ holder /= "none"
    /\ leaseActive = FALSE
    /\ holder' = o
    /\ leaseActive' = TRUE
    /\ holders' = {o}

Release(o) ==
    /\ holder = o
    /\ holder' = "none"
    /\ leaseActive' = FALSE
    /\ holders' = holders \ {o}

Next ==
    \/ \E o \in Owners : Acquire(o) \/ Renew(o) \/ ReclaimStale(o) \/ Release(o)
    \/ Expire

Spec == Init /\ [][Next]_vars

SingleOwner == Cardinality(holders) <= 1
=============================================================================
