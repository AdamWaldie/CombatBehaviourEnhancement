/*
 * Author: WaldoTheWarfighter
 * Builds bounded helicopter anchor/descent/landing geometry for the controlled rappel port.
 * Read-only admission building block; it does not dispatch, reserve, move, animate or land actors.
 * Locality/authority: call on the intended executor with current replicated world geometry.
 * Repeat/JIP: no stored state or replay; a result is a snapshot, never permission to descend.
 * Revalidate against the live aircraft/obstacles before entry and during descent. No cached retry.
 * Arguments:
 * 0: helicopter <OBJECT> (objNull); living helicopter, upright and moving <=2 m/s.
 * 1: declared anchors <ARRAY> ([]); at most six model-space xyz or Memory selection names.
 *    Empty selects six bounded hull probes. Invalid declared input never falls back to discovery.
 * Return: <HASHMAP> aircraft, positionASL, direction, up, observedAt, routes.
 * Each route is [anchorModel, startASL, supportASL, supportObject]; <=2 routes, >=1.5m apart.
 * Empty routes means no admitted geometry. It is not a landing/arrival/cleanup acknowledgement.
 * Current callers: controlled rappel executor integration pending; no behaviour module exposed.
 * Example: private _plan = [helicopter, []] call CBE_fnc_RappelRoutePlan;
 * Limits: <=6 hull probes (8 hits each), <=60 route rays (one hit each), no world scan/worker.
 * Supports terrain or static House/Building surfaces with matching Roadway geometry. Refuses
 * water, vehicles, steep/narrow supports and obstructed corridors. Geometry is not walkability proof.
 *
 * Hull-probe layout adapted from Advanced Rappelling; separate animation/sound assets not copied.
 * The MIT License (MIT), Copyright (c) 2016 Seth Duda
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without restriction,
 * including without limitation the rights to use, copy, modify, merge, publish, distribute,
 * sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
params [["_aircraft",objNull,[objNull]],["_declared",[],[[]]]];
private _result=createHashMapFromArray [["aircraft",_aircraft],["routes",[]]];
if (isNull _aircraft || {!alive _aircraft} || {!(_aircraft isKindOf "Helicopter")}
    || {!simulationEnabled _aircraft} || {isObjectHidden _aircraft}
    || {vectorMagnitude velocity _aircraft > 2} || {(vectorUp _aircraft) select 2 < 0.97}
    || {count _declared > 6}) exitWith {_result};
private _vectorValid={
    params ["_value"];
    _value isEqualType [] && {count _value == 3}
        && {_value findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x} || {abs _x > 100000}} < 0}
};
private _box=2 boundingBoxReal _aircraft;
private _low=_box select 0;
private _high=_box select 1;
if (!([_low] call _vectorValid) || {!([_high] call _vectorValid)}
    || {_low distance _high > 100} || {_low distance _high < 1}) exitWith {_result};
private _points=[];
private _invalid=false;
if (_declared isNotEqualTo []) then {
    {
        if (isNil "_x") then {_invalid=true} else {
            private _point=_x;
            if (_point isEqualType "") then {
                if (count _point == 0 || {count _point > 64}) then {_invalid=true} else {
                    _point=_aircraft selectionPosition [_point,"Memory"];
                    if (_point isEqualTo [0,0,0]) then {_invalid=true};
                };
            };
            if (!([_point] call _vectorValid)) then {_invalid=true} else {
                if ([0,1,2] findIf {(_point select _x) < ((_low select _x)-1)
                    || {(_point select _x) > ((_high select _x)+1)}} >= 0) then {_invalid=true}
                else {_points pushBackUnique _point};
            };
        };
    } forEach _declared;
} else {
    // Six hull probes only: no mutable provider CODE, class tables or custom point list scans.
    private _mass=getCenterOfMass _aircraft;
    private _width=(((_high select 0)-(_low select 0))*0.5-abs (_mass select 0))*0.2;
    private _length=(((_high select 1)-(_low select 1))*0.5-abs (_mass select 1))*0.45;
    if (_width > 0 && {_length > 0}) then {
        {
            private _xModel=(_mass select 0)+(_x select 0)*_width*0.6;
            private _yModel=(_mass select 1)+(_x select 1)*_length*0.6;
            private _from=_aircraft modelToWorldWorld [_xModel,_yModel,(_low select 2)-0.5];
            private _to=_aircraft modelToWorldWorld [_xModel,_yModel,(_high select 2)+0.5];
            // Under-ground start is refused, not raised through the ground into an apparent hull.
            if ((ASLToAGL _from) select 2 > 0) then {
                private _hits=lineIntersectsSurfaces [_from,_to,objNull,objNull,true,8,"GEOM","NONE",false];
                private _index=_hits findIf {(_x select 2) == _aircraft || {(_x select 3) == _aircraft}};
                if (_index >= 0) then {
                    _points pushBackUnique (_aircraft worldToModel (ASLToAGL ((_hits select _index) select 0)));
                };
            };
        } forEach [[-1,0],[1,0],[-1,1],[1,1],[-1,-1],[1,-1]];
    };
};
if (_invalid) exitWith {_result};
private _routes=[];
{
    if (count _routes >= 2) exitWith {};
    private _anchor=_x;
    private _start=(_aircraft modelToWorldWorld _anchor) vectorAdd [0,0,-1];
    private _bottom=_start vectorAdd [0,0,-45];
    private _hits=lineIntersectsSurfaces [_start,_bottom,objNull,objNull,true,1,"GEOM","NONE"];
    if (_hits isNotEqualTo []) then {
        (_hits select 0) params ["_support","_normal","_object","_parent"];
        if (!isNull _parent) then {_object=_parent};
        private _height=(_start select 2)-(_support select 2);
        private _safe=_height >= 4 && {_height <= 45} && {_normal select 2 >= 0.9}
            && {!surfaceIsWater (ASLToAGL _support)}
            && {isNull _object || {(_object isKindOf "House" || {_object isKindOf "Building"})
                && {vectorMagnitude velocity _object < 0.05}}}
            && {_routes findIf {((_x select 2) distance2D _support) < 1.5} < 0};
        if (_safe && {!isNull _object}) then {
            private _road=lineIntersectsSurfaces [_start,_bottom,objNull,objNull,true,1,"ROADWAY","NONE"];
            _safe=_road isNotEqualTo [] && {((_road select 0) select 0) distance _support < 0.25}
                && {((_road select 0) select 2) == _object || {((_road select 0) select 3) == _object}};
        };
        if (_safe) then {
            // Four footprint supports and four body-clearance rays; do not ignore the helicopter.
            {
                private _offset=_x;
                private _foot=_support vectorAdd _offset;
                private _probe=lineIntersectsSurfaces [_foot vectorAdd [0,0,1.8],
                    _foot vectorAdd [0,0,-0.3],objNull,objNull,true,1,"GEOM","NONE"];
                if (_probe isEqualTo [] || {abs (((_probe select 0) select 0 select 2)-(_support select 2)) > 0.25}
                    || {((_probe select 0) select 1 select 2) < 0.9}
                    || {private _hitObject=(_probe select 0) select 2;
                        private _hitParent=(_probe select 0) select 3;
                        if (!isNull _hitParent) then {_hitObject=_hitParent};
                        _hitObject != _object}) exitWith {_safe=false};
                private _blocked=lineIntersectsSurfaces [_start vectorAdd _offset,
                    _foot vectorAdd [0,0,1.8],objNull,objNull,true,1,"GEOM","NONE"];
                if (_blocked isNotEqualTo []) exitWith {_safe=false};
            } forEach [[-0.5,0,0],[0.5,0,0],[0,-0.5,0],[0,0.5,0]];
        };
        if (_safe) then {_routes pushBack [_anchor,_start,_support,_object]};
    };
} forEach _points;
_result set ["positionASL",getPosASL _aircraft];
_result set ["direction",vectorDir _aircraft];
_result set ["up",vectorUp _aircraft];
_result set ["observedAt",diag_tickTime];
_result set ["routes",_routes];
_result
