/*
 * Author: WaldoTheWarfighter
 * Spacing phase consumes only the current tick/revision gap observation; no duplicate transform scan.
 * Purpose: Executes one bounded physical convoy step and derives its semantic FSM phase from the authoritative snapshot, contact evidence, recovery leases and measured predecessor gaps.
 * Locality / Authority: Runs through CBE's shared scheduler on the convoy group owner. ConvoyTick rechecks authority at every vehicle command boundary.
 * Execution: A queued callback requires a live current FSM handle. Ended work retires
 * the callback only; existing restart admission retains all original task budgets/journals.
 * Repeat/JIP: One-shot callback. Registry revision, configuration identity and job token reject stale work after settings changes, JIP replay or headless migration.
 * Spacing diagnostics reuse ConvoyTick's cached vehicle dimensions and aligned forward-gap rule.
 * Public status updates immediately on semantic changes, otherwise at the first existing callback
 * after ten seconds. Local FSM execution is not throttled; a new brain publishes its first sample.
 * Arguments: 0 convoy brain <HASHMAP> created by CBE_fnc_ConvoyOperationStart.
 * Return Value: Number - always -1 because the FSM schedules each later step separately.
 * Current caller: CBE_fnc_ConvoyOperationQueue through CBE_fnc_CortexQueueJob.
 * Example: [_brain] call CBE_fnc_ConvoyOperationStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _group=_brain getOrDefault ["group",grpNull];private _configuration=_brain getOrDefault ["configuration",[]];private _registryRevision=_brain getOrDefault ["registryRevision",-1];private _token=_brain getOrDefault ["jobToken",""];
private _cancel={params ["_reason"];_brain set ["pending",false];_brain set ["completed",true];_brain set ["cancelled",true];_brain set ["cancelReason",_reason];-1};
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {[_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel};
if (isNull _group || {!local _group}) exitWith {["OWNERSHIP_LOST"] call _cancel};
if (_registryRevision != (missionNamespace getVariable ["CBE_Convoy_ReceivedRevision",-2]) || {_token isNotEqualTo (_group getVariable ["CBE_Convoy_LocalJobToken",""])}
    || {(_group getVariable ["CBE_Convoy_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {["REPLACED"] call _cancel};
// Queued jobs outlive their submitting FSM. The shared scheduler runs them on a later
// tick, after execFSM has published its handle. An ended executor grants no callback
// command authority. Preserve journals/budgets for the existing bounded restart path.
private _executor=_group getVariable ["CBE_Convoy_Brain_FSM",-1];
if (!(_executor isEqualType 0) || {!finite _executor} || {_executor < 0} || {completedFSM _executor}) exitWith {
    _brain set ["pending",false];_brain set ["completed",true];-1
};
private _entry=(missionNamespace getVariable ["CBE_Convoy_LocalRegistry",[]]) findIf {(_x select 0) isEqualTo _group && {(_x select 1) isEqualTo _configuration}};
if (_entry < 0) exitWith {["REPLACED"] call _cancel};
private _stepEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _stepCurrent={
    local _group && {_stepEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_registryRevision == (missionNamespace getVariable ["CBE_Convoy_ReceivedRevision",-2])}
        && {_token == (_group getVariable ["CBE_Convoy_LocalJobToken",""])}
        && {(_group getVariable ["CBE_Convoy_Brain",createHashMap]) isEqualTo _brain}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
        && {(_brain getOrDefault ["configuration",[]]) isEqualTo _configuration}
        && {((missionNamespace getVariable ["CBE_Convoy_LocalRegistry",[]]) param [_entry,[]]) isEqualTo [_group,_configuration]}
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}
};
if ([_group] call CBE_fnc_CortexZeusHeld) exitWith {["ZEUS"] call _cancel};
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {["EXTERNAL_OWNER"] call _cancel};
[_group,_configuration] call CBE_fnc_ConvoyTick;
if !(call _stepCurrent) exitWith {["REPLACED_DURING_TICK"] call _cancel};
private _state=_group getVariable ["CBE_Convoy_LocalState",createHashMap];private _reason=toUpperANSI (_configuration param [8,"NONE"]);private _phase="CRUISE";private _delay=1;private _spacingPairs=0;private _recoveryActors=0;
if ((_configuration param [5,"TRAVEL"]) == "HALT") then {
 // Slow cadence belongs to a physically settled hold, not merely an accepted HALT flag.
 // Keep bounded braking/crew correction responsive while any local vehicle still moves.
 private _haltMoving=(_configuration param [4,[]]) findIf {!isNull _x && {local _x} && {alive _x} && {abs speed _x >= 1}} >= 0;
 _delay=[30,1] select _haltMoving;_phase=switch (_reason) do {case "ARRIVED":{"ARRIVED"};case "AMBUSH":{"CONTACT_HOLD"};case "MANUAL":{"ORDERED_HOLD"};case "IMMOBILE":{"IMMOBILE"};default {"OBSTRUCTION"}};
} else {
 if (_state getOrDefault ["contact",false]) then {_phase="CONTACT_HOLD"};
 if ((_state getOrDefault ["routeRecoveryAt",-1]) > time) then {_recoveryActors=_recoveryActors+1};
 private _followers=_state getOrDefault ["followers",createHashMap];
 {if (((_followers getOrDefault [_x,[]]) param [4,0]) > 0) then {_recoveryActors=_recoveryActors+1}} forEach (keys _followers);
 // Consume this exact tick's measured gaps; do not recompute an obsolete projection
 // switch or read vehicle transforms a second time merely to publish an FSM phase.
 private _spacingObservation=_state getOrDefault ["spacingObservation",[]];
 if (count _spacingObservation == 3 && {(_spacingObservation select 0) == time}
     && {(_spacingObservation select 1) == (_configuration param [0,-1])}) then {
     _spacingPairs=_spacingObservation select 2;
 };
 if (_recoveryActors > 0) then {_phase="RECOVERY"} else {if (_phase != "CONTACT_HOLD" && {_spacingPairs > 0}) then {_phase="SPACING"}};
};
if ((_configuration param [5,""]) == "TRAVEL" && {_phase != "CONTACT_HOLD"}
    && {_state getOrDefault ["obstacleLimited",false]}) then {_phase="OBSTACLE"};
// Corridor intent describes the lead's existing writer, never an independent convoy controller.
private _corridorPhase=_state getOrDefault ["corridorPhase",""];
if ((_configuration param [5,""]) == "TRAVEL" && {_phase != "CONTACT_HOLD"}
    && {_corridorPhase in ["CORRIDOR_APPROACH","CORRIDOR_CROSS","CORRIDOR_TAIL"]}) then {_phase=_corridorPhase};
private _bypassPhase=_state getOrDefault ["bypassPhase",""];
if ((_configuration param [5,""]) == "TRAVEL" && {_phase != "CONTACT_HOLD"}
    && {_bypassPhase in ["BYPASS_PLAN","BYPASS_FOLLOW","BYPASS_TAIL"]}) then {_phase=_bypassPhase;_delay=1};
// A temporary tactical pause releases local leases but retains this registry brain.
// Describe suspension explicitly instead of publishing stale spacing/recovery roles.
if (_group getVariable ["CBE_Convoy_Suspended",false] || {_state getOrDefault ["ownerSuspended",false]}) then {
 _phase="SUSPENDED";_delay=5;_spacingPairs=0;_recoveryActors=0;
};
private _stepPublished=false;
isNil {
    if (!(call _stepCurrent)
        || {(_group getVariable ["CBE_Convoy_LocalState",createHashMap]) isNotEqualTo _state}) exitWith {};
    _brain set ["phase",_phase];_brain set ["spacingPairs",_spacingPairs];_brain set ["recoveryActors",_recoveryActors];_brain set ["lastStepAt",time];_brain set ["lastDelay",_delay];_brain set ["nextAt",time+_delay];_brain set ["pending",false];_brain set ["completed",true];
    // Execution completion is local even when the public diagnostic packet is unchanged.
    // Keep this cache on the current brain so a replacement/migrated owner publishes anew.
    private _statusKey=[_phase,_configuration param [0,-1],_registryRevision,_spacingPairs,_recoveryActors];
    private _lastStatusAt=_brain getOrDefault ["lastStatusAt",-1e9];
    if (_statusKey isNotEqualTo (_brain getOrDefault ["lastStatus",[]])
        || {serverTime-_lastStatusAt >= 10} || {serverTime < _lastStatusAt}) then {
        _group setVariable ["CBE_Convoy_Brain_State",[_phase,_configuration param [0,-1],_registryRevision,serverTime,"",_spacingPairs,_recoveryActors],true];
        _brain set ["lastStatus",_statusKey];_brain set ["lastStatusAt",serverTime];
    };
    _stepPublished=true;
};
if (!_stepPublished) exitWith {["REPLACED_DURING_PHASE"] call _cancel};
-1
