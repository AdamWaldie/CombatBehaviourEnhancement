/*
 * Author: WaldoTheWarfighter
 * Purpose: Queues one bounded artillery mission step for the current server-owned finite brain.
 * Locality / Authority: Server only. It issues no fire or movement command directly and submits one coalesced callback to CBE's shared scheduler.
 * Repeat/JIP: Battery, token and generation form the coalescing key; replaced missions and stale callbacks are rejected.
 * Arguments: 0 battery <OBJECT>; 1 generation <NUMBER>; 2 brain <HASHMAP>; 3 expected semantic phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: CBE artilleryMission FSM.
 * Example: [_battery,2,_brain,"WARNING"] call CBE_fnc_ArtilleryMissionQueue;
 */
params [["_battery",objNull,[objNull]],["_generation",-1,[0]],["_brain",createHashMap,[createHashMap]],["_expectedPhase","REQUESTED",[""]]];
if (!isServer || {isNull _battery} || {count _brain == 0}
    || {_generation != (_battery getVariable ["CBE_Artillery_BrainGeneration",-2])}
    || {(_battery getVariable ["CBE_Artillery_Brain",createHashMap]) isNotEqualTo _brain}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];
_brain set ["completed",false];
_brain set ["expectedPhase",_expectedPhase];
_brain set ["queuedAt",time];
private _key=format ["CBE_ARTILLERY_%1_%2_%3",netId _battery,_brain getOrDefault ["token",""],_generation];
[CBE_fnc_ArtilleryMissionStep,_brain,0,_key] call CBE_fnc_CortexQueueJob;
true
