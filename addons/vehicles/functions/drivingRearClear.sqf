/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes the swept rear body corridor before and during an owned native reverse leg.
 * Locality / Authority: Read-only on the current vehicle owner. It issues no movement, speed,
 * collision, physics or crew command. The consuming finite operation retains movement authority.
 * Repeat/JIP: No retained clearance or handlers. Each command boundary obtains fresh geometry;
 * observations cannot be replayed after a vehicle moves or changes owner.
 * Current relative velocities also project hull occupancy over two seconds before a reverse.
 * Constant translation is conservative evidence only; changing steering/acceleration is unknown.
 * Arguments:
 * 0 vehicle <OBJECT, objNull> - local ground vehicle.
 * 1 distance <NUMBER, 8> - metres behind the rear body edge, clamped to 1..60.
 * Return Value: ARRAY [clear BOOL, reason STRING, sampledAt NUMBER, rayCount NUMBER].
 * Dense candidate sets fail closed; at most 64 actors (eight hull corners each) and six
 * geometry rays are processed. The query includes a 35 m/s two-second approach envelope,
 * capped at 250 m; oversized envelopes refuse rather than silently truncating the rear area. Vertical overlap uses real hull extents rather than centre height.
 * Dead vehicle entities remain occupied hulls. Dead infantry are excluded from this actor
 * overlap policy; the solid-geometry rays remain independent and can still find obstructions.
 * Discovery uses one live-infantry and one dead-inclusive vehicle query; native query cost
 * remains engine-dependent even though subsequent hull evaluation is capped.
 * Current callers: DrivingAssistStart and CortexVehicleReverseStep.
 * Example: private _clearance = [truck1,8] call WAIT_fnc_DrivingRearClear;
 */
params [["_vehicle",objNull,[objNull]],["_distance",8,[0]]];
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {[false,"OWNER_UNAVAILABLE",time,0]};
_distance=(_distance max 1) min 60;
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _rear=_low select 1;
private _left=(_low select 0)-0.3;private _right=(_high select 0)+0.3;
private _halfWidth=((abs _left) max (abs _right))+4;
private _bodyRadius=sqrt (((abs _rear+_distance+4)^2)+(_halfWidth^2));
private _predictionSeconds=2;
private _radius=_bodyRadius max (35*_predictionSeconds+abs _rear+_distance+4);
if (_radius > 250) exitWith {[false,"REAR_SCAN_BUDGET",time,0]};
private _forward=vectorDir _vehicle;private _up=vectorUp _vehicle;
private _side=vectorNormalized (_forward vectorCrossProduct _up);
private _ownVelocity=velocity _vehicle;
private _area=[getPosATL _vehicle,_radius,_radius,0,false,_radius];
// Keep corpse density out of the live-person budget without dropping wrecked vehicles.
// Two bounded-envelope native queries per reverse admission or active-leg safety sample.
private _actors=(_vehicle nearEntities ["CAManBase",_radius])
    +(_area nearEntities [["LandVehicle"],false,false,false]);
if (count _actors > 64) exitWith {[false,"DENSE_REAR_TRAFFIC",time,0]};
private _predicted=false;
private _occupied=_actors findIf {
    private _thisActor=_x;
    _thisActor != _vehicle && {!(_thisActor in crew _vehicle)}
        && {alive _thisActor || {_thisActor isKindOf "LandVehicle"}}
    && {private _otherBox=boundingBoxReal _thisActor;
        private _otherLow=_otherBox select 0;private _otherHigh=_otherBox select 1;
        // Full projected hulls preserve overlap on slopes and separate stacked roads.
        // Centre height and four z=0 footprint corners cannot represent a tall/tilted hull.
        private _minX=1e9;private _maxX=-1e9;private _minY=1e9;private _maxY=-1e9;
        private _minZ=1e9;private _maxZ=-1e9;
        {
            private _height=_x;
            {
                private _width=_x;
                {
                    private _point=_vehicle worldToModel (_thisActor modelToWorld [_width,_x,_height]);
                    _minX=_minX min (_point select 0);_maxX=_maxX max (_point select 0);
                    _minY=_minY min (_point select 1);_maxY=_maxY max (_point select 1);
                    _minZ=_minZ min (_point select 2);_maxZ=_maxZ max (_point select 2);
                } forEach [_otherLow select 1,_otherHigh select 1];
            } forEach [_otherLow select 0,_otherHigh select 0];
        } forEach [_otherLow select 2,_otherHigh select 2];
        private _current=_maxX >= _left && {_minX <= _right} && {_maxY >= _rear-_distance}
            && {_minY <= _rear+0.5} && {_maxZ >= (_low select 2)-0.3}
            && {_minZ <= (_high select 2)+0.3};
        if (_current) exitWith {true};
        // Intersect overlap-time intervals on all three model axes. A diagonal crossing
        // must occupy width, depth and height together, not merely overlap their union.
        private _relative=(velocity _thisActor) vectorDiff _ownVelocity;
        private _modelVelocity=[_relative vectorDotProduct _side,_relative vectorDotProduct _forward,_relative vectorDotProduct _up];
        private _entry=0;private _exit=_predictionSeconds;private _possible=true;
        private _ranges=[[_minX,_maxX,_left,_right],[_minY,_maxY,_rear-_distance,_rear+0.5],
            [_minZ,_maxZ,(_low select 2)-0.3,(_high select 2)+0.3]];
        for "_axis" from 0 to 2 do {
            (_ranges select _axis) params ["_actorLow","_actorHigh","_areaLow","_areaHigh"];
            private _velocity=_modelVelocity select _axis;
            if (abs _velocity < 0.01) then {
                if (_actorHigh < _areaLow || {_actorLow > _areaHigh}) then {_possible=false};
            } else {
                private _a=(_areaLow-_actorHigh)/_velocity;private _b=(_areaHigh-_actorLow)/_velocity;
                _entry=_entry max (_a min _b);_exit=_exit min (_a max _b);
            };
        };
        private _crosses=_possible && {_entry <= _exit} && {_exit >= 0} && {_entry <= _predictionSeconds};
        if (_crosses) then {_predicted=true};
        _crosses
    }
} >= 0;
if (_occupied) exitWith {[false,["REAR_OCCUPIED","REAR_APPROACHING"] select _predicted,time,0]};
private _clear=true;private _rays=0;
{
    private _height=(_low select 2)+_x;
    {
        // Start at the body edge rather than the centre; width and pitch follow the real hull.
        private _from=_vehicle modelToWorldWorld [_x,_rear+0.1,_height];
        private _to=_vehicle modelToWorldWorld [_x,_rear-_distance,_height];
        _rays=_rays+1;
        if ((lineIntersectsSurfaces [_from,_to,_vehicle,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {_clear=false};
    } forEach [_left,(_left+_right)*0.5,_right];
    if (!_clear) exitWith {};
} forEach [0.45,0.9];
[_clear,["REAR_GEOMETRY","CLEAR"] select _clear,time,_rays]
