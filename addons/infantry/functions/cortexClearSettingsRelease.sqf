/*
 * Author: WaldoTheWarfighter
 * Purpose: Releases unchanged clearance speed/posture independently of native movement tasks.
 * Locality/authority: Current group and actor owner; exact supplied clear generation/epoch.
 * Player, remote, mounted, reserved and specialist actors retain their settings/baselines.
 * Repeat/JIP: Captured metadata is consumed only after a safe restore or observed setting change.
 * Refused work may request one original30second group retry window on the existing group brain.
 * No new scheduler job, event handler, native movement, target or formation command is added.
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
    if (!_hasSpeed && {!_hasStance}) exitWith {_retired=true};
    private _safe=local _actor && {!isPlayer _actor} && {isNull objectParent _actor}
        && {isNull remoteControlled _actor}
        && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
        && {!([_group,true,_actor] call CBE_fnc_CortexExternalTakeover)};
    private _baseline=_actor getVariable ["CBE_Cortex_ClearForcedSpeed",-1];
    private _applied=_actor getVariable ["CBE_Cortex_ClearAppliedSpeed",[]];
    private _stance=_actor getVariable ["CBE_Cortex_ClearStance","AUTO"];
    private _typed=(!_hasSpeed || {_baseline isEqualType 0 && {finite _baseline}
        && {_applied isEqualType 0} && {finite _applied}})
        && {!_hasStance || {_stance isEqualType "" && {_stance in ["AUTO","UP","MIDDLE","DOWN"]}}};
    if (!_safe || {!_typed}) exitWith {
        if (_defer) then {
            private _pending=_group getVariable ["CBE_Cortex_ClearSettingsPending",[]];
            private _retiredEpisode=_pending isEqualType [] && {count _pending == 4}
                && {(_pending select 0) isEqualType 0} && {(_pending select 1) isEqualType 0}
                && {(_pending select 0) != _generation || {(_pending select 1) != _epoch}};
            if (_pending isEqualTo [] || {_retiredEpisode}) then {
                _group setVariable ["CBE_Cortex_ClearSettingsPending",[_generation,_epoch,serverTime+30,0],true];
            };
        };
    };
    // Releasing our unchanged cap/posture does not cancel a native treatment/boarding task.
    // A later different setting is preserved and ends this old lease without restoration.
    if (_hasSpeed && {abs ((getForcedSpeed _actor)-_applied) <= 0.1}) then {_actor forceSpeed _baseline};
    if (_hasStance && {unitPos _actor == "UP"}) then {_actor setUnitPos _stance};
    _actor setVariable ["CBE_Cortex_ClearForcedSpeed",nil,true];
    _actor setVariable ["CBE_Cortex_ClearAppliedSpeed",nil,true];
    _actor setVariable ["CBE_Cortex_ClearStance",nil,true];
    _retired=true;
};
_retired
