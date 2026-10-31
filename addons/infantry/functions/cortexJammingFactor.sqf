/*
 * Author: WaldoTheWarfighter
 * Purpose: Read explicit AI radio-denial fields at an ASL position; never reveal targets.
 * Locality/authority: Read-only on any AI owner using the server's latest public snapshot.
 * Repeat/JIP: Stateless/live position and life checks; no EH, timer, callback or cached
 * permission survives emitter movement/deletion or a later registration update.
 * Arguments: 0 position ASL ARRAY of3 finite NUMBERs, default[] (invalid);
 * 1 receiver SIDE, default sideUnknown (invalid). At most32 fields are inspected.
 * Return Value: NUMBER0 or1. Missing/invalid inputs or registry give0; overlapping
 * matching live fields give1, not additive power. RADAR_HOSTILES requires native radar on,
 * visible/simulated emitter and living actual onboard commander, plus mutual hostility
 * with its current side. Crew/radar/alliance changes take effect at the next real query. Voice and player radios are unchanged.
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
    if (_row isEqualType [] && {count _row in [3,4]}
        && {(_row select 0) isEqualType objNull} && {!isNull (_row select 0)}
        && {alive (_row select 0)} && {(_row select 1) isEqualType 0}
        && {finite (_row select 1)} && {(_row select 1) >= 1} && {(_row select 1) <= 100000}
        && {(_row select 2) isEqualType []}
        && {_position vectorDistance (getPosASL (_row select 0)) <= (_row select 1)}) then {
        private _denied=false;
        if (count _row == 3) then {_denied=_side in (_row select 2)} else {
            private _emitter=_row select 0;
            if ((_row select 3) isEqualTo "RADAR_HOSTILES" && {_emitter isKindOf "AllVehicles"}
                && {simulationEnabled _emitter} && {!isObjectHidden _emitter} && {isVehicleRadarOn _emitter}) then {
                private _commander=effectiveCommander _emitter;
                if (!isNull _commander && {alive _commander} && {vehicle _commander == _emitter}) then {
                    private _emitterSide=side group _commander;
                    _denied=_emitterSide in [west,east,resistance]
                        && {_emitterSide getFriend _side < 0.6} && {_side getFriend _emitterSide < 0.6};
                };
            };
        };
        if (_denied) then {_factor=1};
    };
    if (_factor == 1) exitWith {};
} forEach _fields;
_factor
