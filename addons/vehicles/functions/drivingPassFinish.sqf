/*
 * Author: WaldoTheWarfighter
 * Native crew flight vetoes new steering and route recall; exact cap-only release remains separate.
 * Queued ACE care prevents native stop/follow/route handback, while exact pass
 * metadata and consent retirement remain independent. No treatment queue mutation.
 * Purpose: Retires exact pass work and optionally hands its unchanged command to the native route.
 * Locality/authority: Vehicle/group owner. Current epoch, brain generation, both seats and
 * destinations, live simulation, external controller/Zeus state and the unchanged authored route
 * protect every stop/handback; detectable newer orders/controllers survive.
 * Full original work/brain/task/Zeus proof is re-read after stop before route recall.
 * After the original brain retires, exact owner/epoch/generation proof alone permits its existing cleanup;
 * a new owner or executor never inherits that permission.
 * Pending STOP retains original work/deadline/cap and is observed by the existing bounded cleanup.
 * Both operating actors must acknowledge STOP and measured rest before one authored-goal return.
 * Return acknowledgement uses the existing recovery journal, not another movement controller.
 * Observed STOP events veto command cleanup. Whether a repeated identical STOP emits that
 * group event remains an engine-level interruption test requirement. A newer authored route
 * retires metadata/consent only: cleanup never inserts a formation-follow fallback.
 * Repeat/JIP: Exact local journal and matching public leg receipt retire once, token-specific
 * broker release. Successor owners use DrivingPassRetireInherited, never replay this work. No ownership
 * transfer, physics shortcut or JIP command. A blocked abort records failure and may keep STOP.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 group <GROUP>, grpNull;
 * 2 reason <STRING>, RELEASED; 3 resume native route <BOOL>, false.
 * Return: BOOL - matching work retired; false while exact STOP remains pending/unresolved.
 * Neither return value proves physical route travel.
 * Current callers: DrivingPassStep and DrivingAssistRelease.
 * Example: [truck1,group driver truck1,"RELEASED",true] call CBE_fnc_DrivingPassFinish;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],["_reason","RELEASED",[""]],["_resume",false,[true]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
private _stop=_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]];
private _driver=_work get "driver";private _operator=_work get "operator";
private _brain=_group getVariable ["CBE_Driving_Brain",createHashMap];
private _actorFree={params ["_actor"];local _actor && {!fleeing _actor} && {!isPlayer _actor} && {isNull remoteControlled _actor}
    && {vehicle _actor == _vehicle} && {simulationEnabled _actor} && {!isObjectHidden _actor}
    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
    && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
    && {[_actor] call CBE_fnc_CortexCombatEffective} && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
    && {currentCommand _actor in ["","MOVE","WAIT","STOP"]}};
private _owned={
    _brain=_group getVariable ["CBE_Driving_Brain",createHashMap];
    _stop=_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]];
    private _interrupted=_stop isEqualType [] && {count _stop == 5}
        && {(_stop select [0,3]) isEqualTo [_work get "token",_work get "epoch",_work get "generation"]};
    !(_work getOrDefault ["interrupted",false]) && {!_interrupted} && {local _vehicle} && {local _group} && {(_work get "epoch") == (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {(_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap]) isEqualTo _work}
    && {(_work get "generation") == (_brain getOrDefault ["generation",-1])
        || {count _brain == 0 && {([_group] call CBE_fnc_DrivingOwnerReceipt)
            isEqualTo [clientOwner,_work get "epoch",_work get "generation"]}}}
    && {driver _vehicle == _driver} && {(effectiveCommander _vehicle) in [_operator,objNull]}
    && {[_driver] call _actorFree} && {[_operator] call _actorFree}
    && {group _driver == _group} && {group _operator == _group}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {[_group] call CBE_fnc_DrivingMovementAvailable}
    && {alive _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
    && {(_work getOrDefault ["handback",[]]) isEqualTo [] || {
        private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
        private _cap=_work getOrDefault ["handbackCap",-1e9];
        _cap isEqualType 0 && {finite _cap} && {_cap >= 0}
            && {(_work getOrDefault ["handbackOwner",[]]) isEqualTo ([_group] call CBE_fnc_DrivingOwnerReceipt)}
            && {(_state param [3,grpNull]) == _group} && {(_state param [0,-2]) == _cap}
            && {abs ((getForcedSpeed _vehicle)-_cap) <= 0.1}
            && {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isEqualTo (_work getOrDefault ["handbackBaseline",[]])}
    }}
};
private _retain=false;
isNil {
[_group,_vehicle,_work,true] call CBE_fnc_DrivingPassCommandWatch;
if (call _owned && {_work get "issued"}) then {
    if ((_work getOrDefault ["handback",[]]) isEqualTo []) then {
        private _state=+(_vehicle getVariable ["CBE_DrivingAssist_State",[]]);
        private _cap=_state param [0,-1e9];
        if (_cap isEqualType 0 && {finite _cap} && {_cap >= 0}
            && {(_state param [3,grpNull]) == _group} && {abs ((getForcedSpeed _vehicle)-_cap) <= 0.1}) then {
            private _next=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
            _next set ["handback",[_reason,_resume]];
            _next set ["handbackOwner",[_group] call CBE_fnc_DrivingOwnerReceipt];
            _next set ["handbackBaseline",+(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]])];
            // Stop this exact path once. Zero is a safety cap, not STOP acknowledgement.
            [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
            doStop _driver;if (_operator != _driver) then {doStop _operator};
            _vehicle forceSpeed 0;_state set [0,0];_next set ["handbackCap",0];
            _vehicle setVariable ["CBE_DrivingAssist_State",_state];
            _next set ["driverCommand",+(expectedDestination _driver)];
            _next set ["command",+(expectedDestination _operator)];
            _next set ["handbackTasks",[currentCommand _driver,currentCommand _operator]];
            _vehicle setVariable ["CBE_DrivingPass_Work",_next];_work=_next;
        };
    };
    // Re-read complete authority after STOP. A subsequent observation never repeats it.
    if ((_work getOrDefault ["handback",[]]) isNotEqualTo [] && {call _owned}) then {
        private _request=_work get "handback";
        private _tasks=_work get "handbackTasks";
        private _commandsCurrent=currentCommand _driver in [_tasks select 0,"STOP"]
            && {currentCommand _operator in [_tasks select 1,"STOP"]};
        if (_commandsCurrent) then {
            private _until=_work get "deadline";
            private _linear=vectorMagnitude velocity _vehicle;
            private _angular=vectorMagnitude angularVelocity _vehicle;
            private _stopped=currentCommand _driver == "STOP" && {currentCommand _operator == "STOP"}
                && {finite _linear} && {finite _angular} && {_linear < 0.1} && {_angular < 0.01};
            _retain=!_stopped || {serverTime >= _until};
            if (_retain) then {
                if (serverTime >= _until && {!(_work getOrDefault ["handbackUnresolved",false])}) then {
                    _work set ["handbackUnresolved",true];
                    _vehicle setVariable ["CBE_DrivingPass_Work",_work];
                    _vehicle setVariable ["CBE_DrivingPass_Result",["STOP_UNRESOLVED",serverTime,_work get "phase",_work get "peer",getPosASL _vehicle],true];
                };
                [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
            } else {
                if ((_request select 1) && {call _owned}
                    && {count (_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) == 0}) then {
                    private _route=_work get "route";
                    private _goal=if ((_route param [0,"",[""]]) == "NATIVE_MOVE") then {+(_route select 6)} else {
                        waypointPosition [_group,currentWaypoint _group]
                    };
                    if (_driver != _operator) then {_driver doFollow _operator};
                    private _before=[currentCommand _driver,+(expectedDestination _driver),
                        currentCommand _operator,+(expectedDestination _operator)];
                    _operator doMove _goal;
                    _vehicle setVariable ["CBE_DrivingRecovery_Work",createHashMapFromArray [
                        ["group",_group],["route",+(_work get "route")],["driver",_driver],["operator",_operator],
                        ["kind","PASS_RETURN"],["commandMode","DESTINATION"],["passReturn",_work get "token"],
                        ["passReturnOwner",+(_work get "handbackOwner")],
                        ["started",_work get "started"],["deadline",_until],["hardDeadline",_until],
                        ["cap",_work get "handbackCap"],["baseline",+(_work get "handbackBaseline")],
                        ["driverCommand",+(_before select 1)],["command",+(expectedDestination _operator)],
                        ["nativeReturn",[+_goal,_until,_before]],["releasePending",true]
                    ],true];
                    [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
                };
            };
        };
    };
};
};
if (_retain) exitWith {false};
if ((_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap]) isEqualTo _work) then {
    _vehicle setVariable ["CBE_DrivingPass_Result",[_reason,serverTime,_work get "phase",_work get "peer",getPosASL _vehicle],true];
    _vehicle setVariable ["CBE_DrivingPass_Work",nil];
    private _leg=_vehicle getVariable ["CBE_DrivingPass_Leg",[]];
    if (_leg isEqualType [] && {count _leg == 13} && {(_leg select 0) == "PASS_LEG_V1"}
        && {(_leg select 2) == _group} && {(_leg select 5) == (_work get "token")}
        && {((_leg select 1) == clientOwner && {(_leg select 3) == (_work get "epoch")}
            && {(_leg select 4) == (_work get "generation")})
            || {_leg isEqualTo (_work getOrDefault ["inheritedLeg",[]])}}) then {
        _vehicle setVariable ["CBE_DrivingPass_Leg",nil,true];
        private _handover=_vehicle getVariable ["CBE_DrivingPass_Handover",createHashMap];
        if (_handover isEqualType createHashMap && {(_handover getOrDefault ["leg",[]]) isEqualTo _leg}
            && {(_vehicle getVariable ["CBE_DrivingPass_Handover",createHashMap]) isEqualTo _handover}) then {
            _vehicle setVariable ["CBE_DrivingPass_Handover",nil,true];
        };
    };
};
_stop=_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]];
if (_stop isEqualType [] && {count _stop == 5}
    && {(_stop select [0,3]) isEqualTo [_work get "token",_work get "epoch",_work get "generation"]}
    && {(_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]]) isEqualTo _stop}) then {
    _vehicle setVariable ["CBE_DrivingPass_Interrupted",nil,true];
};
[_vehicle,_group,_work get "token"] call CBE_fnc_DrivingPassAgreementRelease;
true
