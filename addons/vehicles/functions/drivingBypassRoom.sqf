/*
 * Author: WaldoTheWarfighter
 * Purpose: Calculate forward bypass approach/ramp room from already projected obstacle bounds.
 * Locality/authority: Pure arithmetic anywhere; no world query, command or movement authority.
 * Repeat/JIP: Stateless. Results are tied to supplied observations, not physical clearance.
 * Arguments: 0 projected bounds ARRAY [minX,maxX,minY,maxY], []; 1 circumscribed hull
 * radius NUMBER 0, positive <=12m; 2 side NUMBER 1, exactly -1/1;
 * 3 held queue mode BOOL false, permitting a straight corridor only beyond the full hull.
 * Return: HASHMAP status ROOM/REFUSED, reason; valid inputs also return straight BOOL,
 * before/lateral/ramp/clearAfter/after NUMBER and requiredBack NUMBER. requiredBack is only
 * the missing longitudinal approach under unchanged heading/geometry, never permission to reverse.
 * Current caller: DrivingBypassPlan. Recovery may use this shared calculation only with fresh
 * projected metadata, its original budget and independent rear support/body/actor validation.
 * Example: private _room=[[-2,2,25,30],4,1,false] call CBE_fnc_DrivingBypassRoom;
 */
params [["_bounds",[],[[]]],["_radius",0,[0]],["_side",1,[0]],["_queueMode",false,[true]]];
private _fail={params ["_reason"];createHashMapFromArray [["status","REFUSED"],["reason",_reason]]};
if (count _bounds != 4 || {_bounds findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _radius} || {_radius <= 0} || {_radius > 12} || {!(_side in [-1,1])}) exitWith {["INVALID_ROOM_INPUT"] call _fail};
_bounds params ["_minX","_maxX","_minY","_maxY"];
if (_maxX < _minX || {_maxY < _minY} || {_maxX-_minX > 30} || {_maxY-_minY > 30}) exitWith {["INSUFFICIENT_APPROACH_ROOM"] call _fail};
private _straightQueue=_queueMode && {_maxX <= -(_radius+1) || {_minX >= _radius+1}};
private _before=_minY-_radius-3;
private _lateral=if (_straightQueue) then {0} else {if (_side > 0) then {_maxX+_radius+3} else {_minX-_radius-3}};
private _rampTravel=(1.5*abs _lateral/tan 35) max 12;
private _clearAfter=_maxY+_radius+3;
private _after=if (_straightQueue) then {_clearAfter max 12} else {_clearAfter+_rampTravel};
private _reason="";
if (!_straightQueue && {_minY <= _radius+6}) then {_reason="INSUFFICIENT_APPROACH_ROOM"} else {
    if (!_straightQueue && {_before < _rampTravel}) then {_reason="INSUFFICIENT_TURN_ROOM"};
};
private _requiredBack=if (_straightQueue) then {0} else {(_radius+3+_rampTravel-_minY) max 0};
if ([_before,_lateral,_rampTravel,_clearAfter,_after,_requiredBack] findIf {!finite _x} >= 0) exitWith {["INVALID_ROOM_RESULT"] call _fail};
createHashMapFromArray [["status",["REFUSED","ROOM"] select (_reason == "")],["reason",_reason],
    ["straight",_straightQueue],["before",_before],["lateral",_lateral],["ramp",_rampTravel],
    ["clearAfter",_clearAfter],["after",_after],["requiredBack",_requiredBack]]
