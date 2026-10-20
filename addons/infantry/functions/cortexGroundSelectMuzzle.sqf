/*
 * Author: WaldoTheWarfighter
 * Purpose: Select the exact loaded ground-turret weapon/muzzle observed by GroundFireReady.
 * Locality/authority: Actual local AI gunner and local turret only. Callers retain their
 * operation, target, ROE and firing-lane authority; this helper never targets or fires.
 * Repeat/JIP: Read native selected state each call; issue only while it differs, then
 * require native station acknowledgement. No timer, replay, inventory or cached permission.
 * Arguments: 0 platform OBJECT objNull; 1 gunner OBJECT objNull;
 * 2 fresh GroundFireReady observation HASHMAP empty, with loadedWeapon/Muzzle/Turret.
 * Return: BOOL, exact weapon and muzzle are now selected; false is refusal/pending,
 * never proof of firing. Callers retain their original finite retry deadline.
 * Bounds: <=64 crew rows, <=16 station weapons and at most two native state reads.
 * Current callers: CortexVehicles, CortexCombinedArmsLocal and CortexCombinedGroundStep.
 * Example: private _selected=[_tank,gunner _tank,_observation] call CBE_fnc_CortexGroundSelectMuzzle;
 */
params [["_asset",objNull,[objNull]],["_gunner",objNull,[objNull]],
    ["_observation",createHashMap,[createHashMap]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _asset} || {isNull _gunner} || {!local _gunner}
    || {!alive _asset} || {!(_asset isKindOf "LandVehicle")} || {gunner _asset != _gunner}
    || {vehicle _gunner != _asset} || {isPlayer _gunner} || {!isNull remoteControlled _gunner}
    || {!([_gunner] call CBE_fnc_CortexActorFireTaskAvailable)}
    || {!([_gunner] call CBE_fnc_CortexCombatEffective)}
    || {!("loadedTurret" in _observation)}) exitWith {false};
private _weapon=_observation getOrDefault ["loadedWeapon",""];
private _muzzle=_observation getOrDefault ["loadedMuzzle",""];
private _turret=_observation get "loadedTurret";
if (!(_weapon isEqualType "") || {_weapon == ""} || {!(_muzzle isEqualType "")} || {_muzzle == ""}
    || {!(_turret isEqualType [])} || {count _turret > 8}
    || {_turret findIf {!(_x isEqualType 0) || {!finite _x} || {_x != floor _x} || {_x < -1}} >= 0}) exitWith {false};
private _crew=fullCrew [_asset,"",false];
if (count _crew > 64 || {_crew findIf {(_x select 0) == _gunner && {(_x select 3) isEqualTo _turret}} < 0}
    || {!(_asset turretLocal _turret)}
    || {!(_weapon in ((_asset weaponsTurret _turret) select [0,16]))}) exitWith {false};
private _selected=weaponState [_asset,_turret];
if ((_selected param [0,""]) != _weapon || {(_selected param [1,""]) != _muzzle}) then {
    _asset selectWeaponTurret [_weapon,_turret,_muzzle];
    _selected=weaponState [_asset,_turret];
};
(_selected param [0,""]) == _weapon && {(_selected param [1,""]) == _muzzle}
