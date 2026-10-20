/*
 * Author: WaldoTheWarfighter
 * Owner execution preserves unknown/malformed actor reservations through the shared strict predicate.
 * Runs one reserved squad bound as two successive fire-team movements, retaining eligible
 * battle buddies together. Pair cohesion takes priority over equal team sizes; all fit actors remain enrolled.
 * Locality/authority: group owner consumes the current server role and matching lease.
 * Native STOP requires an exact existing support hold; matching holds transfer into the drill
 * without commands, new deadlines or an acknowledgement grace period.
 * Admission, pair allocation and FSM registration share one unscheduled transaction. A stale
 * state, disabled feature, pause, replacement role or task ownership change acquires no drill.
 * Repeat/JIP: sequence prevents duplicate starts; migration restores mover leases before
 * the new owner consumes the durable role. Uses the finite tactical-drill FSM and publishes a
 * heartbeat so GroupTick can fail and restore a lost or starved controller.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: role <ARRAY>, required.
 * Return: Boolean, true if a finite bound starts. Current caller: CortexSupportMaintain.
 * Example: [_group,_state,_role] call CBE_fnc_CortexSupportBoundStart;
 */
params ["_group","_state","_role"];
private _accepted=false;
isNil {
if (isNull _group || {_state isNotEqualTo (_group getVariable ["CBE_AIPass_State",createHashMap])}
    || {!(missionNamespace getVariable ["CBE_AIPass_Enable",false])}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {false};
if (!local _group || {count _role != 5} || {count (_state getOrDefault ["drill",createHashMap]) > 0}) exitWith {false};
// SupportMaintain can observe the role just before a curator or specialist claims the group.
// Recheck at the drill-allocation boundary: a rejected bound leaves the existing native/external
// order untouched and lets the server retire this role on the next acknowledgement.
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {false};
_role params ["_leaseToken","_sequence","_roleName","_point","_enemy"];
if (_roleName != "MOVE" || {_role isNotEqualTo (_group getVariable ["CBE_Cortex_SupportRole",[]])}) exitWith {false};
private _lease=_group getVariable ["CBE_AIPass_SupportLease",[]];
if (count _lease != 6 || {(_lease select 0) != _leaseToken} || {serverTime >= (_lease select 2)}) exitWith {false};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _generation=_state getOrDefault ["supportOperationGeneration",-1];
private _ownerEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
if (_generation < 0 || {(_operation getOrDefault ["generation",-2]) != _generation}
    || {(_operation getOrDefault ["ownerEpoch",-1]) != _ownerEpoch}
    || {(_operation getOrDefault ["intent",""]) != "COORDINATED_ASSAULT"}
    || {(_operation getOrDefault ["phase",""]) == "CANCELLED"}) exitWith {false};
private _final=_point distance2D (_lease select 5) < 2;
private _unavailable=_operation getOrDefault ["unavailable",[]];
private _fit=(units _group) select {
    local _x && {[_x] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _x}
        && {!(_x in _unavailable)} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
        && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
        && {toUpperANSI currentCommand _x != "STOP" || {
            [_group,_state,_x,_leaseToken,_generation,_lease select 2] call CBE_fnc_CortexSupportStopOwned
        }}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
if (count _fit < 3) exitWith {false};
if (count _fit > 64) exitWith {false};
private _nativeCommands=createHashMap;
{
    if (toUpperANSI currentCommand _x == "STOP") then {
        _nativeCommands set [netId _x,[_x,"HOLD",+(expectedDestination _x),formLeader _x,-1,[],[]]];
    };
} forEach _fit;
// Preserve established pairs before distributing orphans. Alternating individual roster
// entries split buddies formed by the parent operation. Keep every eligible role, including
// leaders and support weapons; a temporary reservation cannot pull its partner into the bound.
private _first=[];
private _second=[];
private _remaining=+_fit;
private _pairs=_group getVariable ["CBE_CombatPairs",[]];
if (_pairs isEqualType []) then {
    {
        if (_x isEqualType [] && {count _x == 2}
            && {(_x select 0) != (_x select 1)}
            && {_x findIf {!(_x in _remaining)} < 0}) then {
            ([_first,_second] select (count _first > count _second)) append _x;
            _remaining=_remaining-_x;
        };
    } forEach (_pairs select [0,16]);
};
// Missing, broken or oversized historical pairing metadata never drops an eligible actor.
{
    ([_first,_second] select (count _first > count _second)) pushBack _x;
} forEach _remaining;
// A three-person responder still fields a two-person first element and one-person cover.
if (count _first < count _second) then {
    private _swap=_first;_first=_second;_second=_swap;
};
if (count _first < 2 || {count _second < 1}) exitWith {false};
private _token=format ["SUPPORT:%1:%2:%3",_leaseToken,_sequence,clientOwner];
_state set ["drill",createHashMapFromArray [
    ["token",_token],["supportToken",_leaseToken],["supportSequence",_sequence],
    ["operationGeneration",_generation],["ownerEpoch",_ownerEpoch],
    ["nativeAdmissionChecked",true],["nativeCommands",_nativeCommands],
    ["type","ADVANCE"],["teams",[_first,_second]],["teamSizes",[count _first,count _second]],["teamTurn",0],["units",_fit],["desiredStrength",count _fit],
    ["points",[[+_point,["SUPPORT_BOUND","FINAL"] select _final]]],["index",0],["stage",""],
    ["enemyPos",+_enemy],["disabled",[]],["spots",[]],["started",time],["lastStep",time],
    ["boundStart",time],["pauseUntil",0]
]];
[_group,_state get "drill","START","COORDINATED_BOUND_ACCEPTED"] call CBE_fnc_CortexDrillSetStage;
_state set ["supportBoundSequence",_sequence];
_group setVariable ["CBE_Cortex_SupportBoundResult",[],true];
_group setVariable ["CBE_Cortex_DrillReinforcements",[],true];
// Transfer only the admitted hold rows; obsolete support cleanup cannot recall the new drill.
private _transferredHolds=_state getOrDefault ["supportStopHolds",createHashMap];
{_transferredHolds deleteAt _x} forEach (keys _nativeCommands);
_state set ["supportStopHolds",_transferredHolds];
_accepted=[_group,_token] call CBE_fnc_CortexDrillStart;
};
_accepted
