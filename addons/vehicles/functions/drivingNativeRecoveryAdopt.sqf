/*
 * Author: WaldoTheWarfighter
 * Purpose: Rebind one exact native driving recovery episode at a real locality edge.
 * Locality/authority: Internal current group/vehicle/crew owner only. Metadata adoption
 * requires an original five-second group/vehicle edge proposal, exact cap/seats/native leg,
 * original recovery clocks. Expired exact children receive cleanup-only custody,
 * never execution or a new deadline, while the original edge proof is still live.
 * One exact ordinary bypass/corridor child can
 * rebind with its parent; queued/pass/abort or conflicting children remain refused.
 * Path, phase, visited index and original deadlines survive without command replay;
 * The exact issued-return frame may retain its original STOP/FOLLOW task during transfer,
 * with its original acknowledgement tuple unchanged. Other protected tasks still refuse.
 * the old swept-segment sample is discarded. No geometry or completion is fabricated. Active driving resumes its existing FSM; disabled
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
private _adoptExpiredChild=false;
private _adoptGroup=grpNull;
isNil {
    private _adoptWork=_adoptVehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
    if (!(_adoptWork isEqualType createHashMap) || {count _adoptWork == 0}) exitWith {};
    private _adoptRoute=_adoptWork getOrDefault ["route",[]];
    if (!(_adoptRoute isEqualType []) || {count _adoptRoute != 9}
        || {(_adoptRoute param [0,"",[""]]) != "NATIVE_MOVE"}) exitWith {};
    _adoptGroup=_adoptWork getOrDefault ["group",grpNull];
    if (!(_adoptGroup isEqualType grpNull) || {"queueBinding" in _adoptWork}
        || {["CBE_DrivingPass_Work","CBE_DrivingAbort_Hold"] findIf {
            private _child=_adoptVehicle getVariable [_x,createHashMap];
            !(_child isEqualType createHashMap) || {count _child > 0}
        } >= 0}) exitWith {};
    private _adoptChildKey="";private _adoptChild=createHashMap;private _adoptChildValid=true;
    {
        private _candidate=_adoptVehicle getVariable [_x,createHashMap];
        if (!(_candidate isEqualType createHashMap)) exitWith {_adoptChildValid=false};
        if (count _candidate > 0) then {
            if (_adoptChildKey != "") exitWith {_adoptChildValid=false};
            _adoptChildKey=_x;_adoptChild=_candidate;
        };
    } forEach ["CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work"];
    if (!_adoptChildValid) exitWith {};
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
    private _adoptParentExpired=serverTime >= (_adoptWork get "hardDeadline");
    // Cleanup custody also has a fixed age bound from the original episode, not
    // just a fresh owner edge. Ancient matching cap/task values cannot reclaim it.
    if (_adoptParentExpired && {serverTime >= (_adoptWork get "hardDeadline")+5}) exitWith {};
    if ((_adoptWork get "deadline") < 0 || {_adoptParentExpired && {_adoptChildKey == ""}} || {(_adoptWork get "deadline") > (_adoptWork get "hardDeadline")}
        || {(_adoptWork get "started") > serverTime} || {(_adoptWork get "cap") < 0}
        || {abs (getForcedSpeed _adoptVehicle-(_adoptWork get "cap")) > 0.1}) exitWith {};
    private _adoptBaseline=_adoptWork getOrDefault ["baseline",[]];
    if (!(_adoptBaseline isEqualType []) || {count _adoptBaseline != 1}
        || {!((_adoptBaseline select 0) isEqualType 0)} || {!finite (_adoptBaseline select 0)} || {(_adoptBaseline select 0) < -1}) exitWith {};
    private _adoptMode=_adoptWork getOrDefault ["commandMode","DESTINATION"];
    private _adoptChildState="";
    if (_adoptChildKey != "") then {
        _adoptChildValid=call {
            private _childUntil=_adoptChild getOrDefault ["deadline",-1];
            private _childPhase=_adoptChild getOrDefault ["phase",""];
            if (_adoptMode != "DESTINATION" || {"nativeReturn" in _adoptWork}
                || {!((_adoptWork getOrDefault ["bypassSpent",false]) isEqualTo true)}
                || {_adoptWork getOrDefault ["releasePending",false]}
                || {!((_adoptWork getOrDefault ["kind",""]) in ["REFRESH","FINAL"])}
                || {!(_childUntil isEqualType 0)} || {!finite _childUntil} || {_childUntil < 0}
                || {_childUntil > (_adoptWork get "hardDeadline")}
                || {(_adoptChild getOrDefault ["controller",[]]) isNotEqualTo ["ORDINARY",-1]}
                || {(_adoptChild getOrDefault ["group",grpNull]) != _adoptGroup}
                || {(_adoptChild getOrDefault ["route",[]]) isNotEqualTo _adoptRoute}
                || {(_adoptChild getOrDefault ["driver",objNull]) != _adoptDriver}
                || {(_adoptChild getOrDefault ["operator",objNull]) != _adoptOperator}
                || {(_adoptChild getOrDefault ["recoveryParent",[]]) isNotEqualTo
                    [_adoptGroup,_adoptRoute,_adoptWork get "hardDeadline",_adoptWork get "progressAnchor"]}) exitWith {false};
            // Expiry revokes execution, not exact custody needed to retire the old path.
            // The original real-locality-edge window must still be live.
            _adoptExpiredChild=_adoptParentExpired || {serverTime >= _childUntil};
            private _childInput=vehicleMoveInfo _adoptVehicle;
            if (toUpperANSI (_childInput param [0,"",[""]]) in ["BACK","DIRECTBYCOMANDER"]
                || {toUpperANSI (_childInput param [1,"",[""]]) in ["LEFT","RIGHT"]}) exitWith {false};
            _adoptChildState=[_adoptVehicle,_adoptWork] call CBE_fnc_DrivingRecoveryCommandState;
            private _childContext=_adoptChild getOrDefault ["context",[]];
            if (_adoptChildKey == "CBE_DrivingBypass_Work") then {
                private _obstacle=_adoptChild getOrDefault ["obstacle",objNull];
                if (_childContext isNotEqualTo [_adoptGroup,_adoptRoute,_obstacle,_adoptDriver,_adoptOperator,["ORDINARY",-1]]
                    || {!(_childPhase in ["PLAN","FOLLOW"])}) exitWith {_adoptChildState="LOST"};
                if (_childPhase == "PLAN") then {
                    if (_adoptChildState != "OWNED"
                        || {(expectedDestination _adoptDriver) isNotEqualTo (_adoptChild getOrDefault ["driverCommand",[]])}
                        || {(expectedDestination _adoptOperator) isNotEqualTo (_adoptChild getOrDefault ["command",[]])}
                        || {toUpperANSI currentCommand _adoptDriver != (_adoptChild getOrDefault ["driverTask","__MISSING__"])}
                        || {toUpperANSI currentCommand _adoptOperator != (_adoptChild getOrDefault ["operatorTask","__MISSING__"])}) then {_adoptChildState="LOST"};
                } else {if (_adoptChildState != "BYPASS") then {_adoptChildState="LOST"}};
            } else {
                if (_childContext isNotEqualTo [_adoptChild getOrDefault ["area",objNull],
                    _adoptChild getOrDefault ["definition",[]],_adoptChild getOrDefault ["transform",[]],_adoptRoute,["ORDINARY",-1]]
                    || {!(_childPhase in ["APPROACH","CROSS"])} || {_adoptChildState != "CORRIDOR"}
                    || {(_adoptChild getOrDefault ["hardDeadline",-1]) isNotEqualTo (_adoptWork get "hardDeadline")}) then {_adoptChildState="LOST"};
            };
            if (_adoptChildState == "LOST") exitWith {false};
            if (_childPhase != "PLAN") then {
                private _childPoints=_adoptChild getOrDefault ["points",[]];
                if (!(_childPoints isEqualType []) || {count _childPoints < 2} || {count _childPoints > 24}
                    || {_childPoints findIf {!(_x call _adoptVector)} >= 0}) then {_adoptChildState="LOST"};
                if (_adoptChildKey == "CBE_DrivingBypass_Work") then {
                    private _index=_adoptChild getOrDefault ["index",-1];
                    if (!(_index isEqualType 0) || {!finite _index} || {_index != floor _index}
                        || {_index < 0} || {_index > count _childPoints}
                        || {!((_adoptChild getOrDefault ["far",[]]) call _adoptVector)}
                        || {!((_adoptChild getOrDefault ["forward",[]]) call _adoptVector)}
                        || {["radius","height"] findIf {private _value=_adoptChild getOrDefault [_x,-1];
                            !(_value isEqualType 0) || {!finite _value} || {_value <= 0}} >= 0}) then {_adoptChildState="LOST"};
                } else {
                    private _asl=_adoptChild getOrDefault ["asl",[]];
                    if (!(_asl isEqualType []) || {count _asl < 2} || {count _asl > 20}
                        || {_asl findIf {!(_x call _adoptVector)} >= 0}
                        || {!((_adoptChild getOrDefault ["far",[]]) call _adoptVector)}
                        || {!((_adoptChild getOrDefault ["travel",[]]) call _adoptVector)}) then {_adoptChildState="LOST"};
                };
            };
            _adoptChildState != "LOST"
        };
    };
    if (!_adoptChildValid) exitWith {};
    if (_adoptExpiredChild) then {_adoptResume=false};
    private _adoptNative=false;private _adoptCommandState="LOST";
    if (_adoptMode == "DESTINATION" || {"nativeReturn" in _adoptWork}) then {
        _adoptCommandState=[_adoptVehicle,_adoptWork] call CBE_fnc_DrivingRecoveryCommandState;
        _adoptNative=_adoptCommandState in ["OWNED","PENDING","EXPIRED","BYPASS","CORRIDOR"];
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
    // Only the original issued return frame can retain its STOP/FOLLOW transition.
    // This is observation provenance, never permission for an arbitrary protected task.
    private _adoptReturnProof=_adoptChildKey == ""
        && {_adoptCommandState in ["OWNED","PENDING","EXPIRED"]}
        && {(_adoptWork getOrDefault ["nativeReturn",[]]) isNotEqualTo []
            || {"bypassReturn" in _adoptWork && {(_adoptWork getOrDefault ["request",[]]) isNotEqualTo []}}};
    if (!_adoptNative || {[_adoptDriver,_adoptOperator] findIf {
        !(currentCommand _x in ["","MOVE","WAIT"])
            && {!(currentCommand _x == "STOP" && {_adoptWork getOrDefault ["simpleStopIssued",false]})}
            && {!(_adoptChildState in ["BYPASS","CORRIDOR"])}
            && {!(_adoptReturnProof && {currentCommand _x in ["STOP","FOLLOW"]})}
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
    if (!_adoptResume && {_adoptChildKey == ""}) then {_adoptNext set ["releasePending",true]};
    private _adoptNextState=[_adoptWork get "cap",0,time,_adoptGroup,+(_adoptWork get "origin"),
        time-(serverTime-(_adoptWork get "started")),_adoptStage,time+((_adoptWork get "deadline")-serverTime),
        "ADOPTED_NATIVE_RECOVERY",_adoptNextRoute,_adoptKind == "REVERSE"];
    private _adoptNextChild=createHashMap;
    if (_adoptChildKey != "") then {
        _adoptNextChild=createHashMapFromArray (keys _adoptChild apply {[_x,_adoptChild get _x]});
        _adoptNextChild set ["route",_adoptNextRoute];
        _adoptNextChild set ["recoveryParent",[_adoptGroup,_adoptNextRoute,
            _adoptWork get "hardDeadline",+(_adoptWork get "progressAnchor")]];
        private _nextContext=+(_adoptChild get "context");
        _nextContext set [[1,3] select (_adoptChildKey == "CBE_DrivingCorridor_Work"),_adoptNextRoute];
        _adoptNextChild set ["context",_nextContext];
        if (_adoptChildKey == "CBE_DrivingCorridor_Work") then {_adoptNextChild set ["epoch",_adoptEpoch]};
        // A historical segment must not sweep unobserved checkpoints after transfer.
        _adoptNextChild deleteAt "capture";
    };
    private _adoptFinalOperator=effectiveCommander _adoptVehicle;
    if (isNull _adoptFinalOperator) then {_adoptFinalOperator=driver _adoptVehicle};
    if (!local _adoptVehicle || {!local _adoptGroup}
        || {driver _adoptVehicle != _adoptDriver} || {_adoptFinalOperator != _adoptOperator}
        || {(_adoptGroup getVariable ["CBE_AIPass_Epoch",0]) != _adoptEpoch}
        || {(_adoptVehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _adoptWork}
        || {_adoptChildKey != "" && {(_adoptVehicle getVariable [_adoptChildKey,createHashMap]) isNotEqualTo _adoptChild}}
        || {abs (getForcedSpeed _adoptVehicle-(_adoptWork get "cap")) > 0.1}) exitWith {};
    // One local transaction; public parent/child delivery is not assumed ordered.
    if (_adoptChildKey != "") then {_adoptVehicle setVariable [_adoptChildKey,_adoptNextChild,true]};
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
