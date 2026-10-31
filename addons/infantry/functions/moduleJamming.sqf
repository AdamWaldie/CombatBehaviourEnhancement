/*
 * Author: WaldoTheWarfighter
 * Purpose: Issue a scoped AI radio-denial behaviour on the exact attached emitter.
 * Locality/authority: Placing interface/logic owner; server authenticates the actual curator.
 * Repeat/JIP: Disposable once-only frontend. Cancel sends nothing; no historical task replay.
 * Arguments: 0 logic OBJECT,objNull; 1 synchronized units ARRAY,[]; 2 activated BOOL,true.
 * Return Value: BOOL dialog opened, never server acceptance or physical radio effect.
 * Current callers: CBE_ModuleJamming native curator module; ZEN is optional.
 * Example: [jammerTaskLogic,[],true] call CBE_fnc_ModuleJamming;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}) exitWith {false};
if (_logic getVariable ["CBE_processed",false]) exitWith {false};
_logic setVariable ["CBE_processed",true];
private _emitter=attachedTo _logic;
private _opened=[_emitter] call CBE_fnc_JammingTaskDialog;
deleteVehicle _logic;
_opened
