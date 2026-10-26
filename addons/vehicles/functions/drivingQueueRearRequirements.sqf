/*
 * Author: WaldoTheWarfighter
 * Purpose: Derive finite head-on queue reverse envelopes from the agreed initial hull poses.
 * Locality/authority: Read-only server/actual-owner admission. A distance is not consent,
 * rear clearance, a movement command or a successful crossing. No live enemy knowledge.
 * Repeat/JIP: Stateless; called only on agreement admission/verification, never as a motion loop.
 * Arguments: 0 vehicles ARRAY [] (2..4 objects); 1 canonical context ARRAY [].
 * Return: ARRAY of [clearance metres, stop travel metres], root [0,0]; [] unsupported.
 * Crossing pairs retain ordinary8/6 envelopes. Head-on room requests are integral6..24m;
 * dependencies must leave the parent's full clearance. No room/deadline is fabricated.
 * Current callers: DrivingQueueAgreementServer BEGIN and DrivingQueueAgreementOwner VERIFY.
 * Cost: Four native corner transforms per vehicle, at most16, bounded arithmetic only.
 * Example: private _limits=[_vehicles,_context] call CBE_fnc_DrivingQueueRearRequirements;
 */
params [["_vehicles",[],[[]]],["_context",[],[[]]]];
if (count _vehicles < 2 || {count _vehicles > 4} || {count _context != count _vehicles}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x}} >= 0}) exitWith {[]};
private _poses=[];private _valid=true;
{
    if (!(_x isEqualType []) || {count _x != 6} || {(_x select 0) != (_vehicles select _forEachIndex)}) exitWith {_valid=false};
    private _pose=_x select 4;
    if (!(_pose isEqualType []) || {count _pose != 3} || {_pose findIf {
        !(_x isEqualType []) || {count _x != 3} || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    } >= 0}) exitWith {_valid=false};
    if (abs ((vectorMagnitude (_pose select 1))-1) > 0.01
        || {abs ((vectorMagnitude (_pose select 2))-1) > 0.01}
        || {abs ((_pose select 1) vectorDotProduct (_pose select 2)) > 0.02}) exitWith {_valid=false};
    _poses pushBack _pose;
} forEach _context;
if (!_valid) exitWith {[]};
private _limits=_vehicles apply {[8,6]};_limits set [0,[0,0]];
private _rootPose=_poses select 0;private _rootAxis=+(_rootPose select 1);_rootAxis set [2,0];
private _yieldAxis=+((_poses select 1) select 1);_yieldAxis set [2,0];
if (vectorMagnitude _rootAxis < 0.5 || {vectorMagnitude _yieldAxis < 0.5}) exitWith {[]};
_rootAxis=vectorNormalized _rootAxis;_yieldAxis=vectorNormalized _yieldAxis;
private _alignment=_rootAxis vectorDotProduct _yieldAxis;
if (_alignment > -(cos 25)) exitWith {_limits};
// Re-express native model corners in their agreed world basis. This preserves native
// model offsets and scaling without moving the object or assuming its model origin.
private _hulls=[];
{
    private _vehicle=_x;private _pose=_poses select _forEachIndex;
    private _liveOrigin=getPosWorld _vehicle;private _liveForward=vectorDir _vehicle;private _liveUp=vectorUp _vehicle;
    private _liveRight=_liveForward vectorCrossProduct _liveUp;
    private _right=(_pose select 1) vectorCrossProduct (_pose select 2);
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;
    private _corners=[];
    {
        private _offset=(_vehicle modelToWorldWorld _x) vectorDiff _liveOrigin;
        _corners pushBack (((_pose select 0) vectorAdd (_right vectorMultiply (_offset vectorDotProduct _liveRight)))
            vectorAdd ((_pose select 1) vectorMultiply (_offset vectorDotProduct _liveForward))
            vectorAdd ((_pose select 2) vectorMultiply (_offset vectorDotProduct _liveUp)));
    } forEach [_low,[_high select 0,_low select 1,_low select 2],
        [_low select 0,_high select 1,_low select 2],[_low select 0,_low select 1,_high select 2]];
    private _corner=_corners select 0;
    private _edges=(_corners select [1]) apply {_x vectorDiff _corner};
    private _whole=[];
    for "_mask" from 0 to 7 do {
        private _point=+_corner;
        for "_edge" from 0 to 2 do {if ((floor (_mask/(2^_edge))) mod 2 == 1) then {_point=_point vectorAdd (_edges select _edge)}};
        _whole pushBack _point;
    };
    _hulls pushBack _whole;
} forEach _vehicles;
private _span={
    params ["_hull","_origin","_axis"];
    private _values=_hull apply {(_x vectorDiff _origin) vectorDotProduct _axis};
    [(selectMin _values)-0.05,(selectMax _values)+0.05]
};
private _rootRight=[_rootAxis select 1,-(_rootAxis select 0),0];private _origin=_rootPose select 0;
private _ownAlong=[_hulls select 0,_origin,_rootAxis] call _span;
private _ownAcross=[_hulls select 0,_origin,_rootRight] call _span;
private _radius=sqrt (((abs (_ownAlong select 0)) max (abs (_ownAlong select 1)))^2
    +((abs (_ownAcross select 0)) max (abs (_ownAcross select 1)))^2)+1;
if (!finite _radius || {_radius > 12}) exitWith {[]};
// The longer union budget never admits a single oversized traffic body.
{
    private _alongBody=[_x,_origin,_rootAxis] call _span;
    private _acrossBody=[_x,_origin,_rootRight] call _span;
    // _span adds0.05m on each side; apply the same raw30m hull budget as the planner.
    if ((_alongBody select 1)-(_alongBody select 0) > 30.1
        || {(_acrossBody select 1)-(_acrossBody select 0) > 30.1}) exitWith {_valid=false};
} forEach (_hulls select [1]);
if (!_valid) exitWith {[]};
private _union=[];{_union append _x} forEach (_hulls select [1]);
private _along=[_union,_origin,_rootAxis] call _span;private _across=[_union,_origin,_rootRight] call _span;
private _required=1e6;
{
    private _room=[[_across select 0,_across select 1,_along select 0,_along select 1],_radius,_x,true] call CBE_fnc_DrivingBypassRoom;
    if ((_room getOrDefault ["status",""]) == "ROOM") then {_required=0};
    if ("requiredBack" in _room) then {_required=_required min (_room get "requiredBack")};
} forEach [-1,1];
private _travel=6 max ceil ((_required+1)/(-_alignment));
if (!finite _travel || {_travel > 24}) exitWith {[]};
_limits set [1,[_travel+2,_travel]];
for "_index" from 2 to (count _vehicles-1) do {
    private _parentPose=_poses select (_index-1);private _axis=+(_parentPose select 1);_axis set [2,0];
    _axis=vectorNormalized _axis;
    private _parent=[_hulls select (_index-1),_parentPose select 0,_axis] call _span;
    private _leaf=[_hulls select _index,_parentPose select 0,_axis] call _span;
    private _gap=(_parent select 0)-(_leaf select 1);
    private _leafAxis=+((_poses select _index) select 1);_leafAxis set [2,0];_leafAxis=vectorNormalized _leafAxis;
    private _parallel=_axis vectorDotProduct _leafAxis;
    if (_parallel < cos 25) exitWith {_valid=false};
    _travel=6 max ceil ((((_limits select (_index-1)) select 0)-_gap+1)/_parallel);
    if (!finite _travel || {_travel > 24}) exitWith {_valid=false};
    _limits set [_index,[_travel+2,_travel]];
};
[[],_limits] select _valid
