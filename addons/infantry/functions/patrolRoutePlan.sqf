/*
 * Author: WaldoTheWarfighter
 * Purpose: Plan a bounded ground patrol circuit without issuing native orders.
 * Locality/authority: Read-only world geometry; caller retains group/task/native authority.
 * Repeat/JIP: Stateless, at most8 nodes and4 candidates per node. Each candidate uses one
 * short5m empty-position search and at most one2m vertical body query. No world scan/job.
 * Arguments: 0 centre ATL ARRAY,[]; 1 radius NUMBER,100 (25..500); 2 nodes NUMBER,4 (3..8).
 * Return: ARRAY of ground ATL positions, or[] if any node cannot be placed. Empty-position,
 * dry terrain, slope and body clearance do not prove connected navigation or physical access.
 * Current callers: PatrolOperation START.
 * Example: private _route=[getMarkerPos "patrol",100,4] call CBE_fnc_PatrolRoutePlan;
 */
params [["_centre",[],[[]]],["_radius",100,[0]],["_nodes",4,[0]]];
if (count _centre != 3 || {_centre findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _radius} || {_radius < 25} || {_radius > 500}
    || {!finite _nodes} || {_nodes != floor _nodes} || {_nodes < 3} || {_nodes > 8}
    || {(_centre select 0) < 0} || {(_centre select 1) < 0}
    || {(_centre select 0) > worldSize} || {(_centre select 1) > worldSize}) exitWith {[]};
private _route=[];
private _phase=random 360;
private _failed=false;
for "_node" from 0 to (_nodes-1) do {
    private _selected=[];
    for "_attempt" from 0 to 3 do {
        private _angle=_phase+360*_node/_nodes-8+random 16;
        private _seed=_centre getPos [_radius*(0.6+random 0.3),_angle];
        if ((_seed select 0) >= 0 && {(_seed select 1) >= 0}
            && {(_seed select 0) <= worldSize} && {(_seed select 1) <= worldSize}) then {
            private _point=_seed findEmptyPosition [0,5,"B_Soldier_F"];
            if (count _point == 3 && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {_point distance2D _centre <= _radius} && {!surfaceIsWater _point}
                && {((surfaceNormal _point) select 2) >= 0.85}
                && {(_point select 0) >= 0} && {(_point select 1) >= 0}
                && {(_point select 0) <= worldSize} && {(_point select 1) <= worldSize}
                && {_route findIf {_x distance2D _point < 8} < 0}) then {
                _point set [2,0];
                private _feet=AGLToASL _point;
                if ((lineIntersectsSurfaces [_feet vectorAdd [0,0,0.2],_feet vectorAdd [0,0,2.2],
                    objNull,objNull,true,1,"GEOM","NONE"]) isEqualTo []) then {_selected=_point};
            };
        };
        if (_selected isNotEqualTo []) exitWith {};
    };
    if (_selected isEqualTo []) exitWith {_failed=true};
    _route pushBack _selected;
};
if (_failed) exitWith {[]};
_route
