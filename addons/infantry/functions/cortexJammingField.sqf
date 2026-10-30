/*
 * Author: WaldoTheWarfighter
 * Purpose: Register, update or remove one explicit AI radio-interference emitter.
 * Locality/authority: Server owns the at-most32-field snapshot; client requests refuse.
 * No native aircraft, actor, radio-addon or movement commands are issued.
 * Repeat/JIP: Same registration is idempotent. Latest snapshot is public for joining
 * owners. Queries read current emitter position/life; deletion/death immediately stops
 * its effect without a cleanup worker. Later registration prunes dead entries.
 * Arguments: 0 emitter OBJECT, required; 1 enabled BOOL, required;
 * 2 radius NUMBER, required when enabling, finite1..100000 metres;
 * 3 affected sides ARRAY of SIDE, required when enabling,1..4 unique sides from
 * west/east/resistance/civilian. Explicit sides avoid treating every radar as a jammer.
 * Disable uses only [emitter,false]. No global setting, target knowledge or voice denial.
 * Return Value: BOOL, snapshot accepted; false for invalid input or full registry.
 * Current callers: Server mission scripts; CortexJammingFactor consumes the snapshot.
 * Example: [jammerVehicle,true,200,[west]] call CBE_fnc_CortexJammingField;
 */
if (!isServer || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {!(_this isEqualType [])} || {!(count _this in [2,4])}) exitWith {false};
params ["_emitter","_enabled",["_radius",200],["_sides",[]]];
if (!(_emitter isEqualType objNull) || {isNull _emitter}
    || {!(_enabled isEqualType true)}) exitWith {false};
if (_enabled && {count _this != 4 || {!alive _emitter}
    || {!(_radius isEqualType 0)} || {!finite _radius} || {_radius < 1} || {_radius > 100000}
    || {!(_sides isEqualType [])} || {count _sides < 1} || {count _sides > 4}
    || {_sides findIf {!(_x isEqualType west) || {!(_x in [west,east,resistance,civilian])}} >= 0}
}) exitWith {false};
private _original=missionNamespace getVariable ["CBE_EW_Fields",[]];
if (!(_original isEqualType []) || {count _original > 32}) exitWith {false};
private _fields=_original select {
    _x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualType objNull}
        && {!isNull (_x select 0)} && {alive (_x select 0)}
};
private _index=_fields findIf {(_x select 0) == _emitter};
if (_enabled) then {
    private _affected=[west,east,resistance,civilian] select {_x in _sides};
    private _field=[_emitter,_radius,_affected];
    if (_index >= 0) then {_fields set [_index,_field]} else {
        if (count _fields < 32) then {_fields pushBack _field} else {_index=-2};
    };
} else {
    if (_index >= 0) then {_fields deleteAt _index};
};
if (_index == -2) exitWith {false};
if (_fields isNotEqualTo _original) then {
    missionNamespace setVariable ["CBE_EW_Fields",_fields,true];
};
true
