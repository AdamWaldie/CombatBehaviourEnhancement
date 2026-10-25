/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases exact-issued clearance setting leases independently of native movement tasks.
 * Locality/authority: Current group and actor owner; exact supplied clear generation/epoch.
 * Player, remote, mounted, reserved and specialist actors retain their settings/baselines.
 * Repeat/JIP: Captured metadata is consumed only after a safe restore or observed setting change.
 * Refused work may request one original30second retry window on the shared restoration-only scheduler.
 * Its actor issuer/deadline survives group generation/epoch changes; expired or malformed
 * nonempty windows cannot authorize further automatic restoration or be reset by re-admission.
 * One keyed cleanup callback survives tactical shutdown; no native movement, target or formation command.
 * Arguments: 0 actor OBJECT objNull;1 group GROUP grpNull;2 clear generation NUMBER -1;
 * 3 owner epoch NUMBER -1;4 allow finite deferral BOOL true.
 * Return: BOOL settings retired or absent; false retains baseline without changing controls.
 * Current callers: BuildingOperationStep, CortexClearRelease and GroupBrainStep.
 * Example: [_unit,_group,_generation,_epoch] call CBE_fnc_CortexClearSettingsRelease;
 */
params [["_actor",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_generation",-1,[0]],["_epoch",-1,[0]],["_defer",true,[true]]];
private _retired=false;
isNil {
    if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
    if (isNull _group || {!local _group} || {isNull _actor} || {group _actor != _group}
        || {!finite _generation} || {_generation < 0} || {!finite _epoch} || {_epoch < 0}
        || {_generation != (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
        || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",-1])}) exitWith {};
    private _hasSpeed=!isNil {_actor getVariable "CBE_Cortex_ClearForcedSpeed"};
    private _hasStance=!isNil {_actor getVariable "CBE_Cortex_ClearStance"};
    private _lease=_actor getVariable ["CBE_ActorSettings",[]];
    private _issuer=_actor getVariable ["CBE_Cortex_ClearSettingToken",""];
    if (!_hasSpeed && {!_hasStance} && {_lease isEqualTo []} && {_issuer isEqualTo ""}) exitWith {_retired=true};
    private _window=_actor getVariable ["CBE_Cortex_ClearSettingRetireUntil",[]];
    private _windowValid=_window isEqualType [] && {count _window == 2}
        && {(_window select 0) isEqualType ""} && {(_window select 1) isEqualType 0}
        && {finite (_window select 1)};
    if (_window isNotEqualTo [] && {!_windowValid
        || {(_window select 0) isEqualTo _issuer && {serverTime >= (_window select 1)}}}) exitWith {};
    if (_lease isEqualType [] && {count _lease == 3}
        && {(_lease select 0) isEqualType []} && {count (_lease select 0) == 5}
        && {_issuer isEqualType ""} && {_issuer != ""}
        && {((_lease select 0) select 0) isEqualTo _group}
        && {((_lease select 0) select 1) isEqualTo _issuer}) then {
        private _releaseContext=+(_lease select 0);
        // Only the actual new owner may release a portable old setting; this grants no replay.
        _releaseContext set [3,_epoch];
        private _status=["RELEASE",_actor,_releaseContext] call CBE_fnc_ActorSettings;
        if (_status == "RELEASED") then {
            {_actor setVariable [_x,nil,true]} forEach ["CBE_Cortex_ClearForcedSpeed",
                "CBE_Cortex_ClearAppliedSpeed","CBE_Cortex_ClearStance","CBE_Cortex_ClearSettingToken"];
            if (_windowValid && {(_window select 0) isEqualTo _issuer}
                && {(_actor getVariable ["CBE_Cortex_ClearSettingRetireUntil",[]]) isEqualTo _window}) then {
                _actor setVariable ["CBE_Cortex_ClearSettingRetireUntil",nil,true];
            };
            _retired=true;
        };
    };
    // Unknown/missing canonical state cannot turn surviving mirrors into a new baseline.
    if (!_retired && {_defer} && {_issuer isEqualType ""}) then {
        if (_window isEqualTo [] || {_windowValid && {(_window select 0) isNotEqualTo _issuer}}) then {
            _window=[_issuer,serverTime+30];
            _actor setVariable ["CBE_Cortex_ClearSettingRetireUntil",_window,true];
        };
        // The actor issuer, not a later clear generation, owns this original budget.
        private _until=_window select 1;
        private _pending=_group getVariable ["CBE_Cortex_ClearSettingsPending",[]];
        private _retiredEpisode=_pending isEqualType [] && {count _pending == 4}
            && {(_pending select 0) isEqualType 0} && {(_pending select 1) isEqualType 0}
            && {(_pending select 0) != _generation || {(_pending select 1) != _epoch}};
        if (_pending isEqualTo [] || {_retiredEpisode}) then {
            _group setVariable ["CBE_Cortex_ClearSettingsPending",[_generation,_epoch,_until,0],true];
        };
        private _cleanup=_group getVariable ["CBE_Cortex_ClearSettingsPending",[]];
        if (_cleanup isEqualType [] && {count _cleanup == 4}
            && {(_cleanup select 0) == _generation} && {(_cleanup select 1) == _epoch}
            && {(_cleanup select 2) isEqualType 0} && {finite (_cleanup select 2)}
            && {serverTime < (_cleanup select 2)}) then {
            [CBE_fnc_ActorSettingsCleanupStep,createHashMapFromArray [["group",_group],
                ["ownerEpoch",_epoch],["generation",_generation],["subsystem","SETTINGS_CLEANUP"]],
                0.25,"CLEAR_SETTINGS"] call CBE_fnc_CortexQueueJob;
            [] call CBE_fnc_SchedulerReconcile;
        };

    };
};
_retired
