/*
 * Author: WaldoTheWarfighter
 * Purpose: Open an explicit selected-vehicle point/release behaviour dialog from native Zeus.
 * Locality/authority: Local curator interface; VehiclePointDialog sends authenticated task data.
 * Repeat/JIP: Disposable logic; one dialog, no request on cancel, no worker or historical replay.
 * Arguments: 0 logic OBJECT,objNull;1 synced units ARRAY,[];2 activated BOOL,true.
 * Return: BOOL dialog opened, not task or physical acceptance.
 * Current callers: CBE_ModuleVehiclePoint and CBE_ModuleVehiclePointRelease.
 * Example: [pointLogic,[],true] call CBE_fnc_ModuleVehiclePoint;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}
    || {_logic getVariable ["CBE_processed",false]}) exitWith {false};
_logic setVariable ["CBE_processed",true];
private _position=getPosATL _logic;private _target=attachedTo _logic;
private _order=getText (configOf _logic >> "CBE_operation");
deleteVehicle _logic;
if (!(_order in ["VEHICLE_POINT","VEHICLE_POINT_RELEASE"])) exitWith {false};
[_position,_target,_order == "VEHICLE_POINT_RELEASE"] call CBE_fnc_VehiclePointDialog
