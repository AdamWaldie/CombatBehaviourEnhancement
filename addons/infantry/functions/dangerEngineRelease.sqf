/*
 * Author: WaldoTheWarfighter
 * Cleanup coalesces by group object and epoch, independent of mutable callsigns.
 * Terminal release retires its pending queue slot immediately, without a stance command.
 * Native fleeing defers stance restoration through the original bounded pending-stance path.
 * Any exact owned finite flight move is retired independently through DangerFlight first.
 * Purpose: Release CBE's finite weak danger stance without overwriting a newer owner.
 * Locality / Authority: Runs where the AI soldier is local when the engine danger FSM finishes.
 * Repeat/JIP: Repeat-safe and machine-local. Always clears the completed response marker. Restores
 * the recorded prior stance only while the actor still has CBE's exact applied stance and no player,
 * Zeus, specialist controller or finite actor reservation has taken ownership. New leases also bind operation generation, owner epoch and group; replacement work cannot inherit the restoration.
 * Dormancy, blocked native tasks/reservations and unconfirmed restores retain the original lease for a later
 * existing caller. Automatic retries stop 30 seconds after the original stance expiry; proof remains.
 * One finite keyed shared-scheduler job services pending actors without a tactical brain,
 * including disabled tactics. Direct blocked release wakes an existing queue entry too.
 * No per-actor worker or deadline renewal is created; scheduler pressure can still exhaust the window.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: running cleanup job <BOOL>, false.
 * Only DangerPostureStep passes true to avoid requeueing its already-running callback.
 * Return Value: Boolean - true when CBE restored its exact owned stance, otherwise false.
 * Current callers: Engine danger FSM Finished, OperationStart and IndoorActorOperation START.
 * Example: [cursorObject] call CBE_fnc_DangerEngineRelease;
 */

params [["_actor",objNull,[objNull]],["_cleanupRunning",false,[true]]];
if (isNull _actor) exitWith {false};
["RELEASE",_actor,_cleanupRunning] call CBE_fnc_DangerAttackPace;
// This marker describes the currently executing engine-FSM action. Keeping it after Finished made
// diagnostics report a response which no longer existed and let a later owner inherit stale state.
// Clear it even when there was no stance to restore or locality changed during the response.
_actor setVariable ["CBE_Danger_EngineResponse",nil];
["RELEASE",_actor] call CBE_fnc_DangerFlight;
private _lease=_actor getVariable ["CBE_Danger_EngineStanceLease",[]];
if (count _lease != 6) exitWith {false};
private _evidence={
    params ["_reason",["_retire",false]];
    if (_retire) then {
        _actor setVariable ["CBE_Danger_EngineStanceLease",nil];
        private _receiptGroup=_lease select 5;
        if (_receiptGroup isEqualType grpNull && {!isNull _receiptGroup} && {local _receiptGroup}) then {
            private _pendingRetirement=_receiptGroup getVariable ["CBE_Danger_StancePendingActors",[]];
            if (_pendingRetirement isEqualType [] && {count _pendingRetirement <= 64}) then {
                private _retirementIndex=_pendingRetirement find _actor;
                if (_retirementIndex >= 0) then {
                    _pendingRetirement deleteAt _retirementIndex;
                    _receiptGroup setVariable ["CBE_Danger_StancePendingActors",_pendingRetirement];
                };
            };
        };
    };
    if (!_retire && {_reason in ["ACTOR_RESERVATION","ACTOR_DORMANT","NATIVE_TASK_OR_MEDICAL","RESTORE_PENDING"]}) then {
        private _pendingGroup=group _actor;
        private _pending=_pendingGroup getVariable ["CBE_Danger_StancePendingActors",[]];
        if (local _pendingGroup && {_pending isEqualType []} && {count _pending <= 64}
            && {_actor in _pending || {count _pending < 64}}
            && {(_lease select 2) isEqualType 0} && {finite (_lease select 2)}
            && {time < (_lease select 2)+30}) then {
            if (!(_actor in _pending)) then {_pending pushBack _actor};
            _pendingGroup setVariable ["CBE_Danger_StancePendingActors",_pending];
            if (!_cleanupRunning) then {
                private _cleanupEpoch=_pendingGroup getVariable ["CBE_AIPass_Epoch",0];
                [CBE_fnc_DangerPostureStep,createHashMapFromArray [["group",_pendingGroup],
                    ["ownerEpoch",_cleanupEpoch],["generation",_cleanupEpoch],["subsystem","POSTURE_CLEANUP"]],0.25,
                    "DANGER_POSTURE"] call CBE_fnc_CortexQueueJob;
                [] call CBE_fnc_SchedulerReconcile;
            };
        };
    };
    _actor setVariable ["CBE_Danger_EngineReleaseEvidence",[serverTime,_reason,+_lease,unitPos _actor]];
    false
};
if (!local _actor || {!alive _actor} || {isPlayer _actor}) exitWith {["LOST_ACTOR_AUTHORITY",true] call _evidence};
private _group=group _actor;
if (isNull _group || {!local _group} || {[_group,false,_actor] call CBE_fnc_CortexExternalTakeover}
    || {[_group] call CBE_fnc_CortexZeusHeld}
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}) exitWith {["EXTERNAL_OWNER",true] call _evidence};

if (count _lease >= 6 && {(_lease select 3) != (_group getVariable ["CBE_OperationGeneration",0])
    || {(_lease select 4) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {(_lease select 5) != _group}}) exitWith {["NEW_OPERATION_OR_OWNER",true] call _evidence};
// Dormancy suspends commands, not the original stance proof or operation membership.
if (!simulationEnabled _actor || {isObjectHidden _actor}) exitWith {["ACTOR_DORMANT"] call _evidence};
if ([_actor] call CBE_fnc_CortexActorMoveReserved) exitWith {
    ["ACTOR_RESERVATION"] call _evidence
};
if ((_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []
    || {fleeing _actor} || {!([_actor] call CBE_fnc_CortexCombatEffective)}
    || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {["NATIVE_TASK_OR_MEDICAL"] call _evidence};

private _prior=toUpperANSI (_lease param [0,"",[""]]);
private _applied=toUpperANSI (_lease param [1,"",[""]]);
if (!(_prior in ["AUTO","UP","MIDDLE","DOWN"])
    || {!(_applied in ["AUTO","UP","MIDDLE","DOWN"])}) exitWith {["INVALID_STANCE_PROOF"] call _evidence};
if (toUpperANSI (unitPos _actor) != _applied) exitWith {["STANCE_CHANGED",true] call _evidence};
// Direct stop/start callers share the deferred worker's original hard restoration window.
// Expiry retains proof, but cannot authorise a late native write over intervening intent.
if (!((_lease select 2) isEqualType 0) || {!finite (_lease select 2)}) exitWith {
    ["INVALID_STANCE_PROOF"] call _evidence
};
if (time >= (_lease select 2)+30) exitWith {["RESTORE_WINDOW_EXPIRED"] call _evidence};
// An exact routine strong stance can be the baseline below this weak response.
// Release that owned restriction too, rather than restoring an intermediate CBE value.
private _routine=[_group,_actor] call CBE_fnc_CortexStanceReceipt;
if (count _routine == 4 && {_prior == (_routine select 3)}) exitWith {
    _actor setUnitPos "AUTO";
    if (toUpperANSI unitPos _actor != (_routine select 2)) exitWith {["RESTORE_PENDING"] call _evidence};
    {_actor setVariable [_x,nil,true]} forEach ["CBE_Cortex_StanceReceipt",
        "CBE_Cortex_AppliedStance","CBE_AIPass_StanceSet"];
    ["RESTORED",true] call _evidence;
    true
};
if (_prior != _applied) then {_actor setUnitPosWeak _prior};
if (toUpperANSI (unitPos _actor) != _prior) exitWith {["RESTORE_PENDING"] call _evidence};
["RESTORED",true] call _evidence;
true
