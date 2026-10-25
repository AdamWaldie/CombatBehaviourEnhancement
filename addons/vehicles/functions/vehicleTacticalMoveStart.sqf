/*
 * Author: WaldoTheWarfighter
 * Purpose: Admit one finite native standoff for the selected platform's original operating crew.
 * Locality/authority: Trusted current group/platform owner inside an admitted standoff operation.
 * Exact crew, operation generation/epoch, original route and acquired movement lease are required.
 * No group waypoint, membership, formation or unrelated actor order is changed.
 * Repeat/JIP: One public episode/reference, private exact finite FSM and original deadlines.
 * Pending native work blocks replacement even after ordinary lease expiry. Failed allocation
 * before ISSUE retires without native commands. New owners may adopt retirement only.
 * Arguments: group GROUP grpNull; platform OBJECT objNull; goal ARRAY of3 finite NUMBER,[];
 * original driver/commander ARRAY of2 OBJECT,[]; operation generation NUMBER,-1;
 * original server deadline NUMBER,-1, at most60 seconds ahead.
 * Return: BOOL native worker admitted, never acknowledgement or physical arrival.
 * Current callers: CortexVehicles standoff after OperationStart and movement lease acquisition.
 * Example: [_group,_apc,_point,[driver _apc,effectiveCommander _apc],_generation,_until]
 *     call CBE_fnc_VehicleTacticalMoveStart;
 */
params [["_group",grpNull,[grpNull]],["_battery",objNull,[objNull]],
    ["_spot",[],[[]]],["_seats",[],[[]]],["_generation",-1,[0]],["_until",-1,[0]]];
if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
    || {isNull _battery} || {!local _battery} || {count _spot != 3}
    || {_spot findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {count _seats != 2} || {_seats findIf {!(_x isEqualType objNull)} >= 0}
    || {!finite _generation} || {_generation < 0} || {_generation != floor _generation}
    || {!finite _until} || {_until <= serverTime} || {_until > serverTime+60}) exitWith {false};
private _started=false;
isNil {
    _started=call {
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
        private _publicLease=_group getVariable ["CBE_Cortex_MovementLease",[]];
        if (_epoch < 0 || {(_operation getOrDefault ["generation",-2]) != _generation}
            || {(_operation getOrDefault ["ownerEpoch",-2]) != _epoch}
            || {(_operation getOrDefault ["intent",""]) != "VEHICLE_STANDOFF"}
            || {(_operation getOrDefault ["phase",""]) == "CANCELLED"}
            || {_publicLease isNotEqualTo ["VEHICLE_STANDOFF",_until]}
            || {(_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []}
            || {(_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isNotEqualTo []}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {[] call CBE_fnc_CortexIsPaused}
            || {!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
            || {!([_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
            || {[_group] call CBE_fnc_CortexExternalTakeover}
            || {!([_group,_battery,_seats] call CBE_fnc_CortexVehicleCrewAvailable)}
            || {waterDamaged _battery}
            || {_seats findIf {!(currentCommand _x in ["","MOVE","WAIT"])} >= 0}) exitWith {false};
        private _baseline=[_seats select 0,_seats select 1] call CBE_fnc_VehicleCrewNativeObservation;
        if (count _baseline != 4 || {[0,2] findIf {(_baseline select _x) == "MOVE" && {
            private _goal=(_baseline select (_x+1)) param [0,[],[[]]];
            count _goal != 3 || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        }} >= 0}) exitWith {false};
        private _serial=(_battery getVariable ["CBE_VehicleTacticalMove_Serial",0])+1;
        private _token=format ["STANDOFF:%1:%2:%3",clientOwner,_epoch,_generation];
        private _reference=[_battery,_token,_serial,_epoch,clientOwner];
        private _lease=["VEHICLE_STANDOFF",time+(_until-serverTime)];
        private _work=createHashMapFromArray [["token",_token],["serial",_serial],["group",_group],
            ["kind","STANDOFF"],["operationGeneration",_generation],["owner",clientOwner],
            ["epoch",_epoch],["reference",_reference],["crew",+_seats],
            ["route",[_group] call CBE_fnc_NativeOrderReceipt],["baseline",_baseline],
            ["goal",+_spot],["spot",+_spot],["phase","ISSUE"],["moveUntil",_until],
            ["holdUntil",_until],["localLease",_lease],["progressPosition",getPosASL _battery],
            ["progressAt",serverTime],["release",false],["arrived",false]];
        _battery setVariable ["CBE_VehicleTacticalMove_Serial",_serial,true];
        _battery setVariable ["CBE_VehicleTacticalMove_Work",_work,true];
        _group setVariable ["CBE_VehicleTacticalMove_Reference",_reference,true];
        private _state=[_group] call CBE_fnc_CortexGroupState;
        _state set ["movementLease",_lease];_state set ["vehicleOperationGeneration",_generation];
        private _executorSerial=(_battery getVariable ["CBE_VehicleTacticalMove_ExecutorSerial",0])+1;
        _battery setVariable ["CBE_VehicleTacticalMove_ExecutorSerial",_executorSerial];
        private _handle=[_battery,_token,_serial,_executorSerial] execFSM "\z\cbe\addons\main\fsm\vehicleTacticalMove.fsm";
        _battery setVariable ["CBE_VehicleTacticalMove_FSM",[_serial,_handle,clientOwner,_epoch,_executorSerial]];
        if (!(_handle isEqualType 0) || {!finite _handle} || {_handle < 0}) exitWith {
            _work set ["phase","RETIRED"];_work set ["result","FSM_START_REFUSED"];
            _battery setVariable ["CBE_VehicleTacticalMove_Work",_work,true];
            _group setVariable ["CBE_VehicleTacticalMove_Reference",nil,true];
            if ((_state getOrDefault ["movementLease",[]]) isEqualTo _lease) then {_state deleteAt "movementLease"};
            if ((_state getOrDefault ["vehicleOperationGeneration",-1]) == _generation) then {_state deleteAt "vehicleOperationGeneration"};
            false
        };
        [_battery,"INSTALL",["CBE_VehicleTacticalMove_Work","CBE_VehicleTacticalMove_Reference","VEHICLE_STANDOFF"]]
            call CBE_fnc_VehicleCrewMoveDeletionWatch;
        true
    };
};
_started
