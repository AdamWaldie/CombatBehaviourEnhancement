/*
 * Author: WaldoTheWarfighter
 * Purpose: Proposes a bounded head-on queue roster and rear-to-front room-making dependencies.
 * Locality/authority: Initiating vehicle owner, read-only. Proposed roles are not priority or
 * consent. Remote participant eligibility is observational; actual-owner ACK is separately brokered; a native
 * execution/cleanup FSM remains required and unimplemented. No movement, reservations or speed writes.
 * Repeat/JIP: Stateless fresh proposal, expires within original retry deadline and two seconds.
 * Stationary admission requires total finite linear velocity below1km/h, not only forward-axis speed.
 * This instantaneous observation is not a physically settled HOLD/READY receipt.
 * At most one120m dead-inclusive vehicle query/64 candidates; overflow/fifth chain member refuses.
 * Arguments:0 initiator <OBJECT>,objNull;1 opposing limiting peer <OBJECT>,objNull;
 * 2 original episode deadline <NUMBER>,-1,serverTime. Caller supplies continuous jam dwell.
 * Return: HASHMAP status REFUSED/PROPOSAL,reason; proposal adds vehicles,roles,dependencies,
 * canonical context,observedAt,deadline. Geometry/reverse/consent/success are never inferred.
 * Current callers: DrivingAssistStart after continuous stationary traffic dwell, at most once/30s.
 * Example: private _p=[_own,_peer,_retryDeadline] call CBE_fnc_DrivingQueueProposal;
 */
params [["_vehicle",objNull,[objNull]],["_peer",objNull,[objNull]],["_until",-1,[0]]];
private _fail={params ["_reason"];createHashMapFromArray [["status","REFUSED"],["reason",_reason]]};
if (isRemoteExecuted || {isNull _vehicle} || {!local _vehicle} || {isNull _peer}
    || {_vehicle == _peer} || {!finite _until} || {_until <= serverTime}) exitWith {["INVALID_REQUEST"] call _fail};
private _at=serverTime;
private _observedEligible={
    params ["_object"];
    if (isNull _object || {!alive _object} || {!canMove _object} || {!simulationEnabled _object}
        || {isObjectHidden _object} || {!(_object isKindOf "LandVehicle")}
        || {private _queueLinearSpeed=vectorMagnitude velocity _object;
            !finite _queueLinearSpeed || {_queueLinearSpeed >= (1/3.6)}}
        || {_object getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_object getVariable "CBE_ExternalDrivingOwner"}}) exitWith {false};
    private _driver=driver _object;private _operator=effectiveCommander _object;
    if (isNull _operator) then {_operator=_driver};
    if (isNull _driver || {isNull _operator} || {group _driver != group _operator}
        || {vehicle leader group _driver != _object}
        || {behaviour leader group _driver in ["COMBAT","STEALTH"]}) exitWith {false};
    if ([_driver,_operator] findIf {isPlayer _x || {!alive _x} || {!isNull remoteControlled _x}
        || {!(currentCommand _x in ["","MOVE","WAIT"])}} >= 0) exitWith {false};
    private _group=group _driver;private _index=currentWaypoint _group;
    if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
    private _wp=[_group,_index];private _statements=waypointStatements _wp;
    private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
    waypointType _wp == "MOVE" && {_condition == "true"}
        && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
        && {waypointScript _wp == ""} && {(waypointTimeout _wp param [2,0]) <= 0}
        && {isNull waypointAttachedVehicle _wp} && {isNull waypointAttachedObject _wp}
        && {synchronizedWaypoints _wp isEqualTo []} && {synchronizedTriggers _wp isEqualTo []}
};
if (!([_vehicle] call _observedEligible) || {!([_peer] call _observedEligible)}
    || {group driver _vehicle == group driver _peer}
    || {abs (((getPosASL _vehicle) select 2)-((getPosASL _peer) select 2)) > 2}
    || {_vehicle distance2D _peer > 30}
    || {(vectorDir _vehicle) vectorDotProduct (vectorDir _peer) > -(cos 25)}) exitWith {["NOT_STATIONARY_ONCOMING_PAIR"] call _fail};
private _axis=vectorDir _peer;_axis set [2,0];_axis=vectorNormalized _axis;
private _right=[_axis select 1,-(_axis select 0),0];
private _toward=(getPosASL _vehicle) vectorDiff (getPosASL _peer);
if ((_toward vectorDotProduct _axis) <= 0 || {abs (_toward vectorDotProduct _right) > 6}) exitWith {["NOT_FACING_CORRIDOR"] call _fail};
private _area=[getPosATL _peer,120,120,0,false,120];
private _candidates=_area nearEntities [["LandVehicle"],false,false,false];
if (count _candidates > 64) exitWith {["CHAIN_DISCOVERY_BUDGET"] call _fail};
private _vehicles=[_vehicle,_peer];private _roles=["HOLD_CROSSING","YIELD_ROOT"];
private _dependencies=[-1,-1];private _previous=_peer;private _reason="";
// Three bounded searches: up to two followers plus a mandatory over-budget tail check.
for "_step" from 1 to 3 do {
    private _nearest=objNull;private _best=1e9;
    {
        private _other=_x;
        if (_other != _previous && {_other != _vehicle}) then {
            private _delta=(getPosASL _other) vectorDiff (getPosASL _previous);
            private _behind=-(_delta vectorDotProduct _axis);
            if (_behind > 0 && {_behind <= 25} && {_behind < _best}
                && {abs (_delta vectorDotProduct _right) <= 6}
                && {abs (_delta select 2) <= 2}) then {_nearest=_other;_best=_behind};
        };
    } forEach _candidates;
    if (isNull _nearest) exitWith {};
    if (_nearest in _vehicles) exitWith {_reason="DEPENDENCY_CYCLE"};
    if (count _vehicles >= 4) exitWith {_reason="CHAIN_PARTICIPANT_BUDGET"};
    if (!([_nearest] call _observedEligible)
        || {(vectorDir _nearest) vectorDotProduct _axis < cos 25}
        || {_vehicles findIf {group driver _x == group driver _nearest} >= 0}) exitWith {_reason="REAR_PARTICIPANT_UNAVAILABLE"};
    _dependencies set [count _vehicles-1,count _vehicles];
    _vehicles pushBack _nearest;_roles pushBack "REAR_ROOM";_dependencies pushBack -1;
    _previous=_nearest;
};
if (_reason != "") exitWith {[_reason] call _fail};
private _context=[_vehicles] call CBE_fnc_DrivingQueueContext;
if (_context isEqualTo [] || {serverTime-_at > 2} || {serverTime >= _until}
    || {!local _vehicle} || {_vehicles findIf {!([_x] call _observedEligible)} >= 0}) exitWith {["STALE_CHAIN"] call _fail};
createHashMapFromArray [["status","PROPOSAL"],["reason","OWNER_CONSENT_AND_NATIVE_EXECUTION_REQUIRED"],
    ["vehicles",_vehicles],["roles",_roles],["dependencies",_dependencies],["context",_context],
    ["observedAt",_at],["deadline",(_at+2) min _until],["retryDeadline",_until]]
