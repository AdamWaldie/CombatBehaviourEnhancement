/*
 * Author: WaldoTheWarfighter
 * Classifies a soldier's combat role from what he carries.
 *
 * MG: primary magazine holds 75 rounds or more. AT: has usable anti-armour ammunition. Leaders retain their tactical role; capability is queried separately. MEDIC: ACE
 * or vanilla medic trait. LEADER: group leader. Otherwise RIFLE. Magazine sizes are cached per class
 * in a machine-local map, so repeated calls cost a lookup.
 * Locality and authority: read-only; callable anywhere.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked; owner jobs are retired on migration.
 * Arguments:
 * 0: unit <OBJECT>, objNull
 * 1: medical-first assignment view <BOOL>, false; true preserves dual-role medics before equipment/leader classification.
 *
 * Return Value:
 * String - "LEADER", "MG", "AT", "MEDIC" or "RIFLE"
 *
 * Example:
 * if (([_unit] call CBE_fnc_CortexUnitRole) == "MG") then {...};
 * Result: machine gunners are preferred for suppression and kept in the base of fire.
 *
 * Current callers: CortexFireControl, CortexLocality, CortexAdvanceStart, CortexAssaultStart,
 * CortexFlankStart, CortexFlankStep, CortexGroupTick, DangerGroupHideStep, CortexStaticSupport,
 * CortexGarrison, CortexGarrisonRefill and CortexGarrisonApplyLocal. Default role ordering is unchanged.
 */

params [["_unit", objNull, [objNull]],["_medicalFirst",false,[false]]];
if (isNull _unit) exitWith {"RIFLE"};
if (_medicalFirst && {_unit getUnitTrait "Medic" || {(_unit getVariable ["ace_medical_medicClass",0]) > 0}}) exitWith {"MEDIC"};
if (leader group _unit == _unit) exitWith {"LEADER"};
if ("AT" in ([_unit] call CBE_fnc_CortexCapabilities)) exitWith {"AT"};
private _cache = missionNamespace getVariable ["CBE_AIPass_MagazineSizes", createHashMap];
private _magazine = (primaryWeaponMagazine _unit) param [0, ""];
private _size = _cache getOrDefault [_magazine, -1];
if (_size < 0) then {
    _size = getNumber (configFile >> "CfgMagazines" >> _magazine >> "count");
    _cache set [_magazine, _size];
    missionNamespace setVariable ["CBE_AIPass_MagazineSizes", _cache];
};
if (_size >= 75) exitWith {"MG"};
if (!_medicalFirst && {_unit getUnitTrait "Medic" || {(_unit getVariable ["ace_medical_medicClass", 0]) > 0}}) exitWith {"MEDIC"};
"RIFLE"
