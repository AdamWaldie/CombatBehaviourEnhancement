/*
 * Author: WaldoTheWarfighter
 * Purpose: Read the native command/destination pair for two original vehicle-control actors.
 * Locality/authority: Read-only on both actor owners. The caller supplies and validates
 * platform seats, group/operation/epoch, native task priority and command authority.
 * Repeat/JIP: Stateless one-sample observation; no publication, replay, handler or worker.
 * The unscheduled sample avoids script suspension between reads, not asynchronous engine
 * planning. Identical actors are sampled once; returned destination arrays are independent.
 * Arguments: 0 first actor OBJECT,objNull; 1 second actor OBJECT,objNull.
 * Return: ARRAY [first command STRING,first expectedDestination ARRAY,
 * second command STRING,second expectedDestination ARRAY], or [] if either actor is absent/nonlocal.
 * Missing or idle native destinations are preserved, never converted to movement permission.
 * Current callers: ArtilleryCrewMoveStart and ArtilleryCrewMoveStep.
 * Example: private _native=[driver _vehicle,effectiveCommander _vehicle] call CBE_fnc_VehicleCrewNativeObservation;
 */
params [["_first",objNull,[objNull]],["_second",objNull,[objNull]]];
private _snapshot=[];
isNil {
    if (isNull _first || {isNull _second} || {!local _first} || {!local _second}) exitWith {};
    private _firstCommand=currentCommand _first;
    private _firstDestination=(expectedDestination _first) apply {if (_x isEqualType []) then {+_x} else {_x}};
    private _secondCommand=_firstCommand;
    private _secondDestination=[];
    if (_second != _first) then {
        _secondCommand=currentCommand _second;
        _secondDestination=(expectedDestination _second) apply {if (_x isEqualType []) then {+_x} else {_x}};
    } else {
        _secondDestination=_firstDestination apply {if (_x isEqualType []) then {+_x} else {_x}};
    };
    _snapshot=[_firstCommand,_firstDestination,_secondCommand,_secondDestination];
};
_snapshot
