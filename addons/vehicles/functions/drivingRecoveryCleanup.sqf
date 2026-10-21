/*
 * Author: WaldoTheWarfighter
 * Ordinary unconfirmed cap release shares the four-ticket budget and its original deadline;
 * its cap-only callback never replays reverse, route, corridor, pass or bypass cleanup.
 * Recovery is explicitly mode-bound: destination and SIMPLE_BACK have distinct native
 * ownership proof. Unknown modes grant no cleanup, adoption or command authority.
 * Purpose: Observes exact pending reverse, ordinary-cap and released-cap queue-abort receipts after tactical workers stop.
 * Abort safety observations are throttled per receipt; all ticket types share the four-ticket service bound.
 * Locality / Authority: Local calls only, on the current vehicle owner. Existing release
 * guards alone authorize native handback and cap restoration; this service issues no rear leg.
 * Repeat/JIP: Deduplicated local tickets. Deleted, migrated, replaced or unresolved receipts retire tickets.
 * The exact release service publishes unresolved at the original hard deadline, retaining provenance
 * without further automatic tickets. This service never extends that lifetime.
 * DrivingRecoveryAdopt offers receipts at locality/init edges; delivery beyond its lookup window remains unresolved.
 * Arguments: 0 vehicle <OBJECT, objNull> registers its pending receipt; objNull services tickets.
 * Return Value: Nothing.
 * Current callers: DrivingAssistRelease, DrivingRecoveryRelease, DrivingRecoveryAdopt; its own CBA delayed callback.
 * Example: [truck1] call CBE_fnc_DrivingRecoveryCleanup;
 */
params [["_vehicle",objNull,[objNull]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2 || {isNull _vehicle}}) exitWith {};
// Atomic registration/service prevents two callbacks from consuming or replacing one ticket.
isNil {
    private _registry=localNamespace getVariable ["CBE_DrivingRecovery_Cleanup",createHashMap];
    private _queue=localNamespace getVariable ["CBE_DrivingRecovery_CleanupQueue",[]];
    private _head=localNamespace getVariable ["CBE_DrivingRecovery_CleanupHead",0];
    private _signature={
        params ["_work"];
        ["group","route","driver","operator","started","deadline","hardDeadline",
            "driverCommand","command","kind","cap","baseline","commandMode","simpleBefore","request","nativeReturn","queueBinding","rearEnvelope"] apply {_work getOrDefault [_x,[]]}
    };
    private _abortSignature={
        params ["_hold"];
        ["binding","group","route","driver","operator","owner","deadline","driverCommand",
            "command","driverLeader","operatorLeader","releasedCap"] apply {_hold getOrDefault [_x,[]]}
    };
    if (!isNull _vehicle && {local _vehicle}) then {
        private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        if (_work getOrDefault ["releasePending",false] && {!(_work getOrDefault ["releaseUnresolved",false])}
            && {(_work getOrDefault ["kind",""]) == "REVERSE"}
            && {(_work getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]}) then {
            private _proof=[_work] call _signature;
            private _existing=_vehicle getVariable ["CBE_DrivingRecovery_CleanupTicket",""];
            private _record=_registry getOrDefault [_existing,[]];
            if (_record isEqualTo [] || {!((_record select 1) isEqualTo _proof)}) then {
                private _serial=1+(localNamespace getVariable ["CBE_DrivingRecovery_CleanupSerial",0]);
                localNamespace setVariable ["CBE_DrivingRecovery_CleanupSerial",_serial];
                private _id=str _serial;
                _registry set [_id,[_vehicle,_proof]];
                _vehicle setVariable ["CBE_DrivingRecovery_CleanupTicket",_id];
                _queue pushBack _id;
            };
        };
    };
    if (!isNull _vehicle && {local _vehicle}) then {
        private _hold=_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap];
        if (_hold isEqualType createHashMap && {"releasedCap" in _hold}
            && {private _abortUntil=_hold getOrDefault ["deadline",-1];
                _abortUntil isEqualType 0 && {finite _abortUntil} && {serverTime < _abortUntil}}
            && {private _abortGroup=_hold getOrDefault ["group",grpNull];
                !isNull _abortGroup && {local _abortGroup}
                    && {(_hold getOrDefault ["owner",[]]) isEqualTo ([_abortGroup] call CBE_fnc_DrivingOwnerReceipt)}}) then {
            private _proof=[_hold] call _abortSignature;
            private _existing=_vehicle getVariable ["CBE_DrivingAbort_CleanupTicket",""];
            private _record=_registry getOrDefault [_existing,[]];
            if (_record isEqualTo [] || {!((_record select 1) isEqualTo _proof)}) then {
                private _serial=1+(localNamespace getVariable ["CBE_DrivingRecovery_CleanupSerial",0]);
                localNamespace setVariable ["CBE_DrivingRecovery_CleanupSerial",_serial];
                private _id=str _serial;
                _registry set [_id,[_vehicle,_proof,"ABORT"]];
                _vehicle setVariable ["CBE_DrivingAbort_CleanupTicket",_id];
                _queue pushBack _id;
            };
        };
    };
    if (!isNull _vehicle && {local _vehicle}) then {
        private _cap=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
        if (_cap isEqualType [] && {count _cap == 9}
            && {(_cap select 4) isEqualType 0} && {finite (_cap select 4)} && {serverTime < (_cap select 4)}) then {
            private _existing=_vehicle getVariable ["CBE_DrivingCapRelease_CleanupTicket",""];
            private _record=_registry getOrDefault [_existing,[]];
            if (_record isEqualTo [] || {(_record select 1) isNotEqualTo _cap}) then {
                private _serial=1+(localNamespace getVariable ["CBE_DrivingRecovery_CleanupSerial",0]);
                localNamespace setVariable ["CBE_DrivingRecovery_CleanupSerial",_serial];
                private _id=str _serial;
                _registry set [_id,[_vehicle,+_cap,"CAP"]];
                _vehicle setVariable ["CBE_DrivingCapRelease_CleanupTicket",_id];
                _queue pushBack _id;
            };
        };
    };
    // Registration never consumes work. One service callback handles at most four tickets.
    if (isNull _vehicle) then {
        private _end=(_head+4) min count _queue;
        for "_index" from _head to (_end-1) do {
            private _id=_queue select _index;
            private _record=_registry getOrDefault [_id,[]];
            if (_record isNotEqualTo []) then {
                _record params ["_target","_proof",["_kind","REVERSE"]];
                private _ticketVariable=["CBE_DrivingRecovery_CleanupTicket","CBE_DrivingAbort_CleanupTicket"] select (_kind == "ABORT");
                if (_kind == "CAP") then {_ticketVariable="CBE_DrivingCapRelease_CleanupTicket"};
                private _matching=false;
                if (_kind == "CAP") then {
                    _matching=!isNull _target && {local _target}
                        && {(_target getVariable [_ticketVariable,""]) == _id}
                        && {(_target getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo _proof}
                        && {count _proof == 9} && {serverTime < (_proof select 4)};
                    if (_matching) then {
                        localNamespace setVariable ["CBE_DrivingRecovery_Cleanup",_registry];
                        [_target,_proof select 2,true,_proof] call CBE_fnc_DrivingAssistRelease;
                        _matching=(_target getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo _proof
                            && {serverTime < (_proof select 4)}
                            && {((_target getVariable ["CBE_DrivingCapRelease_Result",[]]) param [0,""])
                                != "UNRESOLVED_HANDOVER"};
                    };
                    if (!_matching && {!isNull _target}
                        && {(_target getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo _proof}
                        && {serverTime >= (_proof select 4)}) then {
                        _target setVariable ["CBE_DrivingCapRelease_Result",["UNRESOLVED_DEADLINE",serverTime]];
                    };
                } else {
                if (_kind == "ABORT") then {
                    private _hold=_target getVariable ["CBE_DrivingAbort_Hold",createHashMap];
                    _matching=!isNull _target && {local _target}
                        && {(_target getVariable [_ticketVariable,""]) == _id}
                        && {_hold isEqualType createHashMap} && {([_hold] call _abortSignature) isEqualTo _proof}
                        && {private _abortUntil=_hold getOrDefault ["deadline",-1];
                            _abortUntil isEqualType 0 && {finite _abortUntil} && {serverTime < _abortUntil}}
                        && {private _abortGroup=_hold getOrDefault ["group",grpNull];
                            !isNull _abortGroup && {local _abortGroup}
                                && {(_hold getOrDefault ["owner",[]]) isEqualTo ([_abortGroup] call CBE_fnc_DrivingOwnerReceipt)}};
                    if (_matching) then {
                        [_target,_hold get "group",createHashMap,[],{true}] call CBE_fnc_DrivingAbortHandback;
                        private _after=_target getVariable ["CBE_DrivingAbort_Hold",createHashMap];
                        _matching=count _after > 0 && {([_after] call _abortSignature) isEqualTo _proof};
                    };
                } else {
                    private _current=_target getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                    _matching=!isNull _target && {local _target}
                        && {(_target getVariable ["CBE_DrivingRecovery_CleanupTicket",""]) == _id}
                        && {_current getOrDefault ["releasePending",false]}
                        && {!(_current getOrDefault ["releaseUnresolved",false])}
                        && {([_current] call _signature) isEqualTo _proof};
                    if (_matching) then {
                        // Release may register the same ticket again; publish the active registry first.
                        localNamespace setVariable ["CBE_DrivingRecovery_Cleanup",_registry];
                        if ((_current getOrDefault ["nativeReturn",[]]) isNotEqualTo []) then {
                            // Observe the return without turning an active driving episode into
                            // a general release. The executor retains its spent budget only for
                            // the exact live brain; cancelled/finished brains retire normally.
                            private _returnRetired=[_target,_current get "group","DEFERRED_HANDBACK"] call CBE_fnc_DrivingRecoveryRelease;
                            if (_returnRetired) then {[_target,_current get "group"] call CBE_fnc_DrivingAssistRelease};
                        } else {
                            [_target,_current get "group"] call CBE_fnc_DrivingAssistRelease;
                        };
                        _current=_target getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                        _matching=_current getOrDefault ["releasePending",false]
                            && {!(_current getOrDefault ["releaseUnresolved",false])}
                            && {([_current] call _signature) isEqualTo _proof};
                    };
                };
                };
                if (_matching) then {_queue pushBack _id} else {
                    _registry deleteAt _id;
                    if (!isNull _target && {(_target getVariable [_ticketVariable,""]) == _id}) then {
                        _target setVariable [_ticketVariable,nil];
                    };
                };
            };
        };
        _head=_end;
    };
    if (_head >= 128 && {_head*2 >= count _queue}) then {_queue=_queue select [_head];_head=0};
    if (count _registry == 0) then {_queue=[];_head=0};
    localNamespace setVariable ["CBE_DrivingRecovery_Cleanup",_registry];
    localNamespace setVariable ["CBE_DrivingRecovery_CleanupQueue",_queue];
    localNamespace setVariable ["CBE_DrivingRecovery_CleanupHead",_head];
    private _scheduled=localNamespace getVariable ["CBE_DrivingRecovery_CleanupScheduled",false];
    if (isNull _vehicle) then {_scheduled=false};
    if (count _registry > 0 && {!_scheduled}) then {
        [{[] call CBE_fnc_DrivingRecoveryCleanup},[],0.25] call CBA_fnc_waitAndExecute;
        _scheduled=true;
    };
    localNamespace setVariable ["CBE_DrivingRecovery_CleanupScheduled",_scheduled];
};
