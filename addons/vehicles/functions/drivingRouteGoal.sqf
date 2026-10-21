/*
 * Author: WaldoTheWarfighter
 * Purpose: Resolve the current plain authored driving goal without executing waypoint code.
 * Locality/authority: Read-only anywhere; callers retain exact route/crew/owner/native-task
 * checks at commands. A returned goal is not movement permission or path/access evidence.
 * Repeat/JIP: Stateless, no replay, cache or worker. Reads one current waypoint only.
 * Arguments: 0 group GROUP grpNull.
 * Return: ARRAY finite PositionAGL goal, or[] for absent/protected/non-MOVE waypoint.
 * Current callers: DrivingAssistStart recovery admission, DrivingGateIntent and DrivingRecoveryRelease.
 * Native script-only MOVE has no authored waypoint and remains unsupported here.
 * Example: private _goal=[group driver truck1] call CBE_fnc_DrivingRouteGoal;
 */
params [["_goalGroup",grpNull,[grpNull]]];
if (isNull _goalGroup) exitWith {[]};
private _goalIndex=currentWaypoint _goalGroup;
if (_goalIndex <= 0 || {_goalIndex >= count waypoints _goalGroup}) exitWith {[]};
private _goalWaypoint=[_goalGroup,_goalIndex];
private _goalStatements=waypointStatements _goalWaypoint;
private _goalCondition=toLowerANSI ((_goalStatements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
if (waypointType _goalWaypoint != "MOVE" || {_goalCondition != "true"}
    || {((_goalStatements param [1,""]) splitString (toString [32,9,13,10])) isNotEqualTo []}
    || {waypointScript _goalWaypoint != ""} || {(waypointTimeout _goalWaypoint param [2,0]) > 0}
    || {!isNull waypointAttachedVehicle _goalWaypoint} || {!isNull waypointAttachedObject _goalWaypoint}
    || {synchronizedWaypoints _goalWaypoint isNotEqualTo []}
    || {synchronizedTriggers _goalWaypoint isNotEqualTo []}) exitWith {[]};
private _goalPosition=waypointPosition _goalWaypoint;
if (count _goalPosition != 3 || {_goalPosition findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {[]};
+_goalPosition
