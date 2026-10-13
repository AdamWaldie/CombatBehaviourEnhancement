/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify the selected ground gunner's actual station has a loaded damaging magazine
 * compatible with an exposed station weapon. Ammunition on another turret cannot qualify it.
 * Locality/authority: Read-only on the gunner owner; vehicle locality may differ; callers retain ROE, safety and token checks.
 * Repeat/JIP: No state, commands or handlers; rereads current crew and magazines at each fire boundary.
 * Arguments: 0 platform <OBJECT, objNull>; 1 selected gunner <OBJECT, objNull>.
 * Return Value: BOOL, station currently has usable damaging ammunition; not proof of firing/effect.
 * Current callers: CortexCombinedArmsLocal and CortexCombinedGroundStep.
 * Example: [_vehicle,gunner _vehicle] call WAIT_fnc_CortexGroundFireReady;
 */
params [["_asset",objNull,[objNull]],["_gunner",objNull,[objNull]]];
if (isNull _asset || {isNull _gunner} || {!local _gunner}
    || {!alive _asset} || {!(_asset isKindOf "LandVehicle")}
    || {gunner _asset != _gunner} || {vehicle _gunner != _asset}) exitWith {false};
private _crew=fullCrew [_asset,"",false];
private _stationIndex=_crew findIf {(_x select 0) == _gunner};
if (_stationIndex < 0) exitWith {false};
private _station=(_crew select _stationIndex) select 3;
private _weapons=_asset weaponsTurret _station;
private _loaded=magazinesAllTurrets _asset;
_loaded findIf {
    _x params ["_magazine","_turret","_rounds"];
    _turret isEqualTo _station && {_rounds > 0} && {
        private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
        (getNumber (_ammo >> "hit") > 0 || {getNumber (_ammo >> "indirectHit") > 0})
            && {_weapons findIf {_magazine in compatibleMagazines _x} >= 0}
    }
} >= 0
