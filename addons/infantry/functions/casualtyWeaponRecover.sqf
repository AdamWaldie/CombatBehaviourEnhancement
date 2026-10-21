/*
 * Author: WaldoTheWarfighter
 * Purpose: Recover one loaded rifle or launcher into an empty slot at a verified casualty visit.
 * Locality/authority: Current point-investigation actor owner only. Exact live brain, casualty,
 * route, epoch and movement lease are required. Native TakeWeapon is distance-independent, so
 * current2m proximity and LOS are rechecked here. No occupied weapon slot is replaced.
 * Repeat/JIP: One immediate attempt/point generation, no worker/deadline extension or replay.
 * One native action, <=8 equipped-weapon rows/snapshot. A command alone never verifies transfer.
 * Arguments: 0 actor OBJECT,objNull; 1 observed body OBJECT,objNull; 2 point brain HASHMAP,empty.
 * Return: BOOL,true only for exact weapon-row conservation/source loss/receiver gain with all
 * pre-existing equipped rows and clothing/backpack classes unchanged. Native effects may occur
 * even when verification refuses; they are never rolled back over newer inventory ownership.
 * Current caller: PointActorOperation after actual point arrival and existing ammo recovery.
 * Example: private _verified=[_actor,_body,_brain] call CBE_fnc_CasualtyWeaponRecover;
 */
params [["_actor",objNull,[objNull]],["_body",objNull,[objNull]],["_brain",createHashMap,[createHashMap]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _actor} || {isNull _body}
    || {!local _actor} || {alive _body} || {isObjectHidden _body}
    || {(_actor getVariable ["CBE_PointActor_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {false};
private _group=group _actor;private _generation=_brain getOrDefault ["generation",-1];
if (!local _group || {(_brain getOrDefault ["actor",objNull]) != _actor}
    || {(_brain getOrDefault ["body",objNull]) != _body} || {!(_brain getOrDefault ["visitReached",false])}
    || {_brain getOrDefault ["weaponRecoveryAttempted",false]}
    || {serverTime >= (_brain getOrDefault ["deadline",-1])}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {(_brain getOrDefault ["operationGeneration",-1]) != (_group getVariable ["CBE_OperationGeneration",0])}
    || {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo (_brain getOrDefault ["lease",[]])}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_brain getOrDefault ["route",[]])}
    || {!([_group,"CBE_AIPass_CasualtyEquipment_Enable",false] call CBE_fnc_CortexFeatureEnabled)}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible)}
    || {!([_actor] call CBE_fnc_CortexCombatEffective)} || {!simulationEnabled _actor} || {isObjectHidden _actor}
    || {isPlayer _actor} || {!isNull remoteControlled _actor} || {!isNull objectParent _actor}
    || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {!(currentCommand _actor in ["","MOVE"])} || {getUnitState _actor in ["BUSY","PLANNING","REPLAN"]}
    || {!isNull getAttackTarget _actor} || {!isNull assignedTarget _actor}
    || {(getPosASL _actor) distance (getPosASL _body) > 2}
    || {lineIntersects [eyePos _actor,(getPosASL _body) vectorAdd [0,0,0.5],_actor,_body]}
    || {([_actor,_brain get "target",_body] call CBE_fnc_CasualtyObservationSelect) != _body}) exitWith {false};
_brain set ["weaponRecoveryAttempted",true];
private _sourceBefore=weaponsItems _body;private _receiverBefore=weaponsItems _actor;
if (count _sourceBefore > 8 || {count _receiverBefore > 8}) exitWith {false};
private _primary=primaryWeapon _actor;private _secondary=secondaryWeapon _actor;
private _handgun=handgunWeapon _actor;private _clothing=[uniform _actor,vest _actor,backpack _actor];
private _candidate=[];private _slot="";
{
    private _row=_x;private _weapon=_row param [0,"",[""]];
    private _type=getNumber (configFile >> "CfgWeapons" >> _weapon >> "type");
    private _empty=(_type == 1 && {_primary == ""} && {primaryWeapon _body == _weapon})
        || {_type == 4 && {_secondary == ""} && {secondaryWeapon _body == _weapon}};
    if (_empty && {count _row == 7}) then {
        private _magazine=_row select 4;
        private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
        private _main=if ("this" in _muzzles) then {"this"} else {_muzzles param [0,"this"]};
        if (count _magazine == 2 && {(_magazine select 1) isEqualType 0}
            && {finite (_magazine select 1)} && {(_magazine select 1) > 0}
            && {(_magazine select 0) in compatibleMagazines [_weapon,_main]}) then {
            if (_candidate isEqualTo [] || {_type == 1 && {_slot != "PRIMARY"}}) then {
                _candidate=+_row;_slot=["SECONDARY","PRIMARY"] select (_type == 1);
            };
        };
    };
} forEach _sourceBefore;
if (_candidate isEqualTo []) exitWith {false};
private _weapon=_candidate select 0;
private _sourceCount={_x isEqualTo _candidate} count _sourceBefore;
if (_sourceCount != 1 || {_receiverBefore findIf {_x isEqualTo _candidate} >= 0}
    || {primaryWeapon _actor != _primary} || {secondaryWeapon _actor != _secondary}
    || {handgunWeapon _actor != _handgun}) exitWith {false};
_actor setVariable ["CBE_PointActor_Equipment",[_generation,"UNVERIFIED",_body,_slot,_weapon,serverTime],true];
_actor action ["TakeWeapon",_body,_weapon];
private _receiverAfter=weaponsItems _actor;
private _sourceAfter=if (!isNull _body) then {weaponsItems _body} else {[]};
private _sourceOthers=_sourceBefore select {!(_x isEqualTo _candidate)};
private _verified=!isNull _body && {!alive _body} && {count _receiverAfter <= 8} && {count _sourceAfter <= 8}
    && {count _receiverAfter == count _receiverBefore+1} && {count _sourceAfter == count _sourceBefore-1}
    && {{_x isEqualTo _candidate} count _receiverAfter == 1}
    && {_sourceAfter findIf {_x isEqualTo _candidate} < 0}
    && {_receiverBefore findIf {private _row=_x;_receiverAfter findIf {_x isEqualTo _row} < 0} < 0}
    && {_sourceOthers findIf {private _row=_x;_sourceAfter findIf {_x isEqualTo _row} < 0} < 0}
    && {[uniform _actor,vest _actor,backpack _actor] isEqualTo _clothing}
    && {handgunWeapon _actor == _handgun}
    && {if (_slot == "PRIMARY") then {primaryWeapon _actor == _weapon && {secondaryWeapon _actor == _secondary}}
        else {secondaryWeapon _actor == _weapon && {primaryWeapon _actor == _primary}}};
_actor setVariable ["CBE_PointActor_Equipment",[_generation,["UNVERIFIED","VERIFIED"] select _verified,
    _body,_slot,_weapon,serverTime],true];
_verified
