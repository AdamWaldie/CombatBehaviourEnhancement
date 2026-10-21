/*
 * Author: WaldoTheWarfighter
 * Purpose: Rebind one exact native driving recovery episode at a real locality edge.
 * Locality/authority: Internal current group/vehicle/crew owner only. Metadata adoption
 * requires an original five-second group/vehicle edge proposal, exact cap/seats/native leg,
 * unexpired original recovery clocks. Active driving resumes its existing FSM; disabled
 * driving invokes only the existing guarded release path, never tactical startup.
 * Repeat/JIP: Init/seat retries cannot create edge proof or renew any deadline. Rebinds only
 * issuer epoch/owner; original goal, stage, baseline, progress anchor and spent budget survive.
 * Arguments: 0 vehicle OBJECT objNull.
 * Return: BOOL metadata adopted, never physical handback or successful FSM execution.
 * Current callers: DrivingRecoveryAdopt after actual group/vehicle locality delivery.
 * Example: private _adopted=[truck1] call CBE_fnc_DrivingNativeRecoveryAdopt;
 */
params [["_adoptVehicle",objNull,[objNull]]];
if (remoteExecutedOwner > 0 || {isNull _adoptVehicle} || {!local _adoptVehicle}) exitWith {false};
private _adoptAccepted=false;
private _adoptResume=false;
private _adoptGroup=grpNull;
isNil {
    private _adoptWork=_adoptVehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
    if (!(_adoptWork isEqualType createHashMap) || {count _adoptWork == 0}) exitWith {};
    private _adoptRoute=_adoptWork getOrDefault ["route",[]];
    if (!(_adoptRoute isEqualType []) || {count _adoptRoute != 9}
        || {(_adoptRoute param [0,"",[""]]) != "NATIVE_MOVE"}) exitWith {};
    _adoptGroup=_adoptWork getOrDefault ["group",grpNull];
    if (!(_adoptGroup isEqualType grpNull) || {"queueBinding" in _adoptWork}
        || {["CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work","CBE_DrivingPass_Work","CBE_DrivingAbort_Hold"] findIf {
            private _child=_adoptVehicle getVariable [_x,createHashMap];
            !(_child isEqualType createHashMap) || {count _child > 0}
        } >= 0}) exitWith {};
    private _adoptDriver=driver _adoptVehicle;private _adoptOperator=effectiveCommander _adoptVehicle;
    if (isNull _adoptOperator) then {_adoptOperator=_adoptDriver};
    if (isNull _adoptGroup || {!local _adoptGroup}
        || {count waypoints _adoptGroup > 1} || {vehicle leader _adoptGroup != _adoptVehicle}
        || {(_adoptRoute select 1) isNotEqualTo _adoptGroup} || {(_adoptRoute select 2) isNotEqualTo _adoptVehicle}
        || {(_adoptRoute select 3) isNotEqualTo _adoptDriver} || {(_adoptRoute select 4) isNotEqualTo _adoptOperator}
        || {(_adoptWork getOrDefault ["driver",objNull]) != _adoptDriver}
        || {(_adoptWork getOrDefault ["operator",objNull]) != _adoptOperator}) exitWith {};
    private _adoptEpoch=_adoptGroup getVariable ["CBE_AIPass_Epoch",0];
    if ([_adoptEpoch,_adoptRoute select 7,_adoptRoute select 8] findIf {
        !(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} >= 0) exitWith {};
    if ((_adoptRoute select 7) == _adoptEpoch && {(_adoptRoute select 8) == clientOwner}) exitWith {};
    private _adoptSource=[];
    private _adoptTransfer=_adoptGroup getVariable ["CBE_DrivingNative_Transfer",[]];
    if (_adoptTransfer isEqualType [] && {count _adoptTransfer == 4}
        && {(_adoptTransfer select 0) isEqualTo (_adoptRoute select 8)}
        && {(_adoptTransfer select 1) isEqualTo (_adoptRoute select 7)}
        && {(_adoptTransfer select 2) isEqualTo _adoptEpoch}
        && {(_adoptTransfer select 3) isEqualType 0} && {finite (_adoptTransfer select 3)}
        && {serverTime < (_adoptTransfer select 3)}) then {_adoptSource=+_adoptTransfer};
    private _adoptEdge=_adoptVehicle getVariable ["CBE_DrivingNative_LocalEdge",[]];
    if (_adoptSource isEqualTo [] && {_adoptEdge isEqualType []} && {count _adoptEdge == 4}
        && {(_adoptEdge select 0) isEqualTo _adoptGroup}
        && {(_adoptEdge select 1) isEqualTo (_adoptRoute select 8)}
        && {(_adoptEdge select 2) isEqualTo (_adoptRoute select 7)}
        && {(_adoptEdge select 3) isEqualType 0} && {finite (_adoptEdge select 3)}
        && {serverTime < (_adoptEdge select 3)}) then {
        _adoptSource=[_adoptEdge select 1,_adoptEdge select 2,_adoptEpoch,_adoptEdge select 3];
    };
    _adoptResume=(missionNamespace getVariable ["CBE_AIPass_Active",false])
        && {[_adoptGroup,"CBE_AIPass_DrivingAssist_Enable",true,_adoptVehicle] call CBE_fnc_CortexFeatureEnabled};
    if (_adoptSource isEqualTo [] || {_adoptResume && {!(_adoptGroup getVariable ["CBE_AIPass_Adopted",false])}}
        || {[_adoptGroup] call CBE_fnc_CortexZeusHeld} || {[_adoptGroup] call CBE_fnc_CortexExternalTakeover}
        || {!([_adoptGroup] call CBE_fnc_DrivingMovementAvailable)}
        || {_adoptVehicle getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_adoptVehicle getVariable "CBE_ExternalDrivingOwner"}}
        || {_adoptWork getOrDefault ["releaseUnresolved",false]}) exitWith {};
    if ([_adoptDriver,_adoptOperator] findIf {isNull _x || {!local _x} || {group _x != _adoptGroup}
        || {isPlayer _x} || {!isNull remoteControlled _x} || {fleeing _x}
        || {!([_x] call CBE_fnc_CortexCombatEffective)} || {[_x] call CBE_fnc_CortexActorMoveReserved}
        || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
        || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} >= 0) exitWith {};
    private _adoptVector={_this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
    private _adoptFrame=_adoptRoute select 5;
    if (!(_adoptFrame isEqualType []) || {count _adoptFrame != 4}
        || {[0,2] findIf {!((_adoptFrame select _x) isEqualType "")} >= 0}
        || {[1,3] findIf {private _frame=_adoptFrame select _x;
            !(_frame isEqualType []) || {count _frame != 3} || {!((_frame select 0) call _adoptVector)}
                || {!((_frame select 1) isEqualType "")} || {!((_frame select 2) isEqualType true)}} >= 0}) exitWith {};
    if (!((_adoptRoute select 6) call _adoptVector)
        || {!((_adoptWork getOrDefault ["origin",[]]) call _adoptVector)}
        || {!((_adoptWork getOrDefault ["progressAnchor",[]]) call _adoptVector)}
        || {["started","deadline","hardDeadline","cap"] findIf {
            private _value=_adoptWork getOrDefault [_x,[]];!(_value isEqualType 0) || {!finite _value}} >= 0}) exitWith {};
    if ((_adoptWork get "deadline") < 0 || {serverTime >= (_adoptWork get "hardDeadline")} || {(_adoptWork get "deadline") > (_adoptWork get "hardDeadline")}
        || {(_adoptWork get "started") > serverTime} || {(_adoptWork get "cap") < 0}
        || {abs (getForcedSpeed _adoptVehicle-(_adoptWork get "cap")) > 0.1}) exitWith {};
    private _adoptBaseline=_adoptWork getOrDefault ["baseline",[]];
    if (!(_adoptBaseline isEqualType []) || {count _adoptBaseline != 1}
        || {!((_adoptBaseline select 0) isEqualType 0)} || {!finite (_adoptBaseline select 0)} || {(_adoptBaseline select 0) < -1}) exitWith {};
    private _adoptMode=_adoptWork getOrDefault ["commandMode","DESTINATION"];
    private _adoptNative=false;
    if (_adoptMode == "DESTINATION" || {"nativeReturn" in _adoptWork}) then {
        _adoptNative=([_adoptVehicle,_adoptWork] call CBE_fnc_DrivingRecoveryCommandState) in ["OWNED","PENDING","EXPIRED"];
    } else {
        if (_adoptMode == "SIMPLE_BACK" && {_adoptDriver != _adoptOperator}) then {
            private _adoptInfo=vehicleMoveInfo _adoptVehicle;
            _adoptNative=(_adoptInfo param [1,""]) == ((_adoptWork getOrDefault ["simpleBefore",[]]) param [1,"MISSING"])
                && {toUpperANSI (_adoptInfo param [0,""]) == "BACK"
                    || {_adoptWork getOrDefault ["simpleStopIssued",false] && {toUpperANSI (_adoptInfo param [0,""]) == "STOP"}}
                    || {!(_adoptWork getOrDefault ["simpleAcknowledged",false])
                        && {_adoptInfo isEqualTo (_adoptWork getOrDefault ["simpleBefore",[]])}}}
                && {(expectedDestination _adoptDriver) isEqualTo (_adoptWork getOrDefault ["driverCommand",[]])}
                && {(expectedDestination _adoptOperator) isEqualTo (_adoptWork getOrDefault ["command",[]])};
        };
    };
    if (!_adoptNative || {[_adoptDriver,_adoptOperator] findIf {
        !(currentCommand _x in ["","MOVE","WAIT"])
            && {!(currentCommand _x == "STOP" && {_adoptWork getOrDefault ["simpleStopIssued",false]})}
    } >= 0}) exitWith {};
    private _adoptState=_adoptVehicle getVariable ["CBE_DrivingAssist_State",[]];
    private _adoptRestore=_adoptVehicle getVariable ["CBE_DrivingAssist_Restore",[]];
    if (!(_adoptState isEqualType []) || {!(_adoptRestore isEqualType [])}
        || {_adoptRestore isNotEqualTo [] && {_adoptRestore isNotEqualTo _adoptBaseline}}
        || {_adoptState isNotEqualTo [] && {count _adoptState < 11
            || {(_adoptState select 0) isNotEqualTo (_adoptWork get "cap")}
            || {(_adoptState select 3) isNotEqualTo _adoptGroup}
            || {(_adoptState select 9) isNotEqualTo _adoptRoute}}}) exitWith {};
    private _adoptKind=_adoptWork getOrDefault ["kind",""];
    if !(_adoptKind in ["REFRESH","REVERSE","FINAL","EXHAUSTED"]) exitWith {};
    if (_adoptMode == "SIMPLE_BACK" && {_adoptKind != "REVERSE"}) exitWith {};
    private _adoptStage=switch (_adoptKind) do {case "REFRESH":{1};case "REVERSE":{2};case "FINAL":{3};default {4}};
    private _adoptNextRoute=+_adoptRoute;
    _adoptNextRoute set [7,_adoptEpoch];_adoptNextRoute set [8,clientOwner];
    private _adoptNext=createHashMapFromArray (keys _adoptWork apply {[_x,_adoptWork get _x]});
    _adoptNext set ["route",_adoptNextRoute];_adoptNext set ["nativeAdoptedFrom",[+_adoptRoute,+_adoptSource]];
    if (!_adoptResume) then {_adoptNext set ["releasePending",true]};
    private _adoptNextState=[_adoptWork get "cap",0,time,_adoptGroup,+(_adoptWork get "origin"),
        time-(serverTime-(_adoptWork get "started")),_adoptStage,time+((_adoptWork get "deadline")-serverTime),
        "ADOPTED_NATIVE_RECOVERY",_adoptNextRoute,_adoptKind == "REVERSE"];
    _adoptVehicle setVariable ["CBE_DrivingRecovery_Work",_adoptNext,true];
    _adoptVehicle setVariable ["CBE_DrivingAssist_State",_adoptNextState];
    _adoptVehicle setVariable ["CBE_DrivingAssist_Restore",+_adoptBaseline];
    _adoptAccepted=true;
};
if (_adoptAccepted) then {
    if (_adoptResume) then {
        // Existing startup retains failed-start terminal receipts; it does not reset this journal.
        [_adoptGroup] call CBE_fnc_DrivingOperationStart;
    } else {
        // Cleanup-only custody never enables tactics or installs an owner/group handler.
        // Existing release rechecks command/cap/route ownership and observes pending handback.
        [_adoptVehicle,_adoptGroup] call CBE_fnc_DrivingAssistRelease;
    };
};
_adoptAccepted
