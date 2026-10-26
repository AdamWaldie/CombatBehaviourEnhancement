/*
 * Author: WaldoTheWarfighter
 * Purpose: Retire an exact post-clear STOP after same-owner master shutdown without tactical work.
 * Locality/authority: Current local group/epoch, original generation, issuer and finite window.
 * Treatment, flight, dormancy and reservations defer handback; new orders/controllers win.
 * Repeat/JIP: One keyed shared-scheduler callback, one actor per pass, original30s server deadline.
 * At most one native follow request per actor; unacknowledged STOP retains proof until expiry.
 * No route reconstruction, world query, tactical admission or locality adoption. Expiry preserves
 * unresolved hold evidence but ends retries. Another owner cannot inherit this command authority.
 * Arguments: 0 state HASHMAP empty: group GROUP, ownerEpoch NUMBER, generation NUMBER,
 * window ARRAY [clearGeneration,epoch,serverExpiry,issuer], attempted ARRAY of actor objects.
 * Return: NUMBER .25 while pending, -1 when finished/refused.
 * Current callers: CortexSchedulerTick, queued by CortexStop after its controlled epoch edge.
 * Example: [_state] call CBE_fnc_ClearHoldCleanupStep;
 */
params [["_state",createHashMap,[createHashMap]]];
private _group=_state getOrDefault ["group",grpNull];
private _window=_state getOrDefault ["window",[]];
private _hold=_group getVariable ["CBE_Cortex_ClearHold",[]];
private _finish={_state set ["done",true];-1};
if (isNull _group || {!local _group} || {!(_window isEqualType [])} || {count _window != 4}
    || {!(_hold isEqualType [])} || {count _hold != 5}
    || {_window findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {(_window select 3) != clientOwner}
    || {(_window select 0) != (_state getOrDefault ["generation",-1])}
    || {(_window select 1) != (_state getOrDefault ["ownerEpoch",-1])}
    || {(_window select 1) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
    || {(_window select 0) != (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
    || {(_hold select [0,2]) isNotEqualTo (_window select [0,2])}
    || {(_group getVariable ["CBE_Cortex_ClearHoldRetire",[]]) isNotEqualTo _window}) exitWith {call _finish};
if (serverTime >= (_window select 2)) exitWith {
    _group setVariable ["CBE_Cortex_ClearHoldRetireResult",["UNRESOLVED",+_window],true];
    call _finish
};
// A successor owns its new state. Retirement metadata cannot authorise a return through it.
if ([_group] call CBE_fnc_CortexExternalTakeover
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}) exitWith {call _finish};
if (!((_hold select 3) isEqualType []) || {!((_hold select 4) isEqualType [])}
    || {count (_hold select 4) > 16}
    || {(_hold select 3) findIf {!(_x isEqualType objNull)} >= 0}
    || {(_hold select 4) findIf {!(_x isEqualType []) || {count _x != 2}
        || {!((_x select 0) isEqualType "")} || {!((_x select 1) isEqualType [])}
        || {count (_x select 1) != 3}
        || {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}) exitWith {call _finish};
private _actors=+(_hold select 3);
if (_actors isEqualTo [] || {count _actors > 16}) exitWith {call _finish};
private _actor=_actors deleteAt 0;
private _retain=false;
if (_actor isEqualType objNull && {!isNull _actor} && {group _actor == _group}
    && {alive _actor} && {!isPlayer _actor} && {isNull objectParent _actor}) then {
    if (!local _actor) then {_retain=true} else {
        private _holdJob=createHashMapFromArray [["group",_group],
            ["nativeHoldPositions",createHashMapFromArray (_hold select 4)]];
        if ([_actor,_holdJob] call CBE_fnc_BuildingActorHoldOwned
            && {!([_group,true,_actor] call CBE_fnc_CortexExternalTakeover)}) then {
            _retain=true;
            private _attempted=_state getOrDefault ["attempted",[]];
            private _leader=leader _group;
            if (!(_actor in _attempted) && {!isNull _leader} && {local _leader}
                && {[_leader] call CBE_fnc_CortexCombatEffective}
                && {[_actor] call CBE_fnc_CortexCombatEffective}
                && {simulationEnabled _actor} && {!isObjectHidden _actor}
                && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
                && {!fleeing _actor} && {isNull remoteControlled _actor}
                && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
                && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}) then {
                _attempted pushBack _actor;_state set ["attempted",_attempted];
                _group setVariable ["CBE_Cortex_ClearHoldRetireAttempts",[_window select 0,_window select 2,+_attempted],true];
                _actor doFollow _leader;
                // Readback is command acknowledgement only, never physical travel proof.
                _retain=currentCommand _actor == "STOP";
            };
        };
    };
};
if (_retain) then {_actors pushBack _actor};
private _remaining=+_hold;_remaining set [3,_actors];
_remaining set [4,(_hold select 4) select {(_x select 0) in (_actors apply {netId _x})}];
if (_actors isEqualTo []) exitWith {
    _group setVariable ["CBE_Cortex_ClearHold",nil,true];
    _group setVariable ["CBE_Cortex_ClearHoldRetire",nil,true];
    _group setVariable ["CBE_Cortex_ClearHoldRetireResult",["RETIRED",+_window],true];
    call _finish
};
_group setVariable ["CBE_Cortex_ClearHold",_remaining,true];
0.25
