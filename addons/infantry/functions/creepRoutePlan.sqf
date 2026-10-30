/*
 * Author: WaldoTheWarfighter
 * Purpose: Plan three ground approach legs toward a supplied native contact belief, stopping
 * outside its infantry/vehicle stand-off plus uncertainty. Selects one of three screened avenues.
 * Locality/authority: Read-only planning on the group owner. No enemy transform or native order.
 * Repeat/JIP: Stateless; at most9 short empty-position/body queries and one bounded avenue
 * selection. Geometry is not proof of native path connectivity, concealment or physical arrival.
 * Arguments: 0 own origin ATL ARRAY,[]; 1 native belief ATL ARRAY,[];
 * 2 stand-off NUMBER,40 (40..250); 3 belief error NUMBER,0 (0..100).
 * Return: ARRAY of exactly3 dry ground ATL destinations, or[] on invalid/too-close terrain.
 * Current callers: CreepOperation START/UPDATE.
 * Example: private _route=[getPosATL leader _group,_belief,40,10] call CBE_fnc_CreepRoutePlan;
 */
params [["_origin",[],[[]]],["_belief",[],[[]]],["_standOff",40,[0]],["_error",0,[0]]];
if ([_origin,_belief] findIf {count _x != 3 || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0
    || {!finite _standOff} || {_standOff < 40} || {_standOff > 250}
    || {!finite _error} || {_error < 0} || {_error > 100}
    || {(_origin select 2) < -0.5} || {(_origin select 2) > 2.5}) exitWith {[]};
private _distance=_origin distance2D _belief;
private _travel=_distance-_standOff-_error-5;
if (_travel < 30 || {_distance > 2000}) exitWith {[]};
private _direction=_origin getDir _belief;
private _candidates=[];
{
    private _bend=_x;
    private _route=[];
    for "_leg" from 1 to 3 do {
        private _fraction=_leg/3;
        private _seed=_origin getPos [_travel*_fraction,_direction];
        if (_leg < 3) then {_seed=_seed getPos [_bend,_direction+90]};
        if ((_seed select 0) < 0 || {(_seed select 1) < 0}
            || {(_seed select 0) > worldSize} || {(_seed select 1) > worldSize}) exitWith {};
        private _point=_seed findEmptyPosition [0,3,"B_Soldier_F"];
        if (count _point != 3 || {_point findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {(_point select 2) < -0.5} || {(_point select 2) > 2.5}
            || {(_point select 0) < 0} || {(_point select 1) < 0}
            || {(_point select 0) > worldSize} || {(_point select 1) > worldSize}
            || {surfaceIsWater _point} || {((surfaceNormal _point) select 2) < 0.85}
            || {_point distance2D _belief < _standOff+_error}
            || {_route findIf {_x distance2D _point < 8} >= 0}) exitWith {};
        _point set [2,0];
        private _feet=AGLToASL _point;
        if ((lineIntersectsSurfaces [_feet vectorAdd [0,0,0.2],_feet vectorAdd [0,0,2.2],
            objNull,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {};
        _route pushBack _point;
    };
    if (count _route == 3) then {_candidates pushBack _route};
} forEach [0,20,-20];
[_origin,_candidates,_belief] call CBE_fnc_CortexSelectAvenue
