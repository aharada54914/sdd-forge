----------------------------- MODULE GateLifecycle -----------------------------
EXTENDS Naturals
CONSTANT
    \* @type: Int;
    MaxRounds,
    \* @type: Str;
    Fault
VARIABLES
    \* @type: Str;
    status,
    \* @type: Bool;
    approved,
    \* @type: Str;
    gateVerdict,
    \* @type: Int;
    rounds,
    \* @type: Bool;
    tamper,
    \* @type: Str;
    drift,
    \* @type: Bool;
    oq

\* Explicit frame equalities let Apalache use these actions as trace predicates
\* even after Next has already assigned the successor state.
vars == <<status, approved, gateVerdict, rounds, tamper, drift, oq>>
Init == /\ status = "Planned" /\ approved = FALSE /\ gateVerdict = "NONE"
        /\ rounds = 0 /\ tamper = FALSE /\ drift = "CLEAN" /\ oq = FALSE

Approve == /\ status = "Planned" /\ ~approved /\ approved' = TRUE
           /\ status' = status /\ gateVerdict' = gateVerdict /\ rounds' = rounds /\ tamper' = tamper /\ drift' = drift /\ oq' = oq
StartTask == /\ status = "Planned" /\ (approved \/ Fault = "Approval")
             /\ status' = "InProgress"
             /\ approved' = approved /\ gateVerdict' = gateVerdict /\ rounds' = rounds /\ tamper' = tamper /\ drift' = drift /\ oq' = oq
CompleteImpl == /\ status = "InProgress" /\ status' = "ImplComplete"
                /\ approved' = approved /\ gateVerdict' = gateVerdict /\ rounds' = rounds /\ tamper' = tamper /\ drift' = drift /\ oq' = oq

RunGatePass == /\ status = "ImplComplete" /\ gateVerdict = "NONE"
               /\ gateVerdict' = "PASS" /\ tamper' = FALSE
               /\ drift' \in IF Fault = "Drift" THEN {"CLEAN", "UNDECLARED_DRIFT"} ELSE {"CLEAN"}
               /\ status' = status /\ approved' = approved /\ rounds' = rounds /\ oq' = oq
RunGateFail == /\ status = "ImplComplete" /\ gateVerdict = "NONE"
               /\ gateVerdict' = "FAIL" /\ tamper' \in BOOLEAN
               /\ oq' = (tamper' /\ Fault /= "MissingOQ")
               /\ drift' \in {"CLEAN", "UNDECLARED_DRIFT"}
               /\ status' = status /\ approved' = approved /\ rounds' = rounds
Repair == /\ status = "ImplComplete" /\ gateVerdict = "FAIL"
          /\ (~tamper \/ Fault = "Tamper")
          /\ (rounds < MaxRounds \/ (Fault = "Retry" /\ rounds = MaxRounds))
          /\ status' = "InProgress" /\ rounds' = rounds + 1 /\ gateVerdict' = "NONE"
          /\ approved' = approved /\ tamper' = tamper /\ drift' = drift /\ oq' = oq
Escalate == /\ status = "ImplComplete" /\ gateVerdict = "FAIL" /\ (tamper \/ rounds >= MaxRounds)
            /\ status' = "Blocked" /\ oq' = (Fault /= "MissingOQ")
            /\ approved' = approved /\ gateVerdict' = gateVerdict /\ rounds' = rounds /\ tamper' = tamper /\ drift' = drift
MarkDone == /\ status = "ImplComplete" /\ gateVerdict = "PASS"
            /\ status' = "Done" /\ approved' = approved /\ gateVerdict' = gateVerdict /\ rounds' = rounds /\ tamper' = tamper /\ drift' = drift /\ oq' = oq
Next == Approve \/ StartTask \/ CompleteImpl \/ RunGatePass \/ RunGateFail \/ Repair \/ Escalate \/ MarkDone
Spec == Init /\ [][Next]_vars

DoneRequiresGatePass == status = "Done" => (approved /\ gateVerdict = "PASS")
RetryBound == rounds <= MaxRounds
EscalationRequiresOQ == (status = "Blocked" \/ (tamper /\ gateVerdict = "FAIL")) => oq
NoTamperRepair == status = "InProgress" => ~tamper
NoDriftPass == gateVerdict = "PASS" => drift /= "UNDECLARED_DRIFT"
===============================================================================
