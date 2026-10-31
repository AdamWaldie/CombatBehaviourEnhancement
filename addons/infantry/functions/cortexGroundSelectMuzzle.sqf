/*
 * Author: WaldoTheWarfighter
 * Purpose: Select the exact loaded ground-turret weapon/muzzle observed by GroundFireReady.
 * Locality/authority: Actual local AI gunner and local turret only. Callers retain their
 * operation, target, ROE and firing-lane authority; this helper never targets or fires.
 * Alternate stations require the exact live AA episode; ordinary ground callers remain primary-only.
 * Repeat/JIP: Read native selected state each call; issue only while it differs, then
 * require native station acknowledgement with the same loaded magazine, positive rounds
 * and completed magazine reload phase. Positive/unknown reload phase grants no fire admission.
 * A stale observation cannot select an emptied or changed magazine. No timer, replay,
 * inventory or cached permission.
 * Arguments: 0 platform OBJECT objNull; 1 gunner OBJECT objNull;
 * 2 fresh GroundFireReady observation HASHMAP empty, with loadedWeapon/Muzzle/Magazine/Turret.
 * Return: BOOL, exact weapon and muzzle are now selected; false is refusal/pending,
 * never proof of firing. Callers retain their original finite retry deadline.
 * Bounds: <=64 crew rows, <=16 station weapons and at most three native state reads.
 * Current callers: CortexVehicles, CortexCombinedArmsLocal, CortexCombinedGroundStep and CortexAAIntercept.
 * Example: private _selected=[_tank,gunner _tank,_observation] call CBE_fnc_CortexGroundSelectMuzzle;
 * Optional argument3: finite fire-owner token STRING, empty; only matching owner may select.
 */
params [["_asset",objNull,[objNull]],["_gunner",objNull,[objNull]],
    ["_observation",createHashMap,[createHashMap]],["_fireOwner","",[""]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _asset} || {isNull _gunner} || {!local _gunner}
    || {!alive _asset} || {!(_asset isKindOf "LandVehicle")}
    || {vehicle _gunner != _asset} || {isPlayer _gunner} || {!isNull remoteControlled _gunner}
    || {!([_gunner,_fireOwner] call CBE_fnc_CortexActorFireTaskAvailable)}
    || {!([_gunner] call CBE_fnc_CortexCombatEffective)}
    || {!("loadedTurret" in _observation)}) exitWith {false};
private _weapon=_observation getOrDefault ["loadedWeapon",""];
private _muzzle=_observation getOrDefault ["loadedMuzzle",""];
private _magazine=_observation getOrDefault ["loadedMagazine",""];
private _turret=_observation get "loadedTurret";
if (!(_weapon isEqualType "") || {_weapon == ""} || {!(_muzzle isEqualType "")} || {_muzzle == ""}
    || {!(_magazine isEqualType "")} || {_magazine == ""}
    || {!(_turret isEqualType [])} || {count _turret > 8}
    || {_turret findIf {!(_x isEqualType 0) || {!finite _x} || {_x != floor _x} || {_x < -1}} >= 0}) exitWith {false};
// Only the exact live AA episode may extend this selector beyond the primary gunner.
// A token prefix or another station's observation is not admission.
if (gunner _asset != _gunner) then {
    private _aa=_asset getVariable ["CBE_AA_Intercept",createHashMap];
    if (_fireOwner == "" || {(_aa getOrDefault ["token",""]) != _fireOwner}
        || {_aa getOrDefault ["finished",false]} || {time >= (_aa getOrDefault ["until",-1])}
        || {(_aa getOrDefault ["gunner",objNull]) != _gunner}
        || {(_aa getOrDefault ["turret",[]]) isNotEqualTo _turret}
        || {_asset turretUnit _turret != _gunner}) exitWith {_fireOwner=""};
};
if (gunner _asset != _gunner && {_fireOwner == ""}) exitWith {false};
private _crew=fullCrew [_asset,"",false];
if (count _crew > 64 || {_crew findIf {(_x select 0) == _gunner && {(_x select 3) isEqualTo _turret}} < 0}
    || {!(_asset turretLocal _turret)}
    || {!(_weapon in ((_asset weaponsTurret _turret) select [0,16]))}) exitWith {false};
// Read the exact requested muzzle again, not just the currently selected station weapon.
// A cached proposal or completed reload cannot borrow an earlier loaded-magazine receipt.
private _loaded=weaponState [_asset,_turret,_weapon,_muzzle];
private _loadedPhase=_loaded param [6,1,[0]];
if (count _loaded < 7 || {(_loaded select 0) != _weapon} || {(_loaded select 1) != _muzzle}
    || {(_loaded select 3) != _magazine} || {!((_loaded select 4) isEqualType 0)}
    || {!finite (_loaded select 4)} || {(_loaded select 4) <= 0}
    || {!finite _loadedPhase} || {_loadedPhase != 0}) exitWith {false};
private _selected=weaponState [_asset,_turret];
if ((_selected param [0,""]) != _weapon || {(_selected param [1,""]) != _muzzle}) then {
    _asset selectWeaponTurret [_weapon,_turret,_muzzle];
    _selected=weaponState [_asset,_turret];
};
(_selected param [0,""]) == _weapon && {(_selected param [1,""]) == _muzzle}
    && {(_selected param [3,"",[""]]) == _magazine}
    && {private _rounds=_selected param [4,0,[0]]; finite _rounds && {_rounds > 0}}
    && {private _phase=_selected param [6,1,[0]]; finite _phase && {_phase == 0}}
