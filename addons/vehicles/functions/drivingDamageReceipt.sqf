/*
 * Author: WaldoTheWarfighter
 * Purpose: Read/copy a bounded vehicle hitpoint snapshot or validate an inherited snapshot.
 * Locality/authority: Live reads require the actual vehicle owner; inherited arrays are read-only
 * validation only and grant no command authority. No damage, repair or feature write occurs.
 * Repeat/JIP: No retained state or worker; at most 128 entries per validated table. Engine table
 * retrieval cost remains engine-dependent. Callers bind snapshots to their own finite operation.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 inherited table <ARRAY>, [] when vehicle is null.
 * Return: ARRAY [names,selections,damage values], cloned columns, or [] for unknown/invalid data.
 * Current callers: DrivingAssistStart rear recovery admission, monitoring and inherited validation.
 * Example: private _snapshot=[_vehicle] call CBE_fnc_DrivingDamageReceipt;
 */
params [["_damageVehicle",objNull,[objNull]],["_table",[],[[]]]];
if (!isNull _damageVehicle && {!local _damageVehicle}) exitWith {[]};
if (!isNull _damageVehicle) then {_table=getAllHitPointsDamage _damageVehicle};
if (count _table != 3 || {_table findIf {!(_x isEqualType [])} >= 0}) exitWith {[]};
private _count=count (_table select 0);
if (_count == 0 || {_count > 128} || {count (_table select 1) != _count}
    || {count (_table select 2) != _count}
    || {(_table select 0) findIf {!(_x isEqualType "")} >= 0}
    || {(_table select 1) findIf {!(_x isEqualType "")} >= 0}
    || {(_table select 2) findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x > 1}} >= 0}) exitWith {[]};
_table apply {+_x}
