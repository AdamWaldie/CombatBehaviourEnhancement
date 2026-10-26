/*
 * Author: WaldoTheWarfighter
 * Purpose: Diagnose actual ordinary bypass approach room before spending an episode.
 * Locality/authority: Read-only current vehicle owner. Geometry arithmetic grants no
 * rear clearance, native command, obstacle exemption or permission to bypass traffic.
 * Repeat/JIP: Stateless; fresh observation and current poses only. No cached admission.
 * Arguments: 0 vehicle OBJECT objNull; 1 solid observation ARRAY [], nine fields.
 * Return: HASHMAP status ROOM/BACKOFF/UNSUPPORTED. BACKOFF includes requiredBack NUMBER;
 * valid geometry includes sourcePose ARRAY and vehiclePose ARRAY for downstream rechecks.
 * Cost: two affine hull projections, two scalar side calculations, one bounded obstacle
 * availability check. No world discovery, ray, state, timer or movement writer.
 * Current callers: DrivingBypassStep and DrivingRearPlan. Queue/convoy bypass admission
 * uses its own plans; default queue rear preflight supplies no obstacle extension.
 * Example: private _room=[truck1,_observation] call CBE_fnc_DrivingBypassApproach;
 */
params [["_vehicle",objNull,[objNull]],["_observation",[],[[]]]];
private _unsupported=createHashMapFromArray [["status","UNSUPPORTED"]];
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle} || {!canMove _vehicle}
    || {!(_vehicle isKindOf "LandVehicle")} || {count _observation != 9}) exitWith {_unsupported};
private _source=_observation param [1,objNull,[objNull]];
private _sampled=_observation param [3,-1,[0]];private _gap=_observation param [2,-1,[0]];
if ((_observation param [5,"",[""]]) != "STATIC"
    || {!finite _sampled} || {time < _sampled} || {time-_sampled > 1.5}
    || {!finite _gap} || {_gap < 0} || {_gap > 50}
    || {!([_source] call CBE_fnc_DrivingBypassObstacleAvailable)}) exitWith {_unsupported};
private _sourcePose=[getPosWorld _source,vectorDir _source,vectorUp _source];
private _vehiclePose=[getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle];
if (_sourcePose isNotEqualTo (_observation select 8)) exitWith {_unsupported};
private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
private _width=(abs (_low select 0)) max (abs (_high select 0));
private _length=(abs (_low select 1)) max (abs (_high select 1));
private _radius=sqrt (_width^2+_length^2)+1;
private _forward=+(_vehiclePose select 1);_forward set [2,0];
if (!finite _radius || {_radius > 12} || {vectorMagnitude _forward < 0.5}) exitWith {_unsupported};
_forward=vectorNormalized _forward;private _right=[_forward select 1,-(_forward select 0),0];
private _along=[_source,_vehiclePose select 0,_forward] call CBE_fnc_DrivingHullInterval;
private _across=[_source,_vehiclePose select 0,_right] call CBE_fnc_DrivingHullInterval;
if (_along isEqualTo [] || {_across isEqualTo []}
    || {(boundingBoxReal _source select 0) vectorDistance (boundingBoxReal _source select 1) < 0.5}) exitWith {_unsupported};
private _hasRoom=false;private _backoff=true;private _required=1e6;
{
    private _room=[[_across select 0,_across select 1,_along select 0,_along select 1],_radius,_x,false] call CBE_fnc_DrivingBypassRoom;
    if ((_room get "status") == "ROOM") then {_hasRoom=true};
    if ((_room getOrDefault ["reason",""]) in ["INSUFFICIENT_APPROACH_ROOM","INSUFFICIENT_TURN_ROOM"]
        && {"requiredBack" in _room}) then {_required=_required min (_room get "requiredBack")} else {_backoff=false};
} forEach [-1,1];
if (!_hasRoom && {!_backoff || {!finite _required} || {_required <= 0}}) exitWith {_unsupported};
createHashMapFromArray [["status",["BACKOFF","ROOM"] select _hasRoom],
    ["requiredBack",if (_hasRoom) then {0} else {_required}],
    ["sourcePose",_sourcePose],["vehiclePose",_vehiclePose]]
