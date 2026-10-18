/*
 * Author: WaldoTheWarfighter
 * Applies side effects after CBA changes a Combat Behaviour Enhancement (CBE) setting.
 * Locality / Authority: Called on every machine by a global CBA setting callback. Each machine may
 * only start or stop work it owns; the server remains responsible for cross-group coordination.
 * Repeat/JIP: Idempotent. PreInit callbacks update values but defer runtime work until postInit.
 * Counter-battery disable invalidates the server generation of delayed emission responses;
 * re-enable cannot revive those callbacks. Already issued native fire is a separate lifecycle.
 * Arguments: 0 setting name <STRING>; 1 new value <ANY>.
 * Return Value: BOOL - true when the change was accepted.
 * Current callers: callbacks registered by CBE_fnc_AITweaksRegisterSettings.
 * Example: ["CBE_AIPass_Enable", false] call CBE_fnc_AITweaksSettingChanged;
 */

params [["_name", "", [""]], "_value"];
if (_name == "") exitWith {false};
missionNamespace setVariable [_name, _value];
if !(missionNamespace getVariable ["CBE_AITweaks_PostInitComplete", false]) exitWith {true};

if (_name == "CBE_AIPass_Enable") then {
    if (_value) then {[] call CBE_fnc_CortexInit} else {[] call CBE_fnc_CortexStop};
};
// A quick off/on must not revive delayed radar fixes or observer wakes from the old
// counter-battery session. Only the server owns these callbacks and this generation.
if (_name == "CBE_AIPass_CounterBattery_Enable" && {isServer} && {_value isEqualTo false}) then {
    isNil {
        missionNamespace setVariable ["CBE_AIPass_CounterGeneration",
            (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])+1,true];
    };
};
// Relocation has its own per-purpose lifetime: closing scoot must not cancel firing,
// and closing counter-battery must not cancel unrelated support relocation.
if (isServer && {_value isEqualTo false}) then {
    private _scootGeneration=switch (_name) do {
        case "CBE_AIPass_Artillery_Enable";
        case "CBE_AIPass_Artillery_ShootAndScoot": {"CBE_ArtilleryScoot_SupportGeneration"};
        case "CBE_AIPass_CounterBattery_Enable";
        case "CBE_AIPass_CounterBattery_ShootAndScoot": {"CBE_ArtilleryScoot_CounterGeneration"};
        default {""};
    };
    if (_scootGeneration != "") then {
        isNil {missionNamespace setVariable [_scootGeneration,
            (missionNamespace getVariable [_scootGeneration,0])+1,true]};
    };
};
// These optional handlers must follow CBA changes immediately, including disable/re-enable.
// Reuse the guarded owner-local installer; ordinary tuning values remain live reads.
if (_name in ["CBE_AIPass_GrenadeEvasion_Enable", "CBE_AIPass_CivilianReaction_Enable"]
    && {missionNamespace getVariable ["CBE_AIPass_Active", false]}) then {
    [] call CBE_fnc_CortexInit;
};
// Danger assessment is a LIVE setting.  Discovery runs sparsely by design, so relying on its next
// sweep would leave disabled observers active, or newly enabled groups unobserved, for up to a
// full discovery interval.  Reuse the bounded, repeat-safe per-group installer on the current
// owner only; this changes listeners and the finite FSM generation, never the scheduler or route.
if (_name == "CBE_AIPass_Danger_Enable" && {missionNamespace getVariable ["CBE_AIPass_Active", false]}) then {
    {if (local _x) then {[_x] call CBE_fnc_DangerSetup}} forEach allGroups;
};
if (_name find "CBE_AIRebalance_" == 0 || {_name in ["CBE_AI_InfantryDispersion", "CBE_AI_VehicleCrewAimMultiplier", "CBE_AI_VehicleCrewDispersion", "CBE_AI_AirCrewDispersion"]}) then {
    if (missionNamespace getVariable ["CBE_AIRebalance_Enable", true]) then {
        [
            missionNamespace getVariable ["CBE_AIRebalance_Mode", "AUTO"],
            missionNamespace getVariable ["CBE_AIRebalance_Profile", "LINE"]
        ] call CBE_fnc_AIRebalanceInit;
    } else {
        [] call CBE_fnc_AIRebalanceStop;
    };
};
if (_name == "CBE_ImprovedHelicopterLanding_Enable") then {
    if (_value) then {
        [] call CBE_fnc_ImprovedHelicopterLandingInit;
        private _install = missionNamespace getVariable ["CBE_ImprovedHelicopterLanding_InstallLocal", {}];
        {if (local _x) then {[_x] call _install}} forEach vehicles;
    } else {
        {if (local _x && {_x isKindOf "Helicopter"}) then {
            _x setVariable ["CBE_ImprovedHelicopterLanding_TrackerGenerationLocal", (_x getVariable ["CBE_ImprovedHelicopterLanding_TrackerGenerationLocal",0])+1];
            _x setVariable ["CBE_ImprovedHelicopterLanding_TrackedLocal", false];
            [_x, false, "", true] call CBE_fnc_ImprovedHelicopterLandingRestoreLocal;
        }} forEach vehicles;
        missionNamespace setVariable ["CBE_Aircraft_LandingSchedulerActive", false];
        [] call CBE_fnc_SchedulerReconcile;
    };
};
if (_name == "CBE_HelicopterDeceleration_Enable") then {
    if (_value) then {
        [] call CBE_fnc_HelicopterDecelerationInit;
        private _install = missionNamespace getVariable ["CBE_HelicopterDeceleration_InstallLocal", {}];
        {if (local _x) then {[_x] call _install}} forEach vehicles;
    } else {
        // Retire generations before removing their jobs.  A re-enable therefore creates fresh
        // owner-local sampling rather than retaining a stale tracked flag or correction lease.
        {if (local _x && {_x isKindOf "Helicopter" || {_x isKindOf "VTOL_Base_F"}}) then {
            _x setVariable ["CBE_HelicopterDeceleration_GenerationLocal", (_x getVariable ["CBE_HelicopterDeceleration_GenerationLocal",0])+1];
            _x setVariable ["CBE_HelicopterDeceleration_TrackedLocal", false];
            _x setVariable ["CBE_HelicopterDeceleration_Active", false, true];
        }} forEach vehicles;
        missionNamespace setVariable ["CBE_Aircraft_DecelerationSchedulerActive", false];
        [] call CBE_fnc_SchedulerReconcile;
    };
};
true
