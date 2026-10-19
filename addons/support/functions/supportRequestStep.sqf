/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one bounded support-request implementation step and reports its semantic phase to the finite FSM.
 * Locality / Authority: Server only through CBE's shared scheduler; current responder owners retain movement and combat authority.
 * Execution: Ended/invalid FSM handles retire the callback only, without cleanup,
 * replay, phase changes or new deadlines. Existing bounded executor recovery remains owner.
 * Repeat/JIP: One-shot callback. Registry identity, request serial, generation and brain identity reject stale work after replacement or shutdown.
 * Arguments: 0 support request brain <HASHMAP>.
 * Return Value: Number - always -1 because the FSM owns later scheduling.
 * Current caller: CBE_fnc_SupportRequestQueue through CBE_fnc_CortexQueueJob.
 * Example: [_brain] call CBE_fnc_SupportRequestStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _requester=_brain getOrDefault ["requester",grpNull];
private _generation=_brain getOrDefault ["generation",-1];
private _job=_brain getOrDefault ["job",createHashMap];
private _cancel={
    params ["_reason"];
    _brain set ["pending",false];
    _brain set ["completed",true];
    _brain set ["finished",true];
    _brain set ["cancelled",true];
    _brain set ["cancelReason",_reason];
    -1
};
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {[_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel};
if (!isServer || {isNull _requester} || {count _job == 0}) exitWith {["INVALID_REQUEST"] call _cancel};
if (_generation != (_requester getVariable ["CBE_Support_BrainGeneration",-2])
    || {(_requester getVariable ["CBE_Support_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {["REPLACED"] call _cancel};
private _key=_job getOrDefault ["key",""];
private _registered=(missionNamespace getVariable ["CBE_AIPass_SupportRequests",createHashMap]) getOrDefault [_key,createHashMap];
if (_registered isNotEqualTo _job || {(_job getOrDefault ["serial",-1]) != (_brain getOrDefault ["serial",-2])}) exitWith {["REQUEST_RELEASED"] call _cancel};
// Only a live FSM may consume this queued execution callback. The existing
// discovery/restart path retains the original job, leases and phase deadlines.
private _executor=_requester getVariable ["CBE_Support_Brain_FSM",-1];
if (!(_executor isEqualType 0) || {!finite _executor} || {_executor < 0} || {completedFSM _executor}) exitWith {
    _brain set ["pending",false];_brain set ["completed",true];-1
};
private _delay=[_job] call CBE_fnc_CortexSupportStep;
private _leases=_job getOrDefault ["leases",[]];
private _phase=if (_leases findIf {(_x param [4,""]) == "PENDING"} >= 0) then {"RESERVE"} else {
    if (_leases isNotEqualTo []) then {"COORDINATE"} else {"DISCOVER"}
};
_brain set ["phase",_phase];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["pending",false];
_brain set ["completed",true];
if (_delay < 0) then {
    _brain set ["finished",true];
    _brain set ["cancelReason",_job getOrDefault ["terminationReason","REQUEST_ENDED"]];
} else {
    _brain set ["nextAt",time+_delay];
};
_requester setVariable ["CBE_Support_Brain_State",[
    _phase,_generation,serverTime,_brain getOrDefault ["cancelReason",""],_delay,count _leases,_job getOrDefault ["cursor",0]
],true];
-1
