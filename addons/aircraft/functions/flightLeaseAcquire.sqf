/*
 * Author: WaldoTheWarfighter
 * Purpose: Acquires the single owner-local CBE flight-mutation lease for an AI aircraft.
 * Locality / Authority: Aircraft-owner local. Player, curator, specialist and non-local aircraft are rejected before lease mutation.
 * Active declared/provider airframe control refuses acquisition and fast mutation permission.
 * Repeat/JIP: Current pilot/commander player, remote or specialist control refuses before
 * lease mutation, including a separate commander's group Zeus hold. At most two operating
 * actors/groups are read; passengers are not scanned. Re-acquiring the same controller/token
 * retains the airframe lease identity; original crew/order proofs remain the controller's duty.
 * A strictly higher priority may replace another CBE lease; public state grants no authority.
 * Arguments: 0 aircraft <OBJECT>; 1 controller <STRING>; 2 token <STRING>; 3 priority <NUMBER>.
 * Return Value: Boolean - true only when the caller owns the current flight lease.
 * Current callers: airborne one-shot climb, aircraft attack, helicopter landing, missile defence and helicopter braking controllers.
 * Example: [_aircraft,"AIR_ATTACK",str _generation,300] call CBE_fnc_FlightLeaseAcquire;
 */
params [
    ["_aircraft",objNull,[objNull]],
    ["_controller","",[""]],
    ["_token","",[""]],
    ["_priority",0,[0]]
];
if (isNull _aircraft || {!local _aircraft} || {!alive _aircraft} || {_controller == ""} || {_token == ""}) exitWith {false};
// A provider may take the airframe between the slower planner checks.
if ([_aircraft] call CBE_fnc_CompatibilityExternalControl) exitWith {false};
private _pilot=currentPilot _aircraft;
if (isNull _pilot || {!([_pilot] call CBE_fnc_CortexCombatEffective)}
    || {isPlayer _pilot} || {!isNull (remoteControlled _pilot)}) exitWith {false};
private _commander=effectiveCommander _aircraft;
if (isNull _commander) then {_commander=_pilot};
private _commanderGroup=group _commander;
// These are current operating identities, not a scan of passengers or other crew.
if (([_pilot,_commander] arrayIntersect [_pilot,_commander]) findIf {
    isPlayer _x || {!isNull remoteControlled _x}
        || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_x] call CBE_fnc_CompatibilityExternalControl}
} >= 0) exitWith {false};
private _group=group _pilot;
if (isNull _group || {[_group] call CBE_fnc_CortexZeusHeld} || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _lease=_aircraft getVariable ["CBE_FlightLease",createHashMap];
// Public state may arrive from the previous owner during headless/client migration. Ownership is
// part of the lease identity, so a new local owner adopts immediately instead of being blocked by
// the previous machine's priority until an old callback that can no longer run releases it.
if (count _lease > 0 && {(_lease getOrDefault ["owner",-1]) != clientOwner}) then {_lease=createHashMap};
if (_commanderGroup != _group && {[_commanderGroup] call CBE_fnc_CortexZeusHeld}) exitWith {false};
private _same=count _lease > 0
    && {(_lease getOrDefault ["controller",""]) == _controller}
    && {(_lease getOrDefault ["token",""]) == _token}
    && {(_lease getOrDefault ["owner",-1]) == clientOwner};
if (_same) exitWith {
    true
};
if (count _lease > 0 && {_priority <= (_lease getOrDefault ["priority",0])}) exitWith {false};
private _revision=(_aircraft getVariable ["CBE_FlightLeaseRevision",0])+1;
_aircraft setVariable ["CBE_FlightLeaseRevision",_revision];
private _newLease=createHashMapFromArray [
    ["controller",_controller],["token",_token],["priority",_priority],
    ["owner",clientOwner],["revision",_revision],["startedAt",serverTime],["updatedAt",serverTime],
    ["replaced",if (count _lease > 0) then {[_lease getOrDefault ["controller",""],_lease getOrDefault ["token",""]]} else {[]}]
];
_aircraft setVariable ["CBE_FlightLease",_newLease,true];
true
