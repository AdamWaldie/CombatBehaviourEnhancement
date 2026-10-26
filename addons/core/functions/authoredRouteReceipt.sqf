/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads authored waypoint content for an operation's replacement-order receipt.
 * Locality/authority: read-only anywhere; consuming movement owner compares before commands.
 * Repeat/JIP: no state, handlers or code execution. Current waypoint progression is excluded;
 * moving attached targets retain their object identities instead of transient world positions.
 * Forced-behaviour changes participate in identity even when the behaviour string is unchanged.
 * The force flag is appended; existing metadata field positions retain their meaning.
 * Arguments: 0 group <GROUP>, grpNull; 1 owned waypoint name <STRING>, empty (exclude none).
 * 2 owned-only <BOOL>, false: read only the named operation waypoint instead of excluding it.
 * 3 waypoint engine index <NUMBER>, -1: negative reads all; otherwise read only that handle.
 * Return: ARRAY of waypoint metadata rows; empty for null/no authored entries or invalid index.
 * A nonnegative index slices at most one handle before filtering/metadata reads. Full-route mode
 * retains all authored rows. Engine waypoint-array retrieval still depends on route size; no
 * world scan, constant-time engine claim or measured frame-time improvement is implied.
 * Current callers: CortexAirAttack admission/owner callback, ConvoyTick recovery,
 * DrivingRouteReceipt and NativeOrderReceipt task/CQB guards.
 * Example: private _receipt=[group pilot1,"CBE_AIR_ownedToken"] call CBE_fnc_AuthoredRouteReceipt;
 */
params [["_group",grpNull,[grpNull]],["_ownedName","",[""]],["_ownedOnly",false,[true]],["_waypointIndex",-1,[0]]];
if (isNull _group || {!finite _waypointIndex}) exitWith {[]};
private _authored=waypoints _group;
// A single-waypoint consumer does not need a SQF predicate over the full route.
// The engine array retrieval still scales with route size. Validate the selected
// handle below before reading metadata; malformed/nonintegral indices grant no receipt.
if (_waypointIndex >= 0) then {
    _authored=if (_waypointIndex == floor _waypointIndex && {_waypointIndex < count _authored}) then {
        _authored select [_waypointIndex,1]
    } else {[]};
};
_authored=_authored select {(_waypointIndex < 0 || {(_x select 1) == _waypointIndex}) && {if (_ownedOnly) then {
    _ownedName != "" && {waypointName _x == _ownedName}
} else {_ownedName == "" || {waypointName _x != _ownedName}}}};
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
        waypointLoiterRadius _waypoint,waypointLoiterType _waypoint,waypointLoiterAltitude _waypoint,
        waypointForceBehaviour _waypoint]
}
