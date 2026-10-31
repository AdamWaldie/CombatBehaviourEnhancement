/*
 * Author: WaldoTheWarfighter
 * Purpose: Validate the complete durable clearance order without manufacturing progress,
 * retry history, original settings or clocks. A second call binds room count to current geometry.
 * Locality/authority: Pure data checks anywhere. This is not producer authentication,
 * source-writer quiescence, a transfer seal, native acknowledgement or incoming authority.
 * Repeat/JIP: Stateless and read-only; <=512 room rows/retries and eight lane ids per row.
 * Sparse retry slots remain absent; validation does not fill or change an input array.
 * Arguments: 0 order ANY,[]; 1 expected room count NUMBER,-1 (unknown before geometry).
 * Return: BOOL complete internally consistent14-field order; expiry, actual geometry/order
 * identity, actors/settings/commands and phase journals still require their existing owners.
 * Current callers: CortexDiscover resume preflight and CortexClearBuilding before startup.
 * Example: private _valid=[_order,count _positions] call CBE_fnc_ClearOrderValid;
 */
params [["_order",[]],["_expectedCount",-1,[0]]];
if (!(_order isEqualType []) || {count _order != 14}
    || {_order findIf {isNil "_x"} >= 0}
    || {!finite _expectedCount} || {_expectedCount != floor _expectedCount}
    || {_expectedCount < -1} || {_expectedCount > 512}) exitWith {false};
_order params ["_building","_cleared","_deadline","_behaviour","_unreachable","_retries",
    "_failures","_progress","_attack","_native","_hard","_belief","_continue","_transform"];
private _vector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} < 0}};
if (!(_building isEqualType objNull) || {!(_behaviour isEqualType "")}
    || {!(_behaviour in ["CARELESS","SAFE","AWARE","COMBAT","STEALTH"])}
    || {!(_attack isEqualType true)} || {!(_continue isEqualType true)}
    || {[_deadline,_progress,_hard] findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} >= 0}
    || {_progress > _deadline}
    || {!(_transform isEqualType [])} || {count _transform != 4}
    || {_transform findIf {isNil "_x"} >= 0}
    || {(_transform select [0,3]) findIf {!(_x call _vector)} >= 0}
    || {!((_transform select 3) isEqualType 0)} || {!finite (_transform select 3)}
    || {(_transform select 3) <= 0}
    || {!(_failures isEqualType [])} || {count _failures < 1} || {count _failures > 512}) exitWith {false};
private _size=count _failures;
if (_expectedCount >= 0 && {_expectedCount != _size}) exitWith {false};
private _index={_this isEqualType 0 && {finite _this} && {_this == floor _this}
    && {_this >= 0} && {_this < _size}};
if ([_cleared,_unreachable] findIf {!(_x isEqualType []) || {count _x > _size}
        || {_x findIf {isNil "_x" || {!(_x call _index)}} >= 0}
        || {count (_x arrayIntersect _x) != count _x}} >= 0
    || {(_cleared arrayIntersect _unreachable) isNotEqualTo []}
    || {!(_retries isEqualType [])} || {count _retries > _size}) exitWith {false};
private _valid=true;
for "_i" from 0 to (count _retries-1) do {
    if (!_valid) exitWith {};
    if (!isNil {_retries select _i}) then {
        private _spent=_retries select _i;
        if (!(_spent isEqualType 0) || {!finite _spent} || {_spent < 0}
            || {_spent != floor _spent}) exitWith {_valid=false};
    };
};
if (!_valid) exitWith {false};
private _laneIds=["PAIR_0","PAIR_1","PAIR_2","PAIR_3","PAIR_4","PAIR_5","PAIR_6","PAIR_7"];
if (_failures findIf {isNil "_x" || {!(_x isEqualType [])} || {count _x > 8}
    || {_x findIf {isNil "_x" || {!(_x in _laneIds)}} >= 0}
    || {count (_x arrayIntersect _x) != count _x}} >= 0) exitWith {false};
if (!(_native isEqualType []) || {!(count _native in [2,3])}
    || {_native findIf {isNil "_x"} >= 0}
    || {!((_native select 0) isEqualType 0)} || {!finite (_native select 0)}
    || {(_native select 0) < 0} || {(_native select 0) != floor (_native select 0)}
    || {!((_native select 1) isEqualType 0)} || {!finite (_native select 1)}
    || {(_native select 1) != floor (_native select 1)}) exitWith {false};
if (count _native == 2) then {
    _valid=(_native select 1) == -1;
} else {
    _valid=(_native select 1) > 0 && {(_native select 1) < (_native select 0)}
        && {(_native select 2) isEqualType []} && {count (_native select 2) == 1}
        && {!isNil {(_native select 2) select 0}}
        && {((_native select 2) select 0) isEqualType []} && {count ((_native select 2) select 0) == 22};
};
if (!_valid || {!(_belief isEqualType [])}) exitWith {false};
if (_belief isNotEqualTo [] && {count _belief != 2 || {_belief findIf {isNil "_x"} >= 0}
    || {!((_belief select 0) call _vector)}
    || {!((_belief select 1) isEqualType 0)} || {!finite (_belief select 1)} || {(_belief select 1) < 0}}) exitWith {false};
true
