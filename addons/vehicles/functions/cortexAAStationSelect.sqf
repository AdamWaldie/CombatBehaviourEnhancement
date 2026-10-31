/*
 * Author: WaldoTheWarfighter
 * Purpose: Prefer the primary gunner, then qualify up to three other occupied cannon
 * stations in the existing primary gunner's defence group for one AA interception.
 * Locality/authority: Read-only, local platform/group/operator/turret. No station switch,
 * native targeting, ammunition loading, lease acquisition or independent controller.
 * Repeat/JIP: Fresh START proposal only; the executor binds the chosen station until it
 * ends. No cache, worker or JIP replay. A failed candidate does not block later candidates.
 * Arguments: 0 vehicle OBJECT,objNull; 1 existing defence group GROUP,grpNull;
 * 2 warned asset OBJECT,objNull. Primary-absent/other-group/driver/FFV stations unsupported.
 * Return: HASHMAP qualifying loaded observation plus actor/geometry, or empty.
 * Bounds: <=32 occupied crew, <=4 candidates, <=32 loaded-state reads/candidate,
 * <=8 config levels with <=32 raw entries/level, <=32 compatibility queries/secondary
 * (<=256 magazines/query) and <=128 native magazine rows/secondary. No world scan.
 * Callers: CortexAAIntercept START after warning/policy/registry admission.
 * Example: private _station=[_vehicle,_group,_victim] call CBE_fnc_CortexAAStationSelect;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],["_victim",objNull,[objNull]]];
if (isNull _vehicle || {!local _vehicle} || {isNull _group} || {!local _group}
    || {isNull gunner _vehicle} || {group gunner _vehicle != _group}) exitWith {createHashMap};
private _crew=fullCrew [_vehicle,"",false];
if (count _crew > 32) exitWith {createHashMap};
private _candidates=[];private _primary=gunner _vehicle;
private _operating={
    params ["_row"];
    (_row select 0) != objNull && {group (_row select 0) == _group}
        && {toLowerANSI (_row select 1) in ["gunner","commander","turret"]}
        && {!(_row select 4)}
};
private _primaryIndex=_crew findIf {(_x select 0) == _primary && {[_x] call _operating}};
if (_primaryIndex >= 0) then {_candidates pushBack _primary};
{
    if (count _candidates >= 4) exitWith {};
    if ([_x] call _operating) then {_candidates pushBackUnique (_x select 0)};
} forEach _crew;
private _selections=_vehicle selectionNames "Memory";
private _qualify={
    params ["_gunner"];
    if (!local _gunner || {!simulationEnabled _gunner} || {isObjectHidden _gunner}
        || {isPlayer _gunner} || {!isNull remoteControlled _gunner}
        || {!isNull (_gunner getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {!([_gunner] call CBE_fnc_CortexCombatEffective)}
        || {!([_gunner] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {[_group,false,_gunner] call CBE_fnc_CortexExternalTakeover}
        || {[_vehicle] call CBE_fnc_CompatibilityExternalControl}
        || {!([_vehicle,_gunner,_group,_victim] call CBE_fnc_CortexAAWarningLink)}) exitWith {createHashMap};
    private _observation=createHashMap;
    if (!([_vehicle,_gunner,objNull,_observation,false,false,true] call CBE_fnc_CortexGroundFireReady)) exitWith {createHashMap};
    private _turret=+(_observation get "loadedTurret");
    if (count _turret < 1 || {count _turret > 8}
        || {_turret findIf {!(_x isEqualType 0) || {!finite _x} || {_x != floor _x} || {_x < 0} || {_x >= 32}} >= 0}
        || {_vehicle turretUnit _turret != _gunner} || {!(_vehicle turretLocal _turret)}) exitWith {createHashMap};
    private _lock=_vehicle lockedCameraTo _turret;
    if (!isNil "_lock" && {!(_lock isEqualType objNull && {isNull _lock})}) exitWith {createHashMap};
    private _magazine=_observation get "loadedMagazine";
    private _speed=getNumber (configFile >> "CfgMagazines" >> _magazine >> "initSpeed");
    private _weaponConfig=configFile >> "CfgWeapons" >> (_observation get "loadedWeapon");
    private _muzzleConfig=_weaponConfig >> (_observation get "loadedMuzzle");
    private _override=getNumber (_weaponConfig >> "initSpeed");
    if (isNumber (_muzzleConfig >> "initSpeed")) then {_override=getNumber (_muzzleConfig >> "initSpeed")};
    if (_override > 0) then {_speed=_override};
    if (_override < 0) then {_speed=_speed*(-_override)};
    private _ammoConfig=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
    private _gravity=if (isNumber (_ammoConfig >> "coefGravity")) then {getNumber (_ammoConfig >> "coefGravity")} else {1};
    if (!finite _speed || {!finite _gravity} || {_gravity < 0} || {_gravity > 4}) exitWith {createHashMap};
    // Preserve the engine's raw turret config indices (BIS_fnc_turretConfig convention).
    // Filtering/reordering child classes can select another station's optical/barrel points.
    private _main=configOf _vehicle;
    {
        private _children=_main >> "Turrets";
        if (count _children > 32 || {_x >= count _children}) exitWith {_main=configNull};
        _main=_children select _x;
        if (!isClass _main) exitWith {_main=configNull};
    } forEach _turret;
    if (!isClass _main) exitWith {createHashMap};
    private _optic=getText (_main >> "memoryPointGunnerOptics");
    // Native multi-barrel turrets may override inherited gunBeg through this array.
    // Use one declared, physically present origin; never substitute model centre.
    // A first-barrel origin approximates alternating barrels, not an exact fired position.
    private _barrels=(getArray (_main >> "memoryPointGun")) select [0,8];
    _barrels pushBackUnique getText (_main >> "gunBeg");
    private _barrel="";
    private _barrelIndex=_barrels findIf {_x isEqualType "" && {_x != ""} && {_x in _selections}};
    if (_barrelIndex >= 0) then {_barrel=_barrels select _barrelIndex};
    if (_speed < 100 || {_speed > 2000} || {!(_barrel in _selections)} || {!(_optic in _selections)}) exitWith {createHashMap};
    private _front="";private _rear="";
    private _secondary=_gunner != _primary;
    if (_secondary) then {
        _front=getText (_main >> "gunBeg");_rear=getText (_main >> "gunEnd");
    };
    if (_secondary && {!(_front in _selections) || {!(_rear in _selections)}
        || {(_vehicle selectionPosition [_rear,"Memory"]) distance
            (_vehicle selectionPosition [_front,"Memory"]) < 0.05}}) exitWith {createHashMap};
    if (_secondary) then {
        private _stationWeapons=_vehicle weaponsTurret _turret;
        private _complete=count _stationWeapons <= 16;private _checks=0;private _matches=[];
        // UseMagazine chooses a weapon by magazine type. Reject any other compatible
        // weapon/muzzle in this station, including unselected or currently empty ones.
        {
            if (!_complete) exitWith {};
            private _weapon=_x;
            private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
            if (_muzzles isEqualTo []) then {_muzzles=["this"]};
            if (count _muzzles > 8) exitWith {_complete=false};
            {
                if (_checks >= 32) exitWith {_complete=false};
                _checks=_checks+1;
                private _muzzle=[_x,_weapon] select (_x == "this");
                private _magazines=compatibleMagazines [_weapon,_x];
                if (count _magazines > 256) exitWith {_complete=false};
                if (_magazine in _magazines) then {_matches pushBackUnique [_weapon,_muzzle]};
            } forEach _muzzles;
        } forEach (_stationWeapons select [0,16]);
        if (!_complete || {_matches isNotEqualTo [[_observation get "loadedWeapon",_observation get "loadedMuzzle"]]}) exitWith {};
        _observation set ["stationWeapons",+_stationWeapons];
    };
    if (_secondary && {!("stationWeapons" in _observation)
        || {([_vehicle,_gunner,_observation] call CBE_fnc_CortexAAMagazineIdentity) isEqualTo []}}) exitWith {createHashMap};
    _observation set ["gunner",_gunner];_observation set ["secondary",_secondary];
    _observation set ["barrel",_barrel];_observation set ["optic",_optic];
    _observation set ["directionFront",_front];_observation set ["directionRear",_rear];
    _observation set ["speed",_speed];_observation set ["gravity",_gravity];
    _observation set ["directFuse",getNumber (_ammoConfig >> "indirectHit") <= 0 && {getNumber (_ammoConfig >> "explosive") <= 0}];
    _observation
};
private _chosen=createHashMap;
_candidates findIf {_chosen=[_x] call _qualify;count _chosen > 0};
_chosen
