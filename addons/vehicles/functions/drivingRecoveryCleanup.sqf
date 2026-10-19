/*
 * Author: WaldoTheWarfighter
 * Recovery is explicitly mode-bound: destination and SIMPLE_BACK have distinct native
 * ownership proof. Unknown modes grant no cleanup, adoption or command authority.
 * Purpose: Observes exact pending reverse-release receipts after tactical workers stop.
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
            "driverCommand","command","kind","cap","baseline","commandMode","simpleBefore","request","queueBinding"] apply {_work getOrDefault [_x,[]]}
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
    // Registration never consumes work. One service callback handles at most four tickets.
    if (isNull _vehicle) then {
        private _end=(_head+4) min count _queue;
        for "_index" from _head to (_end-1) do {
            private _id=_queue select _index;
            private _record=_registry getOrDefault [_id,[]];
            if (_record isNotEqualTo []) then {
                _record params ["_target","_proof"];
                private _current=_target getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                private _matching=!isNull _target && {local _target}
                    && {(_target getVariable ["CBE_DrivingRecovery_CleanupTicket",""]) == _id}
                    && {_current getOrDefault ["releasePending",false]}
                    && {!(_current getOrDefault ["releaseUnresolved",false])}
                    && {([_current] call _signature) isEqualTo _proof};
                if (_matching) then {
                    // Release may register the same ticket again; publish the active registry first.
                    localNamespace setVariable ["CBE_DrivingRecovery_Cleanup",_registry];
                    [_target,_current get "group"] call CBE_fnc_DrivingAssistRelease;
                    _current=_target getVariable ["CBE_DrivingRecovery_Work",createHashMap];
                    _matching=_current getOrDefault ["releasePending",false]
                        && {!(_current getOrDefault ["releaseUnresolved",false])}
                        && {([_current] call _signature) isEqualTo _proof};
                };
                if (_matching) then {_queue pushBack _id} else {
                    _registry deleteAt _id;
                    if (!isNull _target && {(_target getVariable ["CBE_DrivingRecovery_CleanupTicket",""]) == _id}) then {
                        _target setVariable ["CBE_DrivingRecovery_CleanupTicket",nil];
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
