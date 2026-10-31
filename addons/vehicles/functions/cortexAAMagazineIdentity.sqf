/*
 * Author: WaldoTheWarfighter
 * Purpose: Resolve one unambiguous currently loaded AA magazine instance for a local
 * occupied turret. A reserve with the same class/count makes the result ambiguous.
 * Locality/authority: Read-only on the local platform, actor and exact turret owner.
 * The caller owns policy, immutable weapon compatibility proof and firing permission.
 * Repeat/JIP: Fresh native state/inventory every call; no cache, command, timer or replay.
 * Arguments: 0 vehicle OBJECT,objNull; 1 operator OBJECT,objNull;
 * 2 observation HASHMAP,empty, with loadedWeapon/Muzzle/Magazine/Turret and stationWeapons.
 * Return: ARRAY [native magazine id,creator] or [] on missing/ambiguous/changed state.
 * Bounds: <=16 unchanged station weapons, one state read and <=128 inventory rows.
 * Callers: CortexAAStationSelect and CortexAAIntercept immediately before secondary fire.
 * Example: private _identity=[_vehicle,_gunner,_observation] call CBE_fnc_CortexAAMagazineIdentity;
 */
params [["_vehicle",objNull,[objNull]],["_gunner",objNull,[objNull]],
    ["_observation",createHashMap,[createHashMap]]];
private _turret=_observation getOrDefault ["loadedTurret",[]];
if (isNull _vehicle || {isNull _gunner} || {!local _vehicle} || {!local _gunner}
    || {!(_turret isEqualType [])} || {count _turret < 1} || {count _turret > 8}
    || {_turret findIf {!(_x isEqualType 0) || {!finite _x} || {_x != floor _x} || {_x < 0} || {_x >= 32}} >= 0}
    || {_vehicle turretUnit _turret != _gunner} || {!(_vehicle turretLocal _turret)}) exitWith {[]};
private _weapons=_vehicle weaponsTurret _turret;
if (count _weapons > 16 || {_weapons isNotEqualTo (_observation getOrDefault ["stationWeapons",[]])}) exitWith {[]};
private _weapon=_observation getOrDefault ["loadedWeapon",""];
private _muzzle=_observation getOrDefault ["loadedMuzzle",""];
private _magazine=_observation getOrDefault ["loadedMagazine",""];
if (!(_weapon isEqualType "") || {!(_muzzle isEqualType "")} || {!(_magazine isEqualType "")}
    || {_weapon == ""} || {_muzzle == ""} || {_magazine == ""} || {!(_weapon in _weapons)}) exitWith {[]};
private _loaded=weaponState [_vehicle,_turret,_weapon,_muzzle];
private _rounds=_loaded param [4,-1,[0]];private _phase=_loaded param [6,1,[0]];
if (count _loaded < 7 || {(_loaded select 0) != _weapon} || {(_loaded select 1) != _muzzle}
    || {(_loaded select 3) != _magazine} || {_magazine == ""}
    || {!finite _rounds} || {_rounds < 20} || {!finite _phase} || {_phase != 0}) exitWith {[]};
private _inventory=magazinesAllTurrets [_vehicle,true];
if (count _inventory > 128) exitWith {[]};
private _matches=_inventory select {
    count _x >= 5 && {(_x select 0) == _magazine} && {(_x select 1) isEqualTo _turret}
        && {(_x select 2) == _rounds}
};
if (count _matches != 1) exitWith {[]};
private _row=_matches select 0;
private _identity=[_row select 3,_row select 4];
if (_identity findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} >= 0) exitWith {[]};
_identity
