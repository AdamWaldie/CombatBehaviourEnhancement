/*
 * Author: WaldoTheWarfighter
 * Purpose: Propose two synchronised bounding roles with eligible buddies on opposite sides.
 * Locality/authority: Read-only on the group owner. Caller-qualified actors and pairing metadata
 * grant no native command permission; the operation/executor retain all task and fire gates.
 * Repeat/JIP: Deterministic for the supplied roster, pairs and previous roles. Preserve opposite
 * role assignments; repair same-role pairs only at the caller's next-bound allocation boundary.
 * Orphans balance the roles, with the extra actor in role0 for the existing2+1 follow lifecycle.
 * Arguments: 0 group GROUP grpNull; 1 ranked actors ARRAY [] max16; 2 pair rows ARRAY [] max16;
 * 3 previous two role arrays ARRAY [] max2, optional. Invalid scope returns[].
 * Return: ARRAY [role0,role1], or[] when fewer than two actors/scope invalid.
 * Current callers: CortexAdvanceStart and CortexFlankStep next-bound allocation.
 * Cost: <=16 actors/16 pair rows, bounded metadata comparisons; no world/geometry query or worker.
 * Example: private _roles=[_group,[_a,_b,_c,_d],[[_a,_b],[_c,_d]]] call CBE_fnc_CombatPairElements;
 */
params [["_group",grpNull,[grpNull]],["_actors",[],[[]]],
    ["_pairs",[],[[]]],["_previous",[],[[]]]];
if (isNull _group || {!local _group} || {count _actors < 2} || {count _actors > 16}
    || {_actors findIf {!(_x isEqualType objNull) || {isNull _x} || {group _x != _group}} >= 0}
    || {count (_actors arrayIntersect _actors) != count _actors}) exitWith {[]};
private _priorFirst=if (count _previous == 2 && {(_previous select 0) isEqualType []}) then {_previous select 0} else {[]};
private _priorSecond=if (count _previous == 2 && {(_previous select 1) isEqualType []}) then {_previous select 1} else {[]};
private _first=[];private _second=[];private _assigned=[];
{
    if (_x isEqualType [] && {count _x == 2} && {(_x select 0) != (_x select 1)}
        && {_x findIf {!(_x in _actors) || {_x in _assigned}} < 0}) then {
        private _a=_x select 0;private _b=_x select 1;
        private _swap=if (_a in _priorFirst && {_b in _priorSecond}) then {false} else {
            if (_b in _priorFirst && {_a in _priorSecond}) then {true} else {
                (_actors find _b) < (_actors find _a)
            }
        };
        if (_swap) then {_first pushBack _b;_second pushBack _a} else {_first pushBack _a;_second pushBack _b};
        _assigned append [_a,_b];
    };
} forEach (_pairs select [0,16]);
{
    if (count _first <= count _second) then {_first pushBack _x} else {_second pushBack _x};
} forEach (_actors-_assigned);
[_first,_second]
