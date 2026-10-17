/*
 * Author: WaldoTheWarfighter
 * Purpose: Proposes one uncovered exterior ground position around an actual building exit.
 * Locality/authority: Read-only query on the actor owner; never issues movement or changes state.
 * Repeat/JIP: At most one native query per call; callers retain attempt/deadline budgets and public history.
 * The query envelope preserves supplied post and observation-corridor exclusions after native snapping.
 * Computing that envelope adds no world scans, geometry rays, commands or persistent state.
 * Arguments: 0 actor <OBJECT, objNull>; 1 search ATL <ARRAY, []>; 2 exit ATL <ARRAY, []>;
 * 3 reserved ATL points <ARRAY, []>; 4 observer lanes <ARRAY, []>, each [post ATL, watch ATL].
 * Refuses more than 128 reservations or 64 lanes; validates every supplied coordinate.
 * Return Value: ARRAY, proposed ATL or []; caller must validate geometry and physical arrival.
 * Current callers: CBE_fnc_BuildingOperationStep and CBE_fnc_CortexGarrisonApplyLocal.
 * Example: [_unit,_exit getPos [7,180],_exit,[],[]] call CBE_fnc_BuildingExteriorProposal;
 */
params [["_actor",objNull,[objNull]],["_search",[],[[]]],["_entry",[],[[]]],
    ["_taken",[],[[]]],["_observerLanes",[],[[]]]];
private _positionValid={
    params ["_position"];
    _position isEqualType [] && {count _position == 3}
        && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
if (isNull _actor || {!local _actor} || {!([_search] call _positionValid)}
    || {!([_entry] call _positionValid)} || {count _taken > 128}
    || {count _observerLanes > 64}
    || {_taken findIf {!([_x] call _positionValid)} >= 0}
    || {_observerLanes findIf {
        !(_x isEqualType []) || {count _x != 2}
            || {!([_x select 0] call _positionValid)}
            || {!([_x select 1] call _positionValid)}
    } >= 0}) exitWith {[]};
// One correction pass uses live reservations and the actor's actual side.
// Native empty space is only a proposal; it does not establish a path or cover.
private _emptyCentre=+_search;
{
    private _delta=_emptyCentre vectorDiff _x;
    _delta set [2,0];
    private _distance=vectorMagnitude _delta;
    if (_distance < 3.5) then {
        if (_distance < 0.01) then {
            private _bearing=_actor getDir _emptyCentre;
            _delta=[sin _bearing,cos _bearing,0];
        };
        _emptyCentre=_emptyCentre vectorAdd ((vectorNormalized _delta) vectorMultiply (3.5-_distance));
    };
} forEach _taken;
// Correct laterally around committed observation corridors using their
// live direction and this actor's side, not a predefined placement pattern.
{
    private _start=+(_x select 0);
    private _axis=(_x select 1) vectorDiff _start;
    _axis set [2,0];
    private _length=vectorMagnitude _axis;
    if (_length > 0.1) then {
        _axis=vectorNormalized _axis;
        private _normal=[_axis select 1,-(_axis select 0),0];
        private _offset=_emptyCentre vectorDiff _start;
        private _along=_offset vectorDotProduct _axis;
        private _lateral=_offset vectorDotProduct _normal;
        if (_along > 0 && {_along < _length} && {abs _lateral < 1.8}) then {
            private _side=[-1,1] select (((getPosATL _actor) vectorDiff _start) vectorDotProduct _normal >= 0);
            _emptyCentre=_emptyCentre vectorAdd (_normal vectorMultiply (1.8*_side-_lateral));
        };
    };
} forEach _observerLanes;
// Native search can move its result away from the corrected centre. Its whole
// search disc must fit inside the remaining reservation/corridor clearance;
// otherwise the search can undo the correction and repeatedly return a rejected post.
private _exitDistance=_emptyCentre distance2D _entry;
if (_exitDistance > 16) exitWith {[]};
private _searchRadius=8 min (_exitDistance-3.05) min (17.95-_exitDistance);
{
    _searchRadius=_searchRadius min ((_emptyCentre distance2D _x)-3.05);
} forEach _taken;
{
    private _start=+(_x select 0);
    private _axis=(_x select 1) vectorDiff _start;
    _axis set [2,0];
    private _lengthSquared=_axis vectorDotProduct _axis;
    if (_lengthSquared > 0.01) then {
        private _offset=_emptyCentre vectorDiff _start;
        _offset set [2,0];
        private _fraction=(((_offset vectorDotProduct _axis)/_lengthSquared) max 0) min 1;
        private _closest=_start vectorAdd (_axis vectorMultiply _fraction);
        // A 2D corridor envelope is conservative on sloping ground. The caller
        // still checks actual 3D standing space, terrain and both observation directions.
        _searchRadius=_searchRadius min ((_emptyCentre distance2D _closest)-1.25);
    };
} forEach _observerLanes;
if (_searchRadius < 0) exitWith {[]};
// areaRadius=0 ensures the native search does not silently add another 0.75 m
// beyond this envelope. Zero available radius becomes the documented exact-position query.
private _proposal=_emptyCentre findEmptyPosition [0,_searchRadius,typeOf _actor];
if (!([_proposal] call _positionValid)
    || {_proposal distance2D _emptyCentre > _searchRadius+0.01}) exitWith {[]};
_proposal
