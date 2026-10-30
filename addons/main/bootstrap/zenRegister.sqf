/*
 * Author: WaldoTheWarfighter
 * Registers targeted ZEN orders for the standalone AI package after ZEN is available.
 * Locality / Authority: Run on interface clients only. Order dialogs execute locally and send accepted
 * changes through the package's existing server-authoritative functions.
 * Repeat/JIP: A local version guard prevents duplicate module registration for JIP or repeat calls.
 * Arguments: None.
 * Return Value: BOOL - true when registered; false when ZEN is unavailable or no interface exists.
 * Current callers: XEH_postInit.sqf after CBA/ZEN initialization.
 * Example: [] execVM "\z\cbe\addons\main\bootstrap\zenRegister.sqf";
 */

if (!hasInterface || {isNil "zen_custom_modules_fnc_register"}) exitWith {false};
if (missionNamespace getVariable ["CBE_AITweaks_ZenRegisteredLocal", false]) exitWith {true};
missionNamespace setVariable ["CBE_AITweaks_ZenRegisteredLocal", true];

["Combat Behaviour Enhancement (CBE)", "Create AI Convoy", {
    _this call CBE_fnc_ZenConvoyModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Garrison area", {
    _this call CBE_fnc_ZenGarrisonModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Defend area", {
    _this call CBE_fnc_ZenDefendModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Position vehicle", {
    [_this select 0,_this select 1,false] call CBE_fnc_VehiclePointDialog;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Release vehicle position task", {
    [_this select 0,_this select 1,true] call CBE_fnc_VehiclePointDialog;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Advance to position", {
    _this call CBE_fnc_ZenPointAdvanceModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Withdraw to position", {
    [_this select 0,_this select 1,"WITHDRAW_POINT"] call CBE_fnc_ZenPointAdvanceModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Clear buildings in area", {
    _this call CBE_fnc_ZenClearAreaModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Clear building", {
    _this call CBE_fnc_ZenClearModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Navigation corridor", {
    _this call CBE_fnc_ZenDrivingCorridorModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Patrol area", {
    _this call CBE_fnc_ZenPatrolModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Cautious approach", {
    _this call CBE_fnc_ZenCreepModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Hunt known enemy", {
    _this call CBE_fnc_ZenHuntModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Press attack", {
    _this call CBE_fnc_ZenRushModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "Release infantry task", {
    _this call CBE_fnc_ZenReleaseModule;
}] call zen_custom_modules_fnc_register;
["Combat Behaviour Enhancement (CBE)", "AI radio denial", {
    [_this select 1] call CBE_fnc_JammingTaskDialog;
}] call zen_custom_modules_fnc_register;
true
