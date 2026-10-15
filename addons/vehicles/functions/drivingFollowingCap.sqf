/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes vehicle hulls occupying the forward lane and derives a continuous speed cap.
 * Aligned moving predecessors retain measured forward speed. Other intersecting hulls are treated
 * as occupied space without assuming that crossing or oncoming traffic will yield or move away.
 * Empty live vehicles and destroyed vehicle entities at any heading remain obstacles;
 * destruction alone never removes their hull from this observation. No bypass route is planned.
 * A mass-adjusted closing-speed envelope adds provisional braking and cruise-sampling headroom;
 * neither nominal deceleration nor scheduler response is physically guaranteed by this policy.
 * Locality/authority: read-only on the current vehicle owner. The driving operation owns all
 * speed commands and rechecks its driver, route and movement lease before applying this result.
 * Repeat/JIP: no handlers or cached clearance. Each sample uses actual velocity and current hull
 * corners; results must not be replayed after movement, route replacement or locality change.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 requested cap m/s <NUMBER>, 20 (0..35);
 * 2 registered predecessor <OBJECT>, objNull, whose gap is owned by the convoy spacing controller.
 * Return: ARRAY [cap m/s NUMBER, limiting vehicle OBJECT, hull gap m NUMBER,
 * sampledAt NUMBER, candidate count NUMBER]. Dense sets return zero and the vehicle itself as
 * a congestion sentinel; at most 64 candidate hulls are evaluated, eight corners each.
 * Current callers: DrivingAssistStart and ConvoyTick through their finite operation schedulers.
 * Example: private _traffic = [truck1,20] call WAIT_fnc_DrivingFollowingCap;
 */
params [["_vehicle",objNull,[objNull]],["_requested",20,[0]],["_predecessor",objNull,[objNull]]];
_requested=(_requested max 0) min 35;
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}) exitWith {[_requested,objNull,-1,time,0]};
private _box=boundingBoxReal _vehicle;
private _low=_box select 0;private _high=_box select 1;
private _front=_high select 1;
private _forward=vectorDir _vehicle;_forward set [2,0];
if (vectorMagnitude _forward < 0.1) exitWith {[_requested,objNull,-1,time,0]};
_forward=vectorNormalized _forward;
private _ownForward=((velocity _vehicle) vectorDotProduct _forward) max 0;
// Heavy vehicles get a lower nominal deceleration. Account for the ordinary four-second
// cruise sampling interval even though a constrained phase requests work more frequently.
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
private _radius=((_ownForward max _requested)*6+20+(abs _front)) min 250;
// Arma 2.18 area syntax explicitly includes dead vehicle entities. The default
// radius syntax omits them; removing only the alive predicate would not fix discovery.
private _area=[getPosATL _vehicle,_radius,_radius,0,false,_radius];
private _candidates=_area nearEntities [["LandVehicle"],false,false,false];
if (count _candidates > 64) exitWith {[0,_vehicle,-1,time,count _candidates]};
private _cap=_requested;private _limiting=objNull;private _gap=-1;
{
    private _other=_x;
    if (_other != _vehicle && {_other != _predecessor} && {!isNull _other}) then {
        // Heading selects only the following-speed allowance, never obstacle admission.
        // An angled parked hull or a reversing/oncoming vehicle still occupies this lane.
        private _following=((vectorDir _other) vectorDotProduct _forward) > 0.7
            && {((velocity _other) vectorDotProduct _forward) >= -0.5};
        private _otherForward=if (_following) then {
            ((velocity _other) vectorDotProduct _forward) max 0
        } else {0};
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
        // A long sideways hull can intrude past our front even when its centre is behind it.
        private _ahead=_maxY > _front-0.25;
        private _sameLane=_maxX >= (_low select 0)-0.25 && {_minX <= (_high select 0)+0.25};
        private _sameHeight=_maxZ >= (_low select 2)-0.25 && {_minZ <= (_high select 2)+0.25};
        if (_ahead && {_sameLane} && {_sameHeight}) then {
            private _hullGap=(_minY-_front) max 0;
            // Desired six-metre gap plus 1.8 seconds of predecessor travel. Continuous correction
            // avoids binary distance-band starts/stops. Closing-distance reaction only lowers it.
            private _allowed=(_otherForward+((_hullGap-6-(_otherForward*1.8))/3)) max 0;
            // Solve closing distance = reaction*relative speed + relative speed^2/(2*a).
            // This limits approach toward the currently measured predecessor speed; it does
            // not assume that a predecessor's future braking or native steering is known.
            private _room=(_hullGap-6) max 0;
            private _reactionSpeed=_deceleration*_reaction;
            private _closingAllowance=(sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0;
            _allowed=_allowed min (_otherForward+_closingAllowance);
            private _closing=(_ownForward-_otherForward) max 0;
            if (_closing > 0.5 && {_hullGap < 2+(_closing*0.5)}) then {_allowed=0};
            if (_allowed < _cap) then {_cap=_allowed;_limiting=_other;_gap=_hullGap};
        };
    };
} forEach _candidates;
[_cap,_limiting,_gap,time,count _candidates]
