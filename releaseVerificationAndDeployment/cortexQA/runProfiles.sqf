/*
 * Author: WaldoTheWarfighter
 * Verifies behaviour-profile precedence and exact aggression boundaries independently of skill.
 * Locality/authority: scheduled server fixture, exercising the real profile resolver.
 * Repeat/JIP: saves/restores every temporary setting; deletes its one pinned fixture group.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required audit callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAProfiles.sqf";
 */
params ["_check","_phase","_wait"];
private _keys=["CBE_AIPass_ProfileBehaviour","CBE_AIPass_FactionProfiles","CBE_AIPass_BehaviourProfile","CBE_AIPass_Aggression","CBE_AIRebalance_Enable","CBE_AIRebalance_Profile"];
private _saved=_keys apply {missionNamespace getVariable [_x,nil]};
private _group=createGroup [east,true];
_group setVariable ["CBE_Headless_ExcludeGroup",true,true];
_group setVariable ["acex_headless_blacklist",true,true];
_group setVariable ["CBE_AIPass_Exclude",true,true];
private _unit=_group createUnit ["O_Soldier_F",[1800,1700,0],[],0,"NONE"];
_unit setVariable ["acex_headless_blacklist",true,true];
_unit setVariable ["CBE_CortexQA_Label","PROFILE CONFIGURATION CHECK (NOT MOVEMENT)",true];
missionNamespace setVariable ["CBE_CortexQA_Actors",[_unit],true];
["Profiles: resolution and boundaries","This stage checks configuration only: group overrides faction, faction overrides mission, and blank mission follows AI Rebalance. Aggression zero must resolve every chance to zero; maximum is capped. It does not establish flank or assault movement.",getPosATL _unit] call _phase;
private _skillKeys=["aimingAccuracy","aimingShake","aimingSpeed","spotDistance","spotTime","courage","reloadSpeed","commanding","general"];
private _skills=_skillKeys apply {_unit skill _x};
private _table=createHashMapFromArray [
    ["LINE",createHashMapFromArray [["flankChance",0.4],["retreatScale",1.25]]],
    ["MILITIA",createHashMapFromArray [["flankChance",0.2]]],
    ["VETERAN",createHashMapFromArray [["flankChance",0.6]]],
    ["ELITE",createHashMapFromArray [["flankChance",0.8]]],
    ["LEGACY",createHashMapFromArray [["flankChance",0.3]]]
];
missionNamespace setVariable ["CBE_AIPass_ProfileBehaviour",_table];
missionNamespace setVariable ["CBE_AIPass_FactionProfiles",createHashMap];
missionNamespace setVariable ["CBE_AIPass_BehaviourProfile",""];
missionNamespace setVariable ["CBE_AIPass_Aggression",1];
missionNamespace setVariable ["CBE_AIRebalance_Enable",true];
missionNamespace setVariable ["CBE_AIRebalance_Profile","PUBLIC"];
["PROFILE-rebalance-alias",([_group,"flankChance"] call CBE_fnc_CortexProfile) == 0.2] call _check;
missionNamespace setVariable ["CBE_AIPass_BehaviourProfile","VETERAN"];
["PROFILE-mission-over-rebalance",([_group,"flankChance"] call CBE_fnc_CortexProfile) == 0.6] call _check;
missionNamespace setVariable ["CBE_AIPass_FactionProfiles",createHashMapFromArray [[faction _unit,"ELITE"]]];
["PROFILE-faction-over-mission",([_group,"flankChance"] call CBE_fnc_CortexProfile) == 0.8] call _check;
_group setVariable ["CBE_AIPass_Profile","LEGACY"];
["PROFILE-group-over-faction",([_group,"flankChance"] call CBE_fnc_CortexProfile) == 0.3] call _check;
["PROFILE-missing-key-line-fallback",([_group,"retreatScale"] call CBE_fnc_CortexProfile) == 1.25] call _check;
_group setVariable ["CBE_AIPass_Profile","QA_UNKNOWN"];
["PROFILE-unknown-line-fallback",([_group,"flankChance"] call CBE_fnc_CortexProfile) == 0.4] call _check;
_group setVariable ["CBE_AIPass_Profile","ELITE"];
private _chances=["flankChance","assaultChance","advanceChance","investigateChance","coordinatedChance"];
missionNamespace setVariable ["CBE_AIPass_Aggression",0];
private _zero=[_group] call CBE_fnc_CortexProfile;
["PROFILE-zero-all-chances",_chances findIf {(_zero get _x) != 0 || {([_group,_x] call CBE_fnc_CortexProfile) != 0}} < 0] call _check;
missionNamespace setVariable ["CBE_AIPass_Aggression",2];
["PROFILE-maximum-capped",([_group,"flankChance"] call CBE_fnc_CortexProfile) == 1] call _check;
["PROFILE-aggression-preserves-nonchance",([_group,"retreatScale"] call CBE_fnc_CortexProfile) == 1.25] call _check;
["PROFILE-resolver-preserves-skills",(_skillKeys apply {_unit skill _x}) isEqualTo _skills] call _check;
// These are measured skill-layer checks, not proof of target detection or accuracy in combat.
private _lightingKeys = ["CBE_AIRebalance_Mode","CBE_AI_RebalanceActive","CBE_AI_SkillVariance"];
private _lightingSaved = _lightingKeys apply {missionNamespace getVariable [_x,nil]};
private _date = date;
missionNamespace setVariable ["CBE_AI_RebalanceActive",true];
missionNamespace setVariable ["CBE_AIRebalance_Profile","LINE"];
missionNamespace setVariable ["CBE_AI_SkillVariance",0];
_unit unlinkItem hmd _unit;
missionNamespace setVariable ["CBE_AIRebalance_Mode","DAY"];
[_unit] call CBE_fnc_AIApplyProfile;
private _daySpot = _unit skill "spotDistance";
private _nightDate = +_date;
_nightDate set [3,0]; _nightDate set [4,0]; setDate _nightDate;
sleep 2;
["Lighting: automatic darkness and NVGs","Skill-layer check only: ambient darkness must reduce unaided spotting; equipped NVGs must partly recover it; daylight must restore the baseline. Flashlight detection and actual shots need a separate opponent comparison.",getPosATL _unit] call _phase;
missionNamespace setVariable ["CBE_AIRebalance_Mode","AUTO"];
[_unit] call CBE_fnc_AIApplyProfile;
private _nightSpot = _unit skill "spotDistance";
["LIGHT-dark-fixture",(getLighting select 1) <= 5,str getLighting] call _check;
["LIGHT-auto-unaided-penalty",_nightSpot < _daySpot,str [_daySpot,_nightSpot]] call _check;
_unit linkItem "NVGoggles_OPFOR";
[_unit] call CBE_fnc_AIApplyProfile;
private _nvgSpot = _unit skill "spotDistance";
["LIGHT-nvg-partial-recovery",_nvgSpot > _nightSpot && {_nvgSpot <= _daySpot},str [_nightSpot,_nvgSpot,_daySpot]] call _check;
[_unit] call CBE_fnc_AIApplyProfile;
["LIGHT-repeat-no-compounding",abs ((_unit skill "spotDistance")-_nvgSpot) < 0.001] call _check;
// Equipment changes must be detected by the normal owner worker, not a direct apply call.
["Lighting: remove and replace NVGs","Watch the displayed spotting skill return to its unaided night value after removing NVGs, then recover when they are re-equipped. These checks measure automatic skill refresh, not actual enemy detection.",getPosATL _unit] call _phase;
_unit unlinkItem hmd _unit;
private _removedRefresh = [{
    _unit setVariable ["CBE_CortexQA_Label",format ["NVGs REMOVED | spotting %1 | expected %2",_unit skill "spotDistance",_nightSpot],true];
    abs ((_unit skill "spotDistance")-_nightSpot) < 0.001
},90] call _wait;
["LIGHT-nvg-removal-owner-refresh",_removedRefresh,str [_unit skill "spotDistance",_nightSpot]] call _check;
_unit linkItem "NVGoggles_OPFOR";
private _equippedRefresh = [{
    _unit setVariable ["CBE_CortexQA_Label",format ["NVGs EQUIPPED | spotting %1 | expected %2",_unit skill "spotDistance",_nvgSpot],true];
    abs ((_unit skill "spotDistance")-_nvgSpot) < 0.001
},90] call _wait;
["LIGHT-nvg-equipped-owner-refresh",_removedRefresh && {_equippedRefresh},str [_unit skill "spotDistance",_nvgSpot]] call _check;
private _dayDate = +_date;
_dayDate set [3,12]; _dayDate set [4,0]; setDate _dayDate;
sleep 2;
private _refreshed = [{abs ((_unit skill "spotDistance")-_daySpot) < 0.001},90] call _wait;
["LIGHT-owner-worker-refresh",_refreshed,"No direct apply call after daylight change; owner worker must restore skills."] call _check;
["LIGHT-day-restores-baseline",abs ((_unit skill "spotDistance")-_daySpot) < 0.001,str getLighting] call _check;
// State-restoration boundary only: these explicit fixture edits represent an external
// controller's new tuning. No projectile accuracy or player takeover is claimed here.
private _restoreReady=false;
private _restoredOwned=false;
private _preservedExternal=false;
private _restoreIdempotent=false;
isNil {
    [_unit] call CBE_fnc_AIRestoreProfile;
    _unit setSkill ["aimingSpeed",0.013];
    _unit setSkill ["courage",0.37];
    _unit setCustomAimCoef 1.11;
    private _applied=[_unit] call CBE_fnc_AIApplyProfile;
    private _receipt=_unit getVariable ["CBE_AI_AppliedSkills",createHashMap];
    _restoreReady=_applied && {"aimingSpeed" in _receipt}
        && {abs ((_receipt get "aimingSpeed")-0.013) > 0.001};
    _unit setSkill ["courage",0.123];
    _unit setCustomAimCoef 0.88;
    private _released=[_unit] call CBE_fnc_AIRestoreProfile;
    _restoredOwned=_released && {abs ((_unit skill "aimingSpeed")-0.013) < 0.0001};
    _preservedExternal=abs ((_unit skill "courage")-0.123) < 0.0001
        && {abs (getCustomAimCoef _unit-0.88) < 0.0001};
    _restoreIdempotent=!([_unit] call CBE_fnc_AIRestoreProfile)
        && {isNil {_unit getVariable "CBE_AI_AppliedSkills"}}
        && {isNil {_unit getVariable "CBE_AI_OriginalSkills"}};
};
["PROFILE-restore-receipt-prerequisite",_restoreReady] call _check;
["PROFILE-restore-owned-value",_restoreReady && {_restoredOwned}] call _check;
["PROFILE-restore-preserves-external-values",_restoreReady && {_preservedExternal}] call _check;
["PROFILE-restore-idempotent",_restoreReady && {_restoreIdempotent}] call _check;
setDate _date;
{missionNamespace setVariable [_x,_lightingSaved select _forEachIndex]} forEach _lightingKeys;
{missionNamespace setVariable [_x,_saved select _forEachIndex]} forEach _keys;
sleep 5;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
deleteVehicle _unit; deleteGroup _group;
