/*
 * Author: WaldoTheWarfighter
 * Purpose: Replaces unavailable tactical-role participants with capable surviving soldiers without dropping the active element from progress accounting.
 * Locality/authority: Reads only local actors and updates the current group operation on its owner.
 * Roster/pair publication atomically rechecks current operation and candidate native-task eligibility.
 * Newly enrolled replacements capture their platform; retained actors never rebind theirs.
 * Protected native tasks and strictly typed finite actor reservations cannot be recruited or retained as active role participants; an earlier roster entry does not override a newer finite owner.
 * Repeat/JIP: Idempotent for an unchanged generation and owner epoch. Only roster changes publish
 * operation state; unchanged callbacks do not retransmit it. Public state carries the roster after
 * migration; actors marked unavailable remain excluded.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 desired count <NUMBER>; 3 excluded actors <ARRAY, []>.
 * Return Value: ARRAY of capable local participants.
 * Current callers: bounding, clear-building and withdrawal recovery.
 * Example: [group player,4,4,[]] call CBE_fnc_RebalanceRoles;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_desired",0,[0]],["_excluded",[],[[]]]];
if (isNull _group || {!local _group}) exitWith {[]};
if ([_group] call CBE_fnc_CortexZeusHeld || {[_group] call CBE_fnc_CompatibilityExternalControl}) exitWith {[]};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {[]};
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])) exitWith {[]};
if ((_operation getOrDefault ["phase",""]) == "CANCELLED") exitWith {[]};
private _entryEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _entryParticipants=+(_operation getOrDefault ["participants",[]]);
private _entryUnavailable=+(_operation getOrDefault ["unavailable",[]]);
private _blocked=(_operation getOrDefault ["unavailable",[]])+_excluded;
private _actorEligible={
    params ["_actor"];
    private _reservationFree=!([_actor] call CBE_fnc_CortexActorMoveReserved);
    group _actor == _group && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {local _actor} && {!isPlayer _actor} && {isNull (remoteControlled _actor)}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""} && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {isNull objectParent _actor} && {!(_actor in _blocked)}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
        && {_reservationFree}
};
private _capable=(units _group) select {[_x] call _actorEligible};
// Narrow specialist ownership to an eligible ordinary candidate; player/Zeus/group control
// remains group-wide. No candidate means no role publication or replacement.
if (_capable isEqualTo [] || {[_group,false,_capable select 0] call CBE_fnc_CortexExternalTakeover}) exitWith {[]};
private _current=(_operation getOrDefault ["participants",[]]) select {_x in _capable};
{if (count _current < _desired && {!(_x in _current)}) then {_current pushBack _x}} forEach _capable;
// Candidate observation is scheduled. Publish roster and pairs only while the original
// operation still owns these participants and every proposed actor remains eligible.
private _result=[];
isNil {
    private _live=_group getVariable ["CBE_Operation",createHashMap];
    if (!local _group || {_entryEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {(_live getOrDefault ["generation",-2]) != _generation}
        || {(_live getOrDefault ["ownerEpoch",-1]) != _entryEpoch}
        || {(_live getOrDefault ["phase",""]) == "CANCELLED"}
        || {_live isNotEqualTo _operation}
        || {(_live getOrDefault ["participants",[]]) isNotEqualTo _entryParticipants}
        || {(_live getOrDefault ["unavailable",[]]) isNotEqualTo _entryUnavailable}
        || {_current findIf {!([_x] call _actorEligible)} >= 0}
        || {[_group] call CBE_fnc_CortexZeusHeld}
        || {[_group,false,_capable select 0] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
if (_current isNotEqualTo (_operation getOrDefault ["participants",[]])) then {
    // Start measuring replacements at commitment, not at a later scheduler callback.
    // Recruitment itself is not physical progress and must not renew the operation timer.
    private _progress=(_operation getOrDefault ["participantProgress",[]]) select {(_x select 0) in _current};
    {
        private _actor=_x;
        if (_progress findIf {(_x select 0) == _actor} < 0) then {
            _progress pushBack [_actor,getPosATL _actor];
        };
    } forEach _current;
    private _platforms=_operation getOrDefault ["participantPlatforms",createHashMap];
    _operation set ["participantPlatforms",createHashMapFromArray (_current apply {
        [netId _x,_platforms getOrDefault [netId _x,_x]]
    })];
    _operation set ["participantProgress",_progress];
    _operation set ["participants",_current];
    _operation set ["pairs",[_group,_current] call CBE_fnc_CombatPairs];
    _group setVariable ["CBE_Operation",_operation,true];
};
    _result=_current;
};
_result
