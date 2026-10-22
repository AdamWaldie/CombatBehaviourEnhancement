/*
 * Author: WaldoTheWarfighter
 * Purpose: Finish exact post-clear speed/stance handback independently of tactical enablement.
 * Locality/authority: Current group owner/epoch and clearance generation only; ActorSettings
 * validates the actual local actor, issuer and unchanged native setting before restoration.
 * Repeat/JIP: One keyed shared-scheduler job; original public30s window is never renewed.
 * At most64 members are inspected and one actor is offered per callback. No movement,
 * targeting, task replay, world query or per-actor worker. Expiry retains actor proof.
 * Arguments: 0 job HASHMAP, empty; group GROUP, ownerEpoch NUMBER, generation NUMBER.
 * Return: NUMBER .25 while pending, otherwise -1 to retire.
 * Current callers: CortexSchedulerTick, queued by CortexClearSettingsRelease, CortexStop and CortexLocality.
 * Example: [createHashMapFromArray [["group",group soldier1],["ownerEpoch",0],["generation",1]]]
 *     call CBE_fnc_CortexClearSettingsStep;
 */
params [["_state",createHashMap,[createHashMap]]];
private _group=_state getOrDefault ["group",grpNull];
if (isNull _group || {!local _group}) exitWith {-1};
private _pending=_group getVariable ["CBE_Cortex_ClearSettingsPending",[]];
private _valid=_pending isEqualType [] && {count _pending == 4}
    && {[0,1,2,3] findIf {!((_pending select _x) isEqualType 0) || {!finite (_pending select _x)}} < 0};
if (!_valid || {(_pending select 0) != (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
    || {(_pending select 1) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
    || {(_state getOrDefault ["ownerEpoch",-1]) != (_pending select 1)}
    || {(_state getOrDefault ["generation",-1]) != (_pending select 0)}) exitWith {-1};
if (serverTime >= (_pending select 2)) exitWith {
    _group setVariable ["CBE_Cortex_ClearSettingsResult",["WINDOW_EXPIRED",serverTime,+_pending],true];
    _group setVariable ["CBE_Cortex_ClearSettingsPending",nil,true];
    -1
};
if ((_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []
    || {count (_group getVariable ["CBE_BuildingBrain",createHashMap]) > 0}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}) exitWith {0.25};
private _members=units _group;
if (count _members > 64) exitWith {0.25};
private _actors=_members select {
    !isNil {_x getVariable "CBE_Cortex_ClearForcedSpeed"}
        || {!isNil {_x getVariable "CBE_Cortex_ClearStance"}}
        || {!isNil {_x getVariable "CBE_Cortex_ClearSettingToken"}}
};
if (_actors isEqualTo []) exitWith {
    _group setVariable ["CBE_Cortex_ClearSettingsPending",nil,true];
    _group setVariable ["CBE_Cortex_ClearSettingsResult",["RETIRED",serverTime,+_pending],true];
    -1
};
private _cursor=(floor (_pending select 3)) max 0;
[_actors select (_cursor mod count _actors),_group,_pending select 0,_pending select 1,false]
    call CBE_fnc_CortexClearSettingsRelease;
if ((_group getVariable ["CBE_Cortex_ClearSettingsPending",[]]) isNotEqualTo _pending) exitWith {-1};
_pending set [3,_cursor+1];
_group setVariable ["CBE_Cortex_ClearSettingsPending",_pending,true];
0.25
