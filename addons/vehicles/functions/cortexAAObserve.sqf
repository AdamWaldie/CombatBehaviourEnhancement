/*
 * Author: WaldoTheWarfighter
 * Purpose: Reconcile a native AA firing observer and retain one coalesced real-shot receipt.
 * Locality/authority: Handler and receipt are machine-local; only the current vehicle and AI
 * gunner owner records. No target discovery, movement, firing, radar or crew policy is changed.
 * Only shots with a recent personally known assigned hostile air contact create relocation
 * receipts; other qualified fire updates the quiet-time clock without erasing that episode.
 * Repeat/JIP: One versioned local handler per eligible native AA vehicle. Discovery removes it
 * after locality/feature loss; shutdown removes tracked handlers. New owners start without a
 * previous owner's receipt. At most one full observation per second, no timer or new world scan.
 * Arguments: 0 vehicle OBJECT,objNull; 1 release BOOL,false, remove this machine's observer.
 * Return: BOOL,true while an eligible observer is installed; never relocation or hit proof.
 * Current callers: CortexDiscover's existing sixteen-vehicle slice and CortexStop.
 * Example: [_vehicle] call CBE_fnc_CortexAAObserve;
 */
params [["_vehicle",objNull,[objNull]],["_release",false,[true]]];
if (isNull _vehicle) exitWith {false};
private _record=_vehicle getVariable ["CBE_AA_Observer",[]];
private _eligible=!_release && {local _vehicle} && {alive _vehicle}
    && {_vehicle isKindOf "LandVehicle"}
    && {toLowerANSI getText (configOf _vehicle >> "editorSubcategory") == "edsubcat_aas"}
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
private _current=count _record == 3 && {(_record select 0) == 1}
    && {(_record select 1) == clientOwner};
if (_eligible && {_current}) exitWith {true};
// Most vehicles never participate. Do not rewrite nils or the tracked registry for that slice.
if (!_eligible && {_record isEqualTo []}
    && {isNil {_vehicle getVariable "CBE_AA_LastShot"}}
    && {isNil {_vehicle getVariable "CBE_AA_LastFireAt"}}
    && {isNil {_vehicle getVariable "CBE_AA_ObserveDue"}}) exitWith {false};
if (count _record == 3) then {_vehicle removeEventHandler ["Fired",_record select 2]};
_vehicle setVariable ["CBE_AA_Observer",nil];
_vehicle setVariable ["CBE_AA_LastShot",nil];
_vehicle setVariable ["CBE_AA_LastFireAt",nil];
_vehicle setVariable ["CBE_AA_ObserveDue",nil];
private _tracked=missionNamespace getVariable ["CBE_AA_ObservedVehicles",[]];
_tracked=_tracked-[_vehicle,objNull];
missionNamespace setVariable ["CBE_AA_ObservedVehicles",_tracked];
if (!_eligible) exitWith {false};
private _handler=_vehicle addEventHandler ["Fired",{
    params ["_vehicle","_weapon","_muzzle","","_ammo","_magazine","_projectile","_gunner"];
    if (!local _vehicle || {isNull _projectile} || {isNull _gunner}
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
_vehicle setVariable ["CBE_AA_Observer",[1,clientOwner,_handler]];
_tracked pushBackUnique _vehicle;
missionNamespace setVariable ["CBE_AA_ObservedVehicles",_tracked];
true
