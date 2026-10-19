/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one server-owned finite brain for a bounded cross-squad support request.
 * Locality / Authority: Server only. Responder owners continue to validate and execute their own movement and combat roles.
 * Repeat/JIP: The exact request serial reuses its brain. A replacement increments the requester generation and invalidates older queued work; requests are not recreated for JIP.
 * Executor recovery: one ended nonterminal executor resumes the identical admitted record, generation,
 * phase and pending callbacks without new deadlines. Failed execution retires through existing bounded cleanup.
 * Arguments: 0 support request job <HASHMAP>; 1 initial delay <NUMBER>, default 0.
 * Return Value: Boolean - true when the exact support request has an active brain.
 * Current callers: CBE_fnc_CortexSupportServer and server-side CortexDiscover executor maintenance.
 * Example: [_job,1] call CBE_fnc_SupportRequestStart;
 */
params [["_job",createHashMap,[createHashMap]],["_delay",0,[0]]];
if (!isServer || {count _job == 0}) exitWith {false};
private _requester=_job getOrDefault ["requester",grpNull];
private _serial=_job getOrDefault ["serial",-1];
private _key=_job getOrDefault ["key",""];
if (isNull _requester || {_serial < 0} || {_key == ""}) exitWith {false};
private _registered=(missionNamespace getVariable ["CBE_AIPass_SupportRequests",createHashMap]) getOrDefault [_key,createHashMap];
if (_registered isNotEqualTo _job) exitWith {false};
private _retireExecutor={
    params ["_failedBrain","_failure"];
    if ((_requester getVariable ["CBE_Support_Brain",createHashMap]) isNotEqualTo _failedBrain
        || {(_failedBrain getOrDefault ["generation",-1]) != (_requester getVariable ["CBE_Support_BrainGeneration",-2])}
        || {(_failedBrain getOrDefault ["job",createHashMap]) isNotEqualTo _job}
        || {((missionNamespace getVariable ["CBE_AIPass_SupportRequests",createHashMap]) getOrDefault [_key,createHashMap]) isNotEqualTo _job}) exitWith {false};
    _failedBrain set ["cancelled",true];_failedBrain set ["finished",true];_failedBrain set ["pending",false];
    _failedBrain set ["cancelReason",_failure];
    _job set ["executorFailure",_failure];
    [_job] call CBE_fnc_CortexSupportStep;
    _requester setVariable ["CBE_Support_Brain_State",["FAILED",_failedBrain getOrDefault ["generation",-1],serverTime,_failure],true];
    false
};
private _current=_requester getVariable ["CBE_Support_Brain",createHashMap];
if (count _current > 0 && {(_current getOrDefault ["serial",-2]) == _serial}
    && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) exitWith {
    if ((_current getOrDefault ["job",createHashMap]) isNotEqualTo _job
        || {(_current getOrDefault ["generation",-1]) != (_requester getVariable ["CBE_Support_BrainGeneration",-2])}) exitWith {false};
    private _handle=_requester getVariable ["CBE_Support_Brain_FSM",-1];
    if (_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}) exitWith {true};
    if ((_current getOrDefault ["executorRestarts",0]) >= 1) exitWith {[_current,"FSM_RESTART_EXHAUSTED"] call _retireExecutor};
    // The exact admitted record and queued callbacks retain their original deadlines.
    _current set ["executorRestarts",1];
    _handle=[_job,_current get "generation",_current] execFSM "\z\cbe\addons\main\fsm\supportRequest.fsm";
    _requester setVariable ["CBE_Support_Brain_FSM",_handle];
    private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
        && {(_requester getVariable ["CBE_Support_Brain",createHashMap]) isEqualTo _current}
        && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])};
    if (!_started) then {[_current,"FSM_RESTART_FAILED"] call _retireExecutor};
    _started
};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _generation=(_requester getVariable ["CBE_Support_BrainGeneration",0])+1;
private _brain=createHashMapFromArray [
    ["requester",_requester],["job",_job],["serial",_serial],["generation",_generation],
    ["phase","DISCOVER"],["pending",false],["completed",false],["finished",false],
    ["cancelled",false],["cancelReason",""],["nextAt",time+(_delay max 0)],
    ["lastStepAt",-1],["lastDelay",_delay max 0],["queuedAt",-1],["watchdogCount",0],["executorRestarts",0]
];
_requester setVariable ["CBE_Support_BrainGeneration",_generation];
_requester setVariable ["CBE_Support_Brain",_brain];
_requester setVariable ["CBE_Support_Brain_State",["DISCOVER",_generation,serverTime,"STARTED"],true];
private _handle=[_job,_generation,_brain] execFSM "\z\cbe\addons\main\fsm\supportRequest.fsm";
_requester setVariable ["CBE_Support_Brain_FSM",_handle];
private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
    && {(_requester getVariable ["CBE_Support_Brain",createHashMap]) isEqualTo _brain}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])};
if (!_started) then {[_brain,"FSM_START_FAILED"] call _retireExecutor};
_started
