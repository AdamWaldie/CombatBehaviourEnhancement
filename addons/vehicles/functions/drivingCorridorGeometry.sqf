/*
 * Author: WaldoTheWarfighter
 * Purpose: Builds a bounded elevated corridor proposal from current solid support and hull width.
 * Locality / Authority: Read-only on the vehicle owner; no movement/physics/AI commands.
 * Repeat/JIP: No cache or handlers. Call at admission; the executor must invalidate on transform,
 * revision, vehicle or owner changes and retain runtime obstacle checks. Never replay as clearance.
 * Arguments:
 * 0 vehicle <OBJECT, objNull> - local live LandVehicle.
 * 1 area <OBJECT, objNull> - registered Logic, whose world elevation selects the support layer.
 * 2 definition <ARRAY, []> - exact public [revision, halfLength, halfWidth, speedKmh].
 * 3 side <NUMBER, 1> - entry end, exactly -1 or 1 along the area's forward axis.
 * 4 envelope <ARRAY, []> - optional convoy [halfWidth, halfLength, height] metres;
 *   expands the measured lead hull only, never shrinks it. At most three finite scalars.
 * Return Value: ARRAY [valid BOOL, reason STRING, pointsATL ARRAY, pointsASL ARRAY,
 *   transform ARRAY, rayCount NUMBER]. Maximum 20 support stations, 60 support rays and
 *   114 body rays (174 total). Samples are a proposal, not proof of swept-volume passability.
 * Current callers: DrivingCorridorStep, at admission only.
 * Example: [truck1,corridorLogic,corridorLogic getVariable ["WAIT_DrivingCorridor_Task",[]],1]
 *   call WAIT_fnc_DrivingCorridorGeometry;
 */
params [["_vehicle",objNull,[objNull]],["_area",objNull,[objNull]],
    ["_definition",[],[[]]],["_side",1,[0]],["_envelope",[],[[]]]];
private _failure={params ["_reason",["_rays",0]];[false,_reason,[],[],[],_rays]};
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}
    || {!(_vehicle isKindOf "LandVehicle")} || {isNull _area}) exitWith {["OWNER_UNAVAILABLE"] call _failure};
if (count _definition != 4 || {_definition findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(_side in [-1,1])}) exitWith {["INVALID_DEFINITION"] call _failure};
_definition params ["_revision","_halfLength","_halfWidth","_speed"];
if (_halfLength < 5 || {_halfLength > 45} || {_halfWidth < 2} || {_halfWidth > 20}
    || {_speed < 5} || {_speed > 30}
    || {!((_area getVariable ["WAIT_DrivingCorridor_Task",[]]) isEqualTo _definition)}) exitWith {
    ["STALE_DEFINITION"] call _failure
};
private _transform=[getPosWorld _area,vectorDir _area,vectorUp _area];
if (((vectorUp _area) select 2) < 0.98) exitWith {["TILTED_AREA"] call _failure};
private _axis=vectorDir _area;_axis set [2,0];_axis=vectorNormalized _axis;
private _right=[_axis select 1,-(_axis select 0),0];
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
if (_envelope isNotEqualTo [] && {count _envelope != 3 || {
    _envelope findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x > 100}} >= 0
}}) exitWith {["INVALID_ENVELOPE"] call _failure};
private _hullWidth=(((abs (_low select 0)) max (abs (_high select 0)))
    max (_envelope param [0,0]))+0.5;
if (_hullWidth > _halfWidth) exitWith {["HULL_TOO_WIDE"] call _failure};
private _height=(((_high select 2)-(_low select 2)) max 1) max (_envelope param [2,0]);
// Preserve the selected world layer. A deck above water is valid solid support; an empty
// water surface is not. Do not silently substitute terrain below an unsupported bridge.
private _centre=getPosASL _area;
private _halfBodyLength=((abs (_low select 1)) max (abs (_high select 1))) max (_envelope param [1,0]);
// The tail must clear the far plane too. A fixed ten-metre endpoint strands long hulls.
private _extension=(sqrt ((_halfBodyLength^2)+(_hullWidth^2))+6) max 10;
if (_extension > 30) exitWith {["HULL_TOO_LONG"] call _failure};
private _span=2*(_halfLength+_extension);
private _segments=ceil (_span/8);
private _points=[];private _rays=0;private _reason="";
for "_station" from 0 to _segments do {
    if (_reason isEqualTo "") then {
        private _along=(_halfLength+_extension-(_span*_station/_segments))*_side;
        private _base=_centre vectorAdd (_axis vectorMultiply _along);
        private _supports=[];
        {
            private _sample=_base vectorAdd (_right vectorMultiply _x);
            private _hits=lineIntersectsSurfaces [_sample vectorAdd [0,0,3],
                _sample vectorAdd [0,0,-3],_vehicle,_area,true,1,"GEOM","NONE",true];
            _rays=_rays+1;
            if (_hits isEqualTo []) then {_reason="MISSING_SUPPORT"} else {
                private _hit=_hits select 0;
                // Solid terrain beneath water is not a dry crossing permission. An elevated
                // object deck can remain eligible over water; fording capability is unfinished.
                if (surfaceIsWater _sample && {isNull (_hit select 2) || {((_hit select 0) select 2) <= 0.25}}) then {
                    _reason="WET_SUPPORT";
                };
                if (((_hit select 1) select 2) < 0.85) then {_reason="STEEP_SUPPORT"};
                _supports pushBack (_hit select 0);
            };
        } forEach [-_hullWidth,0,_hullWidth];
        if (count _supports == 3) then {
            private _middle=_supports select 1;
            if (abs (((_supports select 0) select 2)-(_middle select 2)) > 0.5
                || {abs (((_supports select 2) select 2)-(_middle select 2)) > 0.5}) then {
                _reason="CROSS_SLOPE"
            };
            _points pushBack _middle;
        };
    };
};
if (_reason isNotEqualTo "") exitWith {[_reason,_rays] call _failure};
for "_segment" from 1 to _segments do {
    if (_reason isEqualTo "") then {
        private _from=_points select (_segment-1);private _to=_points select _segment;
        if (abs ((_to select 2)-(_from select 2)) > (_from distance2D _to)*0.25) then {
            _reason="LONGITUDINAL_SLOPE"
        };
        {
            private _offset=_right vectorMultiply _x;
            {
                private _up=[0,0,_x];
                private _hits=lineIntersectsSurfaces [(_from vectorAdd _offset) vectorAdd _up,
                    (_to vectorAdd _offset) vectorAdd _up,_vehicle,_area,true,1,"GEOM","NONE",true];
                _rays=_rays+1;
                if (_hits isNotEqualTo []) then {_reason="BODY_OBSTRUCTION"};
            } forEach [0.5,_height];
        } forEach [-_hullWidth,0,_hullWidth];
    };
};
if (_reason isNotEqualTo "") exitWith {[_reason,_rays] call _failure};
if (!((_area getVariable ["WAIT_DrivingCorridor_Task",[]]) isEqualTo _definition)
    || {!([getPosWorld _area,vectorDir _area,vectorUp _area] isEqualTo _transform)}) exitWith {
    ["AREA_CHANGED",_rays] call _failure
};
[true,"PROPOSAL",_points apply {ASLToATL _x},_points,_transform,_rays]
