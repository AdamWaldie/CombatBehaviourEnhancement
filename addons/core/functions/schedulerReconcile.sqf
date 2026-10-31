/*
 * Author: WaldoTheWarfighter
 * Maintains one shared callback and retains only jobs belonging to enabled owner-local runtimes.
 * Exact finite posture and already-issued grenade cleanup may outlive tactical disable;
 * no new tactical reaction is retained for them. Grenade cleanup remains one shot per projectile.
 * Locality / Authority: Local runtime lifecycle only; does not change CBA settings or other owners.
 * Repeat/JIP: Idempotent. Each joining owner creates its own callback after effective settings readiness.
 * Retained keyed wakeAt deadlines participate in the idle cache; unrelated lifecycle changes
 * cannot postpone a wake already raised by the current local operation.
 * Arguments: None.
 * Return Value: BOOL - true while at least one local runtime needs the scheduler.
 * Current callers: CortexInit/Stop, AIRebalanceInit/Stop, convoy lifecycle, owner-local aircraft
 * setup and CortexGrenadeCheck after queuing its finite already-issued evasion cleanup.
 * Example: [] call CBE_fnc_SchedulerReconcile;
 */
private _tactics = missionNamespace getVariable ["CBE_AIPass_Active", false];
private _skills = missionNamespace getVariable ["CBE_AI_RebalanceActive", false];
private _convoy = missionNamespace getVariable ["CBE_Convoy_SchedulerActive", false];
private _aircraft = (missionNamespace getVariable ["CBE_Aircraft_DecelerationSchedulerActive", false])
    || {missionNamespace getVariable ["CBE_Aircraft_LandingSchedulerActive", false]};
missionNamespace setVariable ["CBE_Aircraft_SchedulerActive", _aircraft];
private _generation = missionNamespace getVariable ["CBE_AI_LightingGeneration", 0];
private _earliest = -1;
private _posture=false;
private _settings=false;
private _holds=false;
private _grenade=false;
{
    private _retained = (missionNamespace getVariable [_x, []]) select {
        private _state = _x select 2;
        switch (_state getOrDefault ["subsystem", "TACTICS"]) do {
            case "SKILLS": {_skills && {(_state getOrDefault ["generation", -1]) == _generation}};
            case "CONVOY": {_convoy};
            case "AIRCRAFT": {_aircraft};
            case "POSTURE_CLEANUP": {
                private _postureGroup=_state getOrDefault ["group",grpNull];
                private _postureActors=_postureGroup getVariable ["CBE_Danger_StancePendingActors",[]];
                private _retain=!isNull _postureGroup && {local _postureGroup}
                    && {!(_state getOrDefault ["cancelled",false])} && {!(_state getOrDefault ["finished",false])}
                    && {!(_state getOrDefault ["done",false])}
                    && {(_state getOrDefault ["ownerEpoch",-1]) == (_postureGroup getVariable ["CBE_AIPass_Epoch",0])}
                    && {_postureActors isEqualType []} && {count _postureActors > 0} && {count _postureActors <= 64};
                if (_retain) then {_posture=true};
                _retain
            };
            case "GRENADE_CLEANUP": {
                // One existing callback per projectile, never a new reaction/controller.
                // Per-actor original owner/epoch/order proof stays in CortexGrenadeCheck.
                private _grenadeActors=_state getOrDefault ["regroup",[]];
                private _retain=_grenadeActors isEqualType [] && {count _grenadeActors > 0}
                    && {count _grenadeActors <= 16} && {!(_state getOrDefault ["cancelled",false])}
                    && {!(_state getOrDefault ["done",false])};
                if (_retain) then {_grenade=true};
                _retain
            };
            case "HOLD_CLEANUP": {
                private _holdGroup=_state getOrDefault ["group",grpNull];
                private _retain=!isNull _holdGroup && {local _holdGroup}
                    && {(_state getOrDefault ["ownerEpoch",-1]) == (_holdGroup getVariable ["CBE_AIPass_Epoch",0])}
                    && {!(_state getOrDefault ["done",false])};
                if (_retain) then {_holds=true};
                _retain
            };
            case "SETTINGS_CLEANUP": {
                private _settingsGroup=_state getOrDefault ["group",grpNull];
                private _garrisonCleanup=(_state getOrDefault ["kind","CLEAR"]) == "GARRISON";
                private _settingsPending=_settingsGroup getVariable [["CBE_Cortex_ClearSettingsPending",
                    "CBE_Cortex_GarrisonSettingsPending"] select _garrisonCleanup,[]];
                private _retain=!isNull _settingsGroup && {local _settingsGroup}
                    && {!(_state getOrDefault ["cancelled",false])}
                    && {(_state getOrDefault ["ownerEpoch",-1]) == (_settingsGroup getVariable ["CBE_AIPass_Epoch",0])}
                    && {_settingsPending isEqualType []}
                    && {if (_garrisonCleanup) then {count _settingsPending > 0 && {count _settingsPending <= 64}}
                        else {count _settingsPending == 4}};
                if (_retain) then {_settings=true};
                _retain
            };
            default {_tactics};
        }
    };
    {
        private _due = (_x select 0) min ((_x select 2) getOrDefault ["wakeAt",_x select 0]);
        if (_earliest < 0 || {_due < _earliest}) then {_earliest = _due};
    } forEach _retained;
    missionNamespace setVariable [_x, _retained];
} forEach ["CBE_AIPass_Jobs", "CBE_AIPass_PendingJobs"];
missionNamespace setVariable ["CBE_AIPass_NextJobDue", _earliest];
missionNamespace setVariable ["CBE_Danger_PostureSchedulerActive",_posture];
missionNamespace setVariable ["CBE_ActorSettings_SchedulerActive",_settings];
missionNamespace setVariable ["CBE_ClearHold_SchedulerActive",_holds];
missionNamespace setVariable ["CBE_Grenade_CleanupSchedulerActive",_grenade];
private _handle = missionNamespace getVariable "CBE_AIPass_SchedulerHandle";
if (_tactics || {_skills} || {_convoy} || {_aircraft} || {_posture} || {_settings} || {_holds} || {_grenade}) then {
    if (isNil "_handle") then {
        missionNamespace setVariable ["CBE_AIPass_SchedulerHandle",
            [{[] call CBE_fnc_CortexSchedulerTick}, 0] call CBA_fnc_addPerFrameHandler];
    };
} else {
    if (!isNil "_handle") then {
        [_handle] call CBA_fnc_removePerFrameHandler;
        missionNamespace setVariable ["CBE_AIPass_SchedulerHandle", nil];
    };
};
_tactics || {_skills} || {_convoy} || {_aircraft} || {_posture} || {_settings} || {_holds} || {_grenade}
