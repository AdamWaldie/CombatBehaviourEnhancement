/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads the current authored driving waypoint identity without executing its condition.
 * Locality / Authority: Read-only anywhere; only current owners consume it for movement admission.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return Value: ARRAY - empty without an authored current waypoint.
 * Current callers: WAIT_fnc_DrivingAssistStart, DrivingOperationStart and DrivingOperationStep.
 * Example: private _order = [group driver truck1] call WAIT_fnc_DrivingRouteReceipt;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {[]};
private _index=currentWaypoint _group;
if (_index <= 0 || {_index >= count waypoints _group}) exitWith {[]};
private _waypoint=[_group,_index];
[_index,waypointType _waypoint,waypointPosition _waypoint,
    waypointCompletionRadius _waypoint,waypointBehaviour _waypoint,
    waypointSpeed _waypoint,waypointCombatMode _waypoint,waypointFormation _waypoint,
    waypointStatements _waypoint,waypointTimeout _waypoint,synchronizedTriggers _waypoint]
