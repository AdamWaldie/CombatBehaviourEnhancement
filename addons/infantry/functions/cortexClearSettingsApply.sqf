/*
 * Author: WaldoTheWarfighter
 * Purpose: Bind clearance stance/speed acquisition to the shared actor-settings lease.
 * Locality/authority: Actual group/actor owner and current CLEAR operation, visit, route and job.
 * Repeat/JIP: Keeps the original issuer/baselines/deadline. ADOPT updates metadata only, never a
 * native setting or movement. Partial mirrors are retained, not imported as authority.
 * APPLY caps live STEALTH clearance pace at1m/s through the same canonical speed lease;
 * a lower mission-owned cap remains lower. CHECK/ADOPT/PREPARE never replay pacing.
 * Arguments: 0 actor OBJECT objNull; 1 job HASHMAP empty; 2 speed NUMBER4;
 * 3 mode STRING APPLY (CHECK, ADOPT or PREPARE).
 * Return: ActorSettings status STRING; only APPLIED/OWNED/ADOPTED acknowledge settings, not movement.
 * Current callers: BuildingOperationStep, BuildingActorMotion and CortexClearBuilding preparation.
 * Example: [_unit,_job,4] call CBE_fnc_CortexClearSettingsApply;
 */
params [["_actor",objNull,[objNull]],["_job",createHashMap,[createHashMap]],
    ["_speed",4,[0]],["_mode","APPLY",[""]]];
private _result="REFUSED";
isNil {
    private _group=_job getOrDefault ["group",grpNull];
    private _visit=_job getOrDefault ["visitContext",[]];
    private _building=_job getOrDefault ["building",objNull];
    private _generation=_job getOrDefault ["operationGeneration",-1];
    private _epoch=_job getOrDefault ["ownerEpoch",-1];
    private _deadline=_job getOrDefault ["hardDeadline",-1];
    if (!(_mode in ["APPLY","CHECK","ADOPT","PREPARE"]) || {isNull _group} || {!local _group}
        || {isNull _actor} || {!local _actor} || {group _actor != _group}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {!(_visit isEqualType [])} || {count _visit != 4}
        || {!((_visit select 3) isEqualType "")} || {(_visit select 3) == ""}
        || {_visit isNotEqualTo (_group getVariable ["CBE_Cortex_ClearVisitContext",[]])}
        || {isNull _building} || {!alive _building}
        || {(_job getOrDefault ["buildingTransform",[]]) isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
        || {(_job getOrDefault ["generation",-1]) != (_group getVariable ["CBE_AIPass_ClearGeneration",-2])}
        || {(_job getOrDefault ["nativeOrderReceipt",[]]) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        || {((_group getVariable ["CBE_Operation",createHashMap]) getOrDefault ["intent",""]) != "CLEAR"}
        || {serverTime >= ((_job getOrDefault ["deadline",-1]) min _deadline)}) exitWith {};
    private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
    if (!(_mode in ["ADOPT","PREPARE"]) && {(_brain getOrDefault ["job",createHashMap]) isNotEqualTo _job
        || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}}) exitWith {};
    private _canonical=_actor getVariable ["CBE_ActorSettings",[]];
    if (_canonical isEqualTo [] && {
        !isNil {_actor getVariable "CBE_Cortex_ClearStance"}
            || {!isNil {_actor getVariable "CBE_Cortex_ClearForcedSpeed"}}
            || {!isNil {_actor getVariable "CBE_Cortex_ClearAppliedSpeed"}}
            || {!isNil {_actor getVariable "CBE_Cortex_ClearSettingToken"}}
    }) exitWith {};
    private _issuer=_visit select 3;
    if (_mode == "PREPARE") exitWith {
        if (_canonical isEqualTo []) exitWith {_result="ABSENT"};
        if !(_canonical isEqualType [] && {count _canonical == 3}
            && {(_canonical select 0) isEqualType []} && {count (_canonical select 0) == 5}) exitWith {};
        private _previous=+(_canonical select 0);
        if ((_previous select 1) isEqualTo _issuer) exitWith {_result="PREPARED"};
        // A fresh explicit task may retire its predecessor's known clearance settings first.
        // Another issuer, a same-generation claim or partial metadata grants no such handover.
        private _clearIssuer=_actor getVariable ["CBE_Cortex_ClearSettingToken",""];
        if (!(_clearIssuer isEqualType "") || {_clearIssuer == ""}
            || {(_previous select 0) isNotEqualTo _group}
            || {(_previous select 1) isNotEqualTo _clearIssuer}
            || {(_previous select 2) isEqualTo _generation}) exitWith {};
        _previous set [3,_epoch];
        _result=["RELEASE",_actor,_previous] call CBE_fnc_ActorSettings;
        if (_result == "RELEASED") then {
            {_actor setVariable [_x,nil,true]} forEach ["CBE_Cortex_ClearForcedSpeed",
                "CBE_Cortex_ClearAppliedSpeed","CBE_Cortex_ClearStance","CBE_Cortex_ClearSettingToken"];
            _result="PREPARED";
        };
    };
    // Preserve the task's live stealth intent without adding another speed writer.
    // -1 is the native unrestricted sentinel; malformed values still reach typed validation.
    if (_mode == "APPLY" && {behaviour _actor == "STEALTH"} && {finite _speed}
        && {_speed == -1 || {_speed > 1}}) then {_speed=1};
    _result=[_mode,_actor,[_group,_issuer,_generation,_epoch,_deadline],
        createHashMapFromArray [["STANCE","UP"],["SPEED",_speed]]] call CBE_fnc_ActorSettings;
    if (_result in ["APPLIED","ADOPTED","PENDING"]) then {
        private _lease=_actor getVariable ["CBE_ActorSettings",[]];
        private _owned=_lease select 1;
        private _mirrors=[["CBE_Cortex_ClearSettingToken",_issuer]];
        if ("STANCE" in _owned) then {_mirrors pushBack ["CBE_Cortex_ClearStance",(_owned get "STANCE") select 0]};
        if ("SPEED" in _owned) then {
            _mirrors pushBack ["CBE_Cortex_ClearForcedSpeed",(_owned get "SPEED") select 0];
            _mirrors pushBack ["CBE_Cortex_ClearAppliedSpeed",(_owned get "SPEED") select 1];
        };
        {if ((_actor getVariable [_x select 0,[]]) isNotEqualTo (_x select 1)) then {
            _actor setVariable [_x select 0,_x select 1,true];
        }} forEach _mirrors;
    };
};
_result
