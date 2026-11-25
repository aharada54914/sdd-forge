--------------------------- MODULE GateLifecycle ---------------------------
EXTENDS Naturals
CONSTANT RequireGatePass
Statuses == {"Planned", "InProgress", "ImplComplete", "Done"}
Verdicts == {"NONE", "FAIL", "PASS"}
VARIABLES status, gateVerdict

vars == <<status, gateVerdict>>

Init ==
    /\ status = "Planned"
    /\ gateVerdict = "NONE"

StartTask ==
    /\ status = "Planned"
    /\ status' = "InProgress"
    /\ UNCHANGED gateVerdict

CompleteImpl ==
    /\ status = "InProgress"
    /\ status' = "ImplComplete"
    /\ UNCHANGED gateVerdict

RunGatePass ==
    /\ status = "ImplComplete"
    /\ gateVerdict' = "PASS"
    /\ UNCHANGED status

RunGateFail ==
    /\ status = "ImplComplete"
    /\ gateVerdict' = "FAIL"
    /\ UNCHANGED status

MarkDone ==
    /\ status = "ImplComplete"
    /\ IF RequireGatePass THEN gateVerdict = "PASS" ELSE TRUE
    /\ status' = "Done"
    /\ UNCHANGED gateVerdict

Next == StartTask \/ CompleteImpl \/ RunGatePass \/ RunGateFail \/ MarkDone

Spec == Init /\ [][Next]_vars

DoneRequiresGatePass == (status = "Done") => (gateVerdict = "PASS")
=============================================================================
