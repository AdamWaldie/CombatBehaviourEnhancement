/*
 * Author: WaldoTheWarfighter
 * Purpose: Request a better reserve magazine for the current ground gunnery owner and observe its
 * asynchronous native loading. Never selects a target, fires, creates ammunition or moves.
 * Locality/authority: Local vehicle, gunner, turret and group owner; current native intent,
 * ROE, feature gates, personal target knowledge and protected tasks are rechecked at issue.
 * Repeat/JIP: One public finite pending receipt and fifteen-second per-vehicle cadence.
 * Later existing vehicle callbacks observe native completion; no timer or fire replay.
 * New orders/owner/target retire metadata only, never cancel or reverse a native reload.
 * Arguments: 0 asset OBJECT objNull; 1 gunner OBJECT objNull; 2 target OBJECT objNull;
 * 3 original native observation server timestamp NUMBER -1;
 * 4 exact current combined opportunity ARRAY [], empty for routine gunnery.
 * A combined request retains its original contact stamp and opportunity expiry;
 * role replacement or expiry revokes it. No role or observation deadline is renewed.
 * Return: STRING REQUESTED/PENDING blocks this routine firing pass; READY/REFUSED does not.
 * READY requires the exact requested magazine, rounds and native magazine reload phase0;
 * it is not permission to fire. A positive phase retains the original pending deadline.
 * Bounds: <=64 crew/128 inventory rows,16 weapons/8 muzzles each,128 compatible classes
 * per muzzle and at most65 native reads including readiness/final validation. Pending
 * observation uses one read. A reserve magazine must identify one configured muzzle;
 * shared-magazine ambiguity or oversized configuration refuses that weapon.
 * Current callers: CortexVehicles, CortexCombinedArmsLocal and CortexCombinedGroundStep,
 * before their own normal fresh firing/role admission.
 * Example: [_tank,gunner _tank,_enemy,serverTime] call CBE_fnc_CortexGroundReload;
 */
params [["_asset",objNull,[objNull]],["_gunner",objNull,[objNull]],
    ["_target",objNull,[objNull]],["_observedAt",-1,[0]],["_opportunity",[],[[]]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _asset}
    || {isNull _gunner} || {isNull _target}) exitWith {"REFUSED"};
private _pending=_asset getVariable ["CBE_GroundReloadPending",[]];
if (_pending isEqualTo [] && {serverTime < (_asset getVariable ["CBE_GroundReloadAfter",-1])}) exitWith {"REFUSED"};
private _group=group _gunner;
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _route=[_group] call CBE_fnc_NativeOrderReceipt;
private _roleCurrent={
    private _liveRole=_group getVariable ["CBE_Cortex_CombinedRole",[]];
    if (_opportunity isEqualTo []) exitWith {_liveRole isEqualTo []};
    count _opportunity == 8 && {_liveRole isEqualTo _opportunity}
        && {(_opportunity select 2) isEqualTo _target}
        && {(_opportunity select 4) in ["GROUND_FIRE","GROUND_MANOEUVRE"]}
        && {(_opportunity select 5) isEqualType 0} && {finite (_opportunity select 5)}
        && {serverTime < (_opportunity select 5)}
        && {(_opportunity select 7) isEqualType []} && {count (_opportunity select 7) == 3}
        && {((_opportunity select 7) select 0) isEqualTo 1}
        && {((_opportunity select 7) select 1) isEqualTo _observedAt}
};
private _available={
    local _asset && {local _gunner} && {local _group} && {alive _asset} && {alive _target}
        && {_asset isKindOf "LandVehicle"} && {vehicle _gunner == _asset} && {gunner _asset == _gunner}
        && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
        && {simulationEnabled _asset} && {!isObjectHidden _asset}
        && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
        && {[_gunner] call CBE_fnc_CortexCombatEffective}
        && {[_gunner] call CBE_fnc_CortexActorFireTaskAvailable}
        && {[_group,false,true,false,_gunner] call CBE_fnc_CortexIsEligible}
        && {!(toUpperANSI currentCommand _gunner in ["FIRE","FIRE AT POSITION","SUPPRESS"])}
        && {combatMode _group in ["YELLOW","RED"]} && {unitCombatMode _gunner in ["YELLOW","RED"]}
        && {!captive _target} && {!(_target getVariable ["ace_captives_isSurrendering",false])}
        && {!(_target getVariable ["ace_captives_isHandcuffed",false])}
        && {(side _group) getFriend (side _target) < 0.6} && {_gunner knowsAbout _target > 0}
        && {!((_gunner targetKnowledge _target) param [7,false,[true]])}
        && {isNull assignedTarget _gunner || {assignedTarget _gunner == _target}}
        && {isNull getAttackTarget _gunner || {getAttackTarget _gunner == _target}}
        && {finite _observedAt} && {_observedAt >= 0} && {serverTime >= _observedAt}
        && {_opportunity isNotEqualTo [] || {serverTime-_observedAt <= 3}}
        && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
        && {[_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {!([_asset] call CBE_fnc_CompatibilityExternalControl)}
        && {!([_gunner] call CBE_fnc_CompatibilityExternalControl)}
        && {call _roleCurrent}
};
if (_pending isNotEqualTo []) exitWith {
    if (!(_pending isEqualType []) || {count _pending != 13}) exitWith {
        if (local _asset) then {_asset setVariable ["CBE_GroundReloadPending",nil,true]};"REFUSED"
    };
    _pending params ["_oldGroup","_oldEpoch","_oldGunner","_oldTarget","_turret","_weapon","_muzzle","_magazine","_started","_until","_oldRoute","_beforeMagazine","_oldOpportunity"];
    if (_oldGroup != _group || {_oldEpoch != _epoch} || {_oldGunner != _gunner}
        || {_oldTarget != _target} || {_oldRoute isNotEqualTo _route}
        || {_oldOpportunity isNotEqualTo _opportunity}
        || {serverTime >= _until} || {!(call _available)} || {!(_asset turretLocal _turret)}) exitWith {
        if (local _asset) then {_asset setVariable ["CBE_GroundReloadPending",nil,true]};
        "REFUSED"
    };
    private _native=weaponState [_asset,_turret,_weapon,_muzzle];
    private _reloadPhase=_native param [6,1,[0]];
    if (count _native >= 7 && {(_native select 0) == _weapon} && {(_native select 1) == _muzzle}
        && {(_native select 3) == _magazine} && {(_native select 4) isEqualType 0}
        && {finite (_native select 4)} && {(_native select 4) > 0}
        && {finite _reloadPhase} && {_reloadPhase == 0}) exitWith {
        _asset setVariable ["CBE_GroundReloadPending",nil,true];"READY"
    };
    // A different native magazine is a newer choice, not permission to insist on ours.
    if (count _native >= 4 && {!((_native select 3) in ["",_beforeMagazine,_magazine])}) exitWith {
        _asset setVariable ["CBE_GroundReloadPending",nil,true];"REFUSED"
    };
    "PENDING"
};
if (serverTime < (_asset getVariable ["CBE_GroundReloadAfter",-1])
    || {time <= (_gunner getVariable ["CBE_AIPass_TargetHold",-1])} || {!(call _available)}) exitWith {"REFUSED"};
private _targetPlatform=vehicle _target;
private _flag=if (_targetPlatform isKindOf "Man") then {64} else {
    if (_targetPlatform isKindOf "LandVehicle") then {
        [128,512] select (_targetPlatform isKindOf "Tank" || {getNumber (configOf _targetPlatform >> "type") == 1})
    } else {0}
};
if (_flag == 0) exitWith {"REFUSED"};
private _crew=fullCrew [_asset,"",false];
if (count _crew > 64) exitWith {"REFUSED"};
private _seat=_crew findIf {(_x select 0) == _gunner};
if (_seat < 0) exitWith {"REFUSED"};
private _turret=(_crew select _seat) select 3;
if (!(_asset turretLocal _turret)) exitWith {"REFUSED"};
// Spend discovery cadence even when the actual inventory has no better round.
_asset setVariable ["CBE_GroundReloadAfter",serverTime+15,true];
private _loaded=createHashMap;
[_asset,_gunner,_target,_loaded] call CBE_fnc_CortexGroundFireReady;
if ((_loaded getOrDefault ["loadedPreference",-1]) >= 2 || {_loaded getOrDefault ["reloadInProgress",false]}) exitWith {"REFUSED"};
private _inventory=magazinesAllTurrets [_asset,true];
if (count _inventory > 128) exitWith {"REFUSED"};
private _magazines=[];
{if ((_x select 1) isEqualTo _turret && {(_x select 2) > 0}) then {_magazines pushBackUnique (_x select 0)}} forEach _inventory;
private _desired=if (_flag == 512) then {["AP","TANDEMHEAT","HEAT"]} else {["HE","HEAT"]};
private _proposal=[];private _bestRank=-1;private _queries=0;
{
    private _weapon=_x;
    private _config=configFile >> "CfgWeapons" >> _weapon;
    private _muzzles=getArray (_config >> "muzzles");
    if (_muzzles isEqualTo []) then {_muzzles=["this"]};
    if (count _muzzles <= 8) then {
        private _muzzleRows=[];private _configurationValid=true;
        {
            private _compatible=compatibleMagazines [_weapon,_x];
            if (count _compatible > 128) exitWith {_configurationValid=false};
            _muzzleRows pushBack [[_x,_weapon] select (_x == "this"),_compatible];
        } forEach _muzzles;
        if (_configurationValid) then {
            {
                if (_queries >= 32) exitWith {};
                _x params ["_muzzle","_compatible"];
                _queries=_queries+1;
                private _state=weaponState [_asset,_turret,_weapon,_muzzle];
                if (count _state >= 5 && {(_state select 0) == _weapon} && {(_state select 1) == _muzzle}
                    && {(_state param [6,0]) <= 0}) then {
                    {
                        private _magazine=_x;
                        private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
                        private _warhead=toUpperANSI getText (_ammo >> "warheadName");
                        private _flags=getNumber (_ammo >> "aiAmmoUsageFlags");
                        private _suitable=_flags <= 0 || {(floor (_flags/_flag) mod 2) == 1};
                        if (_flag == 64 && {isNumber (_ammo >> "allowAgainstInfantry")} && {getNumber (_ammo >> "allowAgainstInfantry") == 0}) then {_suitable=false};
                        if (_magazine != (_state select 3) && {_warhead in _desired}
                            && {_suitable} && {getNumber (_ammo >> "airLock") <= 0} && {getNumber (_ammo >> "laserLock") <= 0}
                            && {getNumber (_ammo >> "hit") > 0 || {getNumber (_ammo >> "indirectHit") > 0}}
                            && {!isClass (_ammo >> "Components" >> "SensorsManagerComponent" >> "Components" >> "LaserSensorComponent")}) then {
                            private _rank=(count _desired)-(_desired find _warhead);
                            // loadMagazine names a weapon, not a muzzle. Accept only when no
                            // different muzzle of that weapon can consume this magazine class.
                            if (_rank > _bestRank && {_muzzleRows findIf {
                                (_x select 0) != _muzzle && {_magazine in (_x select 1)}
                            } < 0}) then {
                                _bestRank=_rank;_proposal=[_weapon,_muzzle,_magazine,+_state];
                            };
                        };
                    } forEach (_magazines arrayIntersect _compatible);
                };
                if (_bestRank == count _desired) exitWith {};
            } forEach _muzzleRows;
        };
    };
    if (_bestRank == count _desired || {_queries >= 32}) exitWith {};
} forEach ((_asset weaponsTurret _turret) select [0,16]);
if (_proposal isEqualTo []) exitWith {"REFUSED"};
_proposal params ["_weapon","_muzzle","_magazine","_before"];
private _result="REFUSED";
isNil {
    if (call _available && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_route isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        && {_asset turretLocal _turret} && {(_asset turretUnit _turret) == _gunner}
        && {(weaponState [_asset,_turret,_weapon,_muzzle]) isEqualTo _before}) then {
        private _weaponConfig=configFile >> "CfgWeapons" >> _weapon;
        private _reloadSeconds=(getNumber (_weaponConfig >> "magazineReloadTime")) max
            (getNumber (_weaponConfig >> _muzzle >> "magazineReloadTime"));
        private _seconds=(_reloadSeconds+3) max 5 min 60;
        private _until=serverTime+_seconds;
        if (_opportunity isNotEqualTo []) then {_until=_until min (_opportunity select 5)};
        _asset setVariable ["CBE_GroundReloadPending",[_group,_epoch,_gunner,_target,+_turret,_weapon,_muzzle,_magazine,
            serverTime,_until,+_route,_before select 3,+_opportunity],true];
        _asset loadMagazine [_turret,_weapon,_magazine];
        _result="REQUESTED";
    };
};
_result
