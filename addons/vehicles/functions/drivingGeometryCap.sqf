/*
 * Author: WaldoTheWarfighter
 * Purpose: Samples live forward body geometry once for both gates and other solid obstructions.
 * Locality / Authority: Read-only on vehicle owner; trusted server may recheck a remote vehicle.
 * Existing driving/convoy callbacks own all speed/movement commands. No helper props or physics.
 * Repeat/JIP: No handlers/cache/clearance leases. Current transforms and GEOM surfaces are sampled
 * on every call; deletion, movement, rotation and damage do not rely on a mission-object grid.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 requested m/s <NUMBER, 20>, clamped 0..35;
 * 2 server recheck <BOOL, false> - read-only remote-vehicle sampling allowed on server;
 * 3 measured curvature <ARRAY, []> optional finite inverse-metre value from local track;
 * optional second BOOL permits stopped prediction only for fresh native-path evidence;
 * optional third ARRAY contains three fresh ASL path stations at0/3/6m for support observation.
 * An optional fourth native-grade value is consumed by speed policy, not geometry clearance.
 * Empty retains instantaneous native-yaw fallback for independent server/script rechecks.
 * 4 near-contact probe BOOL false; a current stationary pose permits twelve low diagonal/side
 * probes. Callers must qualify failed ordinary recovery before enabling them. Gates, actors,
 * active/attached objects and ambiguous two-sided contact do not become a side diagnosis.
 * Return Value: ARRAY [gate observation ARRAY, solid observation ARRAY]. Gate observation retains
 * [cap m/s, gate OBJECT, gap metres, time, rays]. Solid is empty without a sampled blocker, else
 * [cap m/s, object (objNull for terrain), gap, time, rays, kind, hit ASL, normal, transform].
 * Work: nine straight or at most27 turning rays, plus at most12 qualified near-contact rays;
 * a fresh native grade transition adds at most9 support casts and6 low forward casts within6m.
 * each returns <=4hits. Nominal braking horizon <=600m. No new discovery query or timer.
 * Gate classification is cached only within this call: up to180 hit objects/up to32 config checks
 * each for ambiguous barrier names and native Wall/Fence classes. Static walls and
 * H-barriers are not assumed to be animated gates; house doors gain no generic fallback.
 * Current forward motion and model-space yaw predict at most 2.5 seconds of curved travel,
 * clamped to 70 degrees; the remaining horizon follows the final tangent. Rigid hull offsets
 * rotate with each predicted pose. Unsupported/stationary yaw falls back to straight sensing.
 * Existing hull rows retain current absolute pitch/elevation. Fresh native path stations may add
 * a six-metre support-relative low row when grade diverges by more than0.3m. Each width/station
 * needs one unambiguous upward surface within0.4m of native path elevation; no terrain fallback,
 * support cache or clearance permission. Missing, multiple or steep surfaces refuse the extra row.
 * Gentle upward support is excluded from generic
 * blocking. Downward-facing underside hits remain solid constraints; occupied/active land-vehicle and pedestrian hulls retain their dedicated observers.
 * Stationary engine-off unoccupied land hulls also feed finite bypass planning; their independent
 * traffic cap remains active. Per-call classification inspects at most 16 land hulls and avoids
 * repeated crew reads per ray. Over-budget hulls retain traffic-only handling. No hit
 * never proves an entire path clear. Predicted turns, narrow/low geometry, slopes and actual braking
 * need physical validation. This observes approach constraints, not a bypass/detour executor.
 * Current callers: DrivingAssistStart, ConvoyTick and DrivingGateCap's server-compatible adapter.
 * Example: private _observed=[truck1,15] call CBE_fnc_DrivingGeometryCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]],["_serverCheck",false,[true]],["_measured",[],[[]]],["_nearContact",false,[true]]];
if (!finite _requested) then {_requested=0};
_requested=(_requested max 0) min 35;
if (isNull _vehicle || {!local _vehicle && {!(_serverCheck && {isServer})}} || {!alive _vehicle}) exitWith {[[_requested,objNull,-1,time,0],[]]};
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _front=(_high select 1)+0.2;
private _left=(_low select 0)-0.2;private _right=(_high select 0)+0.2;
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
private _velocity=((velocity _vehicle) vectorDotProduct (vectorDir _vehicle)) max 0;
private _speed=_velocity max _requested;
private _horizon=((_speed*_reaction)+((_speed*_speed)/(2*_deceleration))+6) max 25 min 600;
// Read-only native yaw needs no per-vehicle history, publication or extra callback.
private _yaw=(angularVelocityModelSpace _vehicle) param [2,0];
if (!finite _yaw || {_velocity <= 1}) then {_yaw=0};
private _bendLength=(_velocity*2.5) max 8 min _horizon;
private _curvature=if (_velocity > 1) then {_yaw/_velocity} else {0};
if (count _measured in [1,2,3,4] && {(_measured select 0) isEqualType 0} && {finite (_measured select 0)}) then {
    _curvature=if (_velocity > 1 || {_measured param [1,false,[true]]}) then {_measured select 0} else {0};
};
private _maxCurvature=(70/57.2957795)/_bendLength;
_curvature=(_curvature max -_maxCurvature) min _maxCurvature;
private _turning=abs (_curvature*_bendLength*57.2957795) >= 3;
private _stations=[[0,0,0,0],[0,_horizon,0,_horizon]];
if (_turning) then {
    _stations=[[0,0,0,0]];
    {
        private _distance=_x;private _bent=_distance min _bendLength;
        private _angle=_curvature*_bent*57.2957795;
        private _xPos=(1-cos _angle)/_curvature;private _yPos=(sin _angle)/_curvature;
        if (_distance > _bendLength) then {
            _xPos=_xPos+sin _angle*(_distance-_bendLength);
            _yPos=_yPos+cos _angle*(_distance-_bendLength);
        };
        _stations pushBack [_xPos,_yPos,_angle,_distance];
    } forEach ([0.5*_bendLength,_bendLength,_horizon] arrayIntersect [0.5*_bendLength,_bendLength,_horizon]);
};
private _nearest=1e9;private _gate=objNull;private _rays=0;
private _solidGap=1e9;private _solid=[];private _gateClasses=createHashMap;
private _staticHulls=createHashMap;
private _bottom=(_low select 2)+0.45;
private _top=((_high select 2)-0.2) max _bottom;
private _heights=[_bottom,(_bottom+_top)*0.5,_top];
_heights=_heights arrayIntersect _heights;
private _samples=[];
{
    private _height=_x;
    {
        private _width=_x;
        for "_segment" from 1 to (count _stations-1) do {
        private _modelPoints=[_stations select (_segment-1),_stations select _segment] apply {
            _x params ["_centreX","_centreY","_angle"];
            [_centreX+_width*cos _angle+_front*sin _angle,
                _centreY-_width*sin _angle+_front*cos _angle,_height]
        };
        private _from=_vehicle modelToWorldWorld (_modelPoints select 0);
        private _to=_vehicle modelToWorldWorld (_modelPoints select 1);
        _samples pushBack [_from,_to,(_stations select (_segment-1)) select 3,(_stations select _segment) select 3,0];
        };
    } forEach [_left,(_left+_right)*0.5,_right];
} forEach _heights;
// Add observations only where a fresh native path departs from rigid pitch. Keep
// the original hull rows: these short low rows never erase an overhead constraint.
private _supportPath=_measured param [2,[],[[]]];
if (count _supportPath == 3 && {_supportPath findIf {!(_x isEqualType []) || {count _x != 3}
    || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} < 0}) then {
    private _supportEnd=_supportPath select 2;
    private _modelEnd=_vehicle worldToModel (ASLToAGL _supportEnd);
    private _modelStart=_vehicle worldToModel (ASLToAGL (_supportPath select 0));
    if (abs ((_modelEnd select 2)-(_modelStart select 2)) > 0.3
        && {(_modelEnd select 1) > 1} && {(_supportPath select 0) distance2D getPosASL _vehicle <= 3}
        && {(_supportPath select 0) distance2D _supportEnd <= 7}) then {
        private _supportRows=[];private _supported=true;
        {
            private _width=_x;private _row=[];
            for "_station" from 0 to 2 do {
                private _point=+(_supportPath select _station);
                private _tangent=(_supportPath select ((_station+1) min 2)) vectorDiff
                    (_supportPath select ((_station-1) max 0));
                _tangent set [2,0];
                if (vectorMagnitude _tangent < 0.1) exitWith {_supported=false};
                _tangent=vectorNormalized _tangent;
                _point=_point vectorAdd ([_tangent select 1,-(_tangent select 0),0] vectorMultiply _width);
                // A short vertical window cannot silently fall through an elevated deck
                // to distant terrain. Multiple plausible upward levels are ambiguous.
                private _surfaces=lineIntersectsSurfaces [_point vectorAdd [0,0,0.75],
                    _point vectorAdd [0,0,-0.75],_vehicle,objNull,true,4,"GEOM","NONE"];
                _rays=_rays+1;
                private _levels=_surfaces select {((_x select 1) select 2) >= 0.7
                    && {abs (((_x select 0) select 2)-(_point select 2)) <= 0.4}};
                if (count _levels != 1) exitWith {_supported=false};
                _row pushBack (((_levels select 0) select 0) vectorAdd [0,0,0.45]);
            };
            if (!_supported) exitWith {};
            _supportRows pushBack _row;
        } forEach [_left,(_left+_right)*0.5,_right];
        if (_supported) then {
            {
                private _row=_x;
                for "_station" from 1 to 2 do {
                    private _startGap=((getPosASL _vehicle distance2D (_supportPath select (_station-1)))-_front) max 0;
                    private _endGap=((getPosASL _vehicle distance2D (_supportPath select _station))-_front) max _startGap;
                    _samples pushBack [_row select (_station-1),_row select _station,_startGap,_endGap,0];
                };
            } forEach _supportRows;
        };
    };
};
private _leftContact=[];private _rightContact=[];private _probeBudget=true;private _probeObjects=createHashMap;
if (_nearContact) then {
    private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
    if (finite _linear && {finite _angular} && {_linear < (1/3.6)} && {_angular < 0.01}) then {
        private _frontY=_high select 1;private _rearY=_low select 1;
        private _quarter=_frontY-(_frontY-_rearY)*0.25;
        {
            private _side=_x;
            private _edge=if (_side < 0) then {(_low select 0)+0.1} else {(_high select 0)-0.1};
            {
                private _z=(_low select 2)+_x;
                {
                    _x params ["_fromY","_toY","_reach"];
                    private _from=_vehicle modelToWorldWorld [_edge,_fromY,_z];
                    private _to=_vehicle modelToWorldWorld [_edge+_side*_reach,_toY,_z];
                    _samples pushBack [_from,_to,0,0,_side];
                } forEach [[_frontY-0.1,_frontY+0.55,0.7],[_quarter,_quarter,0.6],[0,0,0.6]];
            } forEach [0.3,0.6];
        } forEach [-1,1];
    };
};
{
        _x params ["_from","_to","_segmentStart","_segmentEnd","_probeSide"];
        _rays=_rays+1;
        private _hits=lineIntersectsSurfaces [_from,_to,_vehicle,objNull,true,4,"GEOM","NONE"];
        {
            private _hit=_x;
            private _object=_hit select 3;
            if (isNull _object) then {_object=_hit select 2};
            private _position=_hit select 0;private _normal=_hit select 1;
            // Braking uses vehicle travel, not the longer arc of its outer body edge.
            private _fraction=((_from vectorDistance _position)/((_from vectorDistance _to) max 0.01)) min 1;
            private _gap=_segmentStart+_fraction*(_segmentEnd-_segmentStart);
            private _isGate=false;
            if (!isNull _object && {_object != _vehicle}) then {
                private _classKey=typeOf _object;
                if (_classKey == "") then {_classKey=str _object};
                private _known=_gateClasses getOrDefault [_classKey,-1];
                if (_known isEqualType true) then {_isGate=_known} else {
                    private _name=toLowerANSI ((typeOf _object)+" "+((getModelInfo _object) param [0,""]));
                    _isGate=["gate","zavora","vrata","branka"] findIf {_name find _x >= 0} >= 0;
                    // Concrete H-barriers and bag walls are obstacles, not gates to animate.
                    // Native wall/fence gates may have no gate/barrier word in the model name.
                    // Require a supported indexed source for these candidates too. Ordinary house
                    // doors gain no generic animation fallback; static walls stay solid obstacles.
                    // At most32 config existence checks per distinct class in this observation.
                    if (!_isGate && {_name find "barrier" >= 0
                        || {_object isKindOf "Wall"} || {_object isKindOf "Fence"}}) then {
                        private _sourceConfig=configOf _object >> "AnimationSources";
                        for "_index" from 1 to 8 do {
                            if ([format ["Door_%1_sound_source",_index],format ["Gate_%1_sound_source",_index],
                                format ["Door_%1_source",_index],format ["Gate_%1_source",_index]]
                                findIf {isClass (_sourceConfig >> _x)} >= 0) exitWith {_isGate=true};
                        };
                    };
                    _gateClasses set [_classKey,_isGate];
                };
                if (_probeSide == 0 && {_isGate} && {_gap < _nearest}) then {_nearest=_gap;_gate=_object};
            };
            // Traffic and pedestrians retain their existing hull observers. Static/classless
            // props, parked aircraft/boats and steep terrain add no synthetic collision props.
            // Upward-facing support is not a blocking wall merely because a forward ray meets a hill/deck.
            // Downward-facing undersides still obstruct the sampled body rows; abs(normal Z)
            // would also erase those overhead constraints.
            private _staticHull=false;
            if (!isNull _object && {_object isKindOf "LandVehicle"}) then {
                private _key=str _object;
                private _cached=_staticHulls getOrDefault [_key,-1];
                if (_cached isEqualType true) then {_staticHull=_cached} else {
                    if (count _staticHulls < 16) then {
                        _staticHull=[_object] call CBE_fnc_DrivingBypassObstacleAvailable;
                        _staticHulls set [_key,_staticHull];
                    };
                };
            };
            private _represented=!isNull _object && {_object isKindOf "CAManBase" || {_object isKindOf "LandVehicle" && {!_staticHull}}};
            if (!_isGate && {!_represented} && {(_normal select 2) < 0.7}) then {
                private _kind=if (isNull _object) then {"TERRAIN"} else {
                    ["STATIC","MOVING_OBJECT"] select (abs speed _object > 0.5)
                };
                private _transform=if (isNull _object) then {[]} else {[getPosWorld _object,vectorDir _object,vectorUp _object]};
                private _candidate=[_object,_kind,+_position,+_normal,_transform];
                if (_probeSide == 0) then {
                    if (_gap < _solidGap) then {_solidGap=_gap;_solid=_candidate};
                } else {
                    if (!isNull _object && {_kind == "STATIC"}) then {
                        private _key=str _object;private _available=_probeObjects getOrDefault [_key,-1];
                        if !(_available isEqualType true) then {
                            if (count _probeObjects >= 16) then {_probeBudget=false;_available=false} else {
                                _available=[_object] call CBE_fnc_DrivingBypassObstacleAvailable;
                                _probeObjects set [_key,_available];
                            };
                        };
                        if (_available) then {
                            if (_probeSide < 0 && {_leftContact isEqualTo []}) then {_leftContact=_candidate};
                            if (_probeSide > 0 && {_rightContact isEqualTo []}) then {_rightContact=_candidate};
                        };
                    };
                };
            };
        } forEach _hits;
} forEach _samples;
// Sampled contact on both sides is not a one-sided diagnosis. Preserve the normal
// forward result in that case; no side clearance or lateral movement is inferred.
if (_probeBudget && {(_leftContact isEqualTo []) != (_rightContact isEqualTo [])}) then {
    _solidGap=0;_solid=if (_leftContact isNotEqualTo []) then {_leftContact} else {_rightContact};
};
private _capForGap={
    params ["_gap"];
    private _room=(_gap-6) max 0;
    private _reactionSpeed=_deceleration*_reaction;
    _requested min ((sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0)
};
private _gateObservation=if (isNull _gate) then {[_requested,objNull,-1,time,_rays]} else {
    [[_nearest] call _capForGap,_gate,_nearest,time,_rays]
};
private _solidObservation=if (_solid isEqualTo []) then {[]} else {
    [[_solidGap] call _capForGap,_solid select 0,_solidGap,time,_rays,
        _solid select 1,_solid select 2,_solid select 3,_solid select 4]
};
[_gateObservation,_solidObservation]
