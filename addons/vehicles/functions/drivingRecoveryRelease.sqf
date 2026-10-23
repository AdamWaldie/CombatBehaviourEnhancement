/*
 * Author: WaldoTheWarfighter
 * Native crew flight vetoes new steering and route recall; exact cap-only release remains separate.
 * Pending ACE care revokes native reverse handback just as its later HEAL command does; queues remain read-only.
 * Native BACK requires its explicit SIMPLE_BACK journal, original distinct crew and unchanged
 * turn/input receipt. An unowned BACK revokes stop/route handback and deferred retention.
 * Native STOP acknowledgement must also have finite measured rest before forward handback.
 * Queue reverse native returns require both operating actors at the original goal and retire
 * without creating another ordinary recovery allowance.
 * Existing owner cleanup observes a pending stop at zero owned cap; no timer or renewed deadline.
 * Recovery is explicitly mode-bound: destination and SIMPLE_BACK have distinct native
 * ownership proof. Unknown modes grant no cleanup, adoption or command authority.
 * Purpose: Retires a matching ordinary recovery journal; only its exact owned reverse can stop
 * and hand back to the unchanged plain authored or native MOVE. Forward retries retire metadata only.
 * Locality / Authority: Current vehicle/group owner. Original seats, both native destinations,
 * route, external/tactical ownership and crew tasks protect cleanup. No waypoint reconstruction.
 * Active fire, attack, service and other non-route commands forbid movement cleanup.
 * The current forced-speed cap must still match this journal before stopping or redirecting
 * a reverse. A changed cap retires metadata only; it never grants handback authority.
 * Effective-commander absence resolves to the driver exactly as at journal capture.
 * A native STOP or individual movement reservation overrides an unchanged destination receipt
 * and forbids movement cleanup; reservation state is never cleared by recovery release.
 * Pending destination requests retain their exact rear journal/cap without stop or route
 * commands. Expired unchanged requests remain uncertain within the original hard deadline;
 * expiry never proves native rejection or authorizes a replay.
 * On the exact current owner, an expired unacknowledged reverse can lower its owned
 * positive cap to zero while retaining command/baseline/deadline proof. This is a safety
 * cap, not acknowledgement or proof of physical stopping. An exact owned pending reverse
 * also lowers its cap at the original hard deadline when native stop remains uncertain,
 * including SIMPLE_BACK after the ordinary callback ends. Newer cap/task ownership wins.
 * Repeat/JIP: Public stage clocks and cap baseline survive migration without command replay.
 * Cleanup compares the current journal before clearing; newer work and commands remain untouched.
 * Admission, route metadata, native command checks and handback execute without suspension.
 * Split vehicle/group/crew locality preserves an unchanged issued reverse journal and cap
 * within the original hard deadline. Split-locality retention reads no crew destination
 * or command; expiry records unresolved proof without further automatic tickets.
 * This retention grants no commands and does not implement native-route owner adoption.
 * Changed seats/route/cap/native intent or external ownership revoke retention immediately.
 * An otherwise exactly owned reverse retains its journal while mobility/simulation prevents
 * handback. Receipt-only cleanup survives tactical shutdown only to the original hard deadline.
 * Expired unchanged handback becomes unresolved; its journal/cap remain and automatic retries stop.
 * Newer native orders can still retire metadata without replaying stale commands.
 * A leader on foot or without an eligible mounted target permits stopping our reverse only;
 * no crew follows a dismounted leader. Result field5 distinguishes native handback from a stop.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 reason <STRING, RELEASED>; 3 resume <BOOL, true> permits exact reverse handback.
 * Return Value: BOOL - matching journal retired, never physical recovery success; false also
 * reports deferred exact reverse handback while its journal remains public.
 * Current callers: DrivingAssistStart and DrivingAssistRelease.
 * Example: [truck1,group driver truck1,"DRIVING_RELEASED"] call CBE_fnc_DrivingRecoveryRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]]];
// No scheduled yield may separate the ownership proof from native commands or retirement.
private _released=false;
isNil {
    _released=call {
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
// Cleanup may run before the driving callback after driver death. Let the same
// live owner FSM observe its surviving commander's original reply first; do not
// classify a dead driver's destination or erase a converted forward budget.
private _casualtyBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
private _casualtyRoute=_work getOrDefault ["route",[]];
private _casualtyObserved=false;
if (_reason == "DEFERRED_HANDBACK" && {local _group}
    && {(_work getOrDefault ["nativeReturn",[]]) isNotEqualTo []}
    && {count _casualtyRoute == 9} && {(_casualtyRoute select 0) == "NATIVE_MOVE"}
    && {!alive (_casualtyRoute select 3)}
    && {(_casualtyBrain getOrDefault ["route",[]]) isEqualTo _casualtyRoute}) then {
    private _casualtyPending=[_group,_casualtyBrain] call CBE_fnc_DrivingRecoveryCrewHandback;
    _casualtyObserved=_casualtyPending
        || {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _work};
};
if (_casualtyObserved) exitWith {false};
// expectedDestination is local-argument. During staggered locality delivery, preserve
// only metadata proved by global seat identity and this local vehicle's exact cap.
// Do not run a native command classifier against a remote crew member.
private _splitDriver=driver _vehicle;private _splitOperator=effectiveCommander _vehicle;
if (isNull _splitOperator) then {_splitOperator=_splitDriver};
private _splitOwner=!local _group || {isNull _splitDriver} || {isNull _splitOperator}
    || {!local _splitDriver} || {!local _splitOperator};
private _splitRoute=_work getOrDefault ["route",[]];
private _nativeIssuerWaiting=_splitRoute isEqualType [] && {count _splitRoute == 9}
    && {(_splitRoute param [0,"",[""]]) == "NATIVE_MOVE"}
    && {(_splitRoute select 8) isNotEqualTo clientOwner
        || {(_splitRoute select 7) isNotEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}};
private _splitNativeCurrent=true;
if (!_splitOwner && {_nativeIssuerWaiting}) then {
    // A local crew may precede its group adoption callback. Classify on this owner
    // before deciding whether the inherited receipt was superseded; never erase an
    // unchanged native recovery merely because its issuer has not yet rebound.
    private _splitMode=_work getOrDefault ["commandMode","DESTINATION"];
    _splitNativeCurrent=false;
    if (_splitMode == "DESTINATION" || {"nativeReturn" in _work}) then {
        _splitNativeCurrent=([_vehicle,_work] call CBE_fnc_DrivingRecoveryCommandState) in ["OWNED","PENDING","EXPIRED"];
    } else {
        if (_splitMode == "SIMPLE_BACK" && {_splitDriver != _splitOperator}) then {
            private _splitInfo=vehicleMoveInfo _vehicle;
            _splitNativeCurrent=(_splitInfo param [1,""]) == ((_work getOrDefault ["simpleBefore",[]]) param [1,"MISSING"])
                && {toUpperANSI (_splitInfo param [0,""]) == "BACK"
                    || {_work getOrDefault ["simpleStopIssued",false] && {toUpperANSI (_splitInfo param [0,""]) == "STOP"}}
                    || {!(_work getOrDefault ["simpleAcknowledged",false])
                        && {_splitInfo isEqualTo (_work getOrDefault ["simpleBefore",[]])}}}
                && {(expectedDestination _splitDriver) isEqualTo (_work getOrDefault ["driverCommand",[]])}
                && {(expectedDestination _splitOperator) isEqualTo (_work getOrDefault ["command",[]])};
        };
    };
    _splitNativeCurrent=_splitNativeCurrent && {count waypoints _group <= 1}
        && {[_splitDriver,_splitOperator] findIf {!(currentCommand _x in ["","MOVE","WAIT"])
            && {!(currentCommand _x == "STOP" && {_work getOrDefault ["simpleStopIssued",false]})}} < 0};
};
if (_splitOwner || {_nativeIssuerWaiting}) exitWith {
    private _splitCap=_work getOrDefault ["cap",-1e9];
    private _splitExact=((_work getOrDefault ["kind",""]) == "REVERSE"
        || {(_work getOrDefault ["nativeReturn",[]]) isNotEqualTo []} || {_nativeIssuerWaiting})
        && {!isNull _splitDriver} && {!isNull _splitOperator}
        && {_splitNativeCurrent}
        && {_splitDriver isEqualTo (_work getOrDefault ["driver",objNull])}
        && {_splitOperator isEqualTo (_work getOrDefault ["operator",objNull])}
        && {group _splitDriver == _group} && {group _splitOperator == _group}
        && {_splitCap isEqualType 0} && {finite _splitCap}
        && {abs (getForcedSpeed _vehicle-_splitCap) <= 0.1};
    if (!_splitExact) exitWith {
        if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work) then {
            _vehicle setVariable ["CBE_DrivingRecovery_Work",nil,true];
            _vehicle setVariable ["CBE_DrivingRecovery_Result",[_reason,serverTime,_group,
                _work getOrDefault ["kind",""],_work getOrDefault ["hardDeadline",-1],"LOCALITY_PROOF_LOST"],true];
        };
        true
    };
    private _splitUntil=_work getOrDefault ["hardDeadline",-1];
    private _splitExpired=!(_splitUntil isEqualType 0) || {!finite _splitUntil} || {serverTime >= _splitUntil};
    private _splitChanged=!(_work getOrDefault ["releasePending",false])
        || {_splitExpired && {!(_work getOrDefault ["releaseUnresolved",false])}};
    if (_splitChanged) then {
        _work set ["releasePending",true];
        if (_splitExpired) then {_work set ["releaseUnresolved",true]};
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[_reason,serverTime,_group,
            _work getOrDefault ["kind",""],_splitUntil,
            ["DEFERRED_LOCALITY","UNRESOLVED_LOCALITY"] select _splitExpired],true];
    };
    if (!_splitExpired) then {[_vehicle] call CBE_fnc_DrivingRecoveryCleanup;};
    false
};
// Shutdown can follow an already-issued temporary-path forward return. Preserve the
// original request as observation-only cleanup; do not classify it as a rear command,
// issue another move, or invent a later acknowledgement/deadline.
if (_resume && {_reason == "DRIVING_RELEASED"} && {"bypassReturn" in _work}
    && {((_work getOrDefault ["route",[]]) param [0,"",[""]]) == "NATIVE_MOVE"}
    && {(_work getOrDefault ["request",[]]) isNotEqualTo []}
    && {([_vehicle,_work] call CBE_fnc_DrivingRecoveryCommandState) in ["OWNED","PENDING","EXPIRED"]}) then {
    _work set ["nativeReturn",+(_work get "request")];
    _work deleteAt "request";
    _work set ["releasePending",true];
    _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
};
// A native-route return was already issued. Observe only; never replay that doMove.
if ((_work getOrDefault ["nativeReturn",[]]) isNotEqualTo []) exitWith {
    private _returnState=[_vehicle,_work] call CBE_fnc_DrivingRecoveryCommandState;
    // An observed command reply does not own a replaced speed cap.
    private _returnCap=_work getOrDefault ["cap",-1e9];
    if (!(_returnCap isEqualType 0) || {!finite _returnCap}
        || {abs (getForcedSpeed _vehicle-_returnCap) > 0.1}) then {_returnState="LOST"};
    if (_returnState in ["PENDING","EXPIRED"]) exitWith {
        if (_returnState == "EXPIRED" && {!(_work getOrDefault ["releaseUnresolved",false])}) then {
            _work set ["releasePending",true];_work set ["releaseUnresolved",true];
            _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
            _vehicle setVariable ["CBE_DrivingRecovery_Result",[_reason,serverTime,_group,
                _work get "kind",_work get "hardDeadline","NATIVE_RETURN_UNRESOLVED"],true];
        };
        false
    };
    // Active driving continues its original spent episode after observed return. Never
    // delete this budget and let the next tick create a fresh reverse allowance.
    private _returnBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
    private _returnRoute=_work getOrDefault ["route",[]];
    private _returnAssist=+(_vehicle getVariable ["CBE_DrivingAssist_State",[]]);
    if (_returnState == "OWNED" && {_reason == "DEFERRED_HANDBACK"}
        && {!((_work getOrDefault ["kind",""]) in ["QUEUE_RETURN","PASS_RETURN"])}
        && {local _group} && {count _returnRoute == 9}
        && {count _returnAssist >= 11} && {(_returnAssist select 3) isEqualTo _group}
        && {(_returnAssist select 9) isEqualTo _returnRoute}
        && {(_returnRoute select 7) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_returnRoute select 8) isEqualTo clientOwner}
        && {!(_returnBrain getOrDefault ["cancelled",true])} && {!(_returnBrain getOrDefault ["finished",true])}
        && {(_returnBrain getOrDefault ["route",[]]) isEqualTo _returnRoute}
        && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work}) exitWith {
        _work deleteAt "nativeReturn";_work deleteAt "releasePending";_work deleteAt "releaseUnresolved";
        _work deleteAt "bypassReturn";
        _work set ["kind","FINAL"];_work set ["commandMode","DESTINATION"];
        _work set ["deadline",_work get "hardDeadline"];
        _work set ["driverCommand",+(expectedDestination driver _vehicle)];
        private _returnOperator=effectiveCommander _vehicle;
        if (isNull _returnOperator) then {_returnOperator=driver _vehicle};
        _work set ["command",+(expectedDestination _returnOperator)];
        if (count _returnAssist >= 11) then {
            _returnAssist set [6,3];_returnAssist set [7,time+((_work get "hardDeadline")-serverTime)];
            _returnAssist set [8,"NATIVE_RETURN_OBSERVED"];_returnAssist set [10,false];
            _vehicle setVariable ["CBE_DrivingAssist_State",_returnAssist];
        };
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        false
    };
    if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work) then {
        _vehicle setVariable ["CBE_DrivingRecovery_Work",nil,true];
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[_reason,serverTime,_group,
            _work get "kind",_work get "hardDeadline",
            ["NATIVE_RETURN_SUPERSEDED","NATIVE_ROUTE_OBSERVED"] select (_returnState == "OWNED")],true];
    };
    true
};
// This executor restores destination commands only, never a different native command mode.
private _commandMode=_work getOrDefault ["commandMode","DESTINATION"];
if !(_commandMode in ["DESTINATION","SIMPLE_BACK"]) exitWith {false};
// A blocked exact handback has only the original recovery lifetime. Expiry preserves
// command/cap provenance but never grants a late command or a newly renewed cleanup window.
// Call this only after proving unchanged ownership; newer orders still retire metadata normally.
private _releaseExpired={
    if (!_resume || {!(_work getOrDefault ["releasePending",false])}) exitWith {false};
    private _until=_work getOrDefault ["hardDeadline",-1];
    private _invalid=!(_until isEqualType 0) || {!finite _until} || {_until < 0};
    if (!(_work getOrDefault ["releaseUnresolved",false]) && {!_invalid} && {serverTime < _until}) exitWith {false};
    if !(_work getOrDefault ["releaseUnresolved",false]) then {
        _work set ["releaseUnresolved",true];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        private _outcome=["UNRESOLVED_DEADLINE","UNRESOLVED_INVALID_DEADLINE"] select _invalid;
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[
            _reason,serverTime,_group,_work get "kind",_until,_outcome
        ],true];
        diag_log format ["CBE driving cleanup %1: vehicle=%2 group=%3 originalDeadline=%4",_outcome,netId _vehicle,_group,_until];
    };
    true
};
private _commandState="OWNED";
if (_commandMode == "DESTINATION") then {
    _commandState=[_vehicle,_work] call CBE_fnc_DrivingRecoveryCommandState;
    if (_commandState == "OWNED" && {"request" in _work}
        && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work}
        && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
        && {abs ((getForcedSpeed _vehicle)-(_work get "cap")) <= 0.1}) then {
        _work set ["driverCommand",+(expectedDestination driver _vehicle)];
        private _ackOperator=effectiveCommander _vehicle;
        if (isNull _ackOperator) then {_ackOperator=driver _vehicle};
        _work set ["command",+(expectedDestination _ackOperator)];_work deleteAt "request";
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
    };
};
private _simpleInfo=vehicleMoveInfo _vehicle;
private _queueStopped="queueBinding" in _work && {_work getOrDefault ["queueStopAcknowledged",false]};
private _destinationControlFree=if (_commandMode == "SIMPLE_BACK") then {
    (_work getOrDefault ["driver",objNull]) != (_work getOrDefault ["operator",objNull])
        && {(_simpleInfo param [1,""]) == ((_work getOrDefault ["simpleBefore",[]]) param [1,"MISSING"])}
        && {toUpperANSI (_simpleInfo param [0,""]) == "BACK" && {!_queueStopped}
            || {_work getOrDefault ["simpleStopIssued",false] && {toUpperANSI (_simpleInfo param [0,""]) == "STOP"}}
            || {!(_work getOrDefault ["simpleAcknowledged",false]) && {!_queueStopped}
                && {_simpleInfo isEqualTo (_work getOrDefault ["simpleBefore",[]])}}}
} else {toUpperANSI (_simpleInfo param [0,"",[""]]) != "BACK"};
private _driver=_work get "driver";private _operator=_work get "operator";
private _liveOperator=effectiveCommander _vehicle;
if (isNull _liveOperator) then {_liveOperator=driver _vehicle};
// Vehicle locality can arrive before group/crew locality. Do not mistake that gap
// for revoked command identity and erase the only public cleanup receipt. This proof
// permits retention only; ordinary handback below still requires every actual owner.
private _retainAcrossLocality=_resume && {_destinationControlFree} && {(_work get "kind") == "REVERSE"}
    && {alive _vehicle} && {!isNull _group} && {!isNull _driver} && {!isNull _operator}
    && {driver _vehicle == _driver} && {_liveOperator == _operator}
    && {abs ((getForcedSpeed _vehicle)-(_work get "cap")) <= 0.1}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
    && {[_driver,_operator] findIf {
        !alive _x || {fleeing _x} || {group _x != _group} || {vehicle _x != _vehicle}
            || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
            || {(_x getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo []}
            || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
            || {!(toUpperANSI currentCommand _x in ["","MOVE","WAIT"])}
    } < 0};
// Both call sites separately establish exact reverse ownership. This helper only
// lowers that same cap, preserving command/baseline/deadline provenance.
private _holdOwnedRearCap={
    private _expiredCap=_work get "cap";
    private _assistState=+(_vehicle getVariable ["CBE_DrivingAssist_State",[]]);
    if (_expiredCap > 0
        && {local _group} && {local _driver} && {local _operator}
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {[_group] call CBE_fnc_DrivingMovementAvailable}
        && {[_driver,_operator] findIf {!([_x] call CBE_fnc_CortexCombatEffective)
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} < 0}
        && {(_assistState param [3,grpNull]) == _group}
        && {(_assistState param [0,-2]) == _expiredCap}
        && {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isEqualTo (_work get "baseline")}
        && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work}) then {
        private _heldWork=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
        _heldWork set ["cap",0];_assistState set [0,0];
        _vehicle forceSpeed 0;
        _vehicle setVariable ["CBE_DrivingAssist_State",_assistState];
        _vehicle setVariable ["CBE_DrivingAssist_Traffic",[0,_vehicle,-1,time,0]];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_heldWork,true];
        _work=_heldWork;
    };
};
// Pending/expired unchanged destination requests do not prove rejection of an issued
// rear move. Retain its exact safety journal/cap; only acknowledged command proof can
// authorize stop/handback. The original hard deadline still bounds automatic observation.
if (_retainAcrossLocality && {_commandState in ["PENDING","EXPIRED"]}) exitWith {
    // An unacknowledged doMove may already be acting. After its original ACK
    // window, retaining a positive cap would let that uncertain rear request run
    // while the ordinary callback yields to cleanup. Only lower our exact lease;
    // never stop/replay a command whose native acknowledgement is still unknown.
    if (_commandState == "EXPIRED") then {call _holdOwnedRearCap};
    if (call _releaseExpired) exitWith {false};
    if !(_work getOrDefault ["releasePending",false]) then {
        _work set ["releasePending",true];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[
            _reason,serverTime,_group,_work get "kind",_work get "hardDeadline","DEFERRED_NATIVE_ACK"
        ],true];
    };
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
    false
};
private _handback="METADATA_ONLY";
private _owned=_resume && {_commandState == "OWNED"} && {_destinationControlFree} && {(_work get "kind") == "REVERSE"}
    && {alive _vehicle}
    && {local _group} && {!isNull _driver} && {!isNull _operator}
    && {driver _vehicle == _driver} && {_liveOperator == _operator}
    && {abs ((getForcedSpeed _vehicle)-(_work get "cap")) <= 0.1}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {[_group] call CBE_fnc_DrivingMovementAvailable}
    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}};
{
    _owned=_owned && {!isNull _x} && {local _x} && {group _x == _group} && {vehicle _x == _vehicle}
        && {!fleeing _x} && {[_x] call CBE_fnc_CortexCombatEffective}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)} && {!isPlayer _x} && {isNull remoteControlled _x}
        && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_x] call CBE_fnc_CortexExternalOwner == ""}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {currentCommand _x != "STOP"}
        && {toUpperANSI currentCommand _x in ["","MOVE","WAIT"]}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
} forEach [_driver,_operator];
// A pending native BACK stop may outlive the ordinary driving callback. At the
// original hard deadline keep the exact owned reverse constrained before its
// observation becomes terminal; expiry never grants another STOP or route replay.
private _hardUntil=_work getOrDefault ["hardDeadline",-1];
if (_owned && {_work getOrDefault ["releasePending",false]}
    && {_hardUntil isEqualType 0} && {finite _hardUntil} && {_hardUntil >= 0}
    && {serverTime >= _hardUntil}) then {call _holdOwnedRearCap};
if (_owned && {call _releaseExpired}) exitWith {false};
private _executable=canMove _vehicle && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
    && {[_driver,_operator] findIf {!simulationEnabled _x || {isObjectHidden _x}} < 0};
if (_owned && {!_executable}) exitWith {
    // Keep proof of the issued rear command; do not turn a failed release into a fresh retry.
    // This receipt is not a motion lease and never renews the original recovery deadlines.
    if !(_work getOrDefault ["releasePending",false]) then {
        _work set ["releasePending",true];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
        _vehicle setVariable ["CBE_DrivingRecovery_Result",[
            _reason,serverTime,_group,_work get "kind",_work get "hardDeadline","DEFERRED"
        ],true];
    };
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
    false
};
private _nativeStopPending=false;
if (_owned) then {
    private _originalGoal=[_group] call CBE_fnc_DrivingRouteGoal;
    if (_originalGoal isNotEqualTo []) then {
        private _leader=leader _group;
        private _leaderVehicle=vehicle _leader;
        private _mountedTarget=!isNull _leader && {[_leader] call CBE_fnc_CortexCombatEffective}
            && {_leaderVehicle != _leader} && {_leaderVehicle isKindOf "LandVehicle"}
            && {alive _leaderVehicle} && {canMove _leaderVehicle}
            && {simulationEnabled _leaderVehicle} && {!isObjectHidden _leaderVehicle};
        // Cancel only this exact native leg, after plain-MOVE validation too.
        // A STOP request alone cannot authorize forward route handback.
        if (_commandMode == "SIMPLE_BACK") then {
            if (toUpperANSI (_simpleInfo param [0,""]) != "STOP") then {
                _vehicle sendSimpleCommand "STOP";
                _work set ["simpleStopIssued",true];
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
                _simpleInfo=vehicleMoveInfo _vehicle;
            };
            private _stopAcknowledged=toUpperANSI (_simpleInfo param [0,""]) == "STOP";
            if (_stopAcknowledged && {"queueBinding" in _work}) then {
                // Once STOP was observed, a later BACK belongs to a newer directive.
                // Retain that fact even while braking inertia delays physical handback.
                _work set ["queueStopAcknowledged",true];
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
            };
            private _stopLinear=vectorMagnitude velocity _vehicle;
            private _stopAngular=vectorMagnitude angularVelocity _vehicle;
            _nativeStopPending=!_stopAcknowledged || {!finite _stopLinear} || {!finite _stopAngular}
                || {_stopLinear >= 0.1} || {_stopAngular >= 0.01};
        };
        if (_nativeStopPending) exitWith {};
        private _nativeHandback=((_work get "route") param [0,"",[""]]) == "NATIVE_MOVE";
        if (_nativeHandback && {serverTime >= (_work get "hardDeadline")}) exitWith {
            _work set ["releasePending",true];_work set ["releaseUnresolved",true];
            _nativeStopPending=true;
        };
        [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
        if (!_nativeHandback) then {doStop _driver;if (_operator != _driver) then {doStop _operator}};
        _handback="STOP_ONLY";
        // Following an on-foot leader could cause crew dismount; never invent that task.
        if (_leaderVehicle == _vehicle || {_mountedTarget}) then {
            if (_driver != _operator && {!_nativeHandback}) then {_driver doFollow _operator};
            if (_leaderVehicle == _vehicle) then {
                private _returnBefore=[currentCommand _driver,+(expectedDestination _driver),
                    currentCommand _operator,+(expectedDestination _operator)];
                _operator doMove _originalGoal;
                _handback=["AUTHORED_ROUTE","NATIVE_ROUTE"] select _nativeHandback;
                if (_nativeHandback) then {
                    // Queue reverse is not an ordinary recovery allowance. Its return
                    // must observe both original-goal MOVE replies and then retire.
                    if ("queueBinding" in _work) then {
                        _work set ["queueReturn",+(_work get "queueBinding")];
                        _work set ["kind","QUEUE_RETURN"];
                    };
                    _work set ["nativeReturn",[+_originalGoal,(serverTime+2) min (_work get "hardDeadline"),_returnBefore]];
                    _work set ["releasePending",true];
                    _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
                };
            } else {
                _operator doFollow _leader;_handback="MOUNTED_LEADER";
            };
        };
    };
};
if ((_work getOrDefault ["nativeReturn",[]]) isNotEqualTo []) exitWith {
    // Keep the existing cap; this observes forward acknowledgement, not a reverse stop.
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
    false
};
if (_nativeStopPending) exitWith {
    _work set ["releasePending",true];
    _vehicle setVariable ["CBE_DrivingRecovery_Work",_work,true];
    // This exact owned native reverse is still stopping. Constrain its existing
    // cap before the caller restores anything; no forward order or new lifetime.
    call _holdOwnedRearCap;
    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
    false
};
if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _work) then {
    _vehicle setVariable ["CBE_DrivingRecovery_Result",[_reason,serverTime,_group,_work get "kind",_work get "hardDeadline",_handback],true];
    _vehicle setVariable ["CBE_DrivingRecovery_Work",nil,true];
};
true

    };
};
_released
