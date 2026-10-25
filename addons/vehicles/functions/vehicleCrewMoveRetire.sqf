/*
 * Author: WaldoTheWarfighter
 * Purpose: Request or adopt finite selected-crew retirement without resuming outward movement.
 * Locality/authority: Internal trusted owner maintenance or authenticated server cancellation.
 * Platform and original group must be local. Exact token, serial, reference, owner epoch and
 * live worker identity protect reuse. The caller supplies its producer's fixed storage/FSM contract;
 * this function does not discover another producer, acquire new movement or adopt replacement crew.
 * Repeat/JIP: Reuses original native reply/cleanup clocks. An exact allocation refusal may retry
 * once within its original window. Other unresolved work stays reserved while an original actor
 * survives or the platform is moving, unless its original private worker has ended and its
 * recorded original return is positively acknowledged, or every surviving original operator
 * accepts a newer active STOP with measured platform rest. No command is issued for
 * either passive proof; STOP interrupts the task and never reports its physical completion.
 * Dead original crew plus measured rest can retire only the
 * matching reservation and lease. Worker loss is not proof of native quiescence.
 * Arguments: 0 platform OBJECT,objNull; 1 token STRING,""; 2 serial NUMBER,-1;
 * 3 fixed producer contract ARRAY of six nonempty STRING,[]:
 * [work key,group reference key,worker key,worker serial key,movement lease owner,FSM path].
 * Return: BOOL retirement worker pending/live, not physical stop or returned native authority.
 * Current callers: ArtilleryCrewMoveRetire with its fixed artillery storage and worker contract.
 * Example: [_vehicle,_token,_serial,_producerContract] call CBE_fnc_VehicleCrewMoveRetire;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_serial",-1,[0]],
    ["_contract",[],[[]]]];
if (count _contract != 6 || {_contract findIf {!(_x isEqualType "") || {_x == ""}} >= 0}) exitWith {false};
_contract params ["_workKey","_referenceKey","_fsmKey","_executorSerialKey","_leaseOwner","_fsmPath"];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2})
    || {isNull _battery} || {!local _battery} || {_token == ""}) exitWith {false};
private _pending=false;
isNil {
    _pending=call {
        private _work=_battery getVariable [_workKey,createHashMap];
        if (count _work == 0 || {(_work getOrDefault ["token",""]) != _token}
            || {(_work getOrDefault ["serial",-2]) != _serial}) exitWith {false};
        private _group=_work getOrDefault ["group",grpNull];
        private _reference=_work getOrDefault ["reference",[]];
        private _phase=_work getOrDefault ["phase",""];
        if (isNull _group || {!local _group} || {count _reference != 5}
            || {(_group getVariable [_referenceKey,[]]) isNotEqualTo _reference}
            || {!(_phase in ["ISSUE","REQUESTED","MOVING","HOLD","STOPPING","RETURNING","UNRESOLVED"])}) exitWith {false};
        private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
        if (_epoch < 0) exitWith {false};
        private _executor=_battery getVariable [_fsmKey,[]];
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
        // Passive return evidence needs an actual completed original private worker,
        // recorded original return orders and fresh local native acknowledgement.
        private _returnObserved=!_live && {_phase in ["RETURNING","UNRESOLVED"]}
            && {[_battery,_work,_executor,_battery getVariable [_executorSerialKey,-1]]
                call CBE_fnc_VehicleCrewMoveReturnProof};
        private _stopObserved=!_live && {_phase == "UNRESOLVED"}
            && {[_battery,_work,_executor,_battery getVariable [_executorSerialKey,-1],"EXTERNAL_STOP"]
                call CBE_fnc_VehicleCrewMoveReturnProof};
        // Otherwise only death of every original actor plus measured rest can retire
        // unresolved movement. Never infer handback from expiry, script loss or new seats.
        if ((_phase == "UNRESOLVED" && {!_retryRefused}) || {_returnObserved} || {_stopObserved}) exitWith {
            private _nativeRetired=_returnObserved || {_stopObserved} || {call {
                private _originalCrew=_work getOrDefault ["crew",[]];
                private _linear=vectorMagnitude velocity _battery;
                private _angular=vectorMagnitude angularVelocity _battery;
                if (count _originalCrew != 2
                    || {_originalCrew findIf {!(_x isEqualType objNull) || {!isNull _x && {alive _x}}} >= 0}
                    || {!finite _linear} || {!finite _angular} || {_linear >= 0.278} || {_angular >= 0.01}) exitWith {false};
                true
            }};
            private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
            private _localLease=_state getOrDefault ["movementLease",[]];
            private _publicLease=_group getVariable ["CBE_Cortex_MovementLease",[]];
            private _expectedPublic=[_leaseOwner,_work getOrDefault ["holdUntil",-1]];
            if (_live || {!_nativeRetired}
                || {_publicLease isNotEqualTo [] && {_publicLease isNotEqualTo _expectedPublic}}
                || {_localLease isNotEqualTo [] && {_localLease isNotEqualTo (_work get "localLease")}}) exitWith {
                // A passive deletion observer does not adopt this unresolved movement.
                [_battery,"INSTALL",[_workKey,_referenceKey,_leaseOwner]] call CBE_fnc_VehicleCrewMoveDeletionWatch;
                false
            };
            if !([_group,_leaseOwner,false] call CBE_fnc_CortexOwnershipLease) exitWith {false};
            private _terminal=+_work;
            _terminal set ["phase","RETIRED"];
            _terminal set ["result",if (_stopObserved) then {"NATIVE_STOP_OBSERVED_AFTER_WORKER"} else {
                ["ORIGINAL_CREW_LOST_AT_REST","NATIVE_RETURN_OBSERVED_AFTER_WORKER"] select _returnObserved
            }];
            _battery setVariable [_workKey,_terminal,true];
            _group setVariable [_referenceKey,nil,true];
            [_battery,"RELEASE",_reference] call CBE_fnc_VehicleCrewMoveDeletionWatch;
            if (_localLease isNotEqualTo []) then {_state deleteAt "movementLease"};
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
            _battery setVariable [_workKey,_journal,true];
            true
        };
        // A lost machine-local handle is not native quiescence. Recreate only the finite
        // observer/retirement path, retaining both native reply and cleanup deadlines.
        if (serverTime >= (_journal get "cleanupUntil")) exitWith {
            _journal set ["phase","UNRESOLVED"];
            _journal set ["result","RETIREMENT_TIMEOUT"];
            _battery setVariable [_workKey,_journal,true];
            false
        };
        private _adoptedReference=[_battery,_token,_serial,_epoch,clientOwner];
        _journal set ["owner",clientOwner];_journal set ["epoch",_epoch];
        _journal set ["reference",_adoptedReference];
        _battery setVariable [_workKey,_journal,true];
        _group setVariable [_referenceKey,_adoptedReference,true];
        [_battery,"INSTALL",[_workKey,_referenceKey,_leaseOwner]] call CBE_fnc_VehicleCrewMoveDeletionWatch;
        private _executorSerial=(_battery getVariable [_executorSerialKey,0])+1;
        _battery setVariable [_executorSerialKey,_executorSerial];
        private _retirementPhase=_journal get "phase";
        private _handle=[_battery,_token,_serial,_executorSerial] execFSM _fsmPath;
        _battery setVariable [_fsmKey,[_serial,_handle,clientOwner,_epoch,_executorSerial]];
        if (!(_handle isEqualType 0) || {!finite _handle} || {_handle < 0}) exitWith {
            _journal set ["retirementResumePhase",_retirementPhase];
            _journal set ["phase","UNRESOLVED"];
            _journal set ["result","RETIREMENT_FSM_REFUSED"];
            _battery setVariable [_workKey,_journal,true];
            false
        };
        true
    };
};
_pending
