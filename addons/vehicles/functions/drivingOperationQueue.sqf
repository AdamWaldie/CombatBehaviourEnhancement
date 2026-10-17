/*
 * Author: WaldoTheWarfighter
 * Purpose: Queues one coalesced physical driving observation through the existing shared scheduler.
 * Locality / Authority: Owner-local group only; no ownership transfer or second scheduler.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 brain <HASHMAP, empty>.
 * Return Value: BOOL - whether a current callback is pending.
 * Current callers: CBE drivingOperation FSM.
 * Example: [_brain] call CBE_fnc_DrivingOperationQueue;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _group=_brain getOrDefault ["group",grpNull];
if (isNull _group || {!local _group} || {_brain getOrDefault ["cancelled",false]}
    || {_brain getOrDefault ["finished",false]}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];_brain set ["completed",false];_brain set ["queuedAt",time];
private _key=format ["CBE_DRIVING_%1_%2_%3",str _group,_brain get "ownerEpoch",_brain get "generation"];
[CBE_fnc_DrivingOperationStep,_brain,0,_key] call CBE_fnc_CortexQueueJob;
true
