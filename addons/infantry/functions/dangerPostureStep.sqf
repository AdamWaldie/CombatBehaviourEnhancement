/*
 * Author: WaldoTheWarfighter
 * Purpose: Service finite deferred danger-stance restoration without starting tactical planning.
 * Locality/authority: Current group owner and epoch only. DangerEngineRelease validates each
 * actor, operation, native task and exact applied stance before any restoration.
 * Repeat/JIP: One keyed shared-scheduler job per group/epoch. Pops one of at most 64 queued
 * actors per callback. Original stance expiry plus 30 seconds bounds retries; no renewal.
 * No persistent worker, world scan or JIP replay. New owners do not inherit local stance proof.
 * Arguments: 0 job state <HASHMAP, empty>, containing group GROUP and ownerEpoch NUMBER.
 * Return: NUMBER, 0.25 seconds while pending work remains, otherwise -1 to retire.
 * Current callers: CortexSchedulerTick, queued by DangerEngineRelease.
 * Example: [createHashMapFromArray [["group",group soldier1],["ownerEpoch",0]]]
 *     call CBE_fnc_DangerPostureStep;
 */
params [["_state",createHashMap,[createHashMap]]];
private _group=_state getOrDefault ["group",grpNull];
if (isNull _group || {!local _group}
    || {(_state getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {-1};
private _pendingPosture=_group getVariable ["CBE_Danger_StancePendingActors",[]];
if (!(_pendingPosture isEqualType []) || {count _pendingPosture > 64}
    || {_pendingPosture isEqualTo []}) exitWith {-1};
// Publish the pop before release. A still-blocked exact receipt requeues itself through
// the same bounded admission path; never overwrite that requeue with a stale local array.
private _actor=_pendingPosture deleteAt 0;
_group setVariable ["CBE_Danger_StancePendingActors",_pendingPosture];
if (_actor isEqualType objNull && {!isNull _actor} && {local _actor} && {group _actor == _group}) then {
    private _proof=_actor getVariable ["CBE_Danger_EngineStanceLease",[]];
    if (_proof isEqualType [] && {count _proof == 6}
        && {(_proof select 2) isEqualType 0} && {finite (_proof select 2)}) then {
        if (time >= (_proof select 2)+30) then {
            _actor setVariable ["CBE_Danger_EngineReleaseEvidence",[serverTime,"RESTORE_WINDOW_EXPIRED",+_proof,unitPos _actor]];
        } else {
            if (time >= (_proof select 2)
                && {time >= ((_actor getVariable ["CBE_Danger_EngineResponse",[]]) param [3,-1,[0]])}) then {
                [_actor,true] call CBE_fnc_DangerEngineRelease;
            } else {
                _pendingPosture pushBack _actor;
                _group setVariable ["CBE_Danger_StancePendingActors",_pendingPosture];
            };
        };
    };
};
if ((_group getVariable ["CBE_Danger_StancePendingActors",[]]) isEqualTo []) exitWith {-1};
0.25
