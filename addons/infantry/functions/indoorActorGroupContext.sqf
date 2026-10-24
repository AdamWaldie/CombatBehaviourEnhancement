/*
 * Author: WaldoTheWarfighter
 * Purpose: Read one bounded group ownership snapshot for indoor actor preflight.
 * Locality/authority: Read-only on the group owner. No movement, generation, lease or public
 * state changes. Participants receive at most64 group/locality checks per snapshot.
 * Repeat/JIP: Same-callback candidate filtering only; never persist or replay the result.
 * Actual actor executors call IndoorActorGroupAvailable without a snapshot to re-read current
 * authority before commands. Unscoped live movement claims and malformed/group-wide ownership
 * return no snapshot. Local leases use time; public leases use serverTime.
 * Arguments: 0 group GROUP, grpNull.
 * Return: ARRAY [group,epoch,generation,participants,drillUnits,supportHeld], or [] for refusal.
 * Current callers: IndoorActorGroupAvailable, IndoorActorDispatch, IndoorObservationDispatch
 * and CortexAirborneGroundHandover same-call cargo preflight.
 * Example: private _context=[group soldier1] call CBE_fnc_IndoorActorGroupContext;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group}) exitWith {[]};
if ((_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []
    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}
    || {_group getVariable ["CBE_AIPass_ClearBuilding",false]}
    || {count (_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap]) > 0}) exitWith {[]};
private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
if (!(_state isEqualType createHashMap)) exitWith {[]};
private _drill=_state getOrDefault ["drill",createHashMap];
if (!(_drill isEqualType createHashMap)) exitWith {[]};
private _drillUnits=_drill getOrDefault ["units",[]];
private _supportHeld=_state getOrDefault ["supportHeld",[]];
if (!(_drillUnits isEqualType []) || {!(_supportHeld isEqualType [])}
    || {count _drillUnits > 64} || {count _supportHeld > 64}) exitWith {[]};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _generation=_group getVariable ["CBE_OperationGeneration",0];
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if (!(_operation isEqualType createHashMap)) exitWith {[]};
// Migration can reserve movement before rebuilding the common operation. Without an
// explicit current roster there is no proof that an indoor actor is disjoint.
private _unscopedClaim=false;
if (count _operation == 0) then {
    private _leaseClaimsMovement={
        params ["_candidateLease","_clockNow"];
        if (_candidateLease isEqualTo []) exitWith {false};
        private _typedLease=_candidateLease isEqualType [] && {count _candidateLease == 2}
            && {(_candidateLease select 0) isEqualType ""} && {(_candidateLease select 0) != ""}
            && {(_candidateLease select 1) isEqualType 0} && {finite (_candidateLease select 1)};
        if (!_typedLease) exitWith {true};
        _clockNow < (_candidateLease select 1)
    };
    if (count _drill > 0
        || {(_state getOrDefault ["responding",false]) isNotEqualTo false}
        || {(_state getOrDefault ["assaulting",false]) isNotEqualTo false}
        || {[_state getOrDefault ["movementLease",[]],time] call _leaseClaimsMovement}
        || {[_group getVariable ["CBE_Cortex_MovementLease",[]],serverTime] call _leaseClaimsMovement}) exitWith {_unscopedClaim=true};
};
if (_unscopedClaim) exitWith {[]};
private _participants=[];
private _contextValid=true;
if (count _operation > 0) then {
    if (!((_operation getOrDefault ["intent",""]) in ["ADVANCE","FLANK","ASSAULT"])
        || {(_operation getOrDefault ["generation",-1]) != _generation}
        || {(_operation getOrDefault ["ownerEpoch",-1]) != _epoch}
        || {(_operation getOrDefault ["cancelReason",""]) != ""}
        || {!((_operation getOrDefault ["participantsRequired",false]) isEqualTo true)}) exitWith {_contextValid=false};
    _participants=_operation getOrDefault ["participants",[]];
    if (!(_participants isEqualType []) || {_participants isEqualTo []} || {count _participants > 64}) exitWith {_contextValid=false};
    if (_participants findIf {!(_x isEqualType objNull) || {isNull _x} || {group _x != _group} || {!local _x}} >= 0) exitWith {_contextValid=false};
};
if (!_contextValid) exitWith {[]};
[_group,_epoch,_generation,+_participants,+_drillUnits,+_supportHeld]
