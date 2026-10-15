/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads authored waypoint content for an operation's replacement-order receipt.
 * Locality/authority: read-only anywhere; consuming movement owner compares before commands.
 * Repeat/JIP: no state, handlers or code execution. Current waypoint progression is excluded;
 * moving attached targets retain their object identities instead of transient world positions.
 * Arguments: 0 group <GROUP>, grpNull; 1 owned waypoint name <STRING>, empty (exclude none).
 * 2 owned-only <BOOL>, false: read only the named operation waypoint instead of excluding it.
 * Return: ARRAY of waypoint metadata rows; empty for null/no authored entries. Cost is proportional
 * to waypoint count (fixed reads per row), not a world scan; large-route costs require profiling.
 * Current callers: WAIT_fnc_CortexAirAttack at admission and active owner callback.
 * Example: private _receipt=[group pilot1,"WAIT_AIR_ownedToken"] call WAIT_fnc_AuthoredRouteReceipt;
 */
params [["_group",grpNull,[grpNull]],["_ownedName","",[""]],["_ownedOnly",false,[true]]];
if (isNull _group) exitWith {[]};
private _authored=waypoints _group select {if (_ownedOnly) then {
    _ownedName != "" && {waypointName _x == _ownedName}
} else {_ownedName == "" || {waypointName _x != _ownedName}}};
_authored apply {
    private _waypoint=_x;
    private _vehicle=waypointAttachedVehicle _waypoint;
    private _object=waypointAttachedObject _waypoint;
    private _position=if (isNull _vehicle && {isNull _object}) then {waypointPosition _waypoint} else {[]};
    [_waypoint select 1,_position,waypointType _waypoint,waypointName _waypoint,
        waypointDescription _waypoint,waypointCompletionRadius _waypoint,
        waypointStatements _waypoint,waypointTimeout _waypoint,waypointSpeed _waypoint,
        waypointBehaviour _waypoint,waypointCombatMode _waypoint,waypointFormation _waypoint,
        waypointScript _waypoint,_vehicle,_object,synchronizedTriggers _waypoint,
        synchronizedWaypoints _waypoint,waypointHousePosition _waypoint,
        waypointLoiterRadius _waypoint,waypointLoiterType _waypoint,waypointLoiterAltitude _waypoint]
}
