/*
 * Author: WaldoTheWarfighter
 * Queued ACE care defers worker admission without marking a casualty or altering treatment.
 * Owner execution preserves unknown/malformed actor reservations through the shared strict predicate.
 * Runs one reserved squad bound as two successive fire-team movements, retaining eligible
 * battle buddies together. New partitions balance primary-ammunition capacity before headcount,
 * without splitting pairs. Saved reconstructed teams are not re-ranked; all fit actors remain enrolled.
 * Locality/authority: group owner consumes the current server role and matching lease.
 * Reconstructed MOVE requires an exact imported native observation; the existing leg is observed without reissue.
 * Native STOP requires an exact existing support hold; matching holds transfer into the drill
 * without commands, new deadlines or an acknowledgement grace period.
 * Parent progress retains original teams and witnessed completed turns; a finished sequence only republishes its result.
 * Admission requires the matching server role/deadline/point receipt and retains that original
 * absolute limit across child reconstruction; owner changes cannot renew the server bound.
 * Admission, pair allocation and FSM registration share one unscheduled transaction. A stale
 * state, disabled feature, pause, replacement role or task ownership change acquires no drill.
 * Repeat/JIP: sequence prevents duplicate starts; migration restores mover leases before
 * the new owner consumes the durable role. Uses the finite tactical-drill FSM and publishes a
 * heartbeat so GroupTick can fail and restore a lost or starved controller.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: role <ARRAY>, required.
 * Return: Boolean, true if a finite bound starts or its already-completed sequence is acknowledged. Current caller: CortexSupportMaintain.
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
if (count _lease != 7 || {(_lease select 0) != _leaseToken} || {serverTime >= (_lease select 2)}) exitWith {false};
private _deadlineReceipt=_group getVariable ["CBE_Cortex_SupportRoleDeadline",[]];
if (!(_deadlineReceipt isEqualType []) || {count _deadlineReceipt != 4}
    || {(_deadlineReceipt select 0) isNotEqualTo _leaseToken} || {(_deadlineReceipt select 1) isNotEqualTo _sequence}
    || {(_deadlineReceipt select 3) isNotEqualTo _point}
    || {!((_deadlineReceipt select 2) isEqualType 0)} || {!finite (_deadlineReceipt select 2)}
    || {serverTime >= (_deadlineReceipt select 2)} || {(_deadlineReceipt select 2) > (_lease select 2)}) exitWith {false};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _generation=_state getOrDefault ["supportOperationGeneration",-1];
private _ownerEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
if (_generation < 0 || {(_operation getOrDefault ["generation",-2]) != _generation}
    || {(_operation getOrDefault ["ownerEpoch",-1]) != _ownerEpoch}
    || {(_operation getOrDefault ["intent",""]) != "COORDINATED_ASSAULT"}
    || {(_operation getOrDefault ["phase",""]) == "CANCELLED"}) exitWith {false};
private _progress=_operation getOrDefault ["boundProgress",[]];
if (!(_sequence isEqualType 0) || {!finite _sequence} || {_sequence < 0} || {_sequence != floor _sequence}) exitWith {false};
if (!(_progress isEqualType []) || {_progress isNotEqualTo [] && {
    count _progress != 4 || {!((_progress select 0) isEqualType 0)} || {!finite (_progress select 0)}
        || {(_progress select 0) < 0} || {(_progress select 0) != floor (_progress select 0)}
        || {!((_progress select 1) isEqualType [])} || {count (_progress select 1) != 3}
        || {(_progress select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        || {!((_progress select 2) isEqualType [])} || {count (_progress select 2) != 2}
        || {(_progress select 2) findIf {!(_x isEqualType []) || {count _x > 64}
            || {_x findIf {!(_x isEqualType objNull)} >= 0}} >= 0}
        || {!((_progress select 3) in [0,1,2])}
        || {private _all=+((_progress select 2) select 0); _all append ((_progress select 2) select 1);
            private _present=_all select {!isNull _x};
            count _all > 64 || {count (_present arrayIntersect _present) != count _present}}
}}) exitWith {false};
private _completedTurns=0;
if (_progress isNotEqualTo []) then {
    if ((_progress select 0) == _sequence) then {
        if ((_progress select 1) isEqualTo _point) then {_completedTurns=_progress select 3} else {_completedTurns=-1};
    };
};
if (_progress isNotEqualTo [] && {(_progress select 0) > _sequence} || {_completedTurns < 0}) exitWith {false};
if (_completedTurns == 2) exitWith {
    _operation set ["supportAdoptionUntil",-1];
    _group setVariable ["CBE_Operation",_operation,true];
    _state set ["supportBoundSequence",_sequence];
    _group setVariable ["CBE_Cortex_SupportBoundResult",[_leaseToken,_sequence,"COMPLETE"],true];
    _accepted=true;
};
private _final=_point distance2D (_lease select 5) < 2;
private _unavailable=_operation getOrDefault ["unavailable",[]];
private _reconstructing=_progress isNotEqualTo [] && {(_progress select 0) == _sequence};
private _inheritedMoves=_state getOrDefault ["supportNativeMoves",createHashMap];
private _moveOwned={
    params ["_actor"];
    if (!(_inheritedMoves isEqualType createHashMap) || {count _inheritedMoves > 64}) exitWith {false};
    private _row=_inheritedMoves getOrDefault [netId _actor,[]];
    count _row == 10 && {(_row select 0) == _actor} && {(_row select 4) == _sequence}
        && {(_row select 5) == _completedTurns} && {currentCommand _actor == "MOVE"}
        && {(expectedDestination _actor) isEqualTo (_row select 1)} && {formLeader _actor == (_row select 2)}
};
private _fit=(units _group) select {
    local _x && {[_x] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _x}
        && {simulationEnabled _x} && {!isObjectHidden _x}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!(_x in _unavailable)} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
        && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
        && {!_reconstructing || {currentCommand _x != "MOVE"} || {[_x] call _moveOwned}}
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
private _resumeMoves=[]; private _resumeSpots=[]; private _resumeProgress=[];
{
    if ([_x] call _moveOwned) then {
        private _row=_inheritedMoves get (netId _x);
        _nativeCommands set [netId _x,[_x,"MOVE",+(_row select 1),_row select 2,-1,[],+(_row select 3)]];
        _resumeMoves pushBack _x;
        _resumeSpots pushBack [_x,+(_row select 3)];
        _resumeProgress pushBack [_x,_row select 6,_row select 7,_row select 8,+(_row select 9)];
    };
} forEach _fit;
// Preserve established pairs before distributing orphans. Alternating individual roster
// entries split buddies formed by the parent operation. Keep every eligible role, including
// leaders and support weapons; a temporary reservation cannot pull its partner into the bound.
private _first=[];
private _second=[];
// Reconstructed bounds use the saved partition below, not a new ammunition ranking.
if (!_reconstructing) then {
private _remaining=+_fit;
private _chunks=[];
private _pairs=_group getVariable ["CBE_CombatPairs",[]];
if (_pairs isEqualType []) then {
    {
        if (_x isEqualType [] && {count _x == 2}
            && {(_x select 0) != (_x select 1)}
            && {_x findIf {!(_x in _remaining)} < 0}) then {
            _chunks pushBack +_x;
            _remaining=_remaining-_x;
        };
    } forEach (_pairs select [0,16]);
};
// Every remaining eligible actor is a singleton, including leaders/support roles.
{_chunks pushBack [_x]} forEach _remaining;
private _armed=_fit select {unitCombatMode _x in ["YELLOW","RED"]
    && {_x checkAIFeature "FIREWEAPON"} && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}};
private _ranked=_chunks apply {[_x,{_x in _armed} count _x]};
private _armedCounts=[0,0];
// At most64 chunks and three bounded passes. Distribute capacity before dry chunks,
// preserving whole pairs; headcount breaks equal-capacity ties deterministically.
// Dry chunks add no capacity: distribute them by headcount, not the armed deficit.
for "_capacity" from 2 to 0 step -1 do {
    {
        _x params ["_chunk","_count"];
        if (_count == _capacity) then {
            private _secondTeam=if (_capacity == 0) then {count _first > count _second} else {
                (_armedCounts select 0) > (_armedCounts select 1)
                    || {(_armedCounts select 0) == (_armedCounts select 1) && {count _first > count _second}}
            };
            private _team=[0,1] select _secondTeam;
            ([_first,_second] select _team) append _chunk;
            _armedCounts set [_team,(_armedCounts select _team)+_count];
        };
    } forEach _ranked;
};
};
// A three-person responder still fields a two-person first element and one-person cover.
if (count _first < count _second) then {
    private _swap=_first;_first=_second;_second=_swap;
};
// Preserve the original partition when reconstructing this server bound. Newcomers
// join the pending second element after the first has completed; completion grants no command authority.
if (_progress isNotEqualTo [] && {(_progress select 0) == _sequence}) then {
    private _savedTeams=_progress select 2;
    _first=(_savedTeams select 0) select {_x in _fit};
    _second=(_savedTeams select 1) select {_x in _fit};
    private _newcomers=_fit-(_first+_second);
    if (_completedTurns == 1) then {_second append _newcomers} else {
        {( [_first,_second] select (count _first > count _second)) pushBack _x} forEach _newcomers;
    };
};
if ((_completedTurns == 0 && {count _first < 2 || {count _second < 1}})
    || {_completedTurns == 1 && {count _first < 1 || {count _second < 1}}}) exitWith {false};
_operation set ["boundProgress",[_sequence,+_point,[+_first,+_second],_completedTurns]];
_group setVariable ["CBE_Operation",_operation,true];
private _token=format ["SUPPORT:%1:%2:%3",_leaseToken,_sequence,clientOwner];
_state set ["drill",createHashMapFromArray [
    ["token",_token],["supportToken",_leaseToken],["supportSequence",_sequence],
    ["operationGeneration",_generation],["ownerEpoch",_ownerEpoch],
    ["supportDeadline",_deadlineReceipt select 2],["supportClock",+_deadlineReceipt],
    ["nativeAdmissionChecked",true],["nativeCommands",_nativeCommands],
    ["resumeNativeMoves",_resumeMoves],["resumeSpots",_resumeSpots],["resumeProgress",_resumeProgress],
    ["type","ADVANCE"],["teams",[_first,_second]],["teamSizes",[count _first,count _second]],["teamTurn",_completedTurns],["units",_fit],["desiredStrength",count _fit],
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
