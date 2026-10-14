/*
 * Author: WaldoTheWarfighter
 * Purpose: Retains eligible infantry partners across operation changes and repairs broken pairs.
 * Locality/authority: Current group owner only; writes group pairing metadata, never actor commands.
 * Repeat/JIP: Unchanged pairs do not republish. Public receipts survive owner migration and JIP.
 * Arguments: 0 group <GROUP, grpNull>; 1 eligible actors <ARRAY of OBJECT, []>, maximum 16.
 * Return Value: ARRAY of one- or two-actor pairs; [] for invalid authority or an oversized request.
 * Current callers: OperationStart, RebalanceRoles and CortexClearBuilding.
 * Example: [group player,[soldier1,soldier2]] call WAIT_fnc_CombatPairs;
 */
params [["_group",grpNull,[grpNull]],["_actors",[],[[]]]];
if (isNull _group || {!local _group} || {count _actors > 16}) exitWith {[]};
private _remaining=(_actors select {
    _x isEqualType objNull && {!isNull _x} && {local _x} && {group _x == _group}
        && {!isPlayer _x} && {isNull objectParent _x}
        && {[_x] call WAIT_fnc_CortexCombatEffective}
        && {isNull remoteControlled _x} && {([_x] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
}) arrayIntersect _actors;
private _previous=_group getVariable ["WAIT_CombatPairs",[]];
private _pairs=[];
private _orphans=[];
// Intact pairs take priority so repairing an orphan cannot steal another partner.
{
    private _pair=_x select {_x in _remaining};
    if (count _pair == 2) then {
        _pairs pushBack _pair;
        _remaining=_remaining-_pair;
    } else {
        if (count _pair == 1) then {_orphans pushBack (_pair select 0)};
    };
} forEach (_previous select [0,16]);
{
    if (_x in _remaining) then {
        private _pair=[_x];
        _remaining=_remaining-[_x];
        if (_remaining isNotEqualTo []) then {_pair pushBack (_remaining deleteAt 0)};
        _pairs pushBack _pair;
    };
} forEach _orphans;
while {_remaining isNotEqualTo []} do {
    private _pair=[_remaining deleteAt 0];
    if (_remaining isNotEqualTo []) then {_pair pushBack (_remaining deleteAt 0)};
    _pairs pushBack _pair;
};
if (_pairs isNotEqualTo _previous) then {_group setVariable ["WAIT_CombatPairs",_pairs,true]};
_pairs
