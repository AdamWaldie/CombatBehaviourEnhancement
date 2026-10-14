/*
 * Author: WaldoTheWarfighter
 * Purpose: Dispatches a native curator driving control on the explicitly attached AI vehicle.
 * Locality / Authority: Placing interface only; server request handler authenticates curator and validates target.
 * Repeat/JIP: Revisioned group exclusion state is public; command effects are owner-local.
 * No JIP command replay. Repeated and stale acknowledgements cannot replace newer requests.
 * Arguments: 0 logic <OBJECT, objNull>; 1 units <ARRAY, []>; 2 activated <BOOL, true>.
 * Return Value: BOOL - dispatch only.
 * Current callers: WAIT_ModuleDrivingEnable/Release/Inspect.
 * Example: [logic1,[],true] call WAIT_fnc_ModuleDriving;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}) exitWith {false};
if (_logic getVariable ["WAIT_processed",false]) exitWith {false};
_logic setVariable ["WAIT_processed",true];
private _target=attachedTo _logic;
private _operation=getText (configFile >> "CfgVehicles" >> typeOf _logic >> "WAIT_operation");
private _result=[_target,[["operation",_operation]]] call WAIT_fnc_DrivingControlRequest;
deleteVehicle _logic;
_result
