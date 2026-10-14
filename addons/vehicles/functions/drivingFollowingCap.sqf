/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes same-direction vehicles ahead and derives a continuous following speed cap.
 * Locality/authority: read-only on the current vehicle owner. The driving operation owns all
 * speed commands and rechecks its driver, route and movement lease before applying this result.
 * Repeat/JIP: no handlers or cached clearance. Each sample uses actual velocity and current hull
 * corners; results must not be replayed after movement, route replacement or locality change.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 requested cap m/s <NUMBER>, 20 (0..35).
 * Return: ARRAY [cap m/s NUMBER, limiting vehicle OBJECT, hull gap m NUMBER,
 * sampledAt NUMBER, candidate count NUMBER]. Dense sets return zero and the vehicle itself as
 * a congestion sentinel; at most 64 candidate hulls are evaluated, eight corners each.
 * Current callers: WAIT_fnc_DrivingAssistStart, through its finite operation scheduler.
 * Example: private _traffic = [truck1,20] call WAIT_fnc_DrivingFollowingCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]]];
_requested=(_requested max 0) min 35;
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {[_requested,objNull,-1,time,0]};
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _front=_high select 1;
private _forward=vectorDir _vehicle;_forward set [2,0];
if (vectorMagnitude _forward < 0.1) exitWith {[_requested,objNull,-1,time,0]};
_forward=vectorNormalized _forward;
private _ownForward=((velocity _vehicle) vectorDotProduct _forward) max 0;
private _radius=((_ownForward max _requested)*6+20+(abs _front)) min 250;
private _candidates=_vehicle nearEntities [["LandVehicle"],_radius];
if (count _candidates > 64) exitWith {[0,_vehicle,-1,time,count _candidates]};
private _cap=_requested;private _limiting=objNull;private _gap=-1;
{
    private _other=_x;
    private _otherForward=((velocity _other) vectorDotProduct _forward) max 0;
    // Actual hull heading and projected velocity distinguish an ordinary predecessor from
    // crossing/oncoming traffic. Those cases require separate arbitration, not this follower rule.
    if (_other != _vehicle && {alive _other}
        && {((vectorDir _other) vectorDotProduct _forward) > 0.7}
        && {((velocity _other) vectorDotProduct _forward) >= -0.5}) then {
        private _otherBox=boundingBoxReal _other;
        private _otherLow=_otherBox select 0;private _otherHigh=_otherBox select 1;
        private _minX=1e9;private _maxX=-1e9;private _minY=1e9;private _maxY=-1e9;
        private _minZ=1e9;private _maxZ=-1e9;
        {
            private _height=_x;
            {
                private _width=_x;
                {
                    private _point=_vehicle worldToModel (_other modelToWorld [_width,_x,_height]);
                    _minX=_minX min (_point select 0);_maxX=_maxX max (_point select 0);
                    _minY=_minY min (_point select 1);_maxY=_maxY max (_point select 1);
                    _minZ=_minZ min (_point select 2);_maxZ=_maxZ max (_point select 2);
                } forEach [_otherLow select 1,_otherHigh select 1];
            } forEach [_otherLow select 0,_otherHigh select 0];
        } forEach [_otherLow select 2,_otherHigh select 2];
        private _centre=_vehicle worldToModel (getPosATL _other);
        private _ahead=(_centre select 1) > _front;
        private _sameLane=_maxX >= (_low select 0)-0.25 && {_minX <= (_high select 0)+0.25};
        private _sameHeight=_maxZ >= (_low select 2)-0.25 && {_minZ <= (_high select 2)+0.25};
        if (_ahead && {_sameLane} && {_sameHeight}) then {
            private _hullGap=(_minY-_front) max 0;
            // Desired six-metre gap plus 1.8 seconds of predecessor travel. Continuous correction
            // avoids binary distance-band starts/stops. Closing-distance reaction only lowers it.
            private _allowed=(_otherForward+((_hullGap-6-(_otherForward*1.8))/3)) max 0;
            private _closing=(_ownForward-_otherForward) max 0;
            if (_closing > 0.5 && {_hullGap < 2+(_closing*0.5)}) then {_allowed=0};
            if (_allowed < _cap) then {_cap=_allowed;_limiting=_other;_gap=_hullGap};
        };
    };
} forEach _candidates;
[_cap,_limiting,_gap,time,count _candidates]
