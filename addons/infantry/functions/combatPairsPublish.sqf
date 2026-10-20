/*
 * Author: WaldoTheWarfighter
 * Purpose: Publishes active pair metadata while retaining untouched out-of-scope partners.
 * Locality/authority: Current group owner only. Metadata gives no movement, reservation,
 * fitness, role or room-clearance authority; consumers still validate their own actors.
 * Repeat/JIP: Active rows win, actors occur once, unchanged registries do not republish.
 * Retains at most sixteen rows of at most two living same-group actors. Owned dormant,
 * incapacitated or mounted members may retain identity without becoming active workers.
 * Arguments: 0 group <GROUP,grpNull>; 1 active pair rows <ARRAY,[]>, maximum sixteen.
 * Return: BOOL accepted metadata publication, including unchanged; false on invalid input.
 * Current callers: CombatPairs and BuildingOperationStep replacement publication.
 * Cost: At most sixteen active and sixteen retained rows; no world query or timer.
 * Example: [group soldier1,[[soldier1,soldier2]]] call CBE_fnc_CombatPairsPublish;
 */
params [["_group",grpNull,[grpNull]],["_active",[],[[]]]];
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}} || {count _active > 16}
    || {_active findIf {!(_x isEqualType []) || {count _x > 2}
        || {_x findIf {!(_x isEqualType objNull)} >= 0}} >= 0}) exitWith {false};
private _accepted=false;
isNil {
    if (!local _group) exitWith {};
    private _previous=_group getVariable ["CBE_CombatPairs",[]];
    private _merged=[];private _seen=[];private _duplicate=false;
    {
        private _row=[];
        {
            if (!isNull _x && {alive _x} && {group _x == _group}) then {
                if (_x in _seen) then {_duplicate=true} else {_row pushBack _x;_seen pushBack _x};
            };
        } forEach _x;
        if (_row isNotEqualTo []) then {_merged pushBack _row};
    } forEach _active;
    if (_duplicate) exitWith {};
    if (_previous isEqualType []) then {
        {
            if (count _merged >= 16) exitWith {};
            if (_x isEqualType [] && {count _x in [1,2]}
                && {_x findIf {!(_x isEqualType objNull) || {_x in _seen}} < 0}) then {
                private _row=(_x arrayIntersect _x) select {!isNull _x && {alive _x} && {group _x == _group}};
                if (_row isNotEqualTo []) then {_merged pushBack _row;_seen append _row};
            };
        } forEach (_previous select [0,16]);
    };
    if (_merged isNotEqualTo _previous) then {_group setVariable ["CBE_CombatPairs",_merged,true]};
    _accepted=true;
};
_accepted
