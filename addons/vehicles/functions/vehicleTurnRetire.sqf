/*
 * Author: WaldoTheWarfighter
 * Purpose: Retain exact tracked-vehicle turn proof until native stop/replacement observation.
 * Locality/authority: Current group and platform owner only; split locality retains proof.
 * RELEASE cancels the original turn, never starts or resumes travel. Changed native orders,
 * control seats, care, Zeus and external owners yield without a late stop command.
 * Repeat/JIP: Public group journal survives group-state cleanup and owner migration. Original
 * eight-second turn deadline plus30s bounds cleanup; one coalesced four-second CBA callback
 * survives addon shutdown. STOPTURNING is issued once, with proof published first; only a
 * subsequent invocation may observe its native NONE acknowledgement. No permanent worker,
 * world query, movement replay or deadline renewal. Terminal unresolved proof remains reserved.
 * Arguments: 0 group GROUP grpNull; 1 mode STRING SERVICE (RELEASE/CLEANUP also supported).
 * Return: BOOL true while a valid/unknown journal reserves movement, never physical success.
 * Current callers: CortexVehicles, OperationCancel/Release/Start, CortexRestoreCalm,
 * CortexReleaseGroup/Stop/Locality, DangerSetup and its finite cleanup callback.
 * Example: [group driver tank1,"RELEASE"] call CBE_fnc_VehicleTurnRetire;
 */
params [["_group",grpNull,[grpNull]],["_mode","SERVICE",[""]]];
if (isNull _group || {!local _group} || {!(_mode in ["SERVICE","RELEASE","CLEANUP"])}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _reserved=false;
isNil {
_reserved=call {
private _work=_group getVariable ["CBE_VehicleTurn_Work",createHashMap];
if (_work isEqualTo createHashMap) exitWith {false};
if (!(_work isEqualType createHashMap)) exitWith {true};
private _vehicle=_work getOrDefault ["vehicle",objNull];
private _marker=_work getOrDefault ["marker",[]];
private _nativeSeats=_work getOrDefault ["nativeSeats",[]];
private _hard=_work getOrDefault ["cleanupUntil",-1];
private _phase=_work getOrDefault ["phase",""];
if (!(_vehicle isEqualType objNull) || {!(_marker isEqualType [])} || {count _marker != 9}
    || {!((_marker select 1) isEqualType grpNull)} || {(_marker select 1) != _group}
    || {!((_marker select 2) isEqualType [])} || {count (_marker select 2) != 3}
    || {(_marker select 2) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {[0,3,4] findIf {!((_marker select _x) isEqualType 0) || {!finite (_marker select _x)} || {(_marker select _x) < 0}} >= 0}
    || {!((_marker select 5) isEqualType objNull)} || {!((_marker select 7) isEqualType objNull)}
    || {!((_marker select 6) isEqualType [])} || {!((_marker select 8) in ["LEFT","RIGHT"])}
    || {!(_nativeSeats isEqualType [])} || {count _nativeSeats != 2}
    || {_nativeSeats findIf {!(_x isEqualType []) || {count _x != 2}} >= 0}
    || {!(_hard isEqualType 0)} || {!finite _hard} || {_hard != (_marker select 3)+30}
    || {!(_phase in ["TURN","STOP"])}) exitWith {true};
private _finish={
    params ["_result"];
    if ((_group getVariable ["CBE_VehicleTurn_Work",createHashMap]) isEqualTo _work) then {
        _group setVariable ["CBE_VehicleTurn_Result",[_result,serverTime,+_marker],true];
        if (!isNull _vehicle && {local _vehicle}
            && {(_vehicle getVariable ["CBE_Danger_VehicleOrient",[]]) isEqualTo _marker}) then {
            _vehicle setVariable ["CBE_Danger_VehicleOrient",nil,true];
        };
        _group setVariable ["CBE_VehicleTurn_Work",nil,true];
        _group setVariable ["CBE_VehicleTurn_Cleanup",nil];
    };
    false
};
private _schedule={
    if (serverTime >= _hard) exitWith {
        private _last=_group getVariable ["CBE_VehicleTurn_Result",[]];
        if ((_last param [0,""]) != "UNRESOLVED_DEADLINE" || {(_last param [2,[]]) isNotEqualTo _marker}) then {
            _group setVariable ["CBE_VehicleTurn_Result",["UNRESOLVED_DEADLINE",serverTime,+_marker],true];
        };
    };
// One finite observation chain per original turn on this owner. Callback carries its exact
// ticket; a locality edge clears it and a successor turn can never consume the old callback.
if ((_group getVariable ["CBE_VehicleTurn_Cleanup",[]]) isEqualTo []) then {
    private _serial=1+(_group getVariable ["CBE_VehicleTurn_CleanupSerial",0]);
    _group setVariable ["CBE_VehicleTurn_CleanupSerial",_serial];
    private _ticket=[clientOwner,_serial,+_marker];
    _group setVariable ["CBE_VehicleTurn_Cleanup",_ticket];
    [{
        params ["_taskGroup","_ticket"];
        if (!isNull _taskGroup && {local _taskGroup}
            && {(_taskGroup getVariable ["CBE_VehicleTurn_Cleanup",[]]) isEqualTo _ticket}) then {
            _taskGroup setVariable ["CBE_VehicleTurn_Cleanup",nil];
            private _current=_taskGroup getVariable ["CBE_VehicleTurn_Work",createHashMap];
            if (_current isEqualType createHashMap
                && {(_current getOrDefault ["marker",[]]) isEqualTo (_ticket select 2)}) then {
                [_taskGroup,"CLEANUP"] call CBE_fnc_VehicleTurnRetire;
            };
        };
    },[_group,_ticket],4 min ((_hard-serverTime) max 0)] call CBA_fnc_waitAndExecute;
};
};
if (_mode != "SERVICE" && {!(_work getOrDefault ["cancelRequested",false])}) then {
    private _cancelCopy=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
    _cancelCopy set ["cancelRequested",true];
    _group setVariable ["CBE_VehicleTurn_Work",_cancelCopy,true];_work=_cancelCopy;
};
if (isNull _vehicle) exitWith {["PLATFORM_DELETED"] call _finish};
// No native reads, writes or inferred acknowledgement on a split platform/group arrival.
if (!local _vehicle) exitWith {call _schedule;true};
private _driver=_marker select 5;
private _commander=_marker select 7;
if (!isNull _driver && {!local _driver} || {!isNull _commander && {!local _commander}}) exitWith {call _schedule;true};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _currentGeneration=_group getVariable ["CBE_OperationGeneration",-1];
private _sameGeneration=_currentGeneration == (_marker select 4)
    && {count _operation == 0 || {(_operation getOrDefault ["generation",-2]) == (_marker select 4)}};
private _sameSeats=!isNull _driver && {!isNull _commander}
    && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _commander}
    && {group _driver == _group} && {group _commander == _group};
private _sameNative=_sameSeats
    && {[[currentCommand _driver,expectedDestination _driver],
        [currentCommand _commander,expectedDestination _commander]] isEqualTo _nativeSeats}
    && {(_marker select 6) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)};
private _available=_sameSeats && {alive _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {!([_vehicle] call CBE_fnc_CompatibilityExternalControl)}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {[_driver,_commander] findIf {isPlayer _x || {!simulationEnabled _x} || {isObjectHidden _x}
        || {!isNull remoteControlled _x} || {!([_x] call CBE_fnc_CortexCombatEffective)}
        || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
        || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}} < 0};
if (!_sameGeneration || {!_sameNative} || {!_available}
    || {(_vehicle getVariable ["CBE_Danger_VehicleOrient",[]]) isNotEqualTo _marker}) exitWith {
    ["YIELDED_TO_REPLACEMENT"] call _finish
};
private _input=vehicleMoveInfo _vehicle;
private _longitudinal=toUpperANSI (_input param [0,"",[""]]);
private _turn=toUpperANSI (_input param [1,"",[""]]);
if (_longitudinal in ["BACK","DIRECTBYCOMANDER"]
    || {!(_turn in ["NONE",_marker select 8])}) exitWith {["NATIVE_INPUT_REPLACED"] call _finish};
if (_phase == "STOP" && {_turn == "NONE"}) exitWith {["NATIVE_STOP_OBSERVED"] call _finish};
private _cancel=_mode != "SERVICE" || {_work getOrDefault ["cancelRequested",false]} || {serverTime >= (_marker select 3)}
    || {!((missionNamespace getVariable ["CBE_AIPass_Active",false]))}
    || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {(_work getOrDefault ["sourceOwner",-1]) != clientOwner}
    || {(_work getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {count _operation == 0 || {(_operation getOrDefault ["phase",""]) == "CANCELLED"}};
if (_phase == "TURN" && {!_cancel}) exitWith {true};
if (serverTime >= _hard) exitWith {
    private _last=_group getVariable ["CBE_VehicleTurn_Result",[]];
    if ((_last param [0,""]) != "UNRESOLVED_DEADLINE" || {(_last param [2,[]]) isNotEqualTo _marker}) then {
        _group setVariable ["CBE_VehicleTurn_Result",["UNRESOLVED_DEADLINE",serverTime,+_marker],true];
    };
    true
};
if (_phase == "TURN") then {
    private _next=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
    _next set ["phase","STOP"];_next set ["stopIssuedAt",serverTime];
    _group setVariable ["CBE_VehicleTurn_Work",_next,true];_work=_next;
    _vehicle sendSimpleCommand "STOPTURNING";
    _group setVariable ["CBE_VehicleTurn_Result",["STOP_PENDING",serverTime,+_marker],true];
};
call _schedule;
true
};
};
_reserved
