/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks whether one CBE controller still owns the local aircraft flight-mutation lease.
 * Locality / Authority: Cheap read on the aircraft owner. It rejects unavailable pilots and player/direct-control takeover; each bounded controller retains its existing slower Zeus, order and specialist validation before mutation.
 * Active declared/provider airframe control refuses acquisition and fast mutation permission.
 * Repeat/JIP: Current pilot/commander player, remote or declared specialist control refuses
 * before another flight write. A distinct commander group also uses the existing Zeus hold
 * check, including its timing cache/remaining-waypoint inspection. Same-group crew add no
 * extra Zeus query. At most two operating actors are read; passengers are not scanned.
 * Each controller retains its slower pilot-group Zeus/order checks.
 * This remains airframe lease permission, not original actor/order or native quiescence proof.
 * Each controller retains its own exact crew/route/cleanup receipts. Public state grants no authority.
 * Arguments: 0 aircraft <OBJECT>; 1 controller <STRING>; 2 token <STRING>.
 * Return Value: Boolean - true only for the exact current local lease owner.
 * Current callers: airborne one-shot climb, aircraft attack, helicopter landing, missile defence and helicopter braking mutation boundaries.
 * Example: [_aircraft,"LANDING",str _revision] call CBE_fnc_FlightLeaseValid;
 */
params [["_aircraft",objNull,[objNull]],["_controller","",[""]],["_token","",[""]]];
if (isNull _aircraft || {!local _aircraft} || {!alive _aircraft}) exitWith {false};
// A provider may take the airframe between the slower planner checks.
if ([_aircraft] call CBE_fnc_CompatibilityExternalControl) exitWith {false};
private _pilot=currentPilot _aircraft;
if (isNull _pilot || {!([_pilot] call CBE_fnc_CortexCombatEffective)} || {isPlayer _pilot} || {!isNull (remoteControlled _pilot)}) exitWith {false};
private _commander=effectiveCommander _aircraft;
if (isNull _commander) then {_commander=_pilot};
// These are current operating identities, not a scan of passengers or other crew.
if (([_pilot,_commander] arrayIntersect [_pilot,_commander]) findIf {
    isPlayer _x || {!isNull remoteControlled _x}
        || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_x] call CBE_fnc_CompatibilityExternalControl}
} >= 0) exitWith {false};
// A separate commander group is not covered by the pilot group's slower task checks.
// Common same-group crew add no second Zeus query. Preserve the existing Zeus timing and
// completed-waypoint semantics rather than inventing another cache or stale hold flag.
private _commanderGroup=group _commander;
if (_commanderGroup != group _pilot && {[_commanderGroup] call CBE_fnc_CortexZeusHeld}) exitWith {false};
private _lease=_aircraft getVariable ["CBE_FlightLease",createHashMap];
count _lease > 0
    && {(_lease getOrDefault ["controller",""]) == _controller}
    && {(_lease getOrDefault ["token",""]) == _token}
    && {(_lease getOrDefault ["owner",-1]) == clientOwner}
