/*
 * Author: WaldoTheWarfighter
 * ENDEX/SafeStart pause yields before admission and again before the live retry commit;
 * the existing operation and unspent attempt survive without a new movement request.
 * Explicit Zeus interruption vetoes both preflight and final retry issue, independently of
 * specialist takeover detection; no retry budget is spent while the group is held.
 * Purpose: Makes one bounded native recovery attempt for a stalled participant without enabling disabled AI features, duplicating route commands or delaying the rest of its operation.
 * Locality/authority: Current group owner and current local participant only; local or trusted
 * server call. Final eligibility, strict reservation and live retry budget are checked inside
 * one unscheduled journal/move transaction. Nonfinite destinations are invalid.
 * Native fleeing, queued ACE care, hidden/simulation-disabled actors, native service/medical/assembly tasks and live finite actor reservations yield without a recovery command or consuming the retry budget. Actors outside the roster are invalid.
 * Repeat/JIP: Each actor receives one attempt per operation generation and owner epoch. The final command boundary rechecks takeover; actors with MOVE or PATH disabled are left untouched.
 * Arguments: 0 group <GROUP>; 1 generation <NUMBER>; 2 actor <OBJECT>; 3 destination <ARRAY, two or three numeric coordinates>.
 * Return Value: STRING - RECOVERING, EXHAUSTED, YIELDED or INVALID.
 * Current callers: Operation-backed manoeuvre and building jobs.
 * Example: [group player,4,soldier1,getPosATL player] call CBE_fnc_RecoveryStep;
 */
params [["_group",grpNull,[grpNull]],["_generation",-1,[0]],["_actor",objNull,[objNull]],["_destination",[],[[]]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _group} || {isNull _actor} || {!local _group} || {!local _actor} || {!(count _destination in [2,3])}
    || {_destination findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {"INVALID"};
if ([] call CBE_fnc_CortexIsPaused) exitWith {"YIELDED"};
// This is the final direct movement command in a recovery path. Recheck handover at the point of
// issue because a Zeus or specialist operation can arrive between an earlier operation step and
// this isolated retry. Recovery must retire rather than overwrite the newer controller's route.
if ([_group,false,_actor] call CBE_fnc_CortexExternalTakeover
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {[_group] call CBE_fnc_CortexZeusHeld}) exitWith {"YIELDED"};
if (group _actor != _group || {vehicle _actor != _actor} || {!([_actor] call CBE_fnc_CortexCombatEffective)}) exitWith {"INVALID"};
if (!(_actor checkAIFeature "MOVE") || {!(_actor checkAIFeature "PATH")}
    || {!(simulationEnabled _actor)} || {isObjectHidden _actor}) exitWith {"YIELDED"};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if ((_operation getOrDefault ["phase",""]) == "CANCELLED") exitWith {"INVALID"};
if (count _operation == 0 || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {"INVALID"};
if ((_operation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])
    || {!(_actor in (_operation getOrDefault ["participants",[]]))}) exitWith {"INVALID"};
if (_actor in (_operation getOrDefault ["unavailable",[]])) exitWith {"EXHAUSTED"};
if (fleeing _actor || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}) exitWith {"YIELDED"};
private _reserved={[_actor] call CBE_fnc_CortexActorMoveReserved};
if (call _reserved) exitWith {"YIELDED"};
private _recovery=_operation getOrDefault ["recovery",createHashMap];
private _key=netId _actor;
private _previous=_recovery getOrDefault [_key,[]];
private _used=_operation getOrDefault ["recoveryAttempts",createHashMap];
private _attempts=(if (_previous isEqualType []) then {_previous param [0,0]} else {_previous}) max (_used getOrDefault [_key,0]);
if (_attempts >= 1) exitWith {"EXHAUSTED"};
// Commit the retry journal and sole native move in one unscheduled authority boundary.
// A yielding callback consumes no new attempt; existing generation budgets are never renewed.
private _result="YIELDED";
isNil {
    _result=call {
        if (isNull _group || {isNull _actor} || {!local _group} || {!local _actor}
            || {group _actor != _group} || {vehicle _actor != _actor}
            || {!([_actor] call CBE_fnc_CortexCombatEffective)}) exitWith {"INVALID"};
        if ([_group,false,_actor] call CBE_fnc_CortexExternalTakeover
            || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {[_group] call CBE_fnc_CortexZeusHeld}) exitWith {"YIELDED"};
        if ([] call CBE_fnc_CortexIsPaused) exitWith {"YIELDED"};
        private _currentOperation=_group getVariable ["CBE_Operation",createHashMap];
        if ((_currentOperation getOrDefault ["phase",""]) == "CANCELLED"
            || {count _currentOperation == 0}
            || {(_currentOperation getOrDefault ["generation",-2]) != _generation}
            || {(_currentOperation getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {!(_actor in (_currentOperation getOrDefault ["participants",[]]))}) exitWith {"INVALID"};
        if (_actor in (_currentOperation getOrDefault ["unavailable",[]])) exitWith {"EXHAUSTED"};
        if (fleeing _actor || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
            || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {"YIELDED"};
        if (call _reserved) exitWith {"YIELDED"};
        if (!(_actor checkAIFeature "MOVE") || {!(_actor checkAIFeature "PATH")}
            || {!(simulationEnabled _actor)} || {isObjectHidden _actor}) exitWith {"YIELDED"};
        // Another callback may have spent the attempt since preflight. Read the live budget again.
        _recovery=_currentOperation getOrDefault ["recovery",createHashMap];
        _used=_currentOperation getOrDefault ["recoveryAttempts",createHashMap];
        _previous=_recovery getOrDefault [_key,[]];
        _attempts=(if (_previous isEqualType []) then {_previous param [0,0]} else {_previous}) max (_used getOrDefault [_key,0]);
        if (_attempts >= 1) exitWith {"EXHAUSTED"};
        _used set [_key,_attempts+1];
        _recovery set [_key,[_attempts+1,time,+_destination,getPosATL _actor]];
        _currentOperation set ["recoveryAttempts",_used];
        _currentOperation set ["recovery",_recovery];
        _group setVariable ["CBE_Operation",_currentOperation,true];
        _actor doMove _destination;
        "RECOVERING"
    };
    false
};
_result
