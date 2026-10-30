/*
 * Author: WaldoTheWarfighter
 * Purpose: Read explicit AI radio-denial fields at an ASL position; never reveal targets.
 * Locality/authority: Read-only on any AI owner using the server's latest public snapshot.
 * Repeat/JIP: Stateless/live position and life checks; no EH, timer, callback or cached
 * permission survives emitter movement/deletion or a later registration update.
 * Arguments: 0 position ASL ARRAY of3 finite NUMBERs, default[] (invalid);
 * 1 receiver SIDE, default sideUnknown (invalid). At most32 fields are inspected.
 * Return Value: NUMBER0 or1. Missing/invalid inputs or registry give0; overlapping
 * matching live fields give1, not additive power. Voice and player radios are unchanged.
 * Current callers: CortexCanTransmit; CortexJammingField owns registration.
 * Example: [getPosASL _unit,side group _unit] call CBE_fnc_CortexJammingFactor;
 */
params [["_position",[],[[]]],["_side",sideUnknown,[sideUnknown]]];
if (count _position != 3 || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(_side in [west,east,resistance,civilian])}) exitWith {0};
private _fields=missionNamespace getVariable ["CBE_EW_Fields",[]];
if (!(_fields isEqualType []) || {count _fields > 32}) exitWith {0};
private _factor=0;
{
    private _row=_x;
    if (_row isEqualType [] && {count _row == 3}
        && {(_row select 0) isEqualType objNull} && {!isNull (_row select 0)}
        && {alive (_row select 0)} && {(_row select 1) isEqualType 0}
        && {finite (_row select 1)} && {(_row select 1) >= 1} && {(_row select 1) <= 100000}
        && {(_row select 2) isEqualType []} && {_side in (_row select 2)}
        && {_position vectorDistance (getPosASL (_row select 0)) <= (_row select 1)}) exitWith {_factor=1};
} forEach _fields;
_factor
