/*
 * Author: WaldoTheWarfighter
 * Purpose: Forward a nearby gate observation to server authority under the current driving route.
 * Locality/authority: Current group/vehicle/driver owner only; non-server network calls are refused.
 * Server independently validates every authority, source, transform, lock and geometry condition.
 * Repeat/JIP: One request per vehicle every two seconds; no JIP replay or asynchronous callback.
 * Opening receipt is diagnostic only. Existing geometry cap owns approach/wait and never times out
 * into clearance. Server retains a finite per-route attempt budget across owner migration.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 observation <ARRAY, []>
 * from DrivingGateCap; 3 convoy revision <NUMBER, -1> (-1 ordinary driving).
 * Return Value: BOOL - request sent, not opening, passability or physical passage confirmation.
 * Current callers: DrivingAssistStart and ConvoyTick after their live command-authority checks.
 * Example: [_group,_vehicle,_gateObservation] call WAIT_fnc_DrivingGateRequest;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_observation",[],[[]]],["_revision",-1,[0]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _group || {isNull _vehicle} || {!local _group} || {!local _vehicle}
    || {isNull driver _vehicle} || {!local driver _vehicle} || {group driver _vehicle != _group}
    || {count _observation != 5} || {isNull (_observation select 1)}
    || {(_observation select 2) < 0} || {(_observation select 2) > 12}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled driver _vehicle} || {isObjectHidden driver _vehicle}
    || {abs speed _vehicle > 8} || {[_group] call WAIT_fnc_CortexExternalTakeover}
    || {serverTime < (_vehicle getVariable ["WAIT_DrivingGate_RequestUntil",-1])}) exitWith {false};
private _route=[_group] call WAIT_fnc_DrivingRouteReceipt;
if (_route isEqualTo []) exitWith {false};
private _gate=_observation select 1;
private _payload=[["group",_group],["vehicle",_vehicle],["gate",_gate],["route",_route],
    ["transform",[getPosWorld _gate,vectorDir _gate,vectorUp _gate]],
    ["convoyRevision",_revision],["expires",serverTime+5]];
_vehicle setVariable ["WAIT_DrivingGate_RequestUntil",serverTime+2];
if (isServer) then {[_payload] call WAIT_fnc_DrivingGateOpenServer}
else {[_payload] remoteExecCall ["WAIT_fnc_DrivingGateOpenServer",2]};
true
