/*
 * Author: WaldoTheWarfighter
 * Purpose: Propose one carried replacement magazine for a nearly empty selected rifle.
 * Locality/authority: Read-only current actor owner. Caller must retain actual task, cover,
 * native command and operation authority at the eventual native reload request.
 * Repeat/JIP: Stateless; one weapon-state query, <=128 carried magazine rows and <=128
 * compatible classes. Loaded magazines elsewhere are not reserve supply. No job or replay.
 * Only selected main-muzzle bullet rifles with auto-reload enabled are considered. Existing
 * reload/cycling, unavailable state, >5 rounds or >quarter magazine retains native policy.
 * Arguments: 0 soldier OBJECT,objNull.
 * Return: ARRAY [muzzle,magazine,original weaponState], or[]; not reload completion/readiness.
 * Current callers: CortexFlankStep on a fresh ordinary bound, at most four mover proposals.
 * Example: private _proposal=[soldier1] call CBE_fnc_CortexRifleReloadPlan;
 */
params [["_actor",objNull,[objNull]]];
if (isNull _actor || {!local _actor} || {!reloadEnabled _actor}) exitWith {[]};
private _weapon=primaryWeapon _actor;
if (_weapon == "" || {currentWeapon _actor != _weapon}) exitWith {[]};
private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
private _main=if ("this" in _muzzles) then {_weapon} else {_muzzles param [0,_weapon]};
if (currentMuzzle _actor != _main) exitWith {[]};
private _weaponState=_actor weaponState _main;
if (count _weaponState != 7 || {(_weaponState select 0) != _weapon} || {(_weaponState select 1) != _main}
    || {(_weaponState select [4,3]) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {(_weaponState select 4) < 0} || {(_weaponState select 4) > 5}
    || {!((_weaponState select 5) in [-1,0])} || {(_weaponState select 6) != 0}) exitWith {[]};
private _magazine=_weaponState select 3;
private _capacity=getNumber (configFile >> "CfgMagazines" >> _magazine >> "count");
private _ammo=getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
if (_capacity < 10 || {toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation") != "shotbullet"}
    || {(_weaponState select 4) > _capacity/4}) exitWith {[]};
private _compatible=compatibleMagazines [_weapon,if (_main == _weapon) then {"this"} else {_main}];
if (count _compatible == 0 || {count _compatible > 128}) exitWith {[]};
private _carried=magazinesAmmo _actor;
if (count _carried > 128) exitWith {[]};
private _selected="";private _most=_weaponState select 4;
{
    if (_x isEqualType [] && {count _x == 2} && {(_x select 0) in _compatible}
        && {(_x select 1) isEqualType 0} && {finite (_x select 1)} && {(_x select 1) > _most}) then {
        _selected=_x select 0;_most=_x select 1;
    };
} forEach _carried;
if (_selected == "") exitWith {[]};
private _replacementAmmo=getText (configFile >> "CfgMagazines" >> _selected >> "ammo");
if (toLowerANSI getText (configFile >> "CfgAmmo" >> _replacementAmmo >> "simulation") != "shotbullet") exitWith {[]};
[_main,_selected,+_weaponState]
