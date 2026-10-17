/*
 * Author: WaldoTheWarfighter
 * Exercises real queued squad movement and completion fairness under the minimum scheduler budget.
 * Locality/authority: scheduled server fixture; production scheduler runs owner-local movement jobs.
 * Repeat/JIP: fresh actors, public destinations; caller restores settings, fixture jobs retire on deletion.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; required audit callbacks.
 * Return: Nothing. Current caller: cortexQAServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAScheduler.sqf";
 */
params ["_check","_phase","_wait"];
[createHashMapFromArray [["CBE_AIPass_Enable",true]]] call CBE_fnc_CortexTuning;
private _saved = createHashMapFromArray [
    ["CBE_AIPass_Danger_Enable",missionNamespace getVariable ["CBE_AIPass_Danger_Enable",true]],
    ["CBE_AIPass_TickBudgetMs", missionNamespace getVariable ["CBE_AIPass_TickBudgetMs",1]],
    ["CBE_AIRebalance_Enable", missionNamespace getVariable ["CBE_AIRebalance_Enable",true]],
    ["CBE_AIRebalance_Mode", missionNamespace getVariable ["CBE_AIRebalance_Mode","AUTO"]],
    ["CBE_AIRebalance_Profile", missionNamespace getVariable ["CBE_AIRebalance_Profile","LINE"]]
];
[createHashMapFromArray [["CBE_AIPass_TickBudgetMs",0.2]]] call CBE_fnc_CortexTuning;
// Submit successive updates atomically: the scheduled fixture must not yield between
// admission and observation. Only the production scheduler executes the callback later.
private _coalesceKey="CBE_QA_COALESCE_"+str diag_tickTime;
private _coalesceState=createHashMapFromArray [["calls",0],["value",1]];
private _coalesceCallback={params ["_state"]; _state set ["calls",(_state get "calls")+1]; -1};
private _countMatching={
    ((missionNamespace getVariable ["CBE_AIPass_Jobs",[]])
        +(missionNamespace getVariable ["CBE_AIPass_PendingJobs",[]])) select {
        ((_x select 2) getOrDefault ["jobKey",""]) == _coalesceKey
    }
};
private _earliestWakeRetained=false;
private _queuedCount=0;
isNil {
    [_coalesceCallback,_coalesceState,10,_coalesceKey] call CBE_fnc_CortexQueueJob;
    [_coalesceCallback,createHashMapFromArray [["value",2]],0,_coalesceKey] call CBE_fnc_CortexQueueJob;
    private _earlyWake=_coalesceState getOrDefault ["wakeAt",-1];
    [_coalesceCallback,createHashMapFromArray [["value",3]],5,_coalesceKey] call CBE_fnc_CortexQueueJob;
    _earliestWakeRetained=_earlyWake >= 0 && {(_coalesceState get "wakeAt") == _earlyWake};
    _queuedCount=count (call _countMatching);
};
["SCHED-keyed-earliest-wake-retained",_earliestWakeRetained] call _check;
["SCHED-keyed-single-queued",_queuedCount == 1,str _queuedCount] call _check;
private _coalesceRetired=[{(_coalesceState get "calls") >= 1 && {count (call _countMatching) == 0}},10] call _wait;
["SCHED-keyed-callback-retired",_coalesceRetired] call _check;
["SCHED-keyed-callback-once",_coalesceRetired && {(_coalesceState get "calls") == 1}
    && {(_coalesceState get "value") == 3},str [_coalesceState get "calls",_coalesceState get "value"]] call _check;
// A running callback wakes its own existing job but returns a longer normal cadence.
// The real scheduler must observe the immediate wake through its cached deadline.
private _selfWakeKey="CBE_QA_SELF_WAKE_"+str diag_tickTime;
private _selfWakeState=createHashMapFromArray [["calls",0],["firstAt",-1],["secondAt",-1]];
private _selfWakeCallback={
    params ["_state"];
    private _calls=(_state get "calls")+1;
    _state set ["calls",_calls];
    if (_calls == 1) exitWith {
        _state set ["firstAt",time];
        [CBE_CortexQA_SelfWakeCallback,_state,0,_state get "jobKey"] call CBE_fnc_CortexQueueJob;
        20
    };
    _state set ["secondAt",time];
    -1
};
missionNamespace setVariable ["CBE_CortexQA_SelfWakeCallback",_selfWakeCallback];
[_selfWakeCallback,_selfWakeState,0,_selfWakeKey] call CBE_fnc_CortexQueueJob;
private _selfWakeRan=[{(_selfWakeState get "calls") >= 2},10] call _wait;
["SCHED-running-key-immediate-wake",_selfWakeRan && {(_selfWakeState get "calls") == 2}
    && {(_selfWakeState get "secondAt")-(_selfWakeState get "firstAt") < 10},
    str [_selfWakeState get "calls",_selfWakeState get "firstAt",_selfWakeState get "secondAt"]] call _check;
missionNamespace setVariable ["CBE_CortexQA_SelfWakeCallback",nil];
// Stable aircraft observer keys survive locality changes; generation must isolate their state.
private _generationKey="CBE_QA_GENERATION_"+str diag_tickTime;
private _previousGeneration=createHashMapFromArray [["generation",1],["calls",0],["oldProgress",true]];
private _currentGeneration=createHashMapFromArray [["generation",2],["calls",0]];
isNil {
    [_coalesceCallback,_previousGeneration,1,_generationKey] call CBE_fnc_CortexQueueJob;
    [_coalesceCallback,_currentGeneration,0,_generationKey] call CBE_fnc_CortexQueueJob;
};
private _generationRan=[{(_currentGeneration get "calls") == 1},10] call _wait;
["SCHED-keyed-generation-state-isolated",_generationRan
    && {(_previousGeneration get "generation") == 1}
    && {!("oldProgress" in _currentGeneration)},str [_previousGeneration get "generation",_currentGeneration get "calls"]] call _check;
// Isolated owner-epoch admission check: do not change any live mission group's epoch.
private _epochGroup=createGroup [east,false];
_epochGroup setVariable ["CBE_Headless_ExcludeGroup",true,true];
_epochGroup setVariable ["CBE_AIPass_Epoch",6];
// Authority rejection only: no actors or tactical outcome is fabricated by this boundary case.
private _registeredBrain=createHashMapFromArray [["group",_epochGroup],["ownerEpoch",6],["generation",1],["phase","CALM"]];
private _detachedBrain=createHashMapFromArray [["group",_epochGroup],["ownerEpoch",6],["generation",1],["phase","CONTACT"]];
_epochGroup setVariable ["CBE_GroupBrain_Generation",1];
_epochGroup setVariable ["CBE_GroupBrain",_registeredBrain];
private _detachedAccepted=[_epochGroup,6,1,_detachedBrain,"CONTACT"] call CBE_fnc_GroupBrainQueue;
["SCHED-detached-brain-not-admitted",!_detachedAccepted && {!(_detachedBrain getOrDefault ["pending",false])}] call _check;
private _detachedResult=[_detachedBrain] call CBE_fnc_GroupBrainStep;
["SCHED-detached-brain-step-rejected",_detachedResult == -1
    && {(_detachedBrain getOrDefault ["cancelReason",""]) == "SUPERSEDED"}] call _check;
["SCHED-detached-brain-live-state-preserved",!(_registeredBrain getOrDefault ["cancelled",false])
    && {(_registeredBrain get "phase") == "CALM"}
    && {(_epochGroup getVariable ["CBE_GroupBrain",createHashMap]) isEqualTo _registeredBrain}] call _check;
private _detachedFSMBrain=createHashMapFromArray [["group",_epochGroup],["ownerEpoch",6],["generation",1],["phase","INVESTIGATE"]];
private _detachedFSM=[_epochGroup,6,1,_detachedFSMBrain] execFSM "\z\cbe\addons\main\fsm\groupTactics.fsm";
private _detachedFSMFinished=[{completedFSM _detachedFSM},10] call _wait;
["SCHED-detached-fsm-retires",_detachedFSMFinished] call _check;
["SCHED-detached-fsm-live-brain-preserved",_detachedFSMFinished
    && {(_epochGroup getVariable ["CBE_GroupBrain",createHashMap]) isEqualTo _registeredBrain}
    && {!(_registeredBrain getOrDefault ["cancelled",false])}] call _check;
private _registeredSupport=createHashMapFromArray [["requester",_epochGroup],["phase","DISCOVER"]];
private _detachedSupport=createHashMapFromArray [["requester",_epochGroup],["phase","RESERVE"]];
private _supportReservation=["CBE_QA_SUPPORT_PRESERVE",time+30];
_epochGroup setVariable ["CBE_Support_BrainGeneration",1];
_epochGroup setVariable ["CBE_Support_Brain",_registeredSupport];
_epochGroup setVariable ["CBE_AIPass_SupportLease",_supportReservation];
private _detachedSupportFSM=[createHashMapFromArray [["requester",_epochGroup]],1,_detachedSupport]
    execFSM "\z\cbe\addons\main\fsm\supportRequest.fsm";
private _supportFSMFinished=[{completedFSM _detachedSupportFSM},10] call _wait;
["SCHED-detached-support-fsm-retires",_supportFSMFinished] call _check;
["SCHED-detached-support-state-preserved",_supportFSMFinished
    && {(_epochGroup getVariable ["CBE_Support_Brain",createHashMap]) isEqualTo _registeredSupport}
    && {(_epochGroup getVariable ["CBE_AIPass_SupportLease",[]]) isEqualTo _supportReservation}] call _check;
_epochGroup setVariable ["CBE_AIPass_SupportLease",nil];
private _registeredBuilding=createHashMapFromArray [["group",_epochGroup],["phase","SWEEP"]];
private _detachedBuilding=createHashMapFromArray [["group",_epochGroup],["phase","ENTRY"]];
_epochGroup setVariable ["CBE_AIPass_ClearGeneration",1];
_epochGroup setVariable ["CBE_BuildingBrain",_registeredBuilding];
private _detachedBuildingFSM=[_epochGroup,6,1,_detachedBuilding]
    execFSM "\z\cbe\addons\main\fsm\buildingOperation.fsm";
private _buildingFSMFinished=[{completedFSM _detachedBuildingFSM},10] call _wait;
["SCHED-detached-building-fsm-retires",_buildingFSMFinished] call _check;
["SCHED-detached-building-state-preserved",_buildingFSMFinished
    && {(_epochGroup getVariable ["CBE_BuildingBrain",createHashMap]) isEqualTo _registeredBuilding}
    && {(_registeredBuilding get "phase") == "SWEEP"}] call _check;
private _epochKey="CBE_QA_EPOCH_"+str diag_tickTime;
private _staleState=createHashMapFromArray [["group",_epochGroup],["ownerEpoch",5],["calls",0]];
[_coalesceCallback,_staleState,0,_epochKey] call CBE_fnc_CortexQueueJob;
private _epochQueued=(missionNamespace getVariable ["CBE_AIPass_Jobs",[]])
    +(missionNamespace getVariable ["CBE_AIPass_PendingJobs",[]]);
["SCHED-stale-epoch-not-queued",_epochQueued findIf {((_x select 2) getOrDefault ["jobKey",""]) == _epochKey} < 0] call _check;
["SCHED-stale-epoch-retained",(_staleState get "ownerEpoch") == 5,str (_staleState get "ownerEpoch")] call _check;
private _freshState=createHashMapFromArray [["group",_epochGroup],["calls",0]];
[_coalesceCallback,_freshState,0,_epochKey] call CBE_fnc_CortexQueueJob;
private _freshRan=[{(_freshState get "calls") == 1},10] call _wait;
["SCHED-current-epoch-runs",_freshRan && {(_freshState get "ownerEpoch") == 6}
    && {(_staleState get "calls") == 0},str [_freshState get "calls",_staleState get "calls"]] call _check;
private _oldEpochState=createHashMapFromArray [["group",_epochGroup],["ownerEpoch",6],["calls",0]];
private _newEpochState=createHashMapFromArray [["group",_epochGroup],["calls",0]];
// Change authority before either queued callback can run, even if the fixture is descheduled.
isNil {
    [_coalesceCallback,_oldEpochState,1,_epochKey] call CBE_fnc_CortexQueueJob;
    _epochGroup setVariable ["CBE_AIPass_Epoch",7];
    [_coalesceCallback,_newEpochState,0,_epochKey] call CBE_fnc_CortexQueueJob;
};
["SCHED-keyed-epoch-state-isolated",(_oldEpochState get "ownerEpoch") == 6] call _check;
private _epochsRetired=[{
    private _queued=(missionNamespace getVariable ["CBE_AIPass_Jobs",[]])
        +(missionNamespace getVariable ["CBE_AIPass_PendingJobs",[]]);
    (_newEpochState get "calls") == 1 && {_queued findIf {((_x select 2) getOrDefault ["jobKey",""]) == _epochKey} < 0}
},10] call _wait;
["SCHED-keyed-epoch-no-old-execution",_epochsRetired && {(_oldEpochState get "calls") == 0}
    && {(_newEpochState get "ownerEpoch") == 7},str [_oldEpochState get "calls",_newEpochState get "calls"]] call _check;
deleteGroup _epochGroup;
private _deletedGroup=createGroup [east,false];
private _deletedState=createHashMapFromArray [["group",_deletedGroup],["calls",0]];
isNil {
    [_coalesceCallback,_deletedState,1,"CBE_QA_DELETED_"+str diag_tickTime] call CBE_fnc_CortexQueueJob;
    deleteGroup _deletedGroup;
};
private _deletedRetired=[{(_deletedState getOrDefault ["skippedReason",""]) == "LOCALITY"},10] call _wait;
["SCHED-deleted-group-no-execution",_deletedRetired && {(_deletedState get "calls") == 0},str (_deletedState get "calls")] call _check;
private _cancelKey="CBE_QA_CANCELLED_"+str diag_tickTime;
private _cancelledState=createHashMapFromArray [["calls",0],["cancelled",true]];
private _replacementState=createHashMapFromArray [["calls",0]];
private _cancelAware={params ["_state"]; if (_state getOrDefault ["cancelled",false]) exitWith {-1}; _state set ["calls",(_state get "calls")+1]; -1};
[_cancelAware,_cancelledState,1,_cancelKey] call CBE_fnc_CortexQueueJob;
[_cancelAware,_replacementState,0,_cancelKey] call CBE_fnc_CortexQueueJob;
private _replacementRan=[{(_replacementState get "calls") == 1},10] call _wait;
["SCHED-cancelled-key-fresh-state",_replacementRan && {(_cancelledState get "calls") == 0}
    && {_cancelledState get "cancelled"},str [_cancelledState get "calls",_replacementState get "calls"]] call _check;
private _groups=[];
private _actors=[];
private _states=[];
for "_i" from 0 to 11 do {
    private _group=createGroup [east,true];
    _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setVariable ["CBE_AIPass_Exclude",true,true];
    private _unit=_group createUnit ["O_Soldier_F",[1800+_i*12,1700,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["CBE_CortexQA_Label",format ["QUEUED SQUAD %1",_i+1],true];
    private _target=[1800+_i*12,1780,0];
    _unit setVariable ["CBE_CortexQA_Target",_target,true];
    _group setCombatMode "BLUE";
    _group setBehaviourStrong "CARELESS";
    _groups pushBack _group; _actors pushBack _unit;
    _states pushBack createHashMapFromArray [["group",_group],["unit",_unit],["target",_target],["submitted",diag_tickTime],["first",-1],["complete",0]];
};
missionNamespace setVariable ["CBE_CortexQA_Actors",_actors,true];
["Scheduler: twelve physical movements","Twelve independent squads must walk 80 m to their markers. The real Cortex queue has its minimum 0.2 ms soft budget. Every job must start within ten seconds and retire once; accepted orders alone do not pass.",[1860,1740,0]] call _phase;
// Exercise independent runtime ownership through real CBA settings before measuring movements.
[createHashMapFromArray [["CBE_AIRebalance_Enable",true],["CBE_AIRebalance_Mode","DAY"],["CBE_AIRebalance_Profile","LINE"]]] call CBE_fnc_CortexTuning;
private _skillsReady = [{missionNamespace getVariable ["CBE_AI_RebalanceActive",false]},20] call _wait;
["SCHED-skill-start-prerequisite",_skillsReady] call _check;
private _skillActor = _actors select 0;
private _expectedSpot = _skillActor skill "spotDistance";
[createHashMapFromArray [["CBE_AIPass_Enable",false]]] call CBE_fnc_CortexTuning;
private _skillsOnly = [{!(missionNamespace getVariable ["CBE_AIPass_Active",false]) && {missionNamespace getVariable ["CBE_AI_RebalanceActive",false]}},20] call _wait;
["Scheduler: skills remain after tactics stop","The labelled soldier must retain skill updates while tactical jobs are disabled. This is a measured skill-layer check, not combat acceptance.",getPosATL _skillActor] call _phase;
_skillActor setVariable ["CBE_CortexQA_Label","SKILL REFRESH / TACTICS OFF",true];
_skillActor setSkill ["spotDistance",0];
_skillActor setVariable ["CBE_Cortex_LightingSignature",nil];
private _refreshLimit = (ceil ((count (missionNamespace getVariable ["CBE_Cortex_LightingUnits",[]])) / 10)) + 10;
private _refreshed = [{abs ((_skillActor skill "spotDistance")-_expectedSpot) < 0.01},_refreshLimit] call _wait;
["SCHED-skills-survive-tactics-stop",_skillsOnly && {_expectedSpot > 0} && {_refreshed},str [_expectedSpot,_skillActor skill "spotDistance"]] call _check;
[createHashMapFromArray [["CBE_AIRebalance_Enable",false]]] call CBE_fnc_CortexTuning;
private _allStopped = [{!(missionNamespace getVariable ["CBE_AI_RebalanceActive",false]) && {isNil {missionNamespace getVariable "CBE_AIPass_SchedulerHandle"}}},20] call _wait;
["SCHED-last-runtime-releases-callback",_allStopped] call _check;
[createHashMapFromArray [["CBE_AIPass_Enable",true]]] call CBE_fnc_CortexTuning;
["Scheduler: tactics without skills","With skill adjustment disabled, twelve real queued squads must still walk to their markers. Every job must start, physically arrive and retire once.",[1860,1740,0]] call _phase;
private _active=[{missionNamespace getVariable ["CBE_AIPass_Active",false]},20] call _wait;
["SCHED-active-prerequisite",_active] call _check;
{
    _x set ["submitted",diag_tickTime];
    [{
        params ["_state"];
        private _unit=_state get "unit";
        if (!alive _unit) exitWith {-1};
        if ((_state get "first") < 0) then {
            _state set ["first",diag_tickTime];
            _unit doMove (_state get "target");
        };
        if (_unit distance2D (_state get "target") <= 2) exitWith {
            _state set ["complete",(_state get "complete")+1];
            -1
        };
        0.25
    },_x,0] call CBE_fnc_CortexQueueJob;
} forEach _states;
private _arrived=[{_states findIf {(_x get "complete") != 1} < 0},90] call _wait;
private _delays=_states apply {if ((_x get "first") < 0) then {-1} else {(_x get "first")-(_x get "submitted")}};
["SCHED-no-start-starvation",_delays findIf {_x < 0 || {_x > 10}} < 0,str _delays] call _check;
["SCHED-every-squad-physical-arrival",_arrived && {_states findIf {!alive (_x get "unit") || {(_x get "unit") distance2D (_x get "target") > 2}} < 0},str (_states apply {(_x get "unit") distance2D (_x get "target")})] call _check;
sleep 5;
["SCHED-terminal-jobs-not-repeated",_states findIf {(_x get "complete") != 1} < 0,str (_states apply {_x get "complete"})] call _check;
{deleteVehicle _x} forEach _actors;
{deleteGroup _x} forEach _groups;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
// Isolated recovery boundary: the fixture deliberately replaces one retry with a native
// away leg. This measures real travel and recovery classification, not tactical completion.
private _recoveryGroup=createGroup [east,true];
_recoveryGroup setVariable ["CBE_Headless_ExcludeGroup",true,true];
_recoveryGroup setVariable ["acex_headless_blacklist",true,true];
private _recoveryActor=_recoveryGroup createUnit ["O_Soldier_F",[2350,1700,0],[],0,"NONE"];
_recoveryGroup setCombatMode "BLUE";
_recoveryGroup setBehaviourStrong "CARELESS";
private _recoveryOrigin=getPosATL _recoveryActor;
private _recoveryTarget=_recoveryOrigin vectorAdd [100,0,0];
private _recoveryOperation=[_recoveryGroup,"RECOVERY_DIAGNOSTIC",_recoveryTarget,[_recoveryActor],[_recoveryTarget],"MOVING"] call CBE_fnc_OperationStart;
private _recoveryGeneration=_recoveryOperation getOrDefault ["generation",-1];
private _recoveryAccepted=[_recoveryGroup,_recoveryGeneration,_recoveryActor,_recoveryTarget] call CBE_fnc_RecoveryStep;
private _freshRecoveryState=[_recoveryGroup,_recoveryGeneration,3,12] call CBE_fnc_OperationStep;
["RECOVERY-fresh-window-remains-active",_recoveryAccepted == "RECOVERING" && {_freshRecoveryState == "ACTIVE"}] call _check;
_recoveryActor doMove (_recoveryOrigin vectorAdd [-60,0,0]);
private _awayTravel=[{_recoveryActor distance2D _recoveryOrigin >= 10},25] call _wait;
private _awayOutcome=[_recoveryGroup,_recoveryGeneration,3,0] call CBE_fnc_OperationStep;
["RECOVERY-away-travel-prerequisite",_recoveryAccepted == "RECOVERING" && {_awayTravel}
    && {_recoveryActor distance2D _recoveryTarget > _recoveryOrigin distance2D _recoveryTarget}] call _check;
["RECOVERY-away-travel-does-not-renew",_awayTravel && {_awayOutcome == "STALLED"}
    && {_recoveryActor in ((_recoveryGroup getVariable ["CBE_Operation",createHashMap]) getOrDefault ["unavailable",[]])},str _awayOutcome] call _check;
[_recoveryGroup,_recoveryGeneration,"QA_FINISHED"] call CBE_fnc_OperationCancel;
deleteVehicle _recoveryActor;
deleteGroup _recoveryGroup;
// This section diagnoses the real FSM-to-existing-job bridge. It does not claim combat efficacy.
["Danger: event-to-decision handoff","A fresh ordinary squad keeps its MOVE route. A danger observation must wake its existing budgeted decision job, without revealing a target or creating another movement owner.",[2140,1740,0]] call _phase;
[createHashMapFromArray [["CBE_AIPass_Danger_Enable",true]]] call CBE_fnc_CortexTuning;
private _dangerGroup=createGroup [east,true];
_dangerGroup setVariable ["CBE_Headless_ExcludeGroup",true,true];
_dangerGroup setVariable ["acex_headless_blacklist",true,true];
private _observer=_dangerGroup createUnit ["O_Soldier_F",[2140,1700,0],[],0,"NONE"];
_observer setVariable ["CBE_CortexQA_Label","DANGER OBSERVER / ORDINARY MOVE",true];
missionNamespace setVariable ["CBE_CortexQA_Actors",[_observer],true];
_dangerGroup setBehaviourStrong "AWARE";
_dangerGroup setCombatMode "BLUE";
private _destination=[2140,1900,0];
_observer setVariable ["CBE_CortexQA_Target",_destination,true];
private _waypoint=_dangerGroup addWaypoint [_destination,0];
_waypoint setWaypointType "MOVE";
private _ready=[{count (_dangerGroup getVariable ["CBE_GroupBrain",createHashMap]) > 0
    && {
        private _listeners=_dangerGroup getVariable ["CBE_Danger_GroupHandlers",[]];
        count _listeners == 1 && {(_listeners select 0) param [0,""] == "EnemyDetected"}
    }},20] call _wait;
["DANGER-real-owner-brain-and-listener",_ready] call _check;
private _job=_dangerGroup getVariable ["CBE_GroupBrain",createHashMap];
private _now=time;
private _selected=[[ ["GUNFIRE",[0,0,0],_now,_now+2], ["HIT",[0,0,0],_now,_now+2], ["HIT",[1,0,0],_now-3,_now-1] ],_now] call CBE_fnc_DangerSelect;
["DANGER-priority-and-expiry",count _selected == 4 && {(_selected select 0) == "HIT"} && {(_selected select 1) isEqualTo [0,0,0]}] call _check;
// Require a truly sleeping existing job before measuring the event-driven wake.
private _sleeping=[{(missionNamespace getVariable ["CBE_AIPass_Jobs",[]]) findIf {
    (_x select 2) isEqualTo _job && {(_x select 0) > time+1.5}} >= 0},12] call _wait;
["DANGER-sleeping-job-prerequisite",_sleeping] call _check;
private _before=_job getOrDefault ["lastRunAt",-1];
private _requestedAt=time;
private _accepted=[_observer,"HIT",getPosATL _observer] call CBE_fnc_DangerRequest;
private _woken=[{(_job getOrDefault ["lastRunAt",-1]) > _before},1.4] call _wait;
["DANGER-event-wakes-existing-job",_ready && {_sleeping} && {_accepted} && {_woken},str [_before,_job getOrDefault ["lastRunAt",-1],time-_requestedAt]] call _check;
["DANGER-no-competing-job-owner",(_dangerGroup getVariable ["CBE_GroupBrain",createHashMap]) isEqualTo _job] call _check;
["DANGER-no-target-reveal",isNull assignedTarget _observer && {(_dangerGroup getVariable ["CBE_AIPass_AreaReport",[]]) isEqualTo []}] call _check;
private _origin=getPosATL _observer;
private _travel=[{_observer distance2D _origin >= 10},20] call _wait;
["DANGER-ordinary-route-continues",_travel && {waypointPosition _waypoint distance2D _destination < 1}] call _check;
[createHashMapFromArray [["CBE_AIPass_Danger_Enable",false]]] call CBE_fnc_CortexTuning;
["DANGER-disabled-rejects-observation",!([_observer,"HIT",getPosATL _observer] call CBE_fnc_DangerRequest)] call _check;
[_dangerGroup,true] call CBE_fnc_DangerSetup;
["DANGER-listener-cleanup",isNil {_dangerGroup getVariable "CBE_Danger_GroupHandlers"}
    && {isNil {_dangerGroup getVariable "CBE_Danger_Handlers"}}] call _check;
[createHashMapFromArray [["CBE_AIPass_Danger_Enable",true]]] call CBE_fnc_CortexTuning;
[_dangerGroup] call CBE_fnc_DangerSetup;
[_dangerGroup] call CBE_fnc_CortexZeusMark;
["DANGER-zeus-priority-rejects-observation",!([_observer,"HIT",getPosATL _observer] call CBE_fnc_DangerRequest)
    && {[_dangerGroup] call CBE_fnc_CortexZeusHeld}] call _check;
[_dangerGroup,true] call CBE_fnc_DangerSetup;
[_dangerGroup,true,"DANGER_DIAGNOSTIC_FINISHED"] call CBE_fnc_CortexReleaseGroup;
deleteVehicle _observer; deleteGroup _dangerGroup;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
[_saved] call CBE_fnc_CortexTuning;
