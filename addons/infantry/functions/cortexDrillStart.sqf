/*
 * Author: WaldoTheWarfighter
 * Natural admission transfers only exact completed CBE STOP holds into current-drill proof,
 * retiring their old recall tokens without issuing movement or creating a new hold deadline.
 * The full authored-order receipt freezes once for active execution and locality resume.
 * Purpose: Starts the finite scripted FSM which executes one accepted flank, advance, direct assault or coordinated
 * support bound. The FSM observes lifecycle completion; the shared scheduler owns tactical cadence; bounded tactical calculations and actor
 * commands remain in CortexFlankStep so one implementation serves every manoeuvre type.
 * Locality / Authority: Runs on the current group owner. It refuses remote groups and the FSM exits
 * when ownership or the drill token changes. No server-global scan is created.
 * Repeat/JIP: An accepted drill receives one token and one FSM. Repeated calls for the same live token
 * return success without starting another controller. JIP machines do not recreate owner-local FSMs;
 * locality recovery starts from the group state on its new owner.
 * Arguments:
 * 0: group <GROUP> - locally owned group with an accepted drill.
 * 1: drill token <STRING> - token stored in the group's Cortex state.
 * Return Value: Boolean - true only while the matching FSM is live. Failed startup releases
 * only this accepted drill through the existing exact-token cleanup; no alternate executor is queued.
 * Current callers: CortexFlankStart, CortexAdvanceStart, CortexAssaultStart, CortexSupportBoundStart and CortexDrillResume.
 * Example: [_group,_drill get "token"] call CBE_fnc_CortexDrillStart;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_token","",[""]]
];
if (isNull _group || {!local _group} || {_token == ""}) exitWith {false};

private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
private _drill=_state getOrDefault ["drill",createHashMap];
if (count _drill == 0 || {(_drill getOrDefault ["token",""]) != _token}
    || {(_drill getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {(_drill getOrDefault ["operationGeneration",-1]) != (_group getVariable ["CBE_OperationGeneration",0])}) exitWith {false};

private _existing=_group getVariable ["CBE_Cortex_DrillFSM",[]];
if (count _existing == 2 && {(_existing select 0) == _token} && {
    private _existingHandle=_existing select 1;
    _existingHandle isEqualType 0 && {finite _existingHandle} && {_existingHandle >= 0} && {!completedFSM _existingHandle}
}) exitWith {true};
// An ended executor is not permission to recreate the accepted drill. Retire its exact
// journals; a new tactical decision must obtain a new operation through normal admission.
private _registeredJob=_group getVariable ["CBE_Cortex_DrillFSMJob",createHashMap];
if ((count _existing == 2 && {(_existing select 0) == _token})
    || {(_registeredJob getOrDefault ["drillToken",""]) == _token}) exitWith {
    [_group,_state,"FSM_EXECUTOR_ENDED",_token] call CBE_fnc_CortexFlankEnd;
    false
};

// Freeze authored intent once at admission. Repeated callbacks/checkpoints cannot
// adopt an edited waypoint condition, script, attachment or synchronisation as baseline.
if (isNil {_drill get "authoredOrder"}) then {
    _drill set ["authoredOrder",[_group] call CBE_fnc_NativeOrderReceipt];
};
// Natural starts may inherit an exact completed CBE hold, never a bare native STOP.
// Move its passive proof into this already-accepted drill and retire the old recall token
// atomically. No actor command is issued and no acknowledgement interval is created.
if (_drill getOrDefault ["nativeAdmissionChecked",false]) then {
    isNil {
        private _liveState=_group getVariable ["CBE_AIPass_State",createHashMap];
        private _liveDrill=_liveState getOrDefault ["drill",createHashMap];
        if (!local _group || {_liveState isNotEqualTo _state} || {_liveDrill isNotEqualTo _drill}
            || {(_liveDrill getOrDefault ["token",""]) != _token}
            || {(_drill getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {(_drill getOrDefault ["operationGeneration",-1]) != (_group getVariable ["CBE_OperationGeneration",0])}) exitWith {};
        private _commands=_drill getOrDefault ["nativeCommands",createHashMap];
        private _adopted=[];
        {
            private _actor=_x;
            if (!(netId _actor in _commands) && {count _commands < 64}
                && {[_group,_state,_actor] call CBE_fnc_CortexHolderRecallOwned}) then {
                _commands set [netId _actor,[_actor,"HOLD",+(expectedDestination _actor),formLeader _actor,-1,[],[]]];
                _actor setVariable ["CBE_Cortex_HolderToken",nil,true];
                _adopted pushBack _actor;
            };
        } forEach ((_drill getOrDefault ["units",[]]) select [0,64]);
        if (_adopted isNotEqualTo []) then {
            _drill set ["nativeCommands",_commands];
            _state set ["holders",(_state getOrDefault ["holders",[]])-_adopted];
            _state set ["holderRecallReceipts",(_state getOrDefault ["holderRecallReceipts",[]]) select {
                !(_x isEqualType [] && {count _x == 8} && {(_x select 0) in _adopted})
            }];
        };
    };
};
private _handle=[_group,_token] execFSM "\z\cbe\addons\main\fsm\tacticalDrill.fsm";
private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle};
if (!_started) exitWith {
    // An accepted token is not evidence that an executor started. Keep the same owned
    // cleanup path, rather than bypassing the FSM with a second scheduler controller.
    [_group,_state,"FSM_START_FAILED",_token] call CBE_fnc_CortexFlankEnd;
    false
};

_group setVariable ["CBE_Cortex_DrillFSM",[_token,_handle]];
true
