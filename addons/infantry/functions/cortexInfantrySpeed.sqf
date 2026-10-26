/*
 * Author: WaldoTheWarfighter
 * Purpose: Derives a world-metre friendly-pedestrian speed ceiling for existing driving writers.
 * Locality/authority: Read-only on the current vehicle owner; never issues movement commands.
 * Repeat/JIP: Fresh bounded observations only; no handlers, leases or cached clearance to replay.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 requested km/h <NUMBER, 0>;
 * 2 controlling group <GROUP, grpNull>; 3 ordinary driving <BOOL, false>;
 * 4 travel intent <NUMBER, 0>: 0 actual velocity, -1 owned rear leg, 1 owned forward retry.
 * Ordinary mode follows the driving-assistance gate; convoy mode retains its opt-in infantry gate.
 * Return Value: NUMBER km/h, zero..request. Dense sets fail closed. At most 32 pedestrian hulls,
 * projected through the shared four-transform hull helper, with one observing-hull projection.
 * Horizontal travel/right and absolute vertical axes preserve metre gaps and height separation
 * on tilted/scaled models. Invalid projection returns zero; supported scaling still needs engine
 * validation. A speed-dependent query is capped at 250 m. Nominal braking and four-second
 * response allowance are conservative policy, not measured native braking or crossing prediction.
 * Current callers: ConvoyTick, DrivingAssistStart, convoy avoidance audit.
 * Example: private _speed = [_truck,30,group driver _truck,true] call CBE_fnc_CortexInfantrySpeed;
 */
params [["_vehicle",objNull,[objNull]],["_requested",0,[0]],
    ["_group",grpNull,[grpNull]],["_ordinary",false,[false]],["_travelIntent",0,[0]]];
if (!finite _requested) exitWith {0};
_requested=(_requested max 0) min 126;
if (isNull _vehicle || {isNull _group} || {!local _vehicle}) exitWith {_requested};
private _enabled=if (_ordinary) then {
    [_group,"CBE_AIPass_DrivingAssist_Enable",true] call CBE_fnc_CortexFeatureEnabled
} else {[_group,"CBE_Convoy_AvoidInfantry_Enable",false] call CBE_fnc_CortexFeatureEnabled};
if (!_enabled) exitWith {_requested};
private _heading=vectorDir _vehicle;_heading set [2,0];
if (vectorMagnitude _heading < 0.1) exitWith {0};
_heading=vectorNormalized _heading;
private _forwardSpeed=(velocity _vehicle) vectorDotProduct _heading;
if (!finite _forwardSpeed) exitWith {0};
private _reverse=if (_travelIntent == 0) then {_forwardSpeed < -0.5} else {_travelIntent < 0};
private _sign=[1,-1] select _reverse;
private _along=_heading vectorMultiply _sign;
private _right=[_heading select 1,-(_heading select 0),0];
private _origin=getPosWorld _vehicle;
private _ownHull=[_vehicle,_origin,_right,_along,[0,0,1]] call CBE_fnc_DrivingHullInterval;
if (count _ownHull != 6) exitWith {0};
private _low=[_ownHull select 0,_ownHull select 2,_ownHull select 4];
private _high=[_ownHull select 1,_ownHull select 3,_ownHull select 5];
private _edge=_high select 1;private _behindEdge=_low select 1;
private _speed=abs _forwardSpeed;
private _massFactor=((1+(((getMass _vehicle)-3000)/7000)) max 1) min 2.5;
private _deceleration=4/_massFactor;
private _reaction=4;
private _planningSpeed=_speed max (_requested/3.6);
private _look=(_planningSpeed*_reaction+(_planningSpeed*_planningSpeed)/(2*_deceleration)+5) min 230;
private _radius=(_look+abs _edge+5) min 250;
private _people=_vehicle nearEntities ["CAManBase",_radius];
if (count _people > 32) exitWith {0};
private _limit=_requested;
{
    private _person=_x;
    if (alive _person && {vehicle _person == _person}
        && {(side _group) getFriend (side group _person) >= 0.6}) then {
        private _hull=[_person,_origin,_right,_along,[0,0,1]] call CBE_fnc_DrivingHullInterval;
        if (count _hull != 6) exitWith {_limit=0};
        _hull params ["_minX","_maxX","_minY","_maxY","_minZ","_maxZ"];
        if (_maxX >= (_low select 0)-1 && {_minX <= (_high select 0)+1}
            && {_maxZ >= (_low select 2)-0.3} && {_minZ <= (_high select 2)+0.3}
            && {_maxY >= _behindEdge} && {_minY <= _edge+_look}) then {
            private _room=(_minY-_edge-3) max 0;
            private _reactionSpeed=_deceleration*_reaction;
            private _allowed=(sqrt ((_reactionSpeed*_reactionSpeed)+2*_deceleration*_room)-_reactionSpeed) max 0;
            // No minimum crawl through an occupied hull, and no hysteresis can discard zero.
            _limit=_limit min (_allowed*3.6);
        };
    };
} forEach _people;
_limit
