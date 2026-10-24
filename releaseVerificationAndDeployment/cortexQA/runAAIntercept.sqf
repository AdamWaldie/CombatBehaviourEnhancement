/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe real native Cheetah warning delivery, cannon shots and finite release.
 * Locality/authority: Scheduled dedicated server; normal batch only. Fresh native crew,
 * actual hostile AT launcher and ordinary native target/fire commands provide stimulus.
 * The addon discovers the AA platform and owns its observer, aiming and fire lifecycle.
 * Repeat/JIP: Fresh isolated fixtures, local bounded event records, settings restored and
 * all fixture crew/vehicles removed. No JIP command replay or HC ownership transfer.
 * Arguments: 0 check CODE required; 1 phase CODE required; 2 wait CODE required.
 * Return: Nothing. Current caller: runServer.sqf focused aa normal batch.
 * Limits: This verifies warning/fire/release building blocks, not interception success.
 * Missile disappearance, closest pass, a fuse request or surviving hull cannot prove a kill.
 * No synthetic warning, projectile creation/steering, damage immunity or scripted hit.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAAAIntercept.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false]}) exitWith {};
private _keys=["CBE_AIPass_Enable","CBE_AIPass_Contact_Enable","CBE_AIPass_Vehicles_Enable",
    "CBE_AIPass_VehicleGunnery_Enable","CBE_AIPass_AAIntercept_Enable",
    "CBE_AIPass_DrivingAssist_Enable","CBE_AIPass_VehicleWithdraw_Enable"];
private _prior=createHashMapFromArray (_keys apply {[_x,missionNamespace getVariable [_x,false]]});
[createHashMapFromArray [
    ["CBE_AIPass_Enable",true],["CBE_AIPass_Contact_Enable",true],
    ["CBE_AIPass_Vehicles_Enable",true],["CBE_AIPass_VehicleGunnery_Enable",true],
    ["CBE_AIPass_AAIntercept_Enable",true],["CBE_AIPass_DrivingAssist_Enable",false],
    ["CBE_AIPass_VehicleWithdraw_Enable",false]
]] call CBE_fnc_CortexTuning;
private _position=[4500,3000,0];
private _sourcePosition=_position getPos [900,0];
private _aa=createVehicle ["B_APC_Tracked_01_AA_F",_position,[],0,"NONE"];
_aa setDir 0;createVehicleCrew _aa;
private _aaGroup=group gunner _aa;
private _source=createVehicle ["O_static_AT_F",_sourcePosition,[],0,"NONE"];
_source setDir 180;createVehicleCrew _source;
private _sourceGunner=gunner _source;
private _sourceGroup=group _sourceGunner;
{
    _x setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_aaGroup,_sourceGroup];
_sourceGroup setVariable ["CBE_AIPass_Exclude",true,true];
_aaGroup setCombatMode "BLUE";_aaGroup setBehaviour "AWARE";
_sourceGroup setCombatMode "BLUE";_sourceGroup setBehaviour "AWARE";
_aa setVariable ["CBE_QA_AAShots",[]];
_aa setVariable ["CBE_QA_AAWarnings",[]];
_source setVariable ["CBE_QA_AAShots",[]];
private _warningEH=_aa addEventHandler ["IncomingMissile",{
    params ["_vehicle","_ammo",["_shooter",objNull],["_instigator",objNull],["_missile",objNull]];
    private _rows=_vehicle getVariable ["CBE_QA_AAWarnings",[]];
    if (count _rows < 8) then {_rows pushBack [time,_ammo,_shooter,_instigator,_missile,!isNull _missile]};
}];
private _aaEH=_aa addEventHandler ["Fired",{
    params ["_vehicle","_weapon","_muzzle","","_ammo","_magazine","_projectile"];
    private _rows=_vehicle getVariable ["CBE_QA_AAShots",[]];
    private _episode=_vehicle getVariable ["CBE_AA_Intercept",createHashMap];
    if (count _rows < 64) then {
        _rows pushBack [time,_weapon,_muzzle,_ammo,_magazine,!isNull _projectile,_episode getOrDefault ["token",""],time <= (_episode getOrDefault ["shotWindow",-1])];
    };
}];
private _sourceEH=_source addEventHandler ["Fired",{
    params ["_vehicle","_weapon","","","_ammo","","_projectile"];
    private _rows=_vehicle getVariable ["CBE_QA_AAShots",[]];
    if (count _rows < 8) then {_rows pushBack [time,_weapon,_ammo,_projectile,!isNull _projectile]};
}];
["AA: real incoming missile and native cannon",
    "An actual hostile AT launcher fires at the Cheetah. Watch warning delivery, finite cannon aiming and actual shots. Warning, firing and release checks are separate; this scenario does not certify a missile kill. No projectile or warning is injected.",_position] call _phase;
private _observerReady=[{count (_aa getVariable ["CBE_AA_Observer",[]]) == 4},15] call _wait;
["AA-native-observer-ready",_observerReady] call _check;
private _initialDamage=damage _aa;
if (_observerReady && {!isNull _sourceGunner} && {alive _sourceGunner}) then {
    // Deliberate hostile stimulus only. The defender receives no reveal/target/fire command.
    _aaGroup setCombatMode "RED";
    _sourceGroup setCombatMode "RED";
    _sourceGunner reveal [_aa,4];_sourceGunner doTarget _aa;_sourceGunner doFire _aa;
    [{count (_source getVariable ["CBE_QA_AAShots",[]]) > 0},15] call _wait;
    [{count (_aa getVariable ["CBE_QA_AAShots",[]]) > 0 || {!alive _aa}},15] call _wait;
};
private _sourceShots=_source getVariable ["CBE_QA_AAShots",[]];
private _warnings=_aa getVariable ["CBE_QA_AAWarnings",[]];
private _shots=_aa getVariable ["CBE_QA_AAShots",[]];
["AA-native-hostile-projectile",_sourceShots findIf {_x select 4} >= 0,str _sourceShots] call _check;
["AA-native-warning",_warnings findIf {_x select 5} >= 0,str _warnings] call _check;
["AA-native-episode-cannon-shot",_shots findIf {(_x select 1) == "autocannon_35mm" && {_x select 5} && {(_x select 6) != ""} && {_x select 7}} >= 0,str _shots] call _check;
diag_log format ["CBE AA OUTCOME OBSERVATION ONLY: hullDamage %1 -> %2; alive %3; result %4; warnings %5; sourceShots %6; AA shots %7. No interception pass inferred.",
    _initialDamage,damage _aa,alive _aa,_aa getVariable ["CBE_AA_InterceptResult",[]],_warnings,_sourceShots,_shots];
[createHashMapFromArray [["CBE_AIPass_AAIntercept_Enable",false]]] call CBE_fnc_CortexTuning;
private _released=[{isNil {_aa getVariable "CBE_AA_Intercept"}},10] call _wait;
["AA-native-disable-release",_released] call _check;
_aa removeEventHandler ["IncomingMissile",_warningEH];
_aa removeEventHandler ["Fired",_aaEH];_source removeEventHandler ["Fired",_sourceEH];
[_prior] call CBE_fnc_CortexTuning;
{if (!isNull (_x select 3)) then {deleteVehicle (_x select 3)}} forEach _sourceShots;
{deleteVehicle _x} forEach (crew _aa + crew _source);
deleteVehicle _aa;deleteVehicle _source;
deleteGroup _aaGroup;deleteGroup _sourceGroup;
