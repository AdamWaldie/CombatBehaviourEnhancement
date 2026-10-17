/*
 * Author: WaldoTheWarfighter
 * Purpose: Queues one bounded convoy-control step for the current finite convoy brain.
 * Locality / Authority: Owner-local. It issues no vehicle command directly and submits one coalesced callback to CBE's shared scheduler.
 * Repeat/JIP: Group, registry revision and token coalesce duplicate work and reject stale owners.
 * Arguments: 0 group <GROUP>; 1 registry revision <NUMBER>; 2 configuration <ARRAY>; 3 convoy brain <HASHMAP>; 4 expected semantic phase <STRING>.
 * Return Value: Boolean - true when a current or newly queued step exists.
 * Current caller: CBE convoyOperation FSM.
 * Example: [_group,4,_configuration,_brain,"SPACING"] call CBE_fnc_ConvoyOperationQueue;
 */
params [["_group",grpNull,[grpNull]],["_registryRevision",-1,[0]],["_configuration",[],[[]]],["_brain",createHashMap,[createHashMap]],["_expectedPhase","CRUISE",[""]]];
if (isNull _group || {!local _group} || {count _brain == 0} || {_registryRevision != (missionNamespace getVariable ["CBE_Convoy_ReceivedRevision",-2])} || {(_brain getOrDefault ["jobToken",""]) isNotEqualTo (_group getVariable ["CBE_Convoy_LocalJobToken",""])} || {(_group getVariable ["CBE_Convoy_Brain",createHashMap]) isNotEqualTo _brain} || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
if (_brain getOrDefault ["pending",false]) exitWith {true};
_brain set ["pending",true];_brain set ["completed",false];_brain set ["expectedPhase",_expectedPhase];
_brain set ["queuedAt",time];
private _key=format ["CBE_CONVOY_%1_%2_%3",str _group,_registryRevision,_brain getOrDefault ["jobToken",""]];
[CBE_fnc_ConvoyOperationStep,_brain,0,_key] call CBE_fnc_CortexQueueJob;
true
