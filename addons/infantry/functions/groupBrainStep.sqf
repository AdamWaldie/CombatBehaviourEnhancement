/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one bounded group decision and publish the semantic phase consumed by the
 * owner-local tactical FSM.
 * Post-clear owned STOP handback uses native formation return, including the leader,
 * without replacing the new authored waypoint with a positional movement request.
 * An active replacement operation defers handback without deleting the original hold receipt.
 * Deferred danger posture belongs to DangerPostureStep on the shared scheduler; it does not
 * depend on this tactical brain running and does not wake tactical planning.
 * Locality / Authority: Runs only through CBE's shared scheduler on the group owner. It validates
 * locality, generation, Zeus and external ownership before invoking existing bounded feature logic.
 * Repeat/JIP: One-shot callback. It always returns -1; the FSM queues the next step only after the
 * committed delay or a danger wake. Live coordinated COVER maintenance caps that delay at two
 * seconds so distance/reaction tuning cannot outlast its six-second capacity report. No new worker.
 * A migrated or superseded callback records cancellation only.
 * A callback whose FSM ended retires its queue flags without running decisions or cleanup;
 * the existing discovery sweep owns replacement of the recurring group brain.
 * Arguments: 0: brain <HASHMAP> created by CBE_fnc_GroupBrainStart.
 * Return Value: Number - always -1 because each FSM step is a separate coalesced scheduler job.
 * Current caller: CBE_fnc_GroupBrainQueue through CBE_fnc_CortexQueueJob.
 * Example: [_brain] call CBE_fnc_GroupBrainStep;
 */

params [["_brain",createHashMap,[createHashMap]]];
private _group=_brain getOrDefault ["group",grpNull];
private _epoch=_brain getOrDefault ["ownerEpoch",-1];
private _generation=_brain getOrDefault ["generation",-1];
private _cancel={
    params ["_reason"];
    _brain set ["cancelled",true];
    _brain set ["cancelReason",_reason];
    _brain set ["pending",false];
    _brain set ["completed",true];
    -1
};
if (isNull _group) exitWith {["GROUP_NULL"] call _cancel};
if (_brain getOrDefault ["cancelled",false]) exitWith {
    [_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel
};
if (!local _group) exitWith {["OWNERSHIP_LOST"] call _cancel};
if (_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])) exitWith {["OWNER_EPOCH"] call _cancel};
if (_generation != (_group getVariable ["CBE_GroupBrain_Generation",0])
    || {(_group getVariable ["CBE_GroupBrain",createHashMap]) isNotEqualTo _brain}) exitWith {["SUPERSEDED"] call _cancel};
// Queue delivery follows execFSM handle publication. An ended executor cannot own
// this decision; discovery may replace it without this callback issuing handback commands.
private _executor=_group getVariable ["CBE_GroupBrain_FSM",-1];
if (!(_executor isEqualType 0) || {!finite _executor} || {_executor < 0} || {completedFSM _executor}) exitWith {
    _brain set ["pending",false];
    _brain set ["completed",true];
    -1
};
if (!(missionNamespace getVariable ["CBE_AIPass_Active",false])) exitWith {["DISABLED"] call _cancel};
if ([_group] call CBE_fnc_CortexZeusHeld) exitWith {["ZEUS"] call _cancel};
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {["EXTERNAL_OWNER"] call _cancel};

// Retired coordinated holds share this callback; no token is reacquired and no clock is renewed.
private _supportCleanupState=_group getVariable ["CBE_AIPass_State",createHashMap];
if ((_supportCleanupState getOrDefault ["supportStopCleanup",[]]) isNotEqualTo []) then {
    [_group,_supportCleanupState,"PENDING"] call CBE_fnc_CortexSupportMaintain;
};

// Deferred danger posture uses its finite shared-scheduler job, independently of this brain.

// The original duck timer may have belonged to a previous owner/generation. Service
// one surviving receipt here without recreating that timer or extending its deadline.
private _duckPending=_group getVariable ["CBE_Cortex_GarrisonDuckPending",[]];
if (_duckPending isEqualType [] && {count _duckPending > 0} && {count _duckPending <= 64}) then {
    private _duckActor=_duckPending deleteAt 0;
    if (_duckActor isEqualType objNull && {!isNull _duckActor} && {group _duckActor == _group}) then {
        private _duckReceipt=_duckActor getVariable ["CBE_Cortex_GarrisonDuckRestore",[]];
        if (_duckReceipt isEqualType [] && {count _duckReceipt == 5}
            && {(_duckReceipt select 2) isEqualType 0} && {finite (_duckReceipt select 2)}
            && {serverTime < (_duckReceipt select 2)+30}) then {
            private _status=[_duckActor,_group,"RECOVER"] call CBE_fnc_CortexGarrisonSettings;
            if (_status in ["REFUSED","PENDING"]) then {_duckPending pushBack _duckActor};
        };
    };
    _group setVariable ["CBE_Cortex_GarrisonDuckPending",_duckPending,true];
};

// Garrison settings retirement uses the shared finite restoration-only executor.

// Deferred clearance settings use their finite restoration-only shared-scheduler job.

// A native STOP survives a new waypoint. Release only our matching post-clear hold
// when its author order changes, before ordinary tactical processing resumes.
private _clearHold=_group getVariable ["CBE_Cortex_ClearHold",[]];
if (count _clearHold == 5) then {
    private _owned=(_clearHold select 0) == (_group getVariable ["CBE_AIPass_ClearGeneration",0])
        && {(_clearHold select 1) == _epoch};
    // Another operation owns the decision window. Retain our exact hold metadata until
    // it ends; deleting now would lose stopped nonparticipants before handback can run.
    if (!_owned || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_clearHold select 2)
        && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}}) then {
        _group setVariable ["CBE_Cortex_ClearHold",nil,true];
        if (_owned && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}) then {
            private _leader=leader _group;
            private _deferred=[];
            private _holdJob=createHashMapFromArray [["group",_group],["nativeHoldPositions",createHashMapFromArray (_clearHold select 4)]];

            {
                if (local _x && {group _x == _group} && {!isPlayer _x}
                    && {currentCommand _x == "STOP"} && {[_x,_holdJob] call CBE_fnc_BuildingActorHoldOwned} && {isNull remoteControlled _x}
                    && {[_x] call CBE_fnc_CortexCombatEffective}
                    && {isNull objectParent _x} && {simulationEnabled _x} && {!isObjectHidden _x}
                    && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
                    && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
                    && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
                    && {!([_group,false,_x] call CBE_fnc_CortexExternalTakeover)}) then {
                    // Native formation return also releases a leader's scripted doStop.
                    // Leave waypoint type, gates, attachments and scripts to the engine;
                    // do not flatten a new authored task into one positional MOVE.
                    _x doFollow _leader;
                };
                // A newer individual order retires the old hold. A living soldier's unchanged
                // STOP retains proof across temporary unavailability, not just reservations.
                // The normal group callback retries; no extra observer or movement replay is added.
                // Split actor/group locality cannot grant a native command. Retain only the
                // original receipt until local observation can apply the strict pose/task checks.
                // No new position, epoch, deadline or movement request is manufactured here.
                if (!local _x && {group _x == _group} && {alive _x} && {!isPlayer _x}
                    && {isNull objectParent _x} && {currentCommand _x == "STOP"}) then {
                    _deferred pushBackUnique _x;
                };
                if (local _x && {group _x == _group} && {alive _x} && {!isPlayer _x}
                    && {isNull objectParent _x} && {currentCommand _x == "STOP"} && {[_x,_holdJob] call CBE_fnc_BuildingActorHoldOwned}
                    && {isNull remoteControlled _x}
                    && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
                    && {!([_group,false,_x] call CBE_fnc_CortexExternalTakeover)}
                    && {[_x] call CBE_fnc_CortexActorMoveReserved
                        || {!simulationEnabled _x} || {isObjectHidden _x}
                        || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
                        || {!([_x] call CBE_fnc_CortexCombatEffective)}}) then {
                    _deferred pushBackUnique _x;
                };
            } forEach (_clearHold select 3);
            if (_deferred isNotEqualTo []) then {
                _group setVariable ["CBE_Cortex_ClearHold",[_clearHold select 0,_clearHold select 1,_clearHold select 2,_deferred,(_clearHold select 4) select {(_x select 0) in (_deferred apply {netId _x})}],true];
            };
        };
    };
};
private _legacyJob=createHashMapFromArray [["group",_group]];
private _responsiveUntil=_brain getOrDefault ["responsiveUntil",0];
if (_responsiveUntil > time) then {_legacyJob set ["responsiveUntil",_responsiveUntil]};
private _delay=[_legacyJob] call CBE_fnc_CortexGroupTick;
if (isNil "_delay" || {!(_delay isEqualType 0)} || {_delay < 0}) exitWith {
    [if (_group getVariable ["CBE_AIPass_Managed",false]) then {"RETIRED"} else {"RELEASED"}] call _cancel
};

private _state=[_group] call CBE_fnc_CortexGroupState;
if ([_group] call CBE_fnc_CortexIlluminationStep) then {_delay=_delay min 1};
// Capacity freshness is a protocol deadline, not tactical reaction tuning. Keep only
// a live coordinated COVER helper on this existing callback within its six-second TTL.
private _supportLease=_group getVariable ["CBE_AIPass_SupportLease",[]];
private _supportRole=_group getVariable ["CBE_Cortex_SupportRole",[]];
if (_state getOrDefault ["assaulting",false] && {count _supportLease == 6}
    && {count _supportRole == 5} && {(_supportRole select 0) == (_supportLease select 0)}
    && {(_supportRole select 2) == "COVER"} && {serverTime < (_supportLease select 2)}) then {
    _delay=_delay min 2;
};
private _legacyPhase=_state getOrDefault ["phase","CALM"];
private _semanticPhase=switch (_legacyPhase) do {
    case "RETREAT": {"WITHDRAW"};
    case "CONTACT": {
        private _drill=_state getOrDefault ["drill",createHashMap];
        if (_state getOrDefault ["assaulting",false]) exitWith {"ASSAULT"};
        if (count _drill > 0) exitWith {
            private _stage=toUpperANSI (_drill getOrDefault ["stage",""]);
            private _reason=toUpperANSI (_drill getOrDefault ["stageReason",""]);
            if (_reason find "ASSAULT" >= 0 || {_stage == "ASSAULT"}) then {"ASSAULT"} else {"MANOEUVRE"}
        };
        if ((_group getVariable ["CBE_AIPass_SupportLease",[]]) isNotEqualTo []
            || {(_state getOrDefault ["responding",false])}) exitWith {"SUPPORT"};
        "CONTACT"
    };
    default {_legacyPhase};
};
if (_group getVariable ["CBE_AIPass_ClearBuilding",false]) then {_semanticPhase="CLEAR"};
_brain set ["legacyPhase",_legacyPhase];
_brain set ["phase",_semanticPhase];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["nextAt",time+_delay];
_brain set ["wakeAt",time+_delay];
_brain set ["pending",false];
_brain set ["completed",true];
_group setVariable ["CBE_GroupBrain_State",[
    _semanticPhase,_generation,_epoch,serverTime,
    _state getOrDefault ["phaseReason","STEP"],
    _delay
],true];
-1
