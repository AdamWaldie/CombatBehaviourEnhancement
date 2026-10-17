/*
 * Author: WaldoTheWarfighter
 * Bridges a supported external headless completion signal into CBE's neutral, destination-local handover event.
 * Locality / Authority: The external manager retains transfer authority. This bridge only emits after the engine
 * confirms group locality on the destination owner; it never selects an HC or changes ownership.
 * Repeat/JIP: Installs one repeat-safe listener per machine. Neutral events may arrive more than once; consumers
 * deduplicate by transfer revision and owner.
 * Arguments: None.
 * Return Value: BOOL - true when the bridge is installed or was already installed.
 * Current callers: CBE_fnc_CortexInit, CBE_fnc_AIRebalanceInit and CBE_fnc_ConvoySync.
 * Example: [] call CBE_fnc_CompatibilityHeadlessBridge;
 */
if (missionNamespace getVariable ["CBE_Compatibility_HeadlessBridgeInstalled", false]) exitWith {true};
missionNamespace setVariable ["CBE_Compatibility_HeadlessBridgeInstalled", true];

["Waldo_Headless_GroupMigrated", {
    params [
        ["_group", grpNull, [grpNull]],
        ["_previousOwner", 2, [0]],
        ["_newOwner", -1, [0]]
    ];
    if (isNull _group || {!isServer && {hasInterface}} || {clientOwner != _newOwner} || {!local _group}) exitWith {};
    ["CBE_Compatibility_HeadlessMigrated", [_group, _previousOwner, _newOwner, "COMPANION"]] call CBA_fnc_globalEvent;
}] call CBA_fnc_addEventHandler;

true
