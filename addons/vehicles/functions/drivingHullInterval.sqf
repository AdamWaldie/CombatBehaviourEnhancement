/*
 * Author: WaldoTheWarfighter
 * Purpose: Projects a vehicle's complete oriented model bounds onto a world axis.
 * Locality/authority: Read-only anywhere; geometry is observation, not movement authority.
 * Repeat/JIP: Stateless; callers resample before using changing vehicle poses.
 * Arguments: 0 object <OBJECT, objNull>; 1 origin <ARRAY of three NUMBER, [0,0,0]>;
 * 2 unit world axis <ARRAY of three NUMBER, [0,1,0]>;
 * 3 optional second unit world axis <ARRAY, []>. Empty retains the original two-value result.
 * Return: ARRAY [minimum,maximum] or [minimum,maximum,secondMinimum,secondMaximum],
 * in metres padded outwards by0.05m; [] unavailable. Invalid optional geometry refuses both axes.
 * Current callers: DrivingPassStep, DrivingQueueProposal, DrivingQueueProposalCurrent,
 * DrivingRearPlan, DrivingGateOpenServer and DrivingGateCloseServer.
 * Cost: Four native model transforms for one or two axes; affine edge projection represents
 * all eight corners. Dual-axis callers reuse one box/pose sample instead of repeating transforms.
 * Example: private _span=[truck1,getPosWorld truck2,[0,1,0]] call CBE_fnc_DrivingHullInterval;
 */
params [["_object",objNull,[objNull]],["_origin",[0,0,0],[[]]],["_axis",[0,1,0],[[]]],["_secondAxis",[],[[]]]];
if (isNull _object || {[_origin,_axis] findIf {count _x != 3
    || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {abs ((vectorMagnitude _axis)-1) > 0.01}) exitWith {[]};
private _dual=_secondAxis isNotEqualTo [];
if (_dual && {count _secondAxis != 3 || {_secondAxis findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {abs ((vectorMagnitude _secondAxis)-1) > 0.01}}) exitWith {[]};
private _box=boundingBoxReal _object;private _low=_box select 0;private _high=_box select 1;
// An affine box projection reaches each extremum by independently selecting
// the low/high end of every edge. This represents all eight corners with four
// native transforms, including tilt, scale and asymmetric model bounds.
private _corner=_object modelToWorldWorld _low;
private _cornerAlong=(_corner vectorDiff _origin) vectorDotProduct _axis;
private _minimum=_cornerAlong;private _maximum=_cornerAlong;
private _secondMinimum=0;private _secondMaximum=0;
if (_dual) then {
    _secondMinimum=(_corner vectorDiff _origin) vectorDotProduct _secondAxis;
    _secondMaximum=_secondMinimum;
};
{
    private _edge=(_object modelToWorldWorld _x) vectorDiff _corner;
    private _along=_edge vectorDotProduct _axis;
    _minimum=_minimum+(_along min 0);_maximum=_maximum+(_along max 0);
    if (_dual) then {
        private _secondAlong=_edge vectorDotProduct _secondAxis;
        _secondMinimum=_secondMinimum+(_secondAlong min 0);
        _secondMaximum=_secondMaximum+(_secondAlong max 0);
    };
} forEach [[_high select 0,_low select 1,_low select 2],
    [_low select 0,_high select 1,_low select 2],
    [_low select 0,_low select 1,_high select 2]];
private _span=[_minimum-0.05,_maximum+0.05];
if (_dual) then {_span append [_secondMinimum-0.05,_secondMaximum+0.05]};
_span
