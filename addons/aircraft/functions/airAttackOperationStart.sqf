/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one owner-local finite aircraft-attack brain for a live aircraft and target request.
 * Locality / Authority: Runs only on the aircraft owner. The FSM owns phase persistence; CBE_fnc_CortexAirAttack retains bounded native flight, targeting and weapon-release work.
 * Combined support duplicates must match the job original opportunity; no existing job is rebound.
 * Repeat/JIP: A current live brain is reused. One ended nonterminal executor may resume the identical job,
 * generation and original flight lease without renewing phase deadlines. Exact original jobs
 * can resume cleanup/egress after target deletion. Ended jobs with lost lease/crew epoch retire
 * through exact failure cleanup instead of leaving the attack-active flag stranded.
 * A new generation invalidates older local work after replacement or locality adoption.
 * Arguments: 0 attack job <HASHMAP>; 1 initial delay <NUMBER>, default 0.
 * Return Value: Boolean - true when an active brain exists for the aircraft.
 * Current callers: CBE_fnc_CortexDiscover and CBE_fnc_CortexCombinedArmsLocal.
 * Example: [createHashMapFromArray [["aircraft",_plane],["target",_target]],0] call CBE_fnc_AirAttackOperationStart;
 */
params [["_job",createHashMap,[createHashMap]],["_delay",0,[0]]];
private _aircraft=_job getOrDefault ["aircraft",objNull];
if (isNull _aircraft || {!local _aircraft}) exitWith {false};
private _group=group driver _aircraft;
private _retireExecutor={
    params ["_failedBrain","_failure"];
    if ((_aircraft getVariable ["CBE_AirAttack_Brain",createHashMap]) isNotEqualTo _failedBrain
        || {(_failedBrain getOrDefault ["generation",-1]) != (_aircraft getVariable ["CBE_AirAttack_BrainGeneration",-2])}) exitWith {false};
    _failedBrain set ["cancelled",true];_failedBrain set ["finished",true];_failedBrain set ["pending",false];
    _failedBrain set ["cancelReason",_failure];
    [_failedBrain getOrDefault ["job",createHashMap],_failure] call CBE_fnc_CortexAirAttack;
    [_aircraft,"AIR_ATTACK",_failedBrain getOrDefault ["flightLeaseToken",""],_failure] call CBE_fnc_FlightLeaseRelease;
    if ((_aircraft getVariable ["CBE_AirAttack_Brain",createHashMap]) isEqualTo _failedBrain) then {
        _aircraft setVariable ["CBE_AirAttack_Brain_State",["FAILED",_failedBrain getOrDefault ["generation",-1],serverTime,_failure],true];
    };
    false
};
private _current=_aircraft getVariable ["CBE_AirAttack_Brain",createHashMap];
if (isNull _group || {!local _group}) exitWith {
    // No pilot group cannot resume the old executor. Nonlocal crew can be a temporary
    // ownership split and must retain the original opportunity without terminal cleanup.
    private _handle=_aircraft getVariable ["CBE_AirAttack_Brain_FSM",-1];
    private _alive=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle};
    if (isNull _group && {!_alive} && {count _current > 0}
        && {_job isEqualTo (_current getOrDefault ["job",createHashMap])}
        && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) then {
        [_current,"FSM_RESTART_CONTEXT_LOST"] call _retireExecutor
    } else {false}
};
if (count _current > 0 && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) exitWith {
    private _originalJob=_current getOrDefault ["job",createHashMap];
    private _sameJob=_job isEqualTo _originalJob;
    private _handle=_aircraft getVariable ["CBE_AirAttack_Brain_FSM",-1];
    private _workerAlive=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle};
    private _originalContext=(_originalJob getOrDefault ["group",grpNull]) == _group
        && {(_current getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {[_aircraft,"AIR_ATTACK",_current getOrDefault ["flightLeaseToken",""]] call CBE_fnc_FlightLeaseValid};
    if (!_workerAlive && {_sameJob} && {!_originalContext}) exitWith {
        [_current,"FSM_RESTART_CONTEXT_LOST"] call _retireExecutor
    };
    private _requestedOpportunity=_job getOrDefault ["combinedOpportunity",[]];
    private _currentOpportunity=(_current getOrDefault ["job",createHashMap]) getOrDefault ["combinedOpportunity",[]];
    private _requestedTarget=_job getOrDefault ["target",objNull];
    private _currentTarget=(_current getOrDefault ["job",createHashMap]) getOrDefault ["target",objNull];
    private _sameRequest=(_sameJob || {!isNull _requestedTarget && {!isNull _currentTarget}
        && {_requestedOpportunity isEqualTo [] || {_requestedOpportunity isEqualTo _currentOpportunity}}
        && {_requestedTarget == _currentTarget || {vehicle _requestedTarget == vehicle _currentTarget}}})
        && {((_current getOrDefault ["job",createHashMap]) getOrDefault ["group",grpNull]) == _group}
        && {[_aircraft,"AIR_ATTACK",_current getOrDefault ["flightLeaseToken",""]] call CBE_fnc_FlightLeaseValid};
    if (!_sameRequest || {(_current getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
    if (_workerAlive) exitWith {true};
    if ([_group] call CBE_fnc_CortexZeusHeld || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
    if ((_current getOrDefault ["executorRestarts",0]) >= 1) exitWith {[_current,"FSM_RESTART_EXHAUSTED"] call _retireExecutor};
    _current set ["executorRestarts",1];
    _handle=[_aircraft,_current get "generation",_current] execFSM "\z\cbe\addons\main\fsm\airAttackOperation.fsm";
    _aircraft setVariable ["CBE_AirAttack_Brain_FSM",_handle];
    private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
        && {(_aircraft getVariable ["CBE_AirAttack_Brain",createHashMap]) isEqualTo _current}
        && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])};
    if (!_started) then {[_current,"FSM_RESTART_FAILED"] call _retireExecutor};
    _started
};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
// Bind only a new job; repeated admission must not rewrite the active job's
// original group before its identity check.
_job set ["group",_group];
private _generation=(_aircraft getVariable ["CBE_AirAttack_BrainGeneration",0])+1;
private _leaseToken=str _generation;
if !([_aircraft,"AIR_ATTACK",_leaseToken,300] call CBE_fnc_FlightLeaseAcquire) exitWith {false};
_aircraft setVariable ["CBE_AirAttack_BrainGeneration",_generation];
_job set ["flightLeaseToken",_leaseToken];
private _brain=createHashMapFromArray [
    ["aircraft",_aircraft],["job",_job],["generation",_generation],["phase","PLAN"],
    ["ownerEpoch",_group getVariable ["CBE_AIPass_Epoch",0]],["executorRestarts",0],
    ["pending",false],["completed",false],["finished",false],["cancelled",false],
    ["cancelReason",""],["nextAt",time+(_delay max 0)],["lastStepAt",-1],["lastDelay",_delay max 0],
    ["queuedAt",-1],["watchdogCount",0],["flightLeaseToken",_leaseToken]
];
_aircraft setVariable ["CBE_Cortex_AirAttackJob",true];
_aircraft setVariable ["CBE_AirAttack_Brain",_brain];
_aircraft setVariable ["CBE_AirAttack_Brain_State",["PLAN",_generation,serverTime,"STARTED"],true];
private _handle=[_aircraft,_generation,_brain] execFSM "\z\cbe\addons\main\fsm\airAttackOperation.fsm";
_aircraft setVariable ["CBE_AirAttack_Brain_FSM",_handle];
private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
    && {(_aircraft getVariable ["CBE_AirAttack_Brain",createHashMap]) isEqualTo _brain}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])};
if (!_started) then {[_brain,"FSM_START_FAILED"] call _retireExecutor};
_started
