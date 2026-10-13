/*
 * Author: WaldoTheWarfighter
 * Purpose: Validates an exterior building observation candidate without issuing commands.
 * Locality/authority: Read-only on any machine; caller retains operation and movement authority.
 * Repeat/JIP: Recomputes current geometry and occupancy; publishes nothing and installs no handles.
 * Arguments: 0 actor <OBJECT, objNull>; 1 building <OBJECT, objNull>; 2 candidate ATL <ARRAY, []>;
 * 3 selected exit ATL <ARRAY, []>; 4 watch ATL <ARRAY, []>; 5 exits <ARRAY, []>;
 * 6 reserved ATL positions <ARRAY, []>.
 * Return Value: BOOL, supported exterior observation geometry; never path arrival or room safety.
 * Current callers: WAIT_fnc_BuildingOperationStep.
 * Example: [_unit,_house,_spot,_exit,_watch,[_exit],[]] call WAIT_fnc_BuildingExteriorCandidate;
 */
params [["_actor",objNull,[objNull]],["_building",objNull,[objNull]],
    ["_target",[],[[]]],["_entry",[],[[]]],["_watch",[],[[]]],
    ["_entries",[],[[]]],["_taken",[],[[]]]];
if (isNull _actor || {isNull _building} || {count _target != 3}
    || {count _entry != 3} || {count _watch != 3}) exitWith {false};
private _bounds=boundingBoxReal _building;
private _model=_building worldToModel _target;
private _minimum=_bounds select 0;
private _maximum=_bounds select 1;
private _exterior=(_model select 0) < (_minimum select 0)-0.5
    || {(_model select 0) > (_maximum select 0)+0.5}
    || {(_model select 1) < (_minimum select 1)-0.5}
    || {(_model select 1) > (_maximum select 1)+0.5};
// Cover geometry is not a native path receipt. Exclude configured same-floor exit vicinity and
// validate standing space at the endpoint. Native pathfinding may route around corners.
private _blocksExit=_entries findIf {
    _target distance2D _x < 3 && {abs (((AGLToASL _target) select 2)-((AGLToASL _x) select 2)) <= 1}
} >= 0;
private _observationClear=!terrainIntersectASL [
    (AGLToASL _target) vectorAdd [0,0,1.6],AGLToASL _watch]
    && {(lineIntersectsSurfaces [(AGLToASL _target) vectorAdd [0,0,1.6],
        AGLToASL _watch,_actor,objNull,true,1,"VIEW","NONE"]) isEqualTo []};
private _separated=_taken findIf {_target distance2D _x < 3} < 0
    && {(_target nearEntities ["CAManBase",1.2]) select {_x != _actor} isEqualTo []};
_observationClear && {_separated} && {_exterior} && {!_blocksExit} && {_target distance2D _entry >= 3}
&& {_target distance2D _entry <= 18} && {!surfaceIsWater _target}
&& {((surfaceNormal _target) select 2) >= 0.65}
&& {(lineIntersectsSurfaces [(AGLToASL _target) vectorAdd [0,0,0.15],
    (AGLToASL _target) vectorAdd [0,0,1.8],_actor,objNull,true,1,"GEOM","NONE"]) isEqualTo []}
