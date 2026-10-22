/*
 * Author: WaldoTheWarfighter
 * Separates usable launcher capability from tactical role, including leaders and dual-purpose ammunition.
 * Locality/authority: read-only on the requesting owner unless stated below.
 * Repeat/JIP: no side effects; runtime gates are read again on every call.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: potential equipment threat <BOOL>, false.
 * Potential mode classifies configured launcher ammunition without reading carried/loaded rounds.
 * Own force capability keeps live ammunition checks; potential threat is not confirmed ammunition.
 * Return Value: Array of strings AT and/or AA; empty for no usable launcher or incapable soldier.
 * Current callers: UnitRole, AntiArmour, Morale and reinforcement selection.
 * Example: private _caps = [_soldier] call CBE_fnc_CortexCapabilities;
 */
params [["_unit", objNull, [objNull]],["_potential",false,[false]]];
if !([_unit] call CBE_fnc_CortexCombatEffective) exitWith {[]};
private _weapon = secondaryWeapon _unit;
if (_weapon == "") exitWith {[]};
private _compatible = compatibleMagazines _weapon;
private _caps = [];
private _cache = missionNamespace getVariable ["CBE_AIPass_AmmoCapabilities", createHashMap];
// Live friendly capacity includes loaded rounds. Hostile equipment threat never reads reserves.
// The synthetic positive count in potential mode selects config classification only.
private _ammunition=if (_potential) then {_compatible apply {[_x,1]}} else {magazinesAmmoFull _unit};
// Only immutable config facts are cached; mission overrides remain live.
{
    _x params ["_magazine", "_rounds"];
    if (_rounds > 0 && {_magazine in _compatible}) then {
        private _roles = _cache getOrDefault [_magazine, []];
        if !(_magazine in _cache) then {
            private _ammo = configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
            private _flags = getNumber (_ammo >> "aiAmmoUsageFlags");
            if (getNumber (_ammo >> "airLock") > 0 || {(floor (_flags / 256) mod 2) == 1}) then {_roles pushBack "AA"};
            if ((floor (_flags / 512) mod 2) == 1) then {_roles pushBack "AT"};
            // Older configs may omit usage flags. Only non-AA explosive rockets qualify by fallback.
            if (_roles isEqualTo [] && {toLowerANSI getText (_ammo >> "simulation") in ["shotrocket", "shotmissile"]}
                && {getNumber (_ammo >> "hit") >= 100}) then {_roles pushBack "AT"};
            _cache set [_magazine, _roles];
        };
        private _overrides = missionNamespace getVariable ["CBE_AIPass_AmmoCapabilityOverrides", createHashMap];
        if (_overrides isEqualType createHashMap) then {
            private _override = _overrides getOrDefault [_magazine, _roles];
            if (_override isEqualType []) then {_roles = _override};
        };
        {if (_x in ["AT", "AA"]) then {_caps pushBackUnique _x}} forEach _roles;
    };
} forEach _ammunition;
missionNamespace setVariable ["CBE_AIPass_AmmoCapabilities", _cache];
_caps
