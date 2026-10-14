/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Repeat calls recompute or update the same bounded state; public state is replayable to JIP where this function publishes it.
 * Checks that no friendly, civilian or protected captive is inside the bounded firing cone.
 * The shooter's own firing platform is excluded; other friendly vehicles still block fire.
 *
 * Every friendly-side or civilian soldier and land
 * vehicle within range of the shooter is projected onto the line of fire. Anyone between 2 m in front
 * of the muzzle and 10 m beyond the target, and within 2 m plus about 5 degrees of the line, blocks
 * the shot. Suppression orders are only given when this returns true.
 * Locality and authority: read-only; callable anywhere.
 *
 * Arguments:
 * 0: shooter <OBJECT>
 * 1: target <ARRAY> - ASL position
 *
 * Return Value:
 * Boolean - true when the line of fire is clear
 *
 * Example:
 * if ([_unit, _targetASL] call WAIT_fnc_CortexLineOfFireClear) then {_unit doSuppressiveFire _targetASL};
 * Result: suppression is never ordered through friendly troops.
 *
 * Current callers: WAIT_fnc_CortexFireControl.
 */

params [["_shooter", objNull, [objNull]], ["_target", [], [[]]]];
if (isNull _shooter || {count _target < 3}) exitWith {false};
private _from = eyePos _shooter;
private _length = _from vectorDistance _target;
private _direction = _from vectorFromTo _target;
private _side = side group _shooter;
private _platform=vehicle _shooter;
(_shooter nearEntities [["CAManBase", "LandVehicle"], (_length + 10) min 600]) findIf {
    private _other = _x;
    private _otherSide = side group _other;
    private _protected=captive _other || {_other getVariable ["ace_captives_isSurrendering",false]}
        || {_other getVariable ["ace_captives_isHandcuffed",false]};
    // The mounted muzzle's own platform is not another friendly blocking its shot.
    if (_other == _shooter || {_other == _platform} || {!alive _other}
        || {!(_protected || {_otherSide == civilian} || {_side getFriend _otherSide >= 0.6})}) then {
        false
    } else {
        private _offset = (getPosASL _other vectorAdd [0, 0, 1]) vectorDiff _from;
        private _along = _offset vectorDotProduct _direction;
        _along > 2 && {_along < _length + 10}
            && {vectorMagnitude (_offset vectorDiff (_direction vectorMultiply _along)) < 2 + _along * 0.087}
    };
} < 0

