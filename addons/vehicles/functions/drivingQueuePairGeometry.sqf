/*
 * Author: WaldoTheWarfighter
 * Purpose: Qualifies head-on or crossing stationary queue geometry without granting movement.
 * Locality/authority: read-only on any machine; proposal owners separately validate crew,
 * orders, stationarity, consent and the actual rear/crossing paths before native execution.
 * Repeat/JIP: recomputes current geometry; stores no state or deadlines and installs no worker.
 * Cost: constant vector work; crossing mode projects four bounded eight-corner hull intervals.
 * Arguments: 0 crossing vehicle <OBJECT, objNull>; 1 yielding vehicle <OBJECT, objNull>.
 * Return: ARRAY [] on refusal, otherwise [kind STRING, crossing intersection distance NUMBER,
 * yielding intersection distance NUMBER]. HEAD_ON distances are zero. Crossing angles45..135
 * require forward course intersection and a currently obstructed crossing corridor. This is
 * a geometric proposal, not native steering, clearance or physical recovery acceptance.
 * Current callers: DrivingQueueProposal and DrivingQueueProposalCurrent.
 * Example: private _geometry=[truck1,truck2] call CBE_fnc_DrivingQueuePairGeometry;
 */
params [["_first",objNull,[objNull]],["_yield",objNull,[objNull]]];
if (isNull _first || {isNull _yield} || {_first == _yield}
    || {!(_first isKindOf "LandVehicle")} || {!(_yield isKindOf "LandVehicle")}
    || {_first distance2D _yield > 30}) exitWith {[]};
private _origin=getPosASL _first;
private _relative=(getPosASL _yield) vectorDiff _origin;
if (abs (_relative select 2) > 2) exitWith {[]};
private _firstAxis=vectorDir _first;_firstAxis set [2,0];
private _yieldAxis=vectorDir _yield;_yieldAxis set [2,0];
if ((_origin+_relative+_firstAxis+_yieldAxis) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0
    || {vectorMagnitude _firstAxis < 0.1} || {vectorMagnitude _yieldAxis < 0.1}) exitWith {[]};
_firstAxis=vectorNormalized _firstAxis;_yieldAxis=vectorNormalized _yieldAxis;
private _alignment=_firstAxis vectorDotProduct _yieldAxis;
private _yieldRight=[_yieldAxis select 1,-(_yieldAxis select 0),0];
private _toward=_relative vectorMultiply -1;
if (_alignment <= -(cos 25)) exitWith {
    if ((_toward vectorDotProduct _yieldAxis) > 0 && {abs (_toward vectorDotProduct _yieldRight) <= 6}) then {
        ["HEAD_ON",0,0]
    } else {[]}
};
if (abs _alignment > cos 45) exitWith {[]};
private _det=(_firstAxis select 0)*(_yieldAxis select 1)-(_firstAxis select 1)*(_yieldAxis select 0);
private _firstDistance=((_relative select 0)*(_yieldAxis select 1)-(_relative select 1)*(_yieldAxis select 0))/_det;
private _yieldDistance=((_relative select 0)*(_firstAxis select 1)-(_relative select 1)*(_firstAxis select 0))/_det;
if (_firstDistance < 0 || {_yieldDistance < 0} || {_firstDistance > 30} || {_yieldDistance > 30}) exitWith {[]};
private _firstRight=[_firstAxis select 1,-(_firstAxis select 0),0];
private _ownAlong=[_first,_origin,_firstAxis] call CBE_fnc_DrivingHullInterval;
private _yieldAlong=[_yield,_origin,_firstAxis] call CBE_fnc_DrivingHullInterval;
private _ownSide=[_first,_origin,_firstRight] call CBE_fnc_DrivingHullInterval;
private _yieldSide=[_yield,_origin,_firstRight] call CBE_fnc_DrivingHullInterval;
if ([_ownAlong,_yieldAlong,_ownSide,_yieldSide] findIf {_x isEqualTo []} >= 0) exitWith {[]};
// A future course intersection alone is not a present jam. Require the yielding body
// to obstruct the crossing corridor ahead; whole-body separation is checked separately.
if ((_yieldAlong select 1) < (_ownAlong select 1)-1
    || {(_yieldAlong select 0)-(_ownAlong select 1) > 30}
    || {(_yieldSide select 0) > (_ownSide select 1)+1}
    || {(_ownSide select 0) > (_yieldSide select 1)+1}) exitWith {[]};
["CROSSING",_firstDistance,_yieldDistance]
