/*
 * Author: WaldoTheWarfighter
 * Purpose: Issue garrison, defence, finite patrol/Hunt/attack or scoped infantry release for an explicitly attached AI squad.
 * Locality/authority: placing interface/logic owner only; server authenticates the curator,
 * validates task parameters and forwards to the current group owner for acknowledgement.
 * Repeat/JIP: disposable, processed once. No historical task replay. With ZEN installed,
 * task-specific dialogs expose placement or facing/width. Without ZEN, garrison walks within
 * 50 m; patrol uses100m/four destinations/900s; defence uses a 60 m line facing the attached soldier's direction. Release uses
 * the existing owner-local infantry/patrol cleanup; it changes no addon settings.
 * Arguments: 0 logic <OBJECT>, objNull; 1 synced units <ARRAY>, []; 2 activated <BOOL>, true.
 * Return: BOOL - request/dialog admitted, not physical occupation success.
 * Current callers: CBE_ModuleGarrison, CBE_ModuleDefend, CBE_ModulePatrol, CBE_ModuleHunt, CBE_ModuleRush and CBE_ModuleRelease curator modules.
 * Example: [garrisonLogic,[],true] call CBE_fnc_ModuleGarrison;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}) exitWith {false};
if (_logic getVariable ["CBE_processed",false]) exitWith {false};
_logic setVariable ["CBE_processed",true];
private _target = attachedTo _logic;
private _position = getPosATL _logic;
if (isNull _target || {!(_target isKindOf "CAManBase")} || {isPlayer _target}) exitWith {
    ["AI ORDERS","Place this task on an AI soldier in the intended squad. No nearby squad is selected.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    deleteVehicle _logic;
    false
};
private _group = group _target;
private _order=getText (configFile >> "CfgVehicles" >> typeOf _logic >> "CBE_operation");
if (_order == "") then {_order="GARRISON"};
if !(_order in ["GARRISON","DEFEND","RELEASE","PATROL","HUNT","RUSH"]) exitWith {deleteVehicle _logic;false};
private _result = if (!isNil "zen_dialog_fnc_create") then {
    if (_order == "RUSH") exitWith {[_position,_target] call CBE_fnc_ZenRushModule};
    if (_order == "HUNT") exitWith {[_position,_target] call CBE_fnc_ZenHuntModule};
    if (_order == "PATROL") exitWith {[_position,_target] call CBE_fnc_ZenPatrolModule};
    if (_order == "RELEASE") then {[_position,_target] call CBE_fnc_ZenReleaseModule} else {
        if (_order == "DEFEND") then {[_position,_target] call CBE_fnc_ZenDefendModule}
        else {[_position,_target] call CBE_fnc_ZenGarrisonModule}
    }
} else {
    [[["order",_order],["group",_group],["position",_position],["radius",if (_order == "PATROL") then {100} else {50}],["huntRange",800],["rushDuration",180],["patrolNodes",4],["patrolDuration",900],["width",60],["facing",getDir _target],["teleport",false]],clientOwner] call CBE_fnc_CortexOrderDispatch
};
deleteVehicle _logic;
_result
