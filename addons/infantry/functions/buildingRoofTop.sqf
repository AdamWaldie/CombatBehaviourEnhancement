/*
 * Author: WaldoTheWarfighter
 * Purpose: Return a world-ASL roof-ray endpoint above every transformed model-bound corner.
 * Locality/authority: Read-only on any machine; grants no access, movement or room clearance.
 * Repeat/JIP: Stateless, eight point transforms, no queries, cache, commands or replay.
 * Arguments: 0 building OBJECT objNull; 1 optional boundingBoxReal ARRAY [], queried if absent.
 * Return: NUMBER maximum corner ASL height plus one metre; -1e12 if object/bounds invalid.
 * Current callers: CortexClearBuilding, BuildingOperationStep, IndoorActorNodeSelect,
 * IndoorActorOperation and CortexGarrison. Callers retain live transform/authority and actual nearest-hit checks.
 * Example: private _top=[house1,boundingBoxReal house1] call CBE_fnc_BuildingRoofTop;
 */
params [["_building",objNull,[objNull]],["_bounds",[],[[]]]];
if (isNull _building) exitWith {-1e12};
if (_bounds isEqualTo []) then {_bounds=boundingBoxReal _building};
if (count _bounds != 2 || {_bounds findIf {!(_x isEqualType []) || {count _x != 3}
    || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}) exitWith {-1e12};
private _low=_bounds select 0;private _high=_bounds select 1;
if ([0,1,2] findIf {(_low select _x) > (_high select _x)} >= 0) exitWith {-1e12};
private _top=-1e12;
{
    private _cx=_x;
    {
        private _cy=_x;
        {
            private _corner=_building modelToWorldWorld [_cx,_cy,_x];
            _top=_top max (_corner select 2);
        } forEach [_low select 2,_high select 2];
    } forEach [_low select 1,_high select 1];
} forEach [_low select 0,_high select 0];
_top+1
