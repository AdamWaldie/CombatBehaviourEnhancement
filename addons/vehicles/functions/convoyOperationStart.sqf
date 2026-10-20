/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one owner-local finite convoy brain for a registered convoy snapshot.
 * Locality / Authority: Runs only where the convoy group is local. The FSM owns convoy intent and transitions; physical spacing and route work remains a bounded shared-scheduler callback.
 * Scheduler: CONVOY classification uses the convoy registry gate rather than infantry pause/enable state.
 * Repeat/JIP: Registry revision and local job token invalidate older brains after reconfiguration, JIP replay or locality migration. A matching live executor is reused. One unexpectedly ended nonterminal executor may
 * resume the exact brain on explicit admission; original spacing, pending callbacks and deadlines persist.
 * Missing metadata, terminal brains and exhausted recovery never report successful admission.
 * Arguments: 0 group <GROUP>; 1 configuration <ARRAY>; 2 registry revision <NUMBER>; 3 local job token <STRING>.
 * Return Value: Boolean - true when the current convoy brain exists on this owner.
 * Current callers: CBE_fnc_ConvoySync, its bounded registry maintenance callback and CBE_fnc_ConvoyHeadlessAdoptLocal.
 * Example: [convoyGroup,_configuration,4,"4:2:SYNC"] call CBE_fnc_ConvoyOperationStart;
 */
params [["_group",grpNull,[grpNull]],["_configuration",[],[[]]],["_registryRevision",-1,[0]],["_jobToken","",[""]]];
if (isNull _group || {!local _group} || {count _configuration < 8} || {_registryRevision < 0}) exitWith {false};
// Establish the owner epoch before the scheduler stamps this brain. The first convoy tick
// starts a common operation; letting it adopt an epoch-zero group there invalidates every
// later queued step and strands followers on their initial speed/path command.
if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {
    if ([_group,false,false,true] call CBE_fnc_CortexIsEligible) then {
        [_group,true] call CBE_fnc_CortexLocality;
    };
};
if (!local _group || {!(_group getVariable ["CBE_AIPass_Adopted",false])}) exitWith {false};
// Executor failure retires only this unchanged admission, through the existing native
// receipt cleanup. Retain a terminal brain so maintenance cannot recreate the task.
private _retireExecutor={
    params ["_failedBrain","_failure"];
    if ((_group getVariable ["CBE_Convoy_Brain",createHashMap]) isNotEqualTo _failedBrain
        || {(_failedBrain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {(_group getVariable ["CBE_Convoy_LocalJobToken",""]) != _jobToken}
        || {_registryRevision != (missionNamespace getVariable ["CBE_Convoy_ReceivedRevision",-2])}) exitWith {false};
    _failedBrain set ["cancelled",true];
    _failedBrain set ["finished",true];
    _failedBrain set ["pending",false];
    _failedBrain set ["cancelReason",_failure];
    [_group,false,[],[],_failure,_jobToken] call CBE_fnc_ConvoyReleaseLocal;
    if ((_group getVariable ["CBE_Convoy_Brain",createHashMap]) isEqualTo _failedBrain) then {
        _group setVariable ["CBE_Convoy_Brain_State",["FAILED",_configuration param [0,-1],_registryRevision,serverTime,_failure],true];
    };
    false
};
private _current=_group getVariable ["CBE_Convoy_Brain",createHashMap];
if (count _current > 0 && {(_current getOrDefault ["registryRevision",-2]) == _registryRevision}
    && {(_current getOrDefault ["jobToken",""]) isEqualTo _jobToken}) exitWith {
    if (_current getOrDefault ["cancelled",false] || {_current getOrDefault ["finished",false]}) exitWith {false};
    if ((_current getOrDefault ["group",grpNull]) != _group
        || {(_current getOrDefault ["configuration",[]]) isNotEqualTo _configuration}
        || {(_current getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {_registryRevision != (missionNamespace getVariable ["CBE_Convoy_ReceivedRevision",-2])}
        || {_jobToken != (_group getVariable ["CBE_Convoy_LocalJobToken",""])}
        || {[_group] call CBE_fnc_CortexZeusHeld}
        || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
    private _handle=_group getVariable ["CBE_Convoy_Brain_FSM",-1];
    if (_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}) exitWith {true};
    if ((_current getOrDefault ["executorRestarts",0]) >= 1) exitWith {[_current,"FSM_RESTART_EXHAUSTED"] call _retireExecutor};
    private _entry=(missionNamespace getVariable ["CBE_Convoy_LocalRegistry",[]]) findIf {_x isEqualTo [_group,_configuration]};
    if (_entry < 0) exitWith {false};
    // Resume the same brain, not the locality-adoption reset path. Pending callbacks
    // still own their original queue receipt; the FSM's existing watchdog observes them.
    _current set ["executorRestarts",1];
    _handle=[_group,_registryRevision,_configuration,_current] execFSM "\z\cbe\addons\main\fsm\convoyOperation.fsm";
    _group setVariable ["CBE_Convoy_Brain_FSM",_handle];
    private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
        && {(_group getVariable ["CBE_Convoy_Brain",createHashMap]) isEqualTo _current}
        && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])};
    if (!_started) then {[_current,"FSM_RESTART_FAILED"] call _retireExecutor};
    _started
};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _reason=toUpperANSI (_configuration param [8,"NONE"]);
private _phase=if ((_configuration param [5,"TRAVEL"]) == "HALT") then {switch (_reason) do {case "ARRIVED":{"ARRIVED"};case "AMBUSH":{"CONTACT_HOLD"};case "MANUAL":{"ORDERED_HOLD"};case "IMMOBILE":{"IMMOBILE"};default {"OBSTRUCTION"}}} else {"CRUISE"};
private _brain=createHashMapFromArray [["subsystem","CONVOY"],["ownerEpoch",_group getVariable ["CBE_AIPass_Epoch",0]],["executorRestarts",0],["group",_group],["configuration",_configuration],["registryRevision",_registryRevision],["jobToken",_jobToken],["phase",_phase],["pending",false],["completed",false],["finished",false],["cancelled",false],["cancelReason",""],["nextAt",time],["lastStepAt",-1],["lastDelay",-1],["queuedAt",-1],["watchdogCount",0],["spacingPairs",0],["recoveryActors",0]];
_group setVariable ["CBE_Convoy_Brain",_brain];
_group setVariable ["CBE_Convoy_Brain_State",[_phase,_configuration param [0,-1],_registryRevision,serverTime,"STARTED"],true];
private _handle=[_group,_registryRevision,_configuration,_brain] execFSM "\z\cbe\addons\main\fsm\convoyOperation.fsm";
_group setVariable ["CBE_Convoy_Brain_FSM",_handle];
private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
    && {(_group getVariable ["CBE_Convoy_Brain",createHashMap]) isEqualTo _brain}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])};
if (!_started) then {[_brain,"FSM_START_FAILED"] call _retireExecutor};
_started
