/*
 * Author: WaldoTheWarfighter
 * Purpose: Select a ranked manoeuvre element without needlessly splitting eligible persistent buddies.
 * Eligible partners of receiving-team incumbents take priority, then whole reserve pairs and
 * unpaired candidates. Minimum mover strength may split a pair;
 * caller fire-capacity and specialist-role constraints remain authoritative.
 * Locality/authority: Read-only on the group owner. Metadata grants no actor command authority.
 * Repeat/JIP: Deterministic for unchanged ranked roster/registry. No publication, lease or worker.
 * Arguments: 0 group <GROUP,grpNull>; 1 ranked eligible candidates <ARRAY,[]>, at most16;
 * 2 maximum element size <NUMBER,2>,1..5; 3 minimum mover count <NUMBER,2>,1..maximum;
 * 4 receiving-team incumbents <ARRAY,[]>, at most16, disjoint from ranked candidates.
 * Return: ARRAY of selected actors, or [] for invalid scope/insufficient candidates.
 * Current callers: CortexAdvanceStart, CortexFlankStart, CortexAssaultStart and CortexFlankStep refill.
 * Cost: At most16 candidates and16 persistent rows; no geometry or world scan.
 * Example: [group soldier1,[soldier1,soldier2,soldier3,soldier4],2,2] call CBE_fnc_CombatElementSelect;
 */
params [["_group",grpNull,[grpNull]],["_ranked",[],[[]]],
    ["_maximum",2,[0]],["_minimum",2,[0]],["_incumbents",[],[[]]]];
if (isNull _group || {!local _group} || {count _ranked > 16} || {count _incumbents > 16}
    || {!finite _maximum} || {!finite _minimum}
    || {_maximum != floor _maximum} || {_minimum != floor _minimum}
    || {_maximum < 1} || {_maximum > 5} || {_minimum < 1} || {_minimum > _maximum}
    || {_incumbents findIf {!(_x isEqualType objNull) || {isNull _x} || {group _x != _group}} >= 0}
    || {_ranked findIf {_x in _incumbents} >= 0}
    || {_ranked findIf {!(_x isEqualType objNull) || {isNull _x} || {group _x != _group}} >= 0}) exitWith {[]};
private _candidates=_ranked arrayIntersect _ranked;
if (count _candidates < _minimum) exitWith {[]};
private _registry=_group getVariable ["CBE_CombatPairs",[]];
if !(_registry isEqualType []) then {_registry=[]};
// Rejoin an existing receiving-team buddy before allocating unrelated reserve pairs.
// Only caller-qualified candidates can be selected; incumbents supply identity, not authority.
private _selected=[];
if (_incumbents isNotEqualTo []) then {
    {
        if (count _selected >= _maximum) exitWith {};
        private _actor=_x;
        if ((_registry select [0,16]) findIf {
            _x isEqualType [] && {count _x == 2} && {_actor in _x}
                && {_x findIf {_x in _incumbents} >= 0}
        } >= 0) then {_selected pushBack _actor};
    } forEach _candidates;
    _candidates=_candidates-_selected;
};
private _intact=[];private _paired=[];
{
    if (_x isEqualType [] && {count _x == 2} && {(_x select 0) != (_x select 1)}
        && {_x findIf {!(_x in _candidates) || {_x in _paired}} < 0}) then {
        _intact pushBack +_x;
        _paired append _x;
    };
} forEach (_registry select [0,16]);
private _orphans=[];
{
    private _actor=_x;
    private _pairIndex=_intact findIf {_actor in _x};
    if (_pairIndex < 0) then {_orphans pushBack _actor} else {
        private _pair=_intact select _pairIndex;
        if (!(_actor in _selected) && {count _selected+2 <= _maximum}) then {
            _selected append _pair;
        };
    };
} forEach _candidates;
{
    if (count _selected >= _maximum) exitWith {};
    _selected pushBack _x;
} forEach _orphans;
// Cohesion cannot leave an otherwise viable depleted element without enough movers.
{
    if (count _selected >= _minimum) exitWith {};
    _selected pushBack _x;
} forEach (_candidates-_selected);
_selected
