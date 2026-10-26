/*
 * Author: WaldoTheWarfighter
 * Purpose: Check current driver/effective-commander authority for a tactical vehicle move.
 * Locality/authority: Read-only on local vehicle/group owner; at most two current crew actors.
 * Repeat/JIP: No state or replay. A required exact seat pair binds admission and continuation;
 * changed seats, native tasks, fleeing, care or external ownership refuse continuation.
 * Arguments: 0 group GROUP grpNull; 1 vehicle OBJECT objNull;
 * 2 expected driver/commander ARRAY [] (required exactly two objects; empty refuses).
 * Return: BOOL - current crew may receive tactical movement, never proof of actual travel.
 * Current callers: CortexVehicleJink and CortexVehicles standoff admission/commit and movement continuation.
 * Example: [group driver apc1,apc1,[driver apc1,effectiveCommander apc1]] call CBE_fnc_CortexVehicleCrewAvailable;
 */
params [["_crewGroup",grpNull,[grpNull]],["_crewVehicle",objNull,[objNull]],["_expectedSeats",[],[[]]]];
if (isNull _crewGroup || {!local _crewGroup} || {isNull _crewVehicle} || {!local _crewVehicle}
    || {!alive _crewVehicle} || {!canMove _crewVehicle}
    || {!simulationEnabled _crewVehicle} || {isObjectHidden _crewVehicle}
    || {!isNil {_crewVehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[_crewVehicle] call CBE_fnc_CompatibilityExternalControl}) exitWith {false};
private _crewDriver=driver _crewVehicle;
private _crewCommander=effectiveCommander _crewVehicle;
if (isNull _crewDriver || {isNull _crewCommander}) exitWith {false};
private _seats=[_crewDriver,_crewCommander];
if (_expectedSeats isNotEqualTo _seats) exitWith {false};
(_seats arrayIntersect _seats) findIf {
    !local _x || {group _x != _crewGroup} || {isPlayer _x} || {!isNull remoteControlled _x}
        || {!simulationEnabled _x} || {isObjectHidden _x} || {fleeing _x}
        || {!([_x] call CBE_fnc_CortexCombatEffective)}
        || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
        || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
        || {[_x] call CBE_fnc_CompatibilityExternalControl}
        || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
} < 0
