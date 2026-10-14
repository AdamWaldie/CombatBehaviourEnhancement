/*
 * Author: WaldoTheWarfighter
 * Purpose: Read a bounded receipt for the group's current authored native waypoint order.
 * Locality/authority: Read-only anywhere; movement owners compare receipts before issuing commands.
 * Repeat/JIP: No state or handlers are installed. Callers persist the receipt in their durable operation.
 * Arguments: 0 group <GROUP>, default grpNull.
 * Return: ARRAY - empty for null; [waypoint count,-1] for implicit/no authored order;
 * otherwise count/index, position/type/description, speed/behaviour/combat/formation,
 * completion radius, statements, timeout and synchronized trigger identities.
 * This reads authored values only; it never evaluates conditions or executes statements.
 * Current callers: CortexClearBuilding, BuildingOperationStep, CortexOrderDispatch and CortexOrderLocal.
 * Example: private _receipt = [group soldier1] call WAIT_fnc_NativeOrderReceipt;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group) exitWith {[]};
private _count=count waypoints _group;
private _index=currentWaypoint _group;
// Index zero is the engine's implicit spawn waypoint. Its natural completion is not a new order.
if (_count <= 1 || {_index <= 0} || {_index >= _count}) exitWith {[_count,-1]};
private _waypoint=[_group,_index];
[_count,_index,waypointPosition _waypoint,waypointType _waypoint,
    waypointDescription _waypoint,waypointSpeed _waypoint,waypointBehaviour _waypoint,
    waypointCombatMode _waypoint,waypointFormation _waypoint,
    waypointCompletionRadius _waypoint,waypointStatements _waypoint,
    waypointTimeout _waypoint,synchronizedTriggers _waypoint]
