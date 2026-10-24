/*
 * Author: WaldoTheWarfighter
 * Purpose: Request an immediate airborne insertion for an explicitly attached AI cargo passenger's squad.
 * Locality/authority: Placing interface/logic owner only. Authenticated server dispatch binds
 * the selected passenger and aircraft; the current squad owner rechecks both before the existing drop.
 * Altitude, dry land, AI pilots, external ownership and current task admission remain with that executor.
 * This explicit order can bypass automatic contact/landing timing, never the physical drop guards.
 * Repeat/JIP: Disposable module processes once and is deleted after request/refusal. Existing serial,
 * deadline and owner acknowledgement reject stale requests; no historical drop is replayed for JIP.
 * Arguments: 0 logic OBJECT,objNull; 1 synchronized units ARRAY,[]; 2 activated BOOL,true.
 * Return: BOOL request submitted, not owner acceptance, jump, landing or combat success.
 * Current caller: CBE_ModuleAirborne native curator module, with or without ZEN.
 * Example: [airborneTaskLogic,[],true] call CBE_fnc_ModuleAirborne;
 */
params [["_logic",objNull,[objNull]],["_units",[],[[]]],["_activated",true,[true]]];
if (isNull _logic || {!_activated} || {!local _logic} || {!hasInterface}) exitWith {false};
if (_logic getVariable ["CBE_processed",false]) exitWith {false};
_logic setVariable ["CBE_processed",true];
private _passenger=attachedTo _logic;
private _aircraft=objectParent _passenger;
private _valid=!isNull _passenger && {_passenger isKindOf "CAManBase"}
    && {alive _passenger} && {!isPlayer _passenger} && {!isNull _aircraft}
    && {_aircraft isKindOf "Air"} && {!(_aircraft isKindOf "ParachuteBase")}
    && {private _seats=(fullCrew [_aircraft,"cargo"])
        +((fullCrew [_aircraft,"turret"]) select {_x select 4});
        _seats findIf {(_x select 0) == _passenger} >= 0};
if (!_valid) exitWith {
    ["AIRBORNE","Place this task on an AI cargo or passenger-turret soldier aboard the intended aircraft. No nearby squad is selected.","ERROR"] call CBE_fnc_AITweaksNotifyLocal;
    deleteVehicle _logic;
    false
};
private _submitted=[[["order","AIRBORNE"],["group",group _passenger],
    ["passenger",_passenger],["aircraft",_aircraft]],clientOwner] call CBE_fnc_CortexOrderDispatch;
deleteVehicle _logic;
_submitted
