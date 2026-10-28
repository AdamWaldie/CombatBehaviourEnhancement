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
// Recovery observation remains installed when tactics stops. Native events do no scanning;
// exact receipts permit feature restoration or finite accepted chute deployment only.
// A receipt-free actor costs only its init/Local callback and one handler slot.
["CAManBase","init",{
    params ["_actor"];
    if (isNil {_actor getVariable "CBE_AirPilotFeatureLocalEH"}) then {
        _actor setVariable ["CBE_AirPilotFeatureLocalEH",_actor addEventHandler ["Local",{
            [_this select 0,false,true] call CBE_fnc_CortexCivilianSetup;
            _this call CBE_fnc_CortexAirPilotFeatureAdopt;
            _this call CBE_fnc_DrivingRecoveryCrewAdopt;
            [_this select 0] call CBE_fnc_CortexParachuteProtectionRelease;
            [_this select 0] call CBE_fnc_CortexParachuteDeploy;
            [_this select 0] call CBE_fnc_CortexParachuteObserve;
        }]];
    };
    // This passive class/Local hook exists on every machine, including a future owner.
    // Civilian setup remains gated by actual locality and the active feature.
    [_actor] call CBE_fnc_CortexCivilianSetup;
    [_actor,local _actor] call CBE_fnc_CortexAirPilotFeatureAdopt;
    [_actor,local _actor] call CBE_fnc_DrivingRecoveryCrewAdopt;
    [_actor] call CBE_fnc_CortexParachuteProtectionRelease;
    [_actor] call CBE_fnc_CortexParachuteDeploy;
    [_actor] call CBE_fnc_CortexParachuteObserve;
},true,[],true] call CBA_fnc_addClassEventHandler;

// Driving cleanup adoption stays available with tactical scheduling disabled.
// Only the actual vehicle Local edge supplies disabled-mode source identity; init/crew callbacks cannot invent it.
// Init/Local/GetIn/SeatSwitched install once per native vehicle; no polling or movement replay.
["LandVehicle","init",{
    params ["_vehicle"];
    if (isNil {_vehicle getVariable "CBE_DrivingRecovery_LocalEH"}) then {
        _vehicle setVariable ["CBE_DrivingRecovery_LocalEH",_vehicle addEventHandler ["Local",{
            [_this select 0,_this select 1,0,-1,true] call CBE_fnc_DrivingRecoveryAdopt;
            if (_this select 1) then {
                // Forget private old-host carriage; locality itself grants no new cargo consent.
                private _platform=_this select 0;
                _platform setVariable ["CBE_Cortex_MechBoardSerial",(_platform getVariable ["CBE_Cortex_MechBoardSerial",0])+1];
                _platform setVariable ["CBE_Cortex_MechCargo",nil];
                _platform setVariable ["CBE_Cortex_MechRemoteManifest",nil];
                _platform setVariable ["CBE_Cortex_MechRemoteReplies",nil];
                _platform setVariable ["CBE_Cortex_MechRemoteOffer",nil,true];
            };
        }]];
    };
    // A crew member can board or change driving seats after locality has settled.
    // Native vehicle events offer only those actual local seats to existing cleanup.
    // GetIn also retires old cargo origin; SeatSwitched must never create a fresh carriage episode.
    if (isNil {_vehicle getVariable "CBE_DrivingRecovery_GetInEH"}) then {
        _vehicle setVariable ["CBE_DrivingRecovery_GetInEH",_vehicle addEventHandler ["GetIn",{
            params ["_vehicle","_role","_actor"];
            [_vehicle,_actor] call CBE_fnc_CortexMechanisedBoarded;
            [_actor,true] call CBE_fnc_DrivingRecoveryCrewAdopt;
        }]];
    };
    if (isNil {_vehicle getVariable "CBE_DrivingRecovery_SeatEH"}) then {
        _vehicle setVariable ["CBE_DrivingRecovery_SeatEH",_vehicle addEventHandler ["SeatSwitched",{
            params ["_vehicle","_first","_second"];
            [_first,true] call CBE_fnc_DrivingRecoveryCrewAdopt;
            [_second,true] call CBE_fnc_DrivingRecoveryCrewAdopt;
        }]];
    };
    [_vehicle,local _vehicle] call CBE_fnc_DrivingRecoveryAdopt;
},true,[],true] call CBA_fnc_addClassEventHandler;

if (missionNamespace getVariable ["CBE_AIRebalance_Enable", false]) then {
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
