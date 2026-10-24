/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes the swept rear body corridor before and during an owned native reverse leg.
 * Locality / Authority: Read-only on the current vehicle owner. It issues no movement, speed,
 * collision, physics or crew command. The consuming finite operation retains movement authority.
 * Repeat/JIP: No retained clearance or handlers. Each command boundary obtains fresh geometry;
 * observations cannot be replayed after a vehicle moves or changes owner. Normal unscheduled
 * callbacks share one lazy crew snapshot; scheduled direct calls retain per-actor crew reads.
 * Default rear travel uses nine support samples; longer corridors sample every <=4m
 * (at most48 support samples plus one target ray). Bridge geometry
 * remains eligible independently of terrain water. Vehicle/person and moving-prop surfaces cannot
 * support a reverse, including parent/proxy hits. Every support station rejects submerged ground;
 * static decks above water remain eligible. Discrete samples are not a continuous path proof.
 * Current relative velocities also project hull occupancy over two seconds before a reverse.
 * Measured reverse yaw adds a conservative full-body actor envelope and sampled corner sweeps.
 * These only veto additional hazards; changing steering/acceleration remains unknown.
 * Arguments:
 * 0 vehicle <OBJECT, objNull> - local ground vehicle.
 * 1 distance <NUMBER, 8> - metres behind the rear body edge, clamped to 1..60.
 * Non-finite distances refuse clearance before any world query or geometry calculation.
 * Return Value: ARRAY [clear BOOL, reason STRING, sampledAt NUMBER, rayCount NUMBER,
 * optional supported AGL destination ARRAY]. Destination exists only on the completed observation.
 * It is distance metres behind the vehicle origin, inside the observed rear-body envelope.
 * Dense candidate sets fail closed; at most64 actors use four transform pairs to represent each
 * full eight-corner hull with a0.05m outward model-space rounding pad. At most sixty
 * geometry rays plus up to49 support rays are processed (twelve rear rays plus forty-eight turning corner rays). The query includes a 35 m/s two-second approach envelope,
 * capped at 250 m; oversized envelopes refuse rather than silently truncating the rear area. Vertical overlap uses real hull extents rather than centre height.
 * Dead vehicle entities remain occupied hulls. Dead infantry are excluded from this actor
 * overlap policy; the solid-geometry rays remain independent and can still find obstructions.
 * Discovery uses one live-infantry and one dead-inclusive vehicle query; native query cost
 * remains engine-dependent even though subsequent hull evaluation is capped.
 * Current callers: DrivingRearPlan, active DrivingAssistStart monitoring and CortexVehicleReverseStep.
 * Example: private _clearance = [truck1,8] call CBE_fnc_DrivingRearClear;
 */
params [["_vehicle",objNull,[objNull]],["_distance",8,[0]]];
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {[false,"OWNER_UNAVAILABLE",time,0]};
if (!finite _distance) exitWith {[false,"INVALID_REAR_DISTANCE",time,0]};
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
// Additional veto only: retain the straight rear corridor even when measured yaw bends away.
// Unknown future native steering is not a path permission. Observe at most two seconds of
// current reverse motion, with three finite corner-sweep segments and no new world query.
private _reverseSpeed=(-(velocityModelSpace _vehicle select 1)) max 0;
private _yaw=(angularVelocityModelSpace _vehicle) param [2,0];
if (!finite _yaw) then {_yaw=0};
private _turnSeconds=if (_reverseSpeed > 0.25) then {2 min (_distance/_reverseSpeed)} else {0};
private _turnAngle=_yaw*_turnSeconds*57.2957795;
if (abs _turnAngle > 70) exitWith {[false,"REAR_TURN_ENVELOPE",time,0]};
private _turning=abs _turnAngle >= 3;
private _actorLeft=_left;private _actorRight=_right;
private _actorRear=_rear-_distance;private _actorFront=_rear+0.5;
if (_turning) then {
    // Any hull point rotating through theta moves <=2*radius*sin(theta/2).
    // Include forward corner swing as well as the commanded rear corridor. This broad
    // envelope intentionally refuses some nearby non-conflicting actors; no clearance grant.
    private _cornerRadius=sqrt (((abs (_low select 0)) max (abs (_high select 0)))^2
        +(((abs (_low select 1)) max (abs (_high select 1)))^2));
    private _rotationSwing=2*_cornerRadius*sin ((abs _turnAngle)*0.5);
    private _centreSwing=_reverseSpeed*(1-cos _turnAngle)/(abs _yaw);
    private _swing=_rotationSwing+_centreSwing;
    _actorLeft=_left-_swing;_actorRight=_right+_swing;
    _actorRear=_actorRear-_swing;_actorFront=(_high select 1)+_swing;
};
// Expanded turn actor bounds must remain inside discovery, including approaching actors.
private _actorRadius=sqrt (((abs _actorLeft) max (abs _actorRight))^2
    +(((abs _actorRear) max (abs _actorFront))^2));
_radius=_radius max (_actorRadius+35*_predictionSeconds);
if (_radius > 250) exitWith {[false,"REAR_SCAN_BUDGET",time,0]};
private _area=[getPosATL _vehicle,_radius,_radius,0,false,_radius];
// Keep corpse density out of the live-person budget without dropping wrecked vehicles.
// Two bounded-envelope native queries per reverse admission or active-leg safety sample.
private _actors=(_vehicle nearEntities ["CAManBase",_radius])
    +(_area nearEntities [["LandVehicle"],false,false,false]);
if (count _actors > 64) exitWith {[false,"DENSE_REAR_TRAFFIC",time,0]};
private _scheduledObservation=canSuspend;
private _crewObserved=false;private _ownCrew=[];
private _predicted=false;
private _occupied=_actors findIf {
    private _thisActor=_x;
    _thisActor != _vehicle && {
        // Normal PFH observations cannot suspend: one lazy crew snapshot is sufficient.
        // Preserve the direct scheduled-call contract, where the engine may advance between actors.
        if (!_crewObserved || {_scheduledObservation}) then {
            _ownCrew=crew _vehicle;_crewObserved=true;
        };
        !(_thisActor in _ownCrew)
    }
        && {alive _thisActor || {_thisActor isKindOf "LandVehicle"}}
    && {private _otherBox=boundingBoxReal _thisActor;
        private _otherLow=_otherBox select 0;private _otherHigh=_otherBox select 1;
        // Project the full box with one corner and three edges. Model transforms are affine:
        // each axis extremum is origin plus the negative/positive components of those edges.
        // This represents all eight corners with four transform pairs, including tilt/scale.
        private _origin=_vehicle worldToModel (_thisActor modelToWorld _otherLow);
        private _projectedLow=+_origin;private _projectedHigh=+_origin;
        {
            private _edge=(_vehicle worldToModel (_thisActor modelToWorld _x)) vectorDiff _origin;
            for "_axis" from 0 to 2 do {
                private _component=_edge select _axis;
                _projectedLow set [_axis,(_projectedLow select _axis)+(_component min 0)];
                _projectedHigh set [_axis,(_projectedHigh select _axis)+(_component max 0)];
            };
        } forEach [[_otherHigh select 0,_otherLow select 1,_otherLow select 2],
            [_otherLow select 0,_otherHigh select 1,_otherLow select 2],
            [_otherLow select 0,_otherLow select 1,_otherHigh select 2]];
        // A small outward pad avoids narrowing the safety envelope through subtraction rounding.
        private _minX=(_projectedLow select 0)-0.05;private _maxX=(_projectedHigh select 0)+0.05;
        private _minY=(_projectedLow select 1)-0.05;private _maxY=(_projectedHigh select 1)+0.05;
        private _minZ=(_projectedLow select 2)-0.05;private _maxZ=(_projectedHigh select 2)+0.05;
        private _current=_maxX >= _actorLeft && {_minX <= _actorRight} && {_maxY >= _actorRear}
            && {_minY <= _actorFront} && {_maxZ >= (_low select 2)-0.3}
            && {_minZ <= (_high select 2)+0.3};
        if (_current) exitWith {true};
        // Intersect overlap-time intervals on all three model axes. A diagonal crossing
        // must occupy width, depth and height together, not merely overlap their union.
        // Turning bounds already include our integrated translation in this fixed starting
        // frame. Subtracting our velocity again would count our travel twice.
        private _relative=if (_turning) then {velocity _thisActor} else {
            (velocity _thisActor) vectorDiff _ownVelocity
        };
        private _modelVelocity=[_relative vectorDotProduct _side,_relative vectorDotProduct _forward,_relative vectorDotProduct _up];
        private _entry=0;private _exit=_predictionSeconds;private _possible=true;
        private _ranges=[[_minX,_maxX,_actorLeft,_actorRight],[_minY,_maxY,_actorRear,_actorFront],
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
// Retain knee/bumper observations and sample the actual middle/top of taller hulls.
// These discrete beams still cannot certify a continuously swept body volume.
private _bodyHeight=((_high select 2)-(_low select 2)) max 0.9;
private _heights=[0.45,0.9,(_bodyHeight+0.45)*0.5,_bodyHeight];
_heights=_heights arrayIntersect _heights;
private _clear=true;private _rays=0;
// Empty space behind a hull is not drivable ground. Probe the actual support surface in
// the current vehicle frame, including raised road/bridge geometry above water or terrain.
// Fixed samples bound cost; later callbacks must observe again as the native leg progresses.
// Match forward path support policy: another vehicle or a moving prop is not a road deck.
// Resolve parent/proxy consistently; terrain remains valid with objNull and static bridges survive.
private _stableSupport={
    params ["_hit"];
    private _support=if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2};
    // Every station must preserve the support layer, not just the final target.
    // Submerged terrain between two dry deck points is not a traversable bridge.
    private _drySupport=!(surfaceIsWater (_hit select 0))
        || {!isNull _support && {((_hit select 0) select 2) > 0.25}};
    _drySupport && {isNull _support || {!(_support isKindOf "AllVehicles")
        && {vectorMagnitude velocity _support <= 0.1}}}
};
private _supported=true;
private _supportDistances=[1 min _distance,_distance*0.5,_distance];
if (_distance > 8) then {
    _supportDistances=[1];
    for "_station" from 1 to (ceil (_distance/4)) do {_supportDistances pushBack ((_station*4) min _distance)};
};
{
    private _depth=_rear-_x;
    {
        private _from=_vehicle modelToWorldWorld [_x,_depth,(_low select 2)+1.2];
        private _to=_vehicle modelToWorldWorld [_x,_depth,(_low select 2)-2];
        _rays=_rays+1;
        private _hits=lineIntersectsSurfaces [_from,_to,_vehicle,objNull,true,1,"GEOM","NONE"];
        if (_hits isEqualTo [] || {((_hits select 0 select 1) select 2) < 0.7}
            || {!([_hits select 0] call _stableSupport)}) exitWith {_supported=false};
    } forEach [_low select 0,((_low select 0)+(_high select 0))*0.5,_high select 0];
    if (!_supported) exitWith {};
} forEach (_supportDistances arrayIntersect _supportDistances);
if (!_supported) exitWith {[false,"REAR_SUPPORT",time,_rays]};
// Native movement needs the actual supported surface height, not a terrain-level destination.
// One extra centre-target ray stays inside the already observed rear-body envelope. Open water
// with only submerged terrain is not a deck; require a real hit object above water in that case.
private _targetFrom=_vehicle modelToWorldWorld [0,-_distance,(_low select 2)+1.2];
private _targetTo=_vehicle modelToWorldWorld [0,-_distance,(_low select 2)-2];
_rays=_rays+1;
private _targetHits=lineIntersectsSurfaces [_targetFrom,_targetTo,_vehicle,objNull,true,1,"GEOM","NONE"];
if (_targetHits isEqualTo []) exitWith {[false,"REAR_TARGET_SUPPORT",time,_rays]};
private _targetHit=_targetHits select 0;
private _destination=ASLToAGL (_targetHit select 0);
if (((_targetHit select 1) select 2) < 0.7
    || {!([_targetHit] call _stableSupport)}) exitWith {
    [false,"REAR_TARGET_SUPPORT",time,_rays]
};

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
} forEach _heights;
if (_clear && {_turning}) then {
    {
        private _height=(_low select 2)+_x;
        {
            private _width=_x;
            {
                private _depth=_x;
                private _from=_vehicle modelToWorldWorld [_width,_depth,_height];
                for "_segment" from 1 to 3 do {
                    private _elapsed=_turnSeconds*_segment/3;
                    private _angle=_yaw*_elapsed*57.2957795;
                    // Integrate constant measured yaw and reverse speed, then rotate the
                    // rigid hull offset with the same pose. Three chords are samples only.
                    private _centreX=-_reverseSpeed*(1-cos _angle)/_yaw;
                    private _centreY=-_reverseSpeed*sin _angle/_yaw;
                    private _to=_vehicle modelToWorldWorld [
                        _centreX+_width*cos _angle+_depth*sin _angle,
                        _centreY-_width*sin _angle+_depth*cos _angle,_height];
                    _rays=_rays+1;
                    if ((lineIntersectsSurfaces [_from,_to,_vehicle,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []) exitWith {_clear=false};
                    _from=_to;
                };
                if (!_clear) exitWith {};
            } forEach [_low select 1,_high select 1];
            if (!_clear) exitWith {};
        } forEach [_left,_right];
        if (!_clear) exitWith {};
    } forEach _heights;
};
[_clear,["REAR_GEOMETRY","CLEAR"] select _clear,time,_rays,_destination]
