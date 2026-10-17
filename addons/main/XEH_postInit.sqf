/*
 * Author: WaldoTheWarfighter
 * Starts enabled Combat Behaviour Enhancement (CBE) systems after CBA and the mission have initialized.
 * Locality / Authority: Runs on every machine. AI owners install local handlers; the server owns
 * cross-group Cortex decisions; interface clients install Zeus interruption and optional ZEN controls.
 * Repeat/JIP: Guarded per machine. JIP and locality-aware systems perform their own repeat-safe adoption.
 * Arguments: None.
 * Return Value: BOOL - true once this machine has started the enabled systems.
 * Current callers: Extended_PostInit_EventHandlers in config.cpp and the settings-initialized callback.
 * Example: call compile preprocessFileLineNumbers "\z\cbe\addons\main\XEH_postInit.sqf";
 */

if !(missionNamespace getVariable ["CBE_AITweaks_SettingsReady", false]) exitWith {false};
if (missionNamespace getVariable ["CBE_AITweaks_PostInitComplete", false]) exitWith {true};
missionNamespace setVariable ["CBE_AITweaks_PostInitComplete", true];
[] call CBE_fnc_AITweaksDetectCompatibility;
// Recovery observation remains installed when tactics stops. Native events do no scanning or
// movement; a receipt-free actor costs only its init/Local callback and one handler slot.
["CAManBase","init",{
    params ["_actor"];
    if (isNil {_actor getVariable "CBE_AirPilotFeatureLocalEH"}) then {
        _actor setVariable ["CBE_AirPilotFeatureLocalEH",_actor addEventHandler ["Local",{
            _this call CBE_fnc_CortexAirPilotFeatureAdopt;
        }]];
    };
    [_actor,local _actor] call CBE_fnc_CortexAirPilotFeatureAdopt;
},true,[],true] call CBA_fnc_addClassEventHandler;


if (missionNamespace getVariable ["CBE_AIRebalance_Enable", true]) then {
    [
        missionNamespace getVariable ["CBE_AIRebalance_Mode", "AUTO"],
        missionNamespace getVariable ["CBE_AIRebalance_Profile", "LINE"]
    ] call CBE_fnc_AITweak;
};
if (missionNamespace getVariable ["CBE_ImprovedHelicopterLanding_Enable", true]) then {
    [] call CBE_fnc_ImprovedHelicopterLandingInit;
};
if (missionNamespace getVariable ["CBE_HelicopterDeceleration_Enable", false]) then {
    [] call CBE_fnc_HelicopterDecelerationInit;
};
if ((isServer || {!hasInterface}) && {missionNamespace getVariable ["CBE_AIPass_Enable", true]}) then {
    [] call CBE_fnc_CortexInit;
};
if (hasInterface) then {
    [] call CBE_fnc_CortexZeusWatchLocal;
    [] execVM "\z\cbe\addons\main\bootstrap\zenRegister.sqf";
};

diag_log format ["[Combat Behaviour Enhancement (CBE)] Started on owner %1 (server=%2 interface=%3 HC=%4).",
    clientOwner, isServer, hasInterface, !isServer && {!hasInterface}];
true
