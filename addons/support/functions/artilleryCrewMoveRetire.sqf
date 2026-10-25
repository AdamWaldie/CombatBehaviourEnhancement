/*
 * Author: WaldoTheWarfighter
 * Purpose: Request retirement, or adopt retirement only after the selected-gun worker stops.
 * Locality/authority: Trusted local maintenance or server cancellation; vehicle and original
 * group must both be local. A live exact worker receives release without a second executor.
 * A locality change or failed worker can resume STOPPING/RETURNING observation, never outward
 * movement. Crew, original native route and external-control gates remain in the worker.
 * Repeat/JIP: Exact token/serial/public reference, private owner/epoch/handle and original
 * deadlines. One exact retirement-FSM creation refusal may retry inside its original cleanup
 * window, retaining the saved phase/native observations. No other unresolved reason reopens.
 * Unresolved work stays reserved while any original crew member survives or the gun
 * is moving. Once every original actor is dead/deleted and the gun is at rest, maintenance can
 * retire that exact reference without commands, replacement crew adoption or deadline renewal.
 * Arguments: 0 battery OBJECT,objNull; 1 token STRING,""; 2 serial NUMBER,-1.
 * Return: BOOL retirement worker active, not native stop, physical rest or returned authority.
 * Current callers: Position cancellation, CortexDiscover/CortexLocality maintenance and CortexStop.
 * Example: [_battery,_token,_serial] call CBE_fnc_ArtilleryCrewMoveRetire;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_serial",-1,[0]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2})
    || {isNull _battery} || {!local _battery} || {_token == ""}) exitWith {false};
private _pending=false;
isNil {
    _pending=call {
        private _work=_battery getVariable ["CBE_ArtilleryCrew_Work",createHashMap];
        if (count _work == 0 || {(_work getOrDefault ["token",""]) != _token}
            || {(_work getOrDefault ["serial",-2]) != _serial}) exitWith {false};
        private _group=_work getOrDefault ["group",grpNull];
        private _reference=_work getOrDefault ["reference",[]];
        private _phase=_work getOrDefault ["phase",""];
        if (isNull _group || {!local _group} || {count _reference != 5}
            || {(_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isNotEqualTo _reference}
            || {!(_phase in ["ISSUE","REQUESTED","MOVING","HOLD","STOPPING","RETURNING","UNRESOLVED"])}) exitWith {false};
        private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
        if (_epoch < 0) exitWith {false};
        private _executor=_battery getVariable ["CBE_ArtilleryCrew_FSM",[]];
        private _live=count _executor == 5 && {(_executor select 0) == _serial}
            && {(_executor select 2) == clientOwner} && {(_executor select 3) == _epoch}
            && {(_work get "owner") == clientOwner} && {(_work get "epoch") == _epoch}
            && {(_executor select 1) isEqualType 0} && {finite (_executor select 1)}
            && {(_executor select 1) >= 0} && {!completedFSM (_executor select 1)};
        // A refused FSM allocation never became a native stop/return observer. One
        // replacement may continue the exact saved retirement phase, not a fresh task.
        private _resumePhase=_work getOrDefault ["retirementResumePhase",""];
        private _retryCrew=_work getOrDefault ["crew",[]];
        private _retryUntil=_work getOrDefault ["cleanupUntil",-1];
        private _retryRefused=_phase == "UNRESOLVED" && {!_live}
            && {(_work getOrDefault ["result",""]) == "RETIREMENT_FSM_REFUSED"}
            && {(_work getOrDefault ["retirementFsmRetries",0]) isEqualTo 0}
            && {(_work getOrDefault ["release",false]) isEqualTo true}
            && {_resumePhase in ["ISSUE","REQUESTED","MOVING","HOLD","STOPPING","RETURNING"]}
            && {_retryUntil isEqualType 0} && {finite _retryUntil} && {serverTime < _retryUntil}
            && {_retryCrew isEqualType []} && {count _retryCrew == 2}
            && {_retryCrew findIf {!(_x isEqualType objNull)} < 0}
            && {_retryCrew findIf {!isNull _x && {alive _x}} >= 0};
        // No living original actor can retain our native movement order in this case.
        // Rest is measured independently: a dead driver alone does not stop a rolling gun.
        // Never adopt a replacement crew or remove a different operation's lease.
        if (_phase == "UNRESOLVED" && {!_retryRefused}) exitWith {
            private _originalCrew=_work getOrDefault ["crew",[]];
            private _linear=vectorMagnitude velocity _battery;
            private _angular=vectorMagnitude angularVelocity _battery;
            private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
            private _localLease=_state getOrDefault ["movementLease",[]];
            if (_live || {count _originalCrew != 2}
                || {_originalCrew findIf {!(_x isEqualType objNull) || {!isNull _x && {alive _x}}} >= 0}
                || {!finite _linear} || {!finite _angular} || {_linear >= 0.278} || {_angular >= 0.01}
                || {_localLease isNotEqualTo [] && {_localLease isNotEqualTo (_work get "localLease")}}) exitWith {false};
            if !([_group,"ARTILLERY_CREW",false] call CBE_fnc_CortexOwnershipLease) exitWith {false};
            private _terminal=+_work;
            _terminal set ["phase","RETIRED"];
            _terminal set ["result","ORIGINAL_CREW_LOST_AT_REST"];
            _battery setVariable ["CBE_ArtilleryCrew_Work",_terminal,true];
            _group setVariable ["CBE_ArtilleryCrew_Reference",nil,true];
            if (_localLease isNotEqualTo []) then {_state deleteAt "movementLease"};
            if ((_work getOrDefault ["kind","POSITION"]) == "SCOOT"
                && {(_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token}
                && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo (_work get "session")}) then {
                {_battery setVariable [_x,nil,true]} forEach ["CBE_Cortex_ArtilleryScootToken",
                    "CBE_Cortex_ArtilleryScootSession","CBE_Cortex_ArtilleryScootDeadline","CBE_Cortex_ArtilleryScootPurpose"];
            };
            false
        };
        private _journal=+_work;
        if (_retryRefused) then {
            _journal set ["phase",_resumePhase];
            _journal set ["retirementFsmRetries",1];
            _journal set ["result","RETIREMENT_FSM_RETRY_PENDING"];
        };
        _journal set ["release",true];
        if !("cleanupUntil" in _journal) then {
            _journal set ["cleanupUntil",(serverTime+30) min ((_work get "holdUntil")+30)];
        };
        if (_live) exitWith {
            _battery setVariable ["CBE_ArtilleryCrew_Work",_journal,true];
            true
        };
        // A lost machine-local handle is not native quiescence. Recreate only the finite
        // observer/retirement path, retaining both native reply and cleanup deadlines.
        if (serverTime >= (_journal get "cleanupUntil")) exitWith {
            _journal set ["phase","UNRESOLVED"];
            _journal set ["result","RETIREMENT_TIMEOUT"];
            _battery setVariable ["CBE_ArtilleryCrew_Work",_journal,true];
            false
        };
        private _adoptedReference=[_battery,_token,_serial,_epoch,clientOwner];
        _journal set ["owner",clientOwner];_journal set ["epoch",_epoch];
        _journal set ["reference",_adoptedReference];
        _battery setVariable ["CBE_ArtilleryCrew_Work",_journal,true];
        _group setVariable ["CBE_ArtilleryCrew_Reference",_adoptedReference,true];
        private _executorSerial=(_battery getVariable ["CBE_ArtilleryCrew_ExecutorSerial",0])+1;
        _battery setVariable ["CBE_ArtilleryCrew_ExecutorSerial",_executorSerial];
        private _retirementPhase=_journal get "phase";
        private _handle=[_battery,_token,_serial,_executorSerial] execFSM "\z\cbe\addons\main\fsm\artilleryCrewMove.fsm";
        _battery setVariable ["CBE_ArtilleryCrew_FSM",[_serial,_handle,clientOwner,_epoch,_executorSerial]];
        if (!(_handle isEqualType 0) || {!finite _handle} || {_handle < 0}) exitWith {
            _journal set ["retirementResumePhase",_retirementPhase];
            _journal set ["phase","UNRESOLVED"];
            _journal set ["result","RETIREMENT_FSM_REFUSED"];
            _battery setVariable ["CBE_ArtilleryCrew_Work",_journal,true];
            false
        };
        true
    };
};
_pending
