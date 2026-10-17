/*
 * Author: WaldoTheWarfighter
 * Installs optional, repeat-safe locality handlers for AI helicopter cruise-deceleration correction.
 * The current vehicle owner samples through the one shared bounded scheduler and corrects an aircraft.
 * A Local event retires the prior generation and queues one owner-local step after server/headless-client
 * migration; JIP machines do not become a second authority.
 *
 * Improved Helicopter Landing always has priority. The tracker stands down for any supported landing
 * waypoint and the correction loop releases immediately if the landing controller becomes active.
 * Locality and authority: Each machine installs only its local detection handlers. Only the
 * aircraft's current owner queues sampling or changes flight velocity.
 * Repeat/JIP: The local installed flag prevents duplicate handlers. A joining machine starts
 * only the bounded sampling appropriate to aircraft it owns.
 *
 * Arguments: None.
 * Return Value: BOOL - true when installed/already installed; false while disabled.
 *
 * Example: Set CBE_HelicopterDeceleration_Enable=true in \z\cbe\addons\main\settings\aiConfig.sqf; CBE calls
 * [] call CBE_fnc_HelicopterDecelerationInit automatically from init.sqf.
 * Result: Returns true when handlers are installed or already present, and false while disabled.
 * Current caller: init.sqf on server, interface clients and headless clients after shared settings.
 */

if !(missionNamespace getVariable ["CBE_HelicopterDeceleration_Enable", false]) exitWith {false};
if (missionNamespace getVariable ["CBE_HelicopterDeceleration_HandlerInstalledLocal", false]) exitWith {true};
missionNamespace setVariable ["CBE_HelicopterDeceleration_HandlerInstalledLocal", true];

private _install = {
    params [["_aircraft", objNull, [objNull]]];
    if (isNull _aircraft) exitWith {};
    private _eligibleClass = _aircraft isKindOf "Helicopter"
        || {(missionNamespace getVariable ["CBE_HelicopterDeceleration_IncludeVTOL", false]) && {_aircraft isKindOf "VTOL_Base_F"}};
    if (!_eligibleClass || {getNumber (configOf _aircraft >> "isUav") != 0}) exitWith {};

    if !(_aircraft getVariable ["CBE_HelicopterDeceleration_LocalHandlerInstalled", false]) then {
        _aircraft setVariable ["CBE_HelicopterDeceleration_LocalHandlerInstalled", true];
        _aircraft addEventHandler ["Local", {
            params ["_aircraft", "_isLocal"];
            _aircraft setVariable ["CBE_HelicopterDeceleration_GenerationLocal", (_aircraft getVariable ["CBE_HelicopterDeceleration_GenerationLocal",0])+1];
            _aircraft setVariable ["CBE_HelicopterDeceleration_TrackedLocal", false];
            if (_isLocal) then {
                _aircraft setVariable ["CBE_HelicopterDeceleration_Active", false, true];
                _aircraft setVariable ["CBE_HelicopterDeceleration_TrackedLocal", true];
                missionNamespace setVariable ["CBE_Aircraft_DecelerationSchedulerActive", true];
                [] call CBE_fnc_SchedulerReconcile;
                [CBE_fnc_HelicopterDecelerationStep, createHashMapFromArray [
                    ["aircraft", _aircraft], ["generation", _aircraft getVariable ["CBE_HelicopterDeceleration_GenerationLocal",0]],
                    ["subsystem", "AIRCRAFT"], ["jobKey", "CBE_DECEL_" + netId _aircraft]
                ], 0.1, "CBE_DECEL_" + netId _aircraft] call CBE_fnc_CortexQueueJob;
            };
        }];
    };
    if (local _aircraft && {!(_aircraft getVariable ["CBE_HelicopterDeceleration_TrackedLocal", false])}) then {
        _aircraft setVariable ["CBE_HelicopterDeceleration_TrackedLocal", true];
        missionNamespace setVariable ["CBE_Aircraft_DecelerationSchedulerActive", true];
        [] call CBE_fnc_SchedulerReconcile;
        [CBE_fnc_HelicopterDecelerationStep, createHashMapFromArray [
            ["aircraft", _aircraft], ["generation", _aircraft getVariable ["CBE_HelicopterDeceleration_GenerationLocal",0]],
            ["subsystem", "AIRCRAFT"], ["jobKey", "CBE_DECEL_" + netId _aircraft]
        ], 0.1, "CBE_DECEL_" + netId _aircraft] call CBE_fnc_CortexQueueJob;
    };
};
missionNamespace setVariable ["CBE_HelicopterDeceleration_InstallLocal", _install];

["Helicopter", "init", {
    params ["_aircraft"];
    [_aircraft] call (missionNamespace getVariable ["CBE_HelicopterDeceleration_InstallLocal", {}]);
}, true, [], true] call CBA_fnc_addClassEventHandler;
if (missionNamespace getVariable ["CBE_HelicopterDeceleration_IncludeVTOL", false]) then {
    ["VTOL_Base_F", "init", {
        params ["_aircraft"];
        [_aircraft] call (missionNamespace getVariable ["CBE_HelicopterDeceleration_InstallLocal", {}]);
    }, true, [], true] call CBA_fnc_addClassEventHandler;
};
{[_x] call _install} forEach (vehicles select {
    _x isKindOf "Helicopter"
    || {(missionNamespace getVariable ["CBE_HelicopterDeceleration_IncludeVTOL", false]) && {_x isKindOf "VTOL_Base_F"}}
});
true
