/*
 * Author: WaldoTheWarfighter
 * Purpose: Estimates signed travel-frame curvature from actual travelled positions in unit body axes.
 * Positions, the three-metre sampling threshold and inverse-metre output stay in world metres;
 * object scale cannot multiply curvature or change the displacement threshold.
 * Locality / Authority: Read-only on current vehicle owner; callers store the returned measurement
 * in their existing local brain/state. No commands, public state, history scan or new scheduler.
 * Repeat/JIP: One bounded receipt resets on caller context, seats, owner, reversal, standing or
 * stale sampling. New owners start straight; historical curvature never grants path clearance.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 previous receipt <ARRAY, []>;
 * 2 controller context <ARRAY, []> binding route/configuration/epoch;
 * 3 travel direction NUMBER1, +1 forward or -1 reverse. Direction changes reset the receipt.
 * Return Value: ARRAY [curvature inverse metres NUMBER, local measurement receipt ARRAY].
 * Measurement: >=3 m planar displacement or >=1.5 s; samples older than 6 s reset. Curves wider
 * than 250 m count as straight. At <=1 m/s along the selected direction, prediction is straight and resets.
 * Current callers: DrivingAssistStart and ConvoyTick through their existing bounded callbacks.
 * Example: private _turn=[truck1,_previous,[_route,_epoch]] call CBE_fnc_DrivingTurnTrack;
 */
params [["_vehicle",objNull,[objNull]],["_previous",[],[[]]],["_context",[],[[]]],["_travelDirection",1,[0]]];
if (!(_travelDirection in [-1,1]) || {isRemoteExecuted} || {isNull _vehicle} || {!local _vehicle} || {!alive _vehicle}) exitWith {[0,[]]};
private _identity=[_context,_vehicle,driver _vehicle,effectiveCommander _vehicle,clientOwner,"BODY_METRES",_travelDirection];
private _position=_vehicle modelToWorldWorld [0,0,0];
private _fresh=[_identity,_position,time,0];
private _bodyForward=(vectorNormalized vectorDir _vehicle) vectorMultiply _travelDirection;
private _bodyUp=vectorNormalized vectorUp _vehicle;
private _bodySide=vectorNormalized (_bodyForward vectorCrossProduct _bodyUp);
if (abs (_bodyForward vectorDotProduct _bodyUp) > 0.01
    || {abs ((vectorMagnitude _bodySide)-1) > 0.01}) exitWith {[0,[]]};
private _forward=(velocity _vehicle) vectorDotProduct _bodyForward;
if (!finite _forward || {_forward <= 1}) exitWith {[0,_fresh]};
if (count _previous != 4 || {(_previous select 0) isNotEqualTo _identity}
    || {time-(_previous select 2) > 6} || {time < (_previous select 2)}) exitWith {[0,_fresh]};
private _relative=(_previous select 1) vectorDiff _position;
private _old=[_relative vectorDotProduct _bodySide,_relative vectorDotProduct _bodyForward];
if (_old findIf {!finite _x} >= 0) exitWith {[0,_fresh]};
private _distanceSquared=(_old select 0)^2+(_old select 1)^2;
private _curvature=_previous select 3;
if (_distanceSquared >= 9 || {time-(_previous select 2) >= 1.5}) then {
    _curvature=if (_distanceSquared < 1) then {0} else {2*(_old select 0)/_distanceSquared};
    if (!finite _curvature || {abs _curvature < 0.004}) then {_curvature=0};
    _fresh set [3,_curvature];
} else {_fresh=+_previous};
[_curvature,_fresh]
