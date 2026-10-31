/*
 * Author: WaldoTheWarfighter
 * Purpose: Reconcile native AA firing/warning observers and retain bounded local receipts.
 * Locality/authority: Handler and receipt are machine-local; only the current vehicle and AI
 * gunner owner records. No target discovery, movement, radar or crew policy is changed.
 * Optional default-off interception hands native warnings to a separate finite aim/shot executor.
 * Only shots with a recent personally known assigned hostile air contact create relocation
 * receipts; other qualified fire updates the quiet-time clock without erasing that episode.
 * IncomingMissile authenticates exact native projectile parents and retains launch affiliation
 * for the original15s even after launcher crew loss. Only fresh personal contact may
 * use it for gunnery priority. No target position or fire permission is added.
 * Repeat/JIP: One versioned local handler pair per eligible native AA vehicle. Discovery removes it
 * after locality/feature loss; shutdown removes tracked handlers. Existing discovery also
 * observes ended camera retirement without replaying interception or renewing its deadline. New owners start without a
 * previous owner's receipt. Live AA role is checked at setup and both native callbacks;
 * role withdrawal supplies no new warning/shot receipt while normal cleanup retains its owner.
 * At most one full shot observation per second; warning receipts
 * coalesce per native event. Optional interception passes real shots before the relocation throttle
 * and may start one finite coalesced scheduler episode. No new world scan.
 * Arguments: 0 vehicle OBJECT,objNull; 1 release BOOL,false, remove this machine's observer.
 * Return: BOOL,true while an eligible observer is installed; never relocation or hit proof.
 * Current callers: CortexDiscover's existing sixteen-vehicle slice and CortexStop.
 * Example: [_vehicle] call CBE_fnc_CortexAAObserve;
 */
params [["_vehicle",objNull,[objNull]],["_release",false,[true]]];
if (isNull _vehicle) exitWith {false};
private _record=_vehicle getVariable ["CBE_AA_Observer",[]];
// Reuse the existing sixteen-vehicle discovery slice. An ended interception can keep
// its exact native camera receipt after observer removal or a feature shutdown.
private _retiring=_vehicle getVariable ["CBE_AA_Intercept",createHashMap];
if (_retiring isEqualType createHashMap && {_retiring getOrDefault ["finished",false]}) then {
    [_vehicle,"RELEASE"] call CBE_fnc_CortexAAIntercept;
};
private _eligible=!_release && {local _vehicle} && {alive _vehicle}
    && {_vehicle isKindOf "LandVehicle"}
    && {[_vehicle] call CBE_fnc_CortexAirDefenceRole}
    && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle};
private _gunner=gunner _vehicle;
private _group=group _gunner;
if (_eligible) then {
    _eligible=!isNull _gunner && {local _gunner} && {!isPlayer _gunner}
        && {[_group] call CBE_fnc_CortexIsEligible}
        && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled};
};
private _current=count _record == 4 && {(_record select 0) == 3}
    && {(_record select 1) == clientOwner};
if (_eligible && {_current}) exitWith {true};
// Most vehicles never participate. Do not rewrite nils or the tracked registry for that slice.
if (!_eligible && {_record isEqualTo []}
    && {isNil {_vehicle getVariable "CBE_AA_LastShot"}}
    && {isNil {_vehicle getVariable "CBE_AA_LastFireAt"}}
    && {isNil {_vehicle getVariable "CBE_AA_ObserveDue"}}
    && {isNil {_vehicle getVariable "CBE_AA_MissileWarning"}}) exitWith {false};
[_vehicle,"RELEASE"] call CBE_fnc_CortexAAIntercept;
if (count _record in [3,4]) then {_vehicle removeEventHandler ["Fired",_record select 2]};
if (count _record == 4) then {_vehicle removeEventHandler ["IncomingMissile",_record select 3]};
_vehicle setVariable ["CBE_AA_Observer",nil];
_vehicle setVariable ["CBE_AA_LastShot",nil];
_vehicle setVariable ["CBE_AA_LastFireAt",nil];
_vehicle setVariable ["CBE_AA_ObserveDue",nil];
_vehicle setVariable ["CBE_AA_MissileWarning",nil];
_vehicle setVariable ["CBE_AA_Corrections",nil];
private _tracked=missionNamespace getVariable ["CBE_AA_ObservedVehicles",[]];
_tracked=_tracked-[_vehicle,objNull];
missionNamespace setVariable ["CBE_AA_ObservedVehicles",_tracked];
if (!_eligible) exitWith {false};
private _handler=_vehicle addEventHandler ["Fired",{
    params ["_vehicle","_weapon","_muzzle","","_ammo","_magazine","_projectile","_gunner"];
    if (!isNil {_vehicle getVariable "CBE_AA_Intercept"}) then {[_vehicle,"SHOT",_this] call CBE_fnc_CortexAAIntercept};
    if (!local _vehicle || {isNull _projectile} || {isNull _gunner}
        || {!([_vehicle] call CBE_fnc_CortexAirDefenceRole)}
        || {serverTime < (_vehicle getVariable ["CBE_AA_ObserveDue",-1])}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}) exitWith {};
    _vehicle setVariable ["CBE_AA_ObserveDue",serverTime+1];
    private _group=group _gunner;
    private _simulation=toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation");
    if (!(_simulation in ["shotbullet","shotshell","shotmissile","shotrocket"])
        || {!local _gunner} || {vehicle _gunner != _vehicle} || {isPlayer _gunner}
        || {!isNull remoteControlled _gunner}
        || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {!([_gunner] call CBE_fnc_CortexCombatEffective)}
        || {!([_gunner] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {!([_group] call CBE_fnc_CortexIsEligible)}
        || {!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {};
    _vehicle setVariable ["CBE_AA_LastFireAt",serverTime];
    private _contact=[];
    private _target=assignedTarget _gunner;
    if (!isNull _target && {_target isKindOf "Air"} && {alive _target}
        && {(side _group) getFriend (side _target) < 0.6} && {_gunner knowsAbout _target >= 1}) then {
        private _knowledge=_gunner targetKnowledge _target;
        private _age=time-(_knowledge select 2);
        if ((_knowledge select 1) && {!(_knowledge param [7,false])} && {_age >= 0} && {_age <= 5}) then {
            _contact=[_target,_gunner getHideFrom _target,serverTime-_age];
        };
    };
    if (_contact isEqualTo []) exitWith {};
    _vehicle setVariable ["CBE_AA_LastShot",[clientOwner,_group,
        _group getVariable ["CBE_AIPass_Epoch",0],serverTime,_weapon,_muzzle,_ammo,_magazine,getPosATL _vehicle,
        [_group] call CBE_fnc_NativeOrderReceipt,_contact]];
}];
private _warningHandler=_vehicle addEventHandler ["IncomingMissile",{
    params ["_vehicle","",["_shooter",objNull,[objNull]],"",["_missile",objNull,[objNull]]];
    private _observer=_vehicle getVariable ["CBE_AA_Observer",[]];
    if (!local _vehicle || {!alive _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {!([_vehicle] call CBE_fnc_CortexAirDefenceRole)}
        || {count _observer != 4} || {(_observer select 0) != 3}
        || {(_observer select 1) != clientOwner} || {(_observer select 3) != _thisEventHandler}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}) exitWith {};
    private _gunner=gunner _vehicle;private _group=group _gunner;
    if (isNull _gunner || {!local _gunner} || {isPlayer _gunner} || {!isNull remoteControlled _gunner}
        || {!local _group} || {!([_group] call CBE_fnc_CortexIsEligible)}
        || {!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {};
    private _source=if (isNull _shooter) then {objNull} else {vehicle _shooter};
    if (!([_missile,_group,_source,"RECORD"] call CBE_fnc_CortexAAThreat)) exitWith {};
    _vehicle setVariable ["CBE_AA_MissileWarning",[clientOwner,_group,
        _group getVariable ["CBE_AIPass_Epoch",0],serverTime+15,_missile,_source]];
    ["NOTICE",_vehicle] call CBE_fnc_CortexAAAllocate;
}];
_vehicle setVariable ["CBE_AA_Observer",[3,clientOwner,_handler,_warningHandler]];
_tracked pushBackUnique _vehicle;
missionNamespace setVariable ["CBE_AA_ObservedVehicles",_tracked];
true
