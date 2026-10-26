/*
 * Author: WaldoTheWarfighter
 * Repeat/JIP: Each call requests a new shot; callers own cooldowns. No persistent handler or JIP replay.
 * Fires a vehicle's countermeasure launcher: smoke on ground vehicles, flares on aircraft.
 *
 * Vanilla and most mod smoke launchers and flare launchers use the "cmlauncher" weapon simulation,
 * so the launcher is found from config rather than by name. Turrets are searched driver first, then
 * every turret, including person-turret paths: modded operational turrets may use that flag.
 * Seat protection is handled separately by passenger eligibility. Live inventory is inspected only when a countermeasure is requested: different
 * loadouts of the same class and initially empty turrets must not share stale results. One live
 * whole-vehicle magazine snapshot is filtered by exact turret within this request; it is never cached
 * across requests. BIS_fnc_fire requests the weapon
 * from its own turret.
 * Locality and authority: call where the vehicle and selected station operator are local.
 * Select only an occupied, combat-effective AI station permitted by shared group exclusions and
 * protected-task admission. Internal CBE flight/vehicle ownership is allowed; external control is not.
 * Recheck the same operator/station at dispatch. No crew assignment or fire-policy change is made.
 *
 * Review contract: A nonlocal vehicle is rejected. This helper has no persistent side effects or JIP installation; callers own repetition and cooldown.
 *
 * Arguments:
 * 0: vehicle <OBJECT>
 *
 * Return Value:
 * Boolean - true when a launcher firing request was dispatched; Fired events establish actual fire
 *
 * Example:
 * [_vehicle] call CBE_fnc_CortexFireCountermeasure;
 * Result: a damaged APC pops its smoke screen before withdrawing.
 *
 * Current callers: CBE_fnc_CortexVehicles, CBE_fnc_CortexAirAttack and the aircraft flare
 * handler in CBE_fnc_CortexDiscover.
 */

params [["_vehicle", objNull, [objNull]]];
if (isNull _vehicle || {!alive _vehicle} || {!local _vehicle}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}) exitWith {false};
private _operatorAvailable={
    params ["_actor"];
    !isNull _actor && {local _actor} && {!isPlayer _actor} && {vehicle _actor == _vehicle}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {[_actor] call CBE_fnc_CortexActorFireTaskAvailable}
        && {[group _actor,false,false,true] call CBE_fnc_CortexIsEligible}
};
private _entry = ["", [],objNull];
private _magazineSnapshot=magazinesAllTurrets _vehicle;
{
    private _turret = _x;
    private _operator=_vehicle turretUnit _turret;
    // Reject empty/nonlocal seats cheaply; expensive ownership checks are needed only
    // when that station actually has a compatible countermeasure and ammunition.
    if (!isNull _operator && {local _operator}) then {
        private _weapons = _vehicle weaponsTurret _turret;
        private _turretMagazines=_magazineSnapshot select {(_x select 1) isEqualTo _turret && {(_x select 2) > 0}};
        private _index = _weapons findIf {
            private _weapon=_x;
            toLowerANSI (getText (configFile >> "CfgWeapons" >> _weapon >> "simulation")) == "cmlauncher"
                && {_turretMagazines findIf {(_x select 0) in compatibleMagazines _weapon} >= 0}
        };
        if (_index >= 0 && {[_operator] call _operatorAvailable}) then {_entry = [_weapons select _index, _turret,_operator]};
    };
    if ((_entry select 0) != "") exitWith {};
} forEach ([[-1]] + allTurrets [_vehicle, true]);
_entry params ["_weapon", "_turret","_operator"];
if (_weapon == "") exitWith {
    _vehicle setVariable ["CBE_Cortex_CountermeasureLastRequest",[serverTime,false,"NO_ELIGIBLE_LAUNCHER"],true];
    false
};
private _dispatched=false;
isNil {
    if (!local _vehicle || {!alive _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {(_vehicle turretUnit _turret) != _operator}
        || {!([_operator] call _operatorAvailable)}
        || {!(_weapon in (_vehicle weaponsTurret _turret))}) exitWith {};
    [_vehicle, _weapon, _turret] call BIS_fnc_fire;
    _vehicle setVariable ["CBE_Cortex_CountermeasureLastRequest",[serverTime,true,_weapon,_turret],true];
    _dispatched=true;
};
if (!_dispatched) then {
    _vehicle setVariable ["CBE_Cortex_CountermeasureLastRequest",[serverTime,false,"STATION_CHANGED"],true];
};
_dispatched
