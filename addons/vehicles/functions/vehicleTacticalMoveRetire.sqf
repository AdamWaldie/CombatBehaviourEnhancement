/*
 * Author: WaldoTheWarfighter
 * Purpose: Maintain or request retirement of the exact finite selected-platform tactical worker.
 * Locality/authority: Trusted owner maintenance or server cancellation; no new movement admission.
 * Maintenance leaves a current live worker alone. Shutdown requests retirement across the
 * controlled epoch edge. Shared retirement preserves original identities and cleanup clocks.
 * Repeat/JIP: Missing/nonlocal/foreign work is refused; no reference is cleared on a timer.
 * Dead-original-crew retirement ends only its matching generic operation, without native orders.
 * Arguments: platform OBJECT,objNull; token STRING,""; serial NUMBER,-1;
 * request retirement BOOL,false (true only for an explicit cancellation/shutdown request).
 * Return: BOOL current worker pending/live; never physical native handback proof.
 * Current callers: CortexDiscover, CortexLocality and CortexStop.
 * Example: [_apc,_token,_serial,true] call CBE_fnc_VehicleTacticalMoveRetire;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_serial",-1,[0]],
    ["_request",false,[true]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _battery}
    || {!local _battery} || {_token == ""}) exitWith {false};
private _pending=false;
isNil {
    _pending=call {
        private _work=_battery getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
        if ((_work getOrDefault ["token",""]) != _token
            || {(_work getOrDefault ["serial",-2]) != _serial}) exitWith {false};
        private _group=_work getOrDefault ["group",grpNull];
        if (isNull _group || {!local _group}) exitWith {false};
        private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
        private _executor=_battery getVariable ["CBE_VehicleTacticalMove_FSM",[]];
        private _live=count _executor == 5 && {(_executor select 0) == _serial}
            && {(_executor select 2) == clientOwner} && {(_executor select 3) == _epoch}
            && {(_work getOrDefault ["owner",-1]) == clientOwner}
            && {(_work getOrDefault ["epoch",-2]) == _epoch}
            && {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isEqualTo (_work get "reference")}
            && {(_executor select 1) isEqualType 0} && {finite (_executor select 1)}
            && {(_executor select 1) >= 0} && {!completedFSM (_executor select 1)};
        if (!_request && {_live}) exitWith {true};
        private _result=[_battery,_token,_serial,["CBE_VehicleTacticalMove_Work","CBE_VehicleTacticalMove_Reference",
            "CBE_VehicleTacticalMove_FSM","CBE_VehicleTacticalMove_ExecutorSerial","VEHICLE_STANDOFF",
            "\z\cbe\addons\main\fsm\vehicleTacticalMove.fsm"]] call CBE_fnc_VehicleCrewMoveRetire;
        private _after=_battery getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
        if ((_after getOrDefault ["token",""]) == _token && {(_after getOrDefault ["serial",-2]) == _serial}
            && {(_after getOrDefault ["phase",""]) == "RETIRED"}
            && {(_after getOrDefault ["result",""]) in ["ORIGINAL_CREW_LOST_AT_REST","NATIVE_RETURN_OBSERVED_AFTER_WORKER","NATIVE_STOP_OBSERVED_AFTER_WORKER"]}) then {
            private _generation=_after get "operationGeneration";
            private _reason=_after get "result";
            private _complete=_reason == "NATIVE_RETURN_OBSERVED_AFTER_WORKER"
                && {_after getOrDefault ["arrived",false]}
                && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_after get "route")};
            [_group,_generation,["INCOMPLETE","COMPLETE"] select _complete,_reason] call CBE_fnc_OperationRelease;
            private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
            if ((_state getOrDefault ["vehicleOperationGeneration",-1]) == _generation) then {
                _state deleteAt "vehicleOperationGeneration";
            };
        };
        _result
    };
};
_pending
