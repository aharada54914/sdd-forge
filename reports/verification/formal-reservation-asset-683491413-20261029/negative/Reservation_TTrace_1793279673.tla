---- MODULE Reservation_TTrace_1793279673 ----
EXTENDS Sequences, Reservation, TLCExt, Toolbox, Naturals, TLC

_expression ==
    LET Reservation_TEExpression == INSTANCE Reservation_TEExpression
    IN Reservation_TEExpression!expression
----

_trace ==
    LET Reservation_TETrace == INSTANCE Reservation_TETrace
    IN Reservation_TETrace!trace
----

_inv ==
    ~(
        TLCGet("level") = Len(_TETrace)
        /\
        phase = (<<"release", "release">>)
        /\
        ledger = (2)
        /\
        lock = (0)
        /\
        accepted = ({1, 2})
    )
----

_init ==
    /\ lock = _TETrace[1].lock
    /\ phase = _TETrace[1].phase
    /\ accepted = _TETrace[1].accepted
    /\ ledger = _TETrace[1].ledger
----

_next ==
    /\ \E i,j \in DOMAIN _TETrace:
        /\ \/ /\ j = i + 1
              /\ i = TLCGet("level")
        /\ lock  = _TETrace[i].lock
        /\ lock' = _TETrace[j].lock
        /\ phase  = _TETrace[i].phase
        /\ phase' = _TETrace[j].phase
        /\ accepted  = _TETrace[i].accepted
        /\ accepted' = _TETrace[j].accepted
        /\ ledger  = _TETrace[i].ledger
        /\ ledger' = _TETrace[j].ledger

\* Uncomment the ASSUME below to write the states of the error trace
\* to the given file in Json format. Note that you can pass any tuple
\* to `JsonSerialize`. For example, a sub-sequence of _TETrace.
    \* ASSUME
    \*     LET J == INSTANCE Json
    \*         IN J!JsonSerialize("Reservation_TTrace_1793279673.json", _TETrace)

=============================================================================

 Note that you can extract this module `Reservation_TEExpression`
  to a dedicated file to reuse `expression` (the module in the 
  dedicated `Reservation_TEExpression.tla` file takes precedence 
  over the module `Reservation_TEExpression` below).

---- MODULE Reservation_TEExpression ----
EXTENDS Sequences, Reservation, TLCExt, Toolbox, Naturals, TLC

expression == 
    [
        \* To hide variables of the `Reservation` spec from the error trace,
        \* remove the variables below.  The trace will be written in the order
        \* of the fields of this record.
        lock |-> lock
        ,phase |-> phase
        ,accepted |-> accepted
        ,ledger |-> ledger
        
        \* Put additional constant-, state-, and action-level expressions here:
        \* ,_stateNumber |-> _TEPosition
        \* ,_lockUnchanged |-> lock = lock'
        
        \* Format the `lock` variable as Json value.
        \* ,_lockJson |->
        \*     LET J == INSTANCE Json
        \*     IN J!ToJson(lock)
        
        \* Lastly, you may build expressions over arbitrary sets of states by
        \* leveraging the _TETrace operator.  For example, this is how to
        \* count the number of times a spec variable changed up to the current
        \* state in the trace.
        \* ,_lockModCount |->
        \*     LET F[s \in DOMAIN _TETrace] ==
        \*         IF s = 1 THEN 0
        \*         ELSE IF _TETrace[s].lock # _TETrace[s-1].lock
        \*             THEN 1 + F[s-1] ELSE F[s-1]
        \*     IN F[_TEPosition - 1]
    ]

=============================================================================



Parsing and semantic processing can take forever if the trace below is long.
 In this case, it is advised to uncomment the module below to deserialize the
 trace from a generated binary file.

\*
\*---- MODULE Reservation_TETrace ----
\*EXTENDS IOUtils, Reservation, TLC
\*
\*trace == IODeserialize("Reservation_TTrace_1793279673.bin", TRUE)
\*
\*=============================================================================
\*

---- MODULE Reservation_TETrace ----
EXTENDS Reservation, TLC

trace == 
    <<
    ([phase |-> <<"acquire", "acquire">>,ledger |-> 0,lock |-> 0,accepted |-> {}]),
    ([phase |-> <<"check", "acquire">>,ledger |-> 0,lock |-> 0,accepted |-> {}]),
    ([phase |-> <<"publish", "acquire">>,ledger |-> 0,lock |-> 0,accepted |-> {}]),
    ([phase |-> <<"publish", "check">>,ledger |-> 0,lock |-> 0,accepted |-> {}]),
    ([phase |-> <<"publish", "publish">>,ledger |-> 0,lock |-> 0,accepted |-> {}]),
    ([phase |-> <<"release", "publish">>,ledger |-> 1,lock |-> 0,accepted |-> {1}]),
    ([phase |-> <<"release", "release">>,ledger |-> 2,lock |-> 0,accepted |-> {1, 2}])
    >>
----


=============================================================================

---- CONFIG Reservation_TTrace_1793279673 ----
CONSTANTS
    UseLock = FALSE

INVARIANT
    _inv

CHECK_DEADLOCK
    \* CHECK_DEADLOCK off because of PROPERTY or INVARIANT above.
    FALSE

INIT
    _init

NEXT
    _next

CONSTANT
    _TETrace <- _trace

ALIAS
    _expression
=============================================================================
\* Generated on Thu Oct 29 13:14:33 UTC 2026