/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes the swept rear body corridor before a native vehicle reverse command.
 * Locality / Authority: Read-only on the current vehicle owner. It issues no movement, speed,
 * collision, physics or crew command. The consuming finite operation retains movement authority.
 * Repeat/JIP: No retained clearance or handlers. Each command boundary obtains fresh geometry;
 * observations cannot be replayed after a vehicle moves or changes owner.
 * Arguments:
 * 0 vehicle <OBJECT, objNull> - local ground vehicle.
 * 1 distance <NUMBER, 8> - metres behind the rear body edge, clamped to 1..60.
 * Return Value: ARRAY [clear BOOL, reason STRING, sampledAt NUMBER, rayCount NUMBER].
 * Dense candidate sets fail closed; at most 64 actors and six geometry rays are processed.
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
private _radius=sqrt (((abs _rear+_distance+4)^2)+(_halfWidth^2));
private _actors=_vehicle nearEntities [["CAManBase","LandVehicle"],_radius];
if (count _actors > 64) exitWith {[false,"DENSE_REAR_TRAFFIC",time,0]};
private _occupied=_actors findIf {
    _x != _vehicle && {!(_x in crew _vehicle)} && {alive _x}
    && {private _otherBox=boundingBoxReal _x;
        private _otherLow=_otherBox select 0;private _otherHigh=_otherBox select 1;
        // Project all four corners; a long vehicle's centre may sit outside our corridor.
        private _minX=1e9;private _maxX=-1e9;private _minY=1e9;private _maxY=-1e9;
        {
            _x params ["_object","_corner"];
            private _point=_vehicle worldToModel (_object modelToWorld _corner);
            _minX=_minX min (_point select 0);_maxX=_maxX max (_point select 0);
            _minY=_minY min (_point select 1);_maxY=_maxY max (_point select 1);
        } forEach [
            [_x,[_otherLow select 0,_otherLow select 1,0]],
            [_x,[_otherLow select 0,_otherHigh select 1,0]],
            [_x,[_otherHigh select 0,_otherLow select 1,0]],
            [_x,[_otherHigh select 0,_otherHigh select 1,0]]
        ];
        private _vertical=(_vehicle worldToModel (getPosATL _x)) select 2;
        _maxX >= _left && {_minX <= _right} && {_maxY >= _rear-_distance}
            && {_minY <= _rear+0.5} && {abs _vertical < 4}
    }
} >= 0;
if (_occupied) exitWith {[false,"REAR_OCCUPIED",time,0]};
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
