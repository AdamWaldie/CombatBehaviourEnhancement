/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe real single-carrier static assembly, boarding and one-bag recovery.
 * Locality/authority: Dedicated server, normal batch only. Native acquisition creates contact;
 * the group brain executes equipment handling without direct fixture calls to its executor.
 * Repeat/JIP: Fresh fixture once; runtime tuning restores through runServer. No phase/receipt
 * injection, forced seating, completion calls or production deadline resets. This does not test
 * firing, repeated episodes, HC migration or every optional weapon class.
 * Arguments: 0 check CODE; 1 phase CODE; 2 bounded wait CODE, supplied by runServer.
 * Return: Nothing. Missing installed one-part configuration fails its prerequisite.
 * Current callers: runServer staticsolo focus. Example:
 * [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAStaticSolo.sqf";
 */
params ["_check","_phase","_wait"];
if (missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false]) exitWith {
    ["SOLO-normal-owner-required",false] call _check;
};
// Fixture discovery only: do not hard-code a DLC classname or fabricate an assembly config.
private _bags=("getNumber (_x >> 'isBackpack') == 1" configClasses (configFile >> "CfgVehicles")) select {
    private _info=_x >> "assembleInfo";
    getNumber (_info >> "primary") == 1 && {isText (_info >> "base")}
        && {getText (_info >> "base") == ""}
        && {(getText (_info >> "assembleTo")) isKindOf "StaticWeapon"}
};
["SOLO-installed-one-part-config",_bags isNotEqualTo [],"Requires a loaded native one-part static backpack"] call _check;
if (_bags isEqualTo []) exitWith {};
private _bagClass=configName (_bags select 0);
private _weaponClass=getText ((_bags select 0) >> "assembleInfo" >> "assembleTo");
[createHashMapFromArray [["CBE_AIPass_Enable",true],["CBE_AIPass_Contact_Enable",true],
    ["CBE_AIPass_StaticSupport_Enable",true],["CBE_AIPass_StaticDeploy_Enable",false],
    ["CBE_AIPass_FireControl_Enable",false],["CBE_AIPass_Advance_Enable",false],
    ["CBE_AIPass_Flank_Enable",false],["CBE_AIPass_Assault_Enable",false],
    ["CBE_AIPass_Danger_Enable",false]]] call CBE_fnc_CortexTuning;
private _group=createGroup [west,true];private _enemyGroup=createGroup [east,true];
{_x setVariable ["CBE_Headless_ExcludeGroup",true,true];_x setVariable ["acex_headless_blacklist",true,true]} forEach [_group,_enemyGroup];
private _origin=[3400,3500,0];
private _leader=_group createUnit ["B_Soldier_F",_origin,[],0,"NONE"];
private _actor=_group createUnit ["B_Soldier_F",_origin vectorAdd [4,-4,0],[],0,"NONE"];
private _enemy=_enemyGroup createUnit ["O_Soldier_F",_origin vectorAdd [0,35,0],[],0,"NONE"];
{_x allowDamage false;_x setSkill 1;_x setDir 0;_x setVariable ["acex_headless_blacklist",true,true]} forEach [_leader,_actor,_enemy];
removeAllWeapons _enemy;_enemy disableAI "MOVE";
_enemyGroup setCombatMode "BLUE";_enemyGroup setBehaviourStrong "CARELESS";
_group setCombatMode "YELLOW";_group setBehaviourStrong "AWARE";_group enableAttack false;
removeBackpack _leader;_leader addBackpack "B_HMG_01_weapon_F";
removeBackpack _actor;_actor addBackpack _bagClass;
private _leaderBag=backpack _leader;
_actor setVariable ["CBE_CortexQA_Label","ONE-PART CARRIER",true];
_leader setVariable ["CBE_CortexQA_Label","UNMATCHED PRIMARY",true];
_actor setVariable ["CBE_CortexQA_SoloAssembly",[]];
_actor setVariable ["CBE_CortexQA_SoloPacking",[]];
private _assemblyEH=_actor addEventHandler ["WeaponAssembled",{
    params ["_unit","_weapon"];
    private _record=(group _unit) getVariable ["CBE_Danger_StaticDeployment",[]];
    private _holder=_record param [29,objNull,[objNull]];
    _unit setVariable ["CBE_CortexQA_SoloAssembly",[_weapon,typeOf _weapon,serverTime,
        _holder,!isNull _holder && {typeOf _holder == "GroundWeaponHolder_Scripted"}]];
}];
private _packingEH=_actor addEventHandler ["WeaponDisassembled",{
    params ["_unit","_primary",["_base",objNull,[objNull]]];
    _unit setVariable ["CBE_CortexQA_SoloPacking",[_primary,typeOf _primary,_base,serverTime]];
}];
missionNamespace setVariable ["CBE_CortexQA_Actors",[_leader,_actor,_enemy],true];
["One-part static: native deployment","The unmatched primary must not hide the complete one-part carrier. Watch actual native assembly and boarding. This is a normal-owner mechanics case, not a firing or HC acceptance case.",_origin] call _phase;
private _contact=[{_leader knowsAbout _enemy >= 1
    && {((_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["phase",""]) == "CONTACT"}},45] call _wait;
["SOLO-native-contact",_contact] call _check;
[createHashMapFromArray [["CBE_AIPass_StaticDeploy_Enable",true]]] call CBE_fnc_CortexTuning;
private _admitted=[{count (_group getVariable ["CBE_Danger_StaticDeployment",[]]) >= 30},60] call _wait;
private _record=_group getVariable ["CBE_Danger_StaticDeployment",[]];
["SOLO-complete-carrier-selected",_admitted && {(_record param [2,objNull,[objNull]]) == _actor}
    && {_record param [28,false,[true]]},str [_bagClass,_record]] call _check;
["SOLO-no-second-actor-reserved",(_leader getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []
    && {backpack _leader == _leaderBag}] call _check;
private _mounted=[{private _seen=_actor getVariable ["CBE_CortexQA_SoloAssembly",[]];
    count _seen == 5 && {!isNull (_seen select 0)} && {gunner (_seen select 0) == _actor}},50] call _wait;
private _assembly=_actor getVariable ["CBE_CortexQA_SoloAssembly",[]];
private _weapon=_assembly param [0,objNull,[objNull]];
["SOLO-actual-assembly-and-physical-seat",_mounted && {(_assembly param [1,"",[""]]) == _weaponClass}
    && {backpack _actor == ""},str _assembly] call _check;
["SOLO-empty-target-holder-cleaned",count _assembly == 5 && {_assembly select 4}
    && {isNull (_assembly select 3)}] call _check;
// Remove only the real fixture threat; normal contact-loss/security drives native packing.
deleteVehicle _enemy;
["One-part static: native recovery","After genuine contact loss the carrier must leave, disassemble and pick up the actual returned bag. A result flag or missing task alone cannot pass.",_origin] call _phase;
private _packed=[{private _seen=_actor getVariable ["CBE_CortexQA_SoloPacking",[]];
    count _seen == 4 && {isNull _weapon} && {backpack _actor == _bagClass}},180] call _wait;
private _packing=_actor getVariable ["CBE_CortexQA_SoloPacking",[]];
["SOLO-native-disassembly-one-bag",_packed && {(_packing param [1,"",[""]]) == _bagClass}
    && {isNull (_packing param [2,objNull,[objNull]])},str _packing] call _check;
["SOLO-physical-inventory-restored",_packed && {isNull objectParent _actor}
    && {backpack _leader == _leaderBag} && {isNull _weapon}] call _check;
private _retired=[{(_group getVariable ["CBE_Danger_StaticDeployment",[]]) isEqualTo []
    && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []}
    && {(_actor getVariable ["CBE_Danger_StaticMoveReceipt",[]]) isEqualTo []}},15] call _wait;
["SOLO-operation-retired",_retired] call _check;
// Results above are immutable. Cleanup only the disposable fixture after all observations.
_actor removeEventHandler ["WeaponAssembled",_assemblyEH];
_actor removeEventHandler ["WeaponDisassembled",_packingEH];
private _remaining=_group getVariable ["CBE_Danger_StaticDeployment",[]];
private _remainingHolder=_remaining param [29,objNull,[objNull]];
private _returned=_packing param [0,objNull,[objNull]];
{if (!isNull _x) then {deleteVehicle _x}} forEach ([_leader,_actor,_enemy,_weapon,_remainingHolder,_returned] arrayIntersect [_leader,_actor,_enemy,_weapon,_remainingHolder,_returned]);
{deleteGroup _x} forEach [_group,_enemyGroup];
