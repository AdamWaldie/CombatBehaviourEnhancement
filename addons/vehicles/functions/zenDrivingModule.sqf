/*
 * Author: WaldoTheWarfighter
 * Purpose: Shows labelled ordinary-driving controls for an explicitly selected AI vehicle.
 * Locality / Authority: Interface dialog only; selected operation is validated on the server and executed on current owner.
 * Repeat/JIP: Revisioned group exclusion state is public; command effects are owner-local.
 * No JIP command replay. Repeated and stale acknowledgements cannot replace newer requests.
 * Arguments: 0 position <ARRAY, []>; 1 target <OBJECT, objNull>.
 * Return Value: Nothing.
 * Current callers: bootstrap/zenRegister.sqf.
 * Example: [getPosATL truck1,truck1] call WAIT_fnc_ZenDrivingModule;
 */
params [["_position",[],[[]]],["_target",objNull,[objNull]]];
if (!hasInterface || {isNil "zen_dialog_fnc_create"}) exitWith {};
if (isNull _target || {!(_target isKindOf "LandVehicle")} || {isNull driver _target}) exitWith {
    ["DRIVING","Place this control on a crewed AI land vehicle.","ERROR"] call WAIT_fnc_AITweaksNotifyLocal
};
["Ordinary AI driving",[["COMBO",["Operation","Enable respects global settings and native routes. Release excludes this group from ordinary driving; convoy controls are separate. Inspect reports admission/state, not physical success."],
    [["INSPECT","ENABLE","RELEASE"],["Inspect current driving state","Enable ordinary driving","Release ordinary driving"],0]]],
    {params ["_values","_target"];[_target,[["operation",_values select 0]]] call WAIT_fnc_DrivingControlRequest;},
    {},_target] call zen_dialog_fnc_create;
