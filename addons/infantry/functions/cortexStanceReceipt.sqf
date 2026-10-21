/*
 * Author: WaldoTheWarfighter
 * Purpose: Read typed routine cover-stance provenance without importing partial mirrors.
 * Locality/authority: Actual group and actor owner only. This receipt grants no new native
 * command; callers retain task, Zeus and external-controller checks and compare native stance.
 * Repeat/JIP: Read-only. An older same-group epoch may supply an original baseline to the
 * actual new owner; a future epoch or partially replayed mirrors refuses. No replay worker.
 * Arguments: 0 group GROUP grpNull; 1 actor OBJECT objNull; 2 match native BOOL false.
 * Native matching accepts only this applied stance or an exact current CBE weak overlay.
 * Return: ARRAY [group, issuing epoch, original AUTO, applied UP/MIDDLE], or [] if absent/refused.
 * Current callers: CortexStance, CortexFlankStep, CortexGroupTick, CortexRestoreCalm, ActorSettings.
 * Example: private _proof=[group soldier1,soldier1] call CBE_fnc_CortexStanceReceipt;
 */
params [["_group",grpNull,[grpNull]],["_actor",objNull,[objNull]],["_matchNative",false,[true]]];
if (isNull _group || {!local _group} || {isNull _actor} || {!local _actor}
    || {group _actor != _group}) exitWith {[]};
private _proof=_actor getVariable ["CBE_Cortex_StanceReceipt",[]];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
if (!(_proof isEqualType []) || {count _proof != 4}
    || {(_proof select 0) isNotEqualTo _group}
    || {!((_proof select 1) isEqualType 0)} || {!finite (_proof select 1)}
    || {(_proof select 1) < 0} || {(_proof select 1) != floor (_proof select 1)}
    || {(_proof select 1) > _epoch}
    || {(_proof select 2) isNotEqualTo "AUTO"}
    || {!((_proof select 3) in ["UP","MIDDLE"])}
    || {(_actor getVariable ["CBE_AIPass_StanceSet",false]) isNotEqualTo true}
    || {(_actor getVariable ["CBE_Cortex_AppliedStance",""]) isNotEqualTo (_proof select 3)}) exitWith {[]};
if (_matchNative && {toUpperANSI unitPos _actor != (_proof select 3)}) then {
    private _weak=_actor getVariable ["CBE_Danger_EngineStanceLease",[]];
    if (!(_weak isEqualType []) || {count _weak != 6}
        || {(_weak select 0) isNotEqualTo (_proof select 3)}
        || {(_weak select 1) isNotEqualTo (toUpperANSI unitPos _actor)}
        || {!((_weak select 2) isEqualType 0)} || {!finite (_weak select 2)}
        || {(_weak select 3) isNotEqualTo (_group getVariable ["CBE_OperationGeneration",0])}
        || {(_weak select 4) isNotEqualTo _epoch} || {(_weak select 5) isNotEqualTo _group}) exitWith {_proof=[]};
};
+_proof
