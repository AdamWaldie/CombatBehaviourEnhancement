/*
 * Author: WaldoTheWarfighter
 * Shared movement reservations retain unresolved flight/naval cleanup even after the
 * ordinary marker expires; queued care and native fleeing prevent routine seat changes.
 * Checks shared passenger safety before routine unloading or boarding; emergency engine bailouts remain independent.
 * Locality/authority: read-only on the requesting owner unless stated below.
 * Repeat/JIP: no side effects; runtime gates and actor task ownership are read again on every call.
 * Active or unresolved selected-platform movement refuses routine seat transitions even at rest.
 * Routine seat transitions require finite total linear speed below1km/h and angular speed
 * below0.01rad/s; this instantaneous observation does not authorize a later deferred command.
 * Matching boarding may continue, but medical, equipment, finite actor reservations and replacement
 * boarding tasks yield without issuing seat or movement commands.
 * Hidden/suspended actors or vehicles refuse routine transitions. Boarding additionally
 * preserves explicit STOP and disabled MOVE/PATH; no path request is issued for them.
 * Over water, one downward ray must identify a static non-vehicle parent/deck above0.5m
 * with normalZ>=0.85 and measured rest. Unknown, vehicle/person or moving/rotating support
 * does not admit a routine seat transition. This is not full dismount-footprint clearance.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: vehicle <OBJECT>, objNull; 2: boarding <BOOL>, false.
 * Return Value: Boolean.
 * Current callers: ConvoyCrewLocal, CortexVehicles, CortexRestoreCalm, CortexGroupTick and CortexOnboardContact.
 * Example: [_unit, _vehicle] call CBE_fnc_CortexPassengerReady;
 */
params [["_unit", objNull, [objNull]], ["_vehicle", objNull, [objNull]], ["_boarding", false, [true]]];
if (isNull _vehicle || {!alive _vehicle} || {!local _unit} || {isPlayer _unit}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled _unit} || {isObjectHidden _unit}
    || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {fleeing _unit} || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {[group _unit,false,_unit] call CBE_fnc_CortexExternalTakeover}
    || {"ALL" in ((group _unit) getVariable ["CBE_AIPass_DisabledFeatures", []])}
    || {!isNull (_unit getVariable ["bis_fnc_moduleRemoteControl_owner", objNull])}
    ) exitWith {false};
// A momentary rest sample is not consent to board or unload beneath a selected
// platform move, HOLD or unresolved retirement. Emergency engine bailouts are separate.
private _selectedWork=_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
private _selectedGroup=group effectiveCommander _vehicle;
if (isNull _selectedGroup) then {_selectedGroup=group driver _vehicle};
if (!(_selectedWork isEqualType createHashMap)
    || {count _selectedWork > 0 && {(_selectedWork getOrDefault ["phase",""]) != "RETIRED"}}
    || {!isNull _selectedGroup
        && {(_selectedGroup getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}}) exitWith {false};
private _linearMotion=vectorMagnitude velocity _vehicle;
private _angularMotion=vectorMagnitude angularVelocity _vehicle;
if (!finite _linearMotion || {!finite _angularMotion}
    || {_linearMotion >= (1/3.6)} || {_angularMotion >= 0.01}) exitWith {false};
// A finite actor-level task owns this soldier independently of the passenger group's
// contact episode. Routine dismount/remount must not supersede its cover or recovery move.
private _reserved=[_unit] call CBE_fnc_CortexActorMoveReserved;
if (_reserved) exitWith {false};
// Routine seat changes must not steal an actor's medical, equipment or other authored task.
// The matching GET IN is our permitted continuation, not permission to replace a different seat.
private _command=toUpperANSI currentCommand _unit;
if (_boarding && {_command == "STOP" || {!(_unit checkAIFeature "MOVE")}
    || {!(_unit checkAIFeature "PATH")}}) exitWith {false};
if (_command in ["GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]
    || {_command == "GET IN" && {!_boarding || {assignedVehicle _unit != _vehicle}}}) exitWith {false};
// A ground-level bridge deck is allowed only when a short downward geometry ray actually hits it.
private _position = getPosASL _vehicle;
private _wet = surfaceIsWater _position;
if (_wet) then {
    private _deck = lineIntersectsSurfaces [_position vectorAdd [0,0,0.5], _position vectorAdd [0,0,-3], _vehicle, _unit, true, 1, "GEOM", "NONE"];
    if (_deck isEqualTo []) exitWith {};
    private _hit=_deck select 0;
    private _supportObject=if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2};
    // Another hull or a moving prop is not a bridge, even above the waterline.
    _wet = isNull _supportObject || {_supportObject isKindOf "AllVehicles"}
        || {vectorMagnitude velocity _supportObject > 0.1}
        || {vectorMagnitude angularVelocity _supportObject > 0.01}
        || {((_hit select 0) select 2) <= 0.5}
        || {((_hit select 1) select 2) < 0.85};
};
if (_wet) exitWith {false};
if (_boarding) exitWith {vehicle _unit == _unit && {canMove _vehicle} && {_vehicle emptyPositions "cargo" > 0}};
// Primary driver, gunner and commander roles are operating crew even if a turret flag is set.
vehicle _unit == _vehicle && {(fullCrew [_vehicle, "", false]) findIf {
    (_x select 0) == _unit && {(_x select 1) == "cargo" || {(_x select 1) == "turret" && {_x select 4}}}
} >= 0}
