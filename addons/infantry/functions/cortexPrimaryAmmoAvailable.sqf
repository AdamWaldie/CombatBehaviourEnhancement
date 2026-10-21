/*
 * Author: WaldoTheWarfighter
 * Purpose: Check live main-muzzle primary ammunition for tactical rifle capacity.
 * Locality/authority: Read-only on the actual actor owner; no task, weapon or inventory changes.
 * Repeat/JIP: Stateless. Loaded main-muzzle ammunition takes the cheap path; otherwise inspect
 * compatible carried magazines. Underbarrel ammunition does not supply rifle capacity.
 * Arguments: 0 soldier <OBJECT, objNull>.
 * Return: BOOL, true for loaded main-muzzle rounds or a nonempty compatible reserve.
 * This is ammunition availability, not immediate firing readiness or permission.
 * Current callers: CortexTacticalAssess, CortexAssaultStart, CortexFlankStart,
 * CortexAdvanceStart and CortexFlankStep at relief selection and ordinary new-bound admission.
 * Example: private _armed=[soldier1] call CBE_fnc_CortexPrimaryAmmoAvailable;
 */
params [["_unit",objNull,[objNull]]];
if (isNull _unit || {!local _unit}) exitWith {false};
private _weapon=primaryWeapon _unit;
if (_weapon == "") exitWith {false};
private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
private _mainMuzzle=if ("this" in _muzzles) then {"this"} else {_muzzles param [0,"this"]};
private _loadedMuzzle=if (_mainMuzzle == "this") then {_weapon} else {_mainMuzzle};
if (_unit ammo _loadedMuzzle > 0) exitWith {true};
private _compatible=compatibleMagazines [_weapon,_mainMuzzle];
if (_compatible isEqualTo []) exitWith {false};
(magazinesAmmo _unit) findIf {(_x select 1) > 0 && {(_x select 0) in _compatible}} >= 0
