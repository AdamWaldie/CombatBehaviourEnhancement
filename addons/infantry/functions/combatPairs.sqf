/*
 * Author: WaldoTheWarfighter
 * Purpose: Retains eligible infantry partners across operation changes and repairs broken pairs.
 * Intact pairs win; only unpaired actors choose the nearest remaining eligible partner in3D,
 * with roster order breaking equal-distance ties. Distance is not proof of a connected route.
 * Locality/authority: Current group owner only; writes group pairing metadata, never actor commands.
 * Repeat/JIP: Shared publication retains untouched out-of-scope pairs without returning them
 * as active workers. Unchanged metadata does not republish; public identity survives migration/JIP.
 * Arguments: 0 group <GROUP, grpNull>; 1 eligible actors <ARRAY of OBJECT, []>, maximum 16.
 * Return Value: ARRAY of one- or two-actor pairs; [] for invalid authority or an oversized request.
 * Current callers: OperationStart, RebalanceRoles and CortexClearBuilding.
 * Example: [group player,[soldier1,soldier2]] call CBE_fnc_CombatPairs;
 */
params [["_group",grpNull,[grpNull]],["_actors",[],[[]]]];
if (isNull _group || {!local _group} || {count _actors > 16}) exitWith {[]};
private _remaining=(_actors select {
    _x isEqualType objNull && {!isNull _x} && {local _x} && {group _x == _group}
        && {!isPlayer _x} && {isNull objectParent _x}
        && {[_x] call CBE_fnc_CortexCombatEffective}
        && {isNull remoteControlled _x} && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
}) arrayIntersect _actors;
private _previous=_group getVariable ["CBE_CombatPairs",[]];
if !(_previous isEqualType []) then {_previous=[]};
private _pairs=[];
private _orphans=[];
// Intact pairs take priority so repairing an orphan cannot steal another partner.
{
    private _pair=if (_x isEqualType [] && {count _x in [1,2]}) then {(_x arrayIntersect _x) select {_x in _remaining}} else {[]};
    if (count _pair == 2) then {
        _pairs pushBack _pair;
        _remaining=_remaining-_pair;
    } else {
        if (count _pair == 1) then {_orphans pushBack (_pair select 0)};
    };
} forEach (_previous select [0,16]);
// Preserve every intact pair before choosing replacements; proximity must not steal a buddy.
// This uses only the supplied eligible roster (maximum16), never a world or enemy query.
private _takeNearest={
    params ["_anchor"];
    private _origin=getPosASL _anchor;
    private _bestIndex=0;
    private _bestDistance=1e12;
    {
        private _distance=(getPosASL _x) vectorDistance _origin;
        if (_distance < _bestDistance) then {
            _bestIndex=_forEachIndex;_bestDistance=_distance;
        };
    } forEach _remaining;
    _remaining deleteAt _bestIndex
};
{
    if (_x in _remaining) then {
        private _pair=[_x];
        _remaining=_remaining-[_x];
        if (_remaining isNotEqualTo []) then {_pair pushBack ([(_pair select 0)] call _takeNearest)};
        _pairs pushBack _pair;
    };
} forEach _orphans;
while {_remaining isNotEqualTo []} do {
    private _pair=[_remaining deleteAt 0];
    if (_remaining isNotEqualTo []) then {_pair pushBack ([(_pair select 0)] call _takeNearest)};
    _pairs pushBack _pair;
};
[_group,_pairs] call CBE_fnc_CombatPairsPublish;
_pairs
