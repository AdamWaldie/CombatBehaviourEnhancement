/*
 * Author: WaldoTheWarfighter
 * Purpose: Finish an original carried-static packing request when artillery outlasts SECURITY.
 * Locality/authority: Original group/actor owner only. One exact private worker exclusively
 * delegates equipment commands to CortexStaticDeployStep; it never issues native commands itself.
 * Original record, owner epoch, crew, authored route, current tasks and features still govern.
 * Repeat/JIP: Wait at most120s, then one <=90s packing window within the original210s hard limit.
 * No deadline/retry renewal, native fire cancellation, forced exit/seating or migration replay.
 * Pending fire keeps its token. Quiet native readiness is additional observation, not proof
 * that arbitrary external writers have stopped. New contact/orders/crew/owner revoke this task.
 * Arguments: 0 worker HASHMAP from CortexStaticDeployStep (default empty).
 * Return Value: NUMBER1 next check or-1 on terminal outcome. PACKED only comes from the existing
 * executor's actual equipment checks; timeout or retirement is never physical completion.
 * Current callers: CortexQueueJob after original SECURITY packing request.
 * Example: [CBE_fnc_CortexStaticPackStep,_job,1] call CBE_fnc_CortexQueueJob;
 */
params [["_job",createHashMap,[createHashMap]]];
private _group=_job getOrDefault ["taskGroup",grpNull];
private _weapon=_job getOrDefault ["weapon",objNull];
private _record=if (isNull _group) then {[]} else {_group getVariable ["CBE_Danger_StaticDeployment",[]]};
private _same=count _record >= 31
    && {(_record param [19,[],[[]]]) isEqualTo [clientOwner,_job getOrDefault ["ownerEpoch",-1]]}
    && {(_record param [27,-1,[0]]) == (_job getOrDefault ["generation",-2])}
    && {(_record param [7,objNull,[objNull]]) == _weapon}
    && {(_record param [2,objNull,[objNull]]) == (_job getOrDefault ["gunner",objNull])}
    && {(_record param [3,objNull,[objNull]]) == (_job getOrDefault ["assistant",objNull])};
private _finish={
    params ["_reason",["_retire",false]];
    if (_retire && {_same} && {local _group}
        && {(_group getVariable ["CBE_StaticPack_Local",createHashMap]) isEqualTo _job}) then {
        [_group,[_group] call CBE_fnc_CortexGroupState,[],false,true,true,false,_job]
            call CBE_fnc_CortexStaticDeployStep;
    };
    _job set ["done",true];_job set ["result",_reason];
    if (!isNull _group && {(_group getVariable ["CBE_StaticPack_Local",createHashMap]) isEqualTo _job}) then {
        _group setVariable ["CBE_StaticPack_Local",nil];
    };
    -1
};
if (_job getOrDefault ["done",false]) exitWith {-1};
if (isNull _group || {!local _group} || {isRemoteExecuted}
    || {(_group getVariable ["CBE_StaticPack_Local",createHashMap]) isNotEqualTo _job}
    || {!_same} || {(_job getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {
    ["REPLACED"] call _finish
};
private _packing=(_job getOrDefault ["packUntil",-1]) >= 0;
// Only the validated native disassembly event admits collection after weapon removal.
// A destroyed/deleted ACTIVE weapon must not be mistaken for successful packing.
private _packedBags=_record param [25,[],[[]]];
private _removedByPacking=_packing && {(_record select 1) == "TAKING"}
    && {count _packedBags == ([2,1] select (_record param [28,false,[false]]))}
    && {_packedBags findIf {isNull _x} < 0};
private _state=[_group] call CBE_fnc_CortexGroupState;
private _phase=_state getOrDefault ["phase","CALM"];
if (!(missionNamespace getVariable ["CBE_AIPass_Active",false])
    || {!(_phase in ["SECURITY","SEARCH","REGROUP","CALM"])}
    || {combatMode _group in ["BLUE","GREEN"]}
    || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {!([_group,"CBE_AIPass_StaticSupport_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_StaticDeploy_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {(_record param [30,[],[[]]]) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
    || {(!_removedByPacking) && {isNull _weapon || {!alive _weapon}}}
    || {[_job get "gunner",_job get "assistant"] findIf {
        isNull _x || {!local _x} || {group _x != _group} || {isPlayer _x}
            || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {[_x] call CBE_fnc_CompatibilityExternalControl}
    } >= 0}) exitWith {["AUTHORITY_CHANGED",true] call _finish};
private _originalGunner=_job get "gunner";
private _originalAssistant=_job get "assistant";
if (crew _weapon findIf {_x != _originalGunner} >= 0
    || {!(vehicle _originalGunner in [_originalGunner,_weapon])}
    || {!(assignedVehicle _originalGunner in [objNull,_weapon])}
    || {_originalAssistant != _originalGunner && {
        !isNull objectParent _originalAssistant
            || {assignedVehicle _originalAssistant != (_job get "assistantAssignment")}}}) exitWith {
    ["CREW_CHANGED",true] call _finish
};
private _until=(_job get "hardUntil") min (_job get (["waitUntil","packUntil"] select _packing));
if (serverTime >= _until) exitWith {["OBSERVATION_EXPIRED",true] call _finish};
if ([] call CBE_fnc_CortexIsPaused) exitWith {1};
private _fire=_weapon getVariable ["CBE_AIPass_FireToken",""];
if (!(_fire isEqualType "") || {_fire != "" && {_fire != (_job get "fireToken")}}) exitWith {
    ["NEW_FIRE_OWNER",true] call _finish
};
if (_fire != "") exitWith {1};
private _shot=_weapon getVariable ["CBE_AIPass_ShotReceipt",[]];
private _shotToken=_shot param [0,"",[""]];
if (!_removedByPacking && {!(_shotToken in [_job get "fireToken",_job get "previousShotToken"])}) exitWith {
    ["NEW_FIRE_OWNER",true] call _finish
};
if (!_packing) then {
    private _gunner=_job get "gunner";
    if (!unitReady _weapon || {!unitReady _gunner}
        || {!(toUpperANSI currentCommand _gunner in ["","WAIT"])}) exitWith {};
    _job set ["packUntil",(serverTime+90) min (_job get "hardUntil")];
    _job set ["phase","PACK"];
    _packing=true;
};
if (!_packing) exitWith {1};
// This is equipment SECURITY, not a mutation of the squad's current semantic phase.
private _equipmentState=createHashMapFromArray [["phase","SECURITY"],["phaseStart",_record select 0]];
private _result=[_group,_equipmentState,[],true,false,false,false,_job] call CBE_fnc_CortexStaticDeployStep;
if (_result in ["PACKED","FAILED","YIELDED","IDLE","DISABLED"]) exitWith {[_result] call _finish};
1
