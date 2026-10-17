/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify the selected ground gunner's actual station has a loaded damaging magazine
 * in a native station weapon/muzzle state. Reserve magazines or another turret cannot qualify it.
 * Work: at most16 station weapons,8 configured muzzles each and32 native weapon-state queries.
 * This checks loaded rounds, not completion of the native reload/firing cycle.
 * An optional target also requires configured ammunition intent for its actual platform class.
 * Missing usage flags retain a conservative legacy fallback; no targeting command is issued.
 * Locality/authority: Read-only on the gunner owner; vehicle locality may differ; callers retain ROE, safety and token checks.
 * Repeat/JIP: No world state, commands or handlers; rereads native station state at each boundary.
 * Optional caller-local observation is reset per call; reload evidence grants no firing permission.
 * Arguments: 0 platform <OBJECT, objNull>; 1 selected gunner <OBJECT, objNull>;
 * 2 target <OBJECT, objNull>, omitted means the station-only ammunition check;
 * 3 observation <HASHMAP, empty>, receives reloadInProgress BOOL for queried matching muzzles.
 * Return Value: BOOL, station has usable damaging ammunition for the supplied target,
 * or any damaging ammunition when target is omitted; not proof of firing/effect.
 * Current callers: CortexCombinedArmsLocal, CortexCombinedGroundStep and CortexVehicles.
 * Example: [_vehicle,gunner _vehicle,_enemy] call WAIT_fnc_CortexGroundFireReady;
 */
params [["_asset",objNull,[objNull]],["_gunner",objNull,[objNull]],["_target",objNull,[objNull]],["_observation",createHashMap,[createHashMap]]];
_observation set ["reloadInProgress",false];
if (isNull _asset || {isNull _gunner} || {!local _gunner}
    || {!alive _asset} || {!(_asset isKindOf "LandVehicle")}
    || {gunner _asset != _gunner} || {vehicle _gunner != _asset}) exitWith {false};
private _crew=fullCrew [_asset,"",false];
private _stationIndex=_crew findIf {(_x select 0) == _gunner};
if (_stationIndex < 0) exitWith {false};
private _station=(_crew select _stationIndex) select 3;
private _weapons=_asset weaponsTurret _station;
private _targetPlatform=if (isNull _target) then {objNull} else {vehicle _target};
private _targetFlag=if (isNull _targetPlatform) then {0} else {
    if (_targetPlatform isKindOf "Man") then {64} else {
        if (_targetPlatform isKindOf "Air") then {256} else {
            if (_targetPlatform isKindOf "Tank"
                || {getNumber (configFile >> "CfgVehicles" >> typeOf _targetPlatform >> "type") == 1}) then {512} else {128}
        }
    }
};
private _targetSuitable={
    params ["_ammo"];
    if (_targetFlag == 0) exitWith {true};
    // Explicit infantry exclusion is authoritative even for older unflagged ammo.
    if (_targetFlag == 64 && {isNumber (_ammo >> "allowAgainstInfantry")}
        && {getNumber (_ammo >> "allowAgainstInfantry") == 0}) exitWith {false};
    private _flags=getNumber (_ammo >> "aiAmmoUsageFlags");
    if (_flags > 0) exitWith {(floor (_flags/_targetFlag) mod 2) == 1};
    // Preserve legacy ordinary rounds against soft targets. Armour requires a
    // heavy shell/rocket/missile, consistent with the existing launcher fallback;
    // air needs an explicit air-lock capability. Config intent is not effect proof.
    if (_targetFlag == 256) exitWith {getNumber (_ammo >> "airLock") > 0};
    if (_targetFlag == 512) exitWith {
        toLowerANSI getText (_ammo >> "simulation") in ["shotshell","shotrocket","shotmissile"]
            && {getNumber (_ammo >> "hit") >= 100} && {getNumber (_ammo >> "airLock") <= 0}
    };
    getNumber (_ammo >> "airLock") <= 0
};
// Inventory membership does not prove a magazine is loaded. Query each native
// station muzzle directly, including an unselected coaxial/secondary weapon.
private _queries=0;
(_weapons select [0,16]) findIf {
    private _weapon=_x;
    private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
    if (_muzzles isEqualTo []) then {_muzzles=["this"]};
    (_muzzles select [0,8]) findIf {
        if (_queries >= 32) exitWith {false};
        _queries=_queries+1;
        private _muzzle=[_x,_weapon] select (_x == "this");
        private _state=weaponState [_asset,_station,_weapon,_muzzle];
        private _magazine=_state param [3,"",[""]];
        private _rounds=_state param [4,0,[0]];
        private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
        private _suitable=_magazine != ""
            && {getNumber (_ammo >> "hit") > 0 || {getNumber (_ammo >> "indirectHit") > 0}}
            && {[_ammo] call _targetSuitable};
        private _reload=_state param [6,0,[0]];
        if (count _state >= 7 && {(_state select 0) == _weapon} && {(_state select 1) == _muzzle}
            && {_suitable} && {finite _reload} && {_reload > 0} && {_reload <= 1}) then {
            _observation set ["reloadInProgress",true];
        };
        count _state >= 5 && {(_state select 0) == _weapon}
            && {(_state select 1) == _muzzle}
            && {_magazine != ""} && {finite _rounds} && {_rounds > 0} && {_suitable}
    } >= 0
} >= 0
