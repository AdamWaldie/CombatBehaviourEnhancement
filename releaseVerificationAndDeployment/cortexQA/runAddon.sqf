/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify standalone addon initialization, settings catalogue and dependency support.
 * Locality/authority: Dedicated server; reads initialized production state.
 * Repeat/JIP: Each fresh audit runs once; no settings are mutated by these assertions.
 * Arguments: 0 check callback <CODE>, required. Return: Nothing.
 * Current callers: cortexQAServer.sqf. Example: [_check] call compile preprocessFileLineNumbers "cortexQAAddon.sqf";
 */
params ["_check"];
["ADDON-cba-dependency",isClass (configFile >> "CfgPatches" >> "cba_main")] call _check;
["ADDON-optional-dialog-dependency",!("zen_main" in getArray (configFile >> "CfgPatches" >> "CBE_AI_Tweaks_Main" >> "requiredAddons"))] call _check;
["ADDON-native-convoy-orders",["CBE_ModuleConvoyStart", "CBE_ModuleConvoyHold", "CBE_ModuleConvoyRelease"] findIf {
    getNumber (configFile >> "CfgVehicles" >> _x >> "scopeCurator") != 2
} < 0] call _check;
["ADDON-settings-ready",missionNamespace getVariable ["CBE_AITweaks_SettingsReady",false]] call _check;
["ADDON-postinit-ready",missionNamespace getVariable ["CBE_AITweaks_PostInitComplete",false]] call _check;
private _spec=[] call CBE_fnc_CortexTuningSpec;
["ADDON-setting-values-installed",_spec findIf {isNil {missionNamespace getVariable (_x select 0)}} < 0] call _check;
private _keys=_spec apply {_x select 0};
["ADDON-setting-keys-unique",count _keys == count (_keys arrayIntersect _keys)] call _check;
// Exercise the shared command-boundary predicate before any behavioural fixture is created.
// Config compilation cannot detect a valid SQF expression that returns CODE instead of BOOL;
// letting the suite continue after that failure only produces unrelated downstream timeouts.
private _probeGroup=createGroup [civilian,true];
private _takeoverResult=[_probeGroup] call CBE_fnc_CortexExternalTakeover;
deleteGroup _probeGroup;
["ADDON-command-boundary-boolean",_takeoverResult isEqualType true,typeName _takeoverResult] call _check;

// Configuration visibility only; this does not establish weapon lethality or player accuracy.
private _policyLoaded=isClass (configFile >> "CfgPatches" >> "CBE_policy_turret_aiming");
private _policyReport=[] call CBE_fnc_AIGetDiagnostics;
private _policyRows=(_policyReport getOrDefault ["checks",[]]) select {(_x param [1,""]) == "engine-policy-turret-aiming"};
["ADDON-engine-policy-diagnostic-visible",count _policyRows == 1] call _check;
["ADDON-engine-policy-diagnostic-effective",count _policyRows == 1 && {
    (_policyRows select 0) param [2,""] == (["DISABLED","LOADED"] select _policyLoaded)
},str _policyRows] call _check;
// Effective config only, not observed suppression recovery or combat balance.
private _suppressionLoaded=isClass (configFile >> "CfgPatches" >> "CBE_policy_suppression");
private _suppressionRows=(_policyReport getOrDefault ["checks",[]]) select {(_x param [1,""]) == "engine-policy-suppression"};
["ADDON-suppression-policy-diagnostic",count _suppressionRows == 1 && {
    (_suppressionRows select 0) param [2,""] == (["DISABLED","LOADED"] select _suppressionLoaded)
},str _suppressionRows] call _check;
