/*
 * Author: WaldoTheWarfighter
 * Purpose: Finish exact clearance/garrison setting handback independently of tactical enablement.
 * Locality/authority: Current group owner/epoch and explicit cleanup kind only; ActorSettings
 * validates the actual local actor, issuer and unchanged native setting before restoration.
 * Repeat/JIP: One keyed shared-scheduler job per cleanup kind; original30s windows are never renewed.
 * At most64 members/queued actors are inspected and one actor is offered per callback. No movement,
 * targeting, task replay, world query or per-actor worker. Expiry retains actor proof.
 * A canonical lease with the matching original clearance-retirement issuer stays eligible
 * even if convenience mirrors are absent; unrelated canonical settings are not clearance work.
 * Arguments: 0 job HASHMAP, empty; group GROUP, ownerEpoch NUMBER, generation NUMBER; kind STRING CLEAR/GARRISON (CLEAR default).
 * Return: NUMBER .25 while pending, otherwise -1 to retire.
 * Current callers: CortexSchedulerTick, queued by settings release, CortexStop and CortexLocality.
 * Example: [createHashMapFromArray [["group",group soldier1],["ownerEpoch",0],["generation",1]]]
 *     call CBE_fnc_ActorSettingsCleanupStep;
 */
params [["_state",createHashMap,[createHashMap]]];
private _group=_state getOrDefault ["group",grpNull];
if (isNull _group || {!local _group}
    || {(_state getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",-1])}) exitWith {-1};
private _kind=_state getOrDefault ["kind","CLEAR"];
if (!(_kind in ["CLEAR","GARRISON"])) exitWith {-1};
if (_kind == "GARRISON") exitWith {
    private _pendingGarrison=_group getVariable ["CBE_Cortex_GarrisonSettingsPending",[]];
    if (!(_pendingGarrison isEqualType []) || {_pendingGarrison isEqualTo []}
        || {count _pendingGarrison > 64}) exitWith {-1};
    // Publish the pop before delegating. Refused work keeps the original actor window;
    // no release callback may recreate or extend it through this observation-only path.
    private _actor=_pendingGarrison deleteAt 0;
    _group setVariable ["CBE_Cortex_GarrisonSettingsPending",_pendingGarrison,true];
    if (_actor isEqualType objNull && {!isNull _actor} && {group _actor == _group}) then {
        private _window=_actor getVariable ["CBE_Cortex_GarrisonSettingRetireUntil",[]];
        if (_window isEqualType [] && {count _window == 2}
            && {(_window select 0) isEqualTo (_actor getVariable ["CBE_Cortex_GarrisonSettingToken",""])}
            && {(_window select 1) isEqualType 0} && {finite (_window select 1)}
            && {serverTime < (_window select 1)}) then {
            private _status=[_actor,_group,"RELEASE",createHashMap,false] call CBE_fnc_CortexGarrisonSettings;
            if (!(_status in ["RELEASED","ABSENT"])) then {
                private _remaining=_group getVariable ["CBE_Cortex_GarrisonSettingsPending",[]];
                if (_remaining isEqualType [] && {count _remaining < 64} && {!(_actor in _remaining)}) then {
                    _remaining pushBack _actor;
                    _group setVariable ["CBE_Cortex_GarrisonSettingsPending",_remaining,true];
                };
            };
        };
    };
    if ((_group getVariable ["CBE_Cortex_GarrisonSettingsPending",[]]) isEqualTo []) then {-1} else {0.25}
};
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
        || {
            private _clearWindow=_x getVariable ["CBE_Cortex_ClearSettingRetireUntil",[]];
            private _canonical=_x getVariable ["CBE_ActorSettings",[]];
            _clearWindow isEqualType [] && {count _clearWindow == 2}
                && {(_clearWindow select 0) isEqualType ""} && {(_clearWindow select 0) != ""}
                && {(_clearWindow select 1) isEqualType 0} && {finite (_clearWindow select 1)}
                && {_canonical isEqualType []} && {count _canonical == 3}
                && {(_canonical select 0) isEqualType []} && {count (_canonical select 0) == 5}
                && {((_canonical select 0) select 0) isEqualTo _group}
                && {((_canonical select 0) select 1) isEqualTo (_clearWindow select 0)}
        }
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
