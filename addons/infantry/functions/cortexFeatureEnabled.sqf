/*
 * Author: WaldoTheWarfighter
 * Resolves mission switches and per-group compatibility exclusions without enabling a globally disabled feature.
 * Locality/authority: read-only on the requesting owner unless stated below.
 * Repeat/JIP: no side effects; runtime gates are read again on every call.
 * Empty names, non-boolean settings and malformed exclusion containers refuse the feature.
 * Explicit exclusions return before the existing ownership marker check.
 * Arguments: 0: group <GROUP>, grpNull; 1: setting name <STRING>, empty; 2: fallback <BOOL>, false.
 * 3: optional driving vehicle <OBJECT>, objNull; its exclusion list can only disable an enabled aid.
 * Return Value: Boolean.
 * Current callers: AI behaviours, convoy controller and shared passenger checks.
 * Example: [_group, "CBE_AIPass_Reinforce_Enable", true] call CBE_fnc_CortexFeatureEnabled;
 */
params [["_group", grpNull, [grpNull]], ["_setting", "", [""]], ["_default", false, [true]], ["_vehicle",objNull,[objNull]]];
if (_setting == "") exitWith {false};
private _enabled=missionNamespace getVariable [_setting,_default];
if (!(_enabled isEqualType true) || {!_enabled}) exitWith {false};
private _disabled = if (isNull _group) then {[]} else {_group getVariable ["CBE_AIPass_DisabledFeatures", []]};
if (!(_disabled isEqualType []) || {"ALL" in _disabled} || {_setting in _disabled}) exitWith {false};
if (!isNull _vehicle) then {
    private _vehicleDisabled=_vehicle getVariable ["CBE_Driving_DisabledFeatures",[]];
    if (!(_vehicleDisabled isEqualType []) || {"ALL" in _vehicleDisabled}
        || {_setting in _vehicleDisabled}) exitWith {_enabled=false};
};
_enabled && {isNull _group || {!([_group] call CBE_fnc_CompatibilityExternalControl)}}
