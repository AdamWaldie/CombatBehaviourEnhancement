/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Start the single owner-local building operation FSM for a prepared physical-clearance job.
 * Duplicate success requires a live FSM handle. The same unchanged job may replace one
 * ended executor while retaining room evidence, movement requests and original deadlines.
 * Locality / Authority: Must run where the group is local. It owns semantic building progression but
 * delegates each bounded movement/progress step to CBE's shared scheduler.
 * Repeat/JIP: Exact admitted operation/epoch, target transform, native intent and original deadlines
 * are checked in one unscheduled startup block. A repeated start for its live identical job
 * reuses the existing brain; stale work never stamps a new epoch or cancels a successor.
 * Replaces an older clear generation or one ended matching executor. Public room evidence remains durable and a
 * new owner reconstructs actor assignments through the ordinary clear-order resume path.
 * Arguments: 0: prepared building job <HASHMAP>.
 * Return Value: Boolean - true when a building brain was started for the current owner.
 * A new producer clears this machine's previous private outgoing lane capture.
 * Current callers: CBE_fnc_CortexClearBuilding and CortexDiscover ended-worker recovery.
 * Example: [_job] call CBE_fnc_BuildingOperationStart;
 */

params [["_job",createHashMap,[createHashMap]]];
private _group=_job getOrDefault ["group",grpNull];
if (isNull _group || {!local _group} || {count _job == 0}) exitWith {false};
private _generation=_job getOrDefault ["generation",-1];
private _epoch=_job getOrDefault ["ownerEpoch",-1];
private _started=false;
// Preparation may have yielded since common-operation admission. Startup grants no new
// authority: retain the original operation/epoch and commit only while all proof is current.
isNil {
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _building=_job getOrDefault ["building",objNull];
    if (!local _group || {_generation < 0} || {_epoch < 0}
        || {_generation != (_group getVariable ["CBE_AIPass_ClearGeneration",-2])}
        || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {(_operation getOrDefault ["generation",-2]) != (_job getOrDefault ["operationGeneration",-1])}
        || {(_operation getOrDefault ["ownerEpoch",-2]) != _epoch}
        || {(_operation getOrDefault ["intent",""]) != "CLEAR"}
        || {(_operation getOrDefault ["objective",objNull]) != _building}
        || {!(_group getVariable ["CBE_AIPass_ClearBuilding",false])}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {serverTime >= ((_job getOrDefault ["deadline",-1]) min (_job getOrDefault ["hardDeadline",-1]))}
        || {isNull _building} || {!alive _building}
        || {(_job getOrDefault ["buildingTransform",[]]) isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building,getObjectScale _building]}
        || {(_job getOrDefault ["nativeOrderReceipt",[]]) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}) exitWith {};
    private _old=_group getVariable ["CBE_BuildingBrain",createHashMap];
    private _existingHandle=_group getVariable ["CBE_BuildingBrain_FSM",-1];
    private _workerAlive=_existingHandle isEqualType 0 && {finite _existingHandle}
        && {_existingHandle >= 0} && {!completedFSM _existingHandle};
    private _resumeEnded=count _old > 0 && {!_workerAlive}
        && {(_old getOrDefault ["generation",-1]) == _generation}
        && {(_old getOrDefault ["job",createHashMap]) isEqualTo _job}
        && {(_old getOrDefault ["ownerEpoch",-1]) == _epoch}
        && {!(_old getOrDefault ["cancelled",false])} && {!(_old getOrDefault ["finished",false])}
        && {(_job getOrDefault ["executorRestarts",0]) < 1};
    if (count _old > 0 && {(_old getOrDefault ["generation",-1]) == _generation} && {!_resumeEnded}) exitWith {
        // A duplicate call can acknowledge its own live worker, never restart a retired
        // one or replace different work that happens to present the same generation.
        _started=(_old getOrDefault ["job",createHashMap]) isEqualTo _job
            && {(_old getOrDefault ["ownerEpoch",-1]) == _epoch}
            && {!(_old getOrDefault ["cancelled",false])}
            && {!(_old getOrDefault ["finished",false])} && {_workerAlive};
    };
    if (_resumeEnded) then {_job set ["executorRestarts",1+(_job getOrDefault ["executorRestarts",0])]};
    if (count _old > 0) then {
        _old set ["cancelled",true];
        _old set ["cancelReason","REPLACED"];
    };
    private _brain=createHashMapFromArray [
        ["group",_group],
        ["job",_job],
        ["producerOwner",clientOwner],
        ["ownerEpoch",_epoch],
        ["generation",_generation],
        ["phase",toUpperANSI (_job getOrDefault ["phase","ENTRY"])],
        ["pending",false],
        ["completed",false],
        ["finished",false],
        ["cancelled",false],
        ["cancelReason",""],
        ["nextAt",time],
        ["lastStepAt",-1],
        ["lastDelay",-1],
        ["queuedAt",-1],
        ["watchdogCount",0]
    ];
    _group setVariable ["CBE_Cortex_ClearLaneCaptureLocal",nil];
    _group setVariable ["CBE_BuildingBrain",_brain];
    _group setVariable ["CBE_BuildingBrain_State",[_brain get "phase",_generation,_epoch,serverTime,"STARTED",0,0,count (_job getOrDefault ["positions",[]])],true];
    private _handle=[_group,_epoch,_generation,_brain] execFSM "\z\cbe\addons\main\fsm\buildingOperation.fsm";
    _group setVariable ["CBE_BuildingBrain_FSM",_handle];
    _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
        && {(_group getVariable ["CBE_BuildingBrain",createHashMap]) isEqualTo _brain}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])};
    if (!_started && {(_group getVariable ["CBE_BuildingBrain",createHashMap]) isEqualTo _brain}) then {
        _brain set ["cancelled",true];_brain set ["finished",true];
        _brain set ["pending",false];_brain set ["completed",true];
        _brain set ["cancelReason","FSM_START_FAILED"];
        _group setVariable ["CBE_BuildingBrain_FSM",nil];
        if (local _group && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {_generation == (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}) then {
            _group setVariable ["CBE_BuildingBrain_State",["FAILED",_generation,_epoch,serverTime,"FSM_START_FAILED"],true];
        };
    };
};
// Register only an actually started producer. No readiness or movement permission follows
// from sending this request; a delayed acknowledgement must still match the live job.
if (_started && {isNil {_job get "producerRegistrationRequested"}}) then {
    _job set ["producerRegistrationRequested",true];
    private _registration=[_group,+(_job get "visitContext"),_epoch,_generation,_job get "operationGeneration"];
    if (isServer) then {["REGISTER",_registration] call CBE_fnc_BuildingProducerRegister}
    else {["REGISTER",_registration] remoteExecCall ["CBE_fnc_BuildingProducerRegister",2]};
};
_started
