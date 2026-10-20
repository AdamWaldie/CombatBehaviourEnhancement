/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads exact coordinated-support STOP provenance for hold-to-bound admission.
 * Locality/authority: Current group/actor owner, current support state only. Read-only;
 * caller independently validates actor fitness, external ownership and operation admission.
 * Repeat/JIP: Original support token, operation generation, owner epoch and expiry must
 * match. Unknown STOP and changed destinations/formation leaders grant no permission.
 * No commands, timers, baseline capture, receipt renewal or migration replay occur.
 * Arguments: 0 group GROUP grpNull; 1 state HASHMAP empty; 2 actor OBJECT objNull;
 * 3 support token STRING empty; 4 operation generation NUMBER -1; 5 expiry NUMBER -1.
 * Return: BOOL, exact current local support hold, not movement or arrival acknowledgement.
 * Current callers: CortexSupportBoundStart and CortexSupportMaintain covering admission.
 * Example: [_group,_state,_actor,_token,_generation,_expiry] call CBE_fnc_CortexSupportStopOwned;
 */
params [["_holdGroup",grpNull,[grpNull]],["_holdState",createHashMap,[createHashMap]],
    ["_holdActor",objNull,[objNull]],["_supportToken","",[""]],
    ["_holdGeneration",-1,[0]],["_holdExpiry",-1,[0]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _holdGroup} || {!local _holdGroup}
    || {isNull _holdActor} || {!local _holdActor} || {group _holdActor != _holdGroup}
    || {_holdState isNotEqualTo (_holdGroup getVariable ["CBE_AIPass_State",createHashMap])}
    || {_supportToken == ""} || {!finite _holdGeneration} || {_holdGeneration < 0}
    || {_holdGeneration != (_holdGroup getVariable ["CBE_OperationGeneration",-1])}
    || {!finite _holdExpiry} || {serverTime >= _holdExpiry}
    || {toUpperANSI currentCommand _holdActor != "STOP"}) exitWith {false};
private _holds=_holdState getOrDefault ["supportStopHolds",createHashMap];
if (!(_holds isEqualType createHashMap) || {count _holds > 64}) exitWith {false};
(_holds getOrDefault [netId _holdActor,[]]) isEqualTo [
    _holdActor,_supportToken,_holdGeneration,_holdGroup getVariable ["CBE_AIPass_Epoch",-1],
    expectedDestination _holdActor,formLeader _holdActor,_holdExpiry]
