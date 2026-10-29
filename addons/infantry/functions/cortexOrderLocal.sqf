/*
 * Author: WaldoTheWarfighter
 * Executes an authenticated Zeus order only when the selected group is still local, then acknowledges its result.
 * Locality/authority: server authenticates dispatch; the current owner executes group commands.
 * Repeat/JIP: request tokens are consumed once; authored waypoint and Zeus control receipts
 * fence delayed work before mutation. The server-clock request deadline also prevents an
 * acknowledged timeout from later starting work. No stale order is replayed for JIP.
 * Failed task rollback restores only the unchanged temporary control token, owner epoch,
 * serial, task generations and native route. Capability-only refusal can restore unchanged
 * prior flags; a newer accepted task blocks rollback even without another module request.
 * Arguments: 0: token <STRING>; 1: task parameters <ARRAY> of named pairs.
 * Return Value: Nothing; reports actual owner acceptance.
 * Current callers: CBE_fnc_CortexOrderDispatch.
 * Example: [_token, _pairs] remoteExecCall ["CBE_fnc_CortexOrderLocal", groupOwner _group];
 */
params ["_token", "_pairs"];
if (remoteExecutedOwner != 2) exitWith {};
private _settings = createHashMapFromArray _pairs;
private _group = _settings getOrDefault ["group", grpNull];
if (isNull _group || {!local _group} || {(units _group) findIf {isPlayer _x} >= 0}) exitWith {
    [_token, false, false, clientOwner, "The squad changed owner or now contains a player."] remoteExecCall ["CBE_fnc_CortexOrderResult", 2];
};
private _serial = _settings getOrDefault ["requestSerial",-1];
private _deadline = _settings getOrDefault ["requestDeadline",-1];
private _receipt = _settings getOrDefault ["nativeReceipt",[]];
private _controlReceipt = _settings getOrDefault ["controlReceipt",[]];
private _currentControl = [
    _group getVariable ["CBE_AIPass_ZeusHold",[]],
    _group getVariable ["CBE_AIPass_ZeusWaypoints",false],
    _group getVariable ["CBE_AIPass_ZeusControlKind",""]
];
if (!(_deadline isEqualType 0) || {!finite _deadline} || {serverTime >= _deadline}
    || {!(_serial isEqualType 0)} || {_token != str _serial}
    || {_serial <= (_group getVariable ["CBE_Cortex_LastTaskSerial",-1])}
    || {_receipt isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
    || {_controlReceipt isNotEqualTo _currentControl}) exitWith {
    [_token,false,false,clientOwner,"The task expired, is stale, or newer native/Zeus control replaced it."] remoteExecCall ["CBE_fnc_CortexOrderResult",2];
};
_group setVariable ["CBE_Cortex_LastTaskSerial",_serial,true];
private _order = _settings getOrDefault ["order", ""];
private _position = _settings getOrDefault ["position", []];
private _radius = _settings getOrDefault ["radius", 50];
private _width = _settings getOrDefault ["width",_radius];
private _building = _settings getOrDefault ["building", objNull];
private _facing = _settings getOrDefault ["facing", 0];
private _sortByHeight = _settings getOrDefault ["sortByHeight",true];
private _teleport = _settings getOrDefault ["teleport",false];
if (!(_sortByHeight isEqualType true) || {!(_teleport isEqualType true)} || {!(_width isEqualType 0)} || {!(_facing isEqualType 0)}) exitWith {[_token,false,false,clientOwner,"Invalid task parameters."] remoteExecCall ["CBE_fnc_CortexOrderResult",2]};
private _patrolNodes=_settings getOrDefault ["patrolNodes",4];
private _patrolDuration=_settings getOrDefault ["patrolDuration",900];
if (_order == "PATROL" && {!(_radius isEqualType 0) || {!finite _radius} || {_radius < 25} || {_radius > 500}
    || {!(_patrolNodes isEqualType 0)} || {!finite _patrolNodes} || {_patrolNodes != floor _patrolNodes}
    || {_patrolNodes < 3} || {_patrolNodes > 8} || {!(_patrolDuration isEqualType 0)}
    || {!finite _patrolDuration} || {_patrolDuration < 30} || {_patrolDuration > 1800}
    || {!(_position isEqualType [])} || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) exitWith {
    [_token,false,false,clientOwner,"Invalid finite patrol parameters."] remoteExecCall ["CBE_fnc_CortexOrderResult",2];
};
private _arrivalRadius=_settings getOrDefault ["arrivalRadius",10];
private _pointDuration=_settings getOrDefault ["pointDuration",180];
if (_order == "ADVANCE_POINT" && {!(_arrivalRadius isEqualType 0)
    || {!finite _arrivalRadius} || {_arrivalRadius < 5} || {_arrivalRadius > 25}
    || {!(_pointDuration isEqualType 0)} || {!finite _pointDuration} || {_pointDuration < 30} || {_pointDuration > 300}
    || {!(_position isEqualType [])} || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) exitWith {
    [_token,false,false,clientOwner,"Invalid point-advance parameters."] remoteExecCall ["CBE_fnc_CortexOrderResult",2];
};
private _areaBuildings=_settings getOrDefault ["areaBuildings",4];
private _areaDuration=_settings getOrDefault ["areaDuration",900];
if (_order == "CLEAR_AREA" && {!(_radius isEqualType 0)
    || {!finite _radius} || {_radius < 10} || {_radius > 150}
    || {!(_areaBuildings isEqualType 0)} || {!finite _areaBuildings} || {_areaBuildings != floor _areaBuildings}
    || {_areaBuildings < 1} || {_areaBuildings > 8} || {!(_areaDuration isEqualType 0)}
    || {!finite _areaDuration} || {_areaDuration < 30} || {_areaDuration > 1800}
    || {!(_position isEqualType [])} || {count _position != 3}
    || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) exitWith {
    [_token,false,false,clientOwner,"Invalid finite area-clearance parameters."] remoteExecCall ["CBE_fnc_CortexOrderResult",2];
};
private _huntRange=_settings getOrDefault ["huntRange",800];
if (_order == "HUNT" && {!(_huntRange isEqualType 0) || {!finite _huntRange}
    || {_huntRange < 50} || {_huntRange > 2000} || {!(_patrolDuration isEqualType 0)}
    || {!finite _patrolDuration} || {_patrolDuration < 30} || {_patrolDuration > 1800}}) exitWith {
    [_token,false,false,clientOwner,"Invalid finite Hunt parameters."] remoteExecCall ["CBE_fnc_CortexOrderResult",2];
};
private _rushDuration=_settings getOrDefault ["rushDuration",180];
if (_order == "RUSH" && {!(_huntRange isEqualType 0) || {!finite _huntRange}
    || {_huntRange < 50} || {_huntRange > 2000} || {!(_rushDuration isEqualType 0)}
    || {!finite _rushDuration} || {_rushDuration < 30} || {_rushDuration > 300}}) exitWith {
    [_token,false,false,clientOwner,"Invalid finite attack parameters."] remoteExecCall ["CBE_fnc_CortexOrderResult",2];
};
private _reason = [_group,_order,_building] call CBE_fnc_CortexOrderReason;
if (_reason != "") exitWith {[_token,false,false,clientOwner,_reason] remoteExecCall ["CBE_fnc_CortexOrderResult",2]};
private _oldHold = _group getVariable ["CBE_AIPass_ZeusHold",[]];
private _oldWaypoints = _group getVariable ["CBE_AIPass_ZeusWaypoints",false];
private _oldControlKind = _group getVariable ["CBE_AIPass_ZeusControlKind",""];
private _executionEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _executionTaskKeys=["CBE_ClearAreaSerial","CBE_AIPass_ClearGeneration","CBE_AIPass_GarrisonGeneration",
    "CBE_AIPass_DefendGeneration","CBE_OperationGeneration"];
private _executionTasks=_executionTaskKeys apply {_group getVariable [_x,-1]};
private _temporaryControl=[];
if (_order in ["GARRISON", "DEFEND", "CLEAR", "AIRBORNE", "PATROL", "HUNT", "RUSH", "CLEAR_AREA", "ADVANCE_POINT"]) then {
    _group setVariable ["CBE_AIPass_ZeusControlKind",nil,true];
    _group setVariable ["CBE_AIPass_ZeusWaypoints", false, true];
    _group setVariable ["CBE_AIPass_ZeusHold", [random 1e6, 0], true];
    _temporaryControl=[_group getVariable ["CBE_AIPass_ZeusHold",[]],false,""];
};

private _previousClearFailure=_group getVariable ["CBE_Cortex_ClearAdmissionFailure",[]];
private _previousGarrisonFailure=_group getVariable ["CBE_Cortex_GarrisonAdmissionFailure",[]];
    private _accepted = switch (_order) do {
        case "ADVANCE_POINT": {["START",_group,[_position,_arrivalRadius,_pointDuration]] call CBE_fnc_PointAdvanceOperation};
        case "CLEAR_AREA": {["START",_group,[_position,_radius,_areaBuildings,_areaDuration]] call CBE_fnc_ClearAreaOperation};
        case "RUSH": {["START",_group,[_huntRange,_rushDuration]] call CBE_fnc_RushOperation};
        case "HUNT": {["START",_group,[_huntRange,_patrolDuration]] call CBE_fnc_HuntOperation};
        case "PATROL": {["START",_group,[_position,_radius,_patrolNodes,_patrolDuration]] call CBE_fnc_PatrolOperation};
        case "GARRISON": {[_group, _position, (_radius max 15) min 150, createHashMapFromArray [["teleport",_teleport],["sortByHeight",_sortByHeight]]] call CBE_fnc_CortexGarrison};
        case "DEFEND": {[_group, _position, _facing, (_width max 15) min 150] call CBE_fnc_CortexDefend};
        case "RELEASE": {
            private _areaReleased=["CANCEL",_group,["MODULE_RELEASE"]] call CBE_fnc_ClearAreaOperation;
            private _released = [_group] call CBE_fnc_CortexClearRelease;
            _released=_released || {_areaReleased};
            private _withdrawReleased=["CANCEL",_group] call CBE_fnc_PointWithdrawOperation;
            _released=_released || {_withdrawReleased};
            private _pointReleased=["CANCEL",_group] call CBE_fnc_PointAdvanceOperation;
            _released=_released || {_pointReleased};
            private _rushReleased=["CANCEL",_group] call CBE_fnc_RushOperation;
            _released=_released || {_rushReleased};
            private _patrolReleased=["CANCEL",_group,["MODULE_RELEASE"]] call CBE_fnc_PatrolOperation;
            _released=_released || {_patrolReleased};
            // Release automatic actor jobs too; no group-wide reset is needed to retire them.
            // Inspect every current member so reordered membership cannot hide an admitted actor.
            {
                if ((_x getVariable ["CBE_FiringPosition_Order",[]]) isNotEqualTo []) then {
                    ["RETIRE",_x] call CBE_fnc_FiringPositionOperation;
                };
                private _point=_x getVariable ["CBE_PointActor_Brain",createHashMap];
                if (count _point > 0 || {(_x getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo []}) then {
                    private _retiredPoint=["FINISH",_x,_point] call CBE_fnc_PointActorOperation;
                    _released=_released || {_retiredPoint};
                };
                private _indoor=_x getVariable ["CBE_IndoorActor_Brain",createHashMap];
                if (count _indoor > 0 || {(_x getVariable ["CBE_IndoorActor_Order",[]]) isNotEqualTo []}) then {
                    private _retired=["FINISH",_x,_indoor] call CBE_fnc_IndoorActorOperation;
                    _released=_released || {_retired};
                };
            } forEach units _group;
            if ((_group getVariable ["CBE_AIPass_Garrison", []]) isNotEqualTo []) then {
                private _garrisonReleased=[_group] call CBE_fnc_CortexGarrisonRelease;
                _released=_released || {_garrisonReleased};
            };
            if ((_group getVariable ["CBE_AIPass_Defend", []]) isNotEqualTo []) then {
                private _defendReleased=[_group] call CBE_fnc_CortexDefendRelease;
                _released=_released || {_defendReleased};
            };
            _released
        };
        case "EXCLUDE": {
            if (isNull _group) exitWith {false};
            [_group] call CBE_fnc_CortexClearRelease;
            [_group] call CBE_fnc_CortexGarrisonRelease;
            [_group] call CBE_fnc_CortexDefendRelease;
            [_group] call CBE_fnc_CortexReleaseGroup;
            _group setVariable ["CBE_AIPass_Exclude", true, true];
            true
        };
        case "RETURN": {
            if (isNull _group) exitWith {false};
            _group setVariable ["CBE_AIPass_Exclude", nil, true];
            _group setVariable ["CBE_AIPass_ZeusControlKind",nil,true];
            _group setVariable ["CBE_AIPass_ZeusWaypoints", false, true];
            // A zero-length token cancels any remaining Zeus hold on every machine.
            _group setVariable ["CBE_AIPass_ZeusHold", [random 1e6, 0], true];
            true
        };
        case "CLEAR": {[_group, _building] call CBE_fnc_CortexClearBuilding};
        case "AIRBORNE": {
            private _witnessCurrent=true;
            if ("passenger" in _settings || {"aircraft" in _settings}) then {
                private _passenger=_settings getOrDefault ["passenger",objNull];
                private _aircraft=_settings getOrDefault ["aircraft",objNull];
                _witnessCurrent=_passenger isEqualType objNull && {_aircraft isEqualType objNull}
                    && {!isNull _passenger} && {!isNull _aircraft} && {local _passenger}
                    && {group _passenger == _group} && {objectParent _passenger == _aircraft}
                    && {[_passenger] call CBE_fnc_CortexCombatEffective}
                    && {_aircraft isKindOf "Air"} && {!(_aircraft isKindOf "ParachuteBase")}
                    && {private _seats=(fullCrew [_aircraft,"cargo"])
                        +((fullCrew [_aircraft,"turret"]) select {_x select 4});
                        _seats findIf {(_x select 0) == _passenger} >= 0}
                    && {(units _group) findIf {alive _x && {local _x}
                        && {(vehicle _x) isKindOf "Air"} && {!((vehicle _x) isKindOf "ParachuteBase")}
                        && {vehicle _x != _aircraft}} < 0};
            };
            if (!_witnessCurrent) exitWith {false};
            [_group] call CBE_fnc_CortexAirborneDrop
        };
        default {false};
    };

private _garrisonFailure=_group getVariable ["CBE_Cortex_GarrisonAdmissionFailure",[]];
private _newGarrisonFailure=_order == "GARRISON" && {count _garrisonFailure == 3}
    && {_garrisonFailure isNotEqualTo _previousGarrisonFailure} && {(_garrisonFailure select 2) == _serial};
private _liveControl=[_group getVariable ["CBE_AIPass_ZeusHold",[]],
    _group getVariable ["CBE_AIPass_ZeusWaypoints",false],_group getVariable ["CBE_AIPass_ZeusControlKind",""]];
// Rollback owns only this exact temporary override. A newer order/owner/control token survives.
if (!_accepted && {_temporaryControl isNotEqualTo []}
    && {(_executionTaskKeys apply {_group getVariable [_x,-1]}) isEqualTo _executionTasks}
    && {local _group} && {(_group getVariable ["CBE_AIPass_Epoch",0]) == _executionEpoch}
    && {(_group getVariable ["CBE_Cortex_LastTaskSerial",-1]) == _serial}
    && {_liveControl isEqualTo _temporaryControl}
    && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _receipt}) then {
    _group setVariable ["CBE_AIPass_ZeusControlKind",_oldControlKind,true];
    _group setVariable ["CBE_AIPass_ZeusHold",_oldHold,true];
    _group setVariable ["CBE_AIPass_ZeusWaypoints",_oldWaypoints,true];
};
private _executionReason="No valid positions or eligible passengers were available. The order was not started.";
if (!_accepted && {_newGarrisonFailure}) then {
    _executionReason=switch (_garrisonFailure select 1) do {
        case "PLAN_CONTEXT_CHANGED": {"The squad's orders, owner or actors changed during planning. Garrison was not started and no earlier task was replaced."};
        case "NO_VALID_POSITIONS": {"No valid garrison positions were found in the selected area. No earlier task was replaced."};
        default {"Garrison planning was invalid or exceeded its bounded planning budget. No earlier task was replaced."};
    };
};
if (!_accepted && {_order == "RELEASE"}) then {
    _executionReason="No infantry task was released. There may be no matching task, or current native/owner control may still prevent handback.";
};
if (!_accepted && {_order == "ADVANCE_POINT"}) then {
    _executionReason="Advance was not started. Use a fully dismounted AI squad with capable armed fire teams, steady morale, a safe destination within2km and CBA Advance enabled. Existing tasks or protected native orders take priority.";
};
if (!_accepted && {_order == "CLEAR_AREA"}) then {
    _executionReason="Area clearance was not started. Use a fully dismounted AI squad with two capable soldiers and eligible nearby buildings; release existing tasks first. Partial traversal is never building safety.";
};
if (!_accepted && {_order == "RUSH"}) then {
    _executionReason="Attack was not started. Check fresh native contact, a fully dismounted AI squad with at least two capable soldiers, ammunition/ROE, steady morale, safe approach and enabled contact/advance/assault settings. Existing tasks, protected native orders or another controller also take priority.";
};
if (!_accepted && {_order == "HUNT"}) then {
    _executionReason="Hunt was not started. The squad needs recent native knowledge of a ground enemy, enabled contact behaviours and available foot soldiers. Release existing tasks first; module placement does not reveal a target.";
};
if (!_accepted && {_order == "PATROL"}) then {
    _executionReason="Patrol was not started. Use an available AI foot squad, release existing CBE tasks first, and choose valid dry ground. Newer orders or another controller take priority.";
};
if (!_accepted && {_order == "AIRBORNE"}) then {
    _executionReason="Airborne insertion was refused. Check the selected passenger, squad aircraft, altitude, dry land and AI pilots; newer orders or another controller also take priority.";
};
if (!_accepted && {_order == "CLEAR"}) then {
    private _failure=_group getVariable ["CBE_Cortex_ClearAdmissionFailure",[]];
    _executionReason="Clearance was refused by the current owner; inspect the selected squad and building.";
    if (count _failure >= 2 && {_failure isNotEqualTo _previousClearFailure}) then {
        _executionReason=switch (_failure select 1) do {
            case "TARGET_ABSENT": {"The selected building no longer exists."};
            case "TARGET_DESTROYED": {"The selected building is destroyed."};
            case "POSITION_BUDGET_EXCEEDED": {"The building reports too many positions for this bounded clearance task."};
            case "NO_VALID_ROOFED_POSITIONS": {"The building has no valid roofed internal positions to attempt."};
            case "NO_ELIGIBLE_ACTORS": {"No task-free, capable infantry are available to enter the building."};
            case "INVALID_TARGET_POSITION": {"The clearance target coordinates are invalid."};
            default {format ["Clearance refused: %1. No clearance was started.",_failure select 1]};
        };
    };
};
[_token, _accepted, false, clientOwner, if (_accepted) then {""} else {_executionReason}] remoteExecCall ["CBE_fnc_CortexOrderResult", 2];
