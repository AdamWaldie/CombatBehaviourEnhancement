/*
 * Author: WaldoTheWarfighter
 * Turns a list of leg end points into bound points, inserting street crossings.
 *
 * Shared by the flank and advance drills. Each leg is cut into bounds of
 * CBE_AIPass_Flank_BoundDistance (minimum 15 m). With CBE_AIPass_StreetCrossing_Enable, a leg is
 * sampled every 6 m. Where it runs onto a road (isOnRoad and roadAt, bridges excluded), a CROSS_NEAR
 * point is placed at the near edge and a CROSS_FAR point just past the far edge, using the road width
 * from getRoadInfo. Segment axis and route intersection determine near/far distances,
 * so an oblique crossing is not shortened to perpendicular road width. Near-parallel road
 * travel remains ordinary routing. Ordinary bound points inside crossings are dropped. The last point gets the
 * requested final kind.
 * Locality and authority: pure calculation; callable anywhere.
 *
 * Arguments:
 * 0: start <ARRAY> - ATL position
 * 1: legs <ARRAY> - ATL leg end points, in order
 * 2: final kind <STRING> - kind for the last point (optional, default: "FINAL")
 *
 * 3: group <GROUP> - optional group feature exclusions, default grpNull.
 * 4: maximum ordinary bound <NUMBER>, default0 uses configured spacing; positive values clamp
 *    spacing down to at least15m. Street crossings retain one continuous crossing.
 * Repeat/JIP: pure bounded calculation, no persistent state.
 * Return Value:
 * Array - [[positionATL, kind], ...] with kind BOUND, CROSS_NEAR, CROSS_FAR or the final kind
 *
 * Example:
 * private _points = [_start, [_wide, _close]] call CBE_fnc_CortexPlanRoute;
 * Result: a bounding route that pauses and smokes at each road it crosses.
 *
 * Current callers: CBE_fnc_CortexFlankStart and CBE_fnc_CortexAdvanceStart.
 */

params [["_start", [], [[]]], ["_legs", [], [[]]], ["_finalKind", "FINAL", [""]], ["_group",grpNull,[grpNull]],["_maximumBound",0,[0]]];
private _bound = (missionNamespace getVariable ["CBE_AIPass_Flank_BoundDistance", 55]) max 15;
if (finite _maximumBound && {_maximumBound > 0}) then {_bound=_bound min (_maximumBound max 15)};
private _streets = [_group,"CBE_AIPass_StreetCrossing_Enable",true] call CBE_fnc_CortexFeatureEnabled;
private _points = [];
private _from = _start;
{
    private _to = _x;
    private _length = _from distance2D _to;
    private _direction = _from getDir _to;
    private _crossings = [];
    if (_streets) then {
        private _clearUntil = -1;
        for "_along" from 6 to (_length - 3) step 6 do {
            if (_along > _clearUntil) then {
                private _sample = _from getPos [_along, _direction];
                if (isOnRoad _sample) then {
                    private _road = roadAt _sample;
                    if (!isNull _road) then {
                        private _info = getRoadInfo _road;
                        if !(_info param [8, false]) then {
                            private _halfWidth = ((_info param [1, 8]) max 4) / 2;
                            private _begin=_info param [6,[],[[]]];
                            private _end=_info param [7,[],[[]]];
                            if (count _begin >= 2 && {count _end >= 2}) then {
                                private _roadX=(_end select 0)-(_begin select 0);
                                private _roadY=(_end select 1)-(_begin select 1);
                                private _roadLength=sqrt (_roadX*_roadX+_roadY*_roadY);
                                if (_roadLength > 0.1) then {
                                    private _crossRate=((sin _direction)*_roadY-(cos _direction)*_roadX)/_roadLength;
                                    // Nearly parallel travel has no reliable near/far crossing on this leg.
                                    if (abs _crossRate >= 0.2) then {
                                        private _lateral=(((_sample select 0)-(_begin select 0))*_roadY
                                            -((_sample select 1)-(_begin select 1))*_roadX)/_roadLength;
                                        private _edgeA=_along+(-_halfWidth-_lateral)/_crossRate;
                                        private _edgeB=_along+(_halfWidth-_lateral)/_crossRate;
                                        private _near=_edgeA min _edgeB;
                                        private _far=_edgeA max _edgeB;
                                        // Both staging points must lie on this leg, never clamp an exit into the road.
                                        if (_near >= 3 && {_far+4 <= _length} && {_near < _far}) then {
                                            _crossings pushBack [_near,_far];
                                            _clearUntil=_far+6;
                                        };
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };
    private _marks = [];
    for "_along" from _bound to (_length - 1) step _bound do {
        private _mark = _along;
        if (_crossings findIf {_mark > ((_x select 0)-6) && {_mark < ((_x select 1)+6)}} < 0) then {_marks pushBack [_mark, "BOUND"]};
    };
    {
        _x params ["_near", "_far"];
        _marks pushBack [(_near - 3) max 1, "CROSS_NEAR"];
        _marks pushBack [(_far + 4) min _length, "CROSS_FAR"];
    } forEach _crossings;
    _marks sort true;
    {_points pushBack [_from getPos [_x select 0, _direction], _x select 1]} forEach _marks;
    _points pushBack [_to, if (_forEachIndex == count _legs - 1) then {_finalKind} else {"BOUND"}];
    _from = _to;
} forEach _legs;
_points
