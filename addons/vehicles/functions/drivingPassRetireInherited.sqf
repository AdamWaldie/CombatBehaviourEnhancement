/*
 * Author: WaldoTheWarfighter
 * Successor-owner cleanup yields to queued ACE care on either control seat.
 * Exact stale receipt retirement remains independent and grants no native return command.
 * Purpose: Retires a previous owner's exact issued pass leg; never resumes its pass work.
 * Locality/authority: Current vehicle and crew/group owner only. Matching native destinations,
 * authored route, seats and free actor/controller authority guard native route handback.
 * Same-owner pending STOP belongs to its original observer even after its brain retires.
 * Repeat/JIP: Actual vehicle Local edge and complete source-issued cap/command fact are required.
 * Adopt cleanup only; never the old executable path or a renewed deadline. Native stop/return
 * is delegated to the original finite observer. Missing/mismatched proof records unresolved.
 * No executable work or timer replay. Split locality
 * waits for the existing discovery sweep. Expiry never authorizes renewed passing. An identical
 * native STOP without an observed group event remains ambiguous and needs physical QA.
 * A matching published STOP observation forbids native handback after transfer.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 expected group <GROUP>, grpNull permits any.
 * Return: BOOL - stale receipt retired, not proof of handback movement or passage.
 * Current callers: CortexLocality, CortexDiscover, DrivingAssistStart/Release.
 * Example: [truck1] call CBE_fnc_DrivingPassRetireInherited;
 */
params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _receipt=_vehicle getVariable ["CBE_DrivingPass_Leg",[]];
if (!(_receipt isEqualType []) || {count _receipt != 13}
    || {(_receipt select 0) isNotEqualTo "PASS_LEG_V1"}
    || {[1,3,4,11] findIf {!((_receipt select _x) isEqualType 0) || {!finite (_receipt select _x)}} >= 0}
    || {!((_receipt select 2) isEqualType grpNull)} || {!((_receipt select 5) isEqualType "")}
    || {(_receipt select 5) == ""}
    || {[6,7,12] findIf {!((_receipt select _x) isEqualType objNull)} >= 0}
    || {[8,9,10] findIf {!((_receipt select _x) isEqualType [])} >= 0}) exitWith {false};
_receipt params ["","_oldOwner","_group","_epoch","_generation","_token","_driver","_operator",
    "_driverCommand","_command","_route","_deadline","_peer"];
if (!isNull _expectedGroup && {_group != _expectedGroup}) exitWith {false};
// Wait only while the recorded crew still occupies these seats. Changed seats/deleted groups
// invalidate cleanup authority; remote former occupants must not retain a permanent pass veto.
private _sameSeats=driver _vehicle == _driver && {(effectiveCommander _vehicle) in [_operator,objNull]}
    && {group _driver == _group} && {group _operator == _group};
if (_sameSeats && {!isNull _group} && {(!local _group)
    || {!isNull _driver && {!local _driver}} || {!isNull _operator && {!local _operator}}}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap];
private _brain=createHashMap;
if (!isNull _group) then {_brain=_group getVariable ["CBE_Driving_Brain",createHashMap]};
private _live=_sameSeats && {!isNull _group} && {_oldOwner == clientOwner} && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {(_brain getOrDefault ["generation",-1]) == _generation}
    && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
    && {(_work getOrDefault ["token",""]) == _token}
    && {(_work getOrDefault ["generation",-1]) == _generation};
// Brain shutdown does not make its still-owned STOP journal an inherited path.
// Let the existing receipt observer finish it without repeating STOP or route issue.
private _pendingOwned=_sameSeats && {!isNull _group}
    && {_oldOwner == clientOwner || {(_work getOrDefault ["inheritedLeg",[]]) isEqualTo _receipt}}
    && {(_work getOrDefault ["token",""]) == _token}
    && {(_work getOrDefault ["epoch",-1]) == _epoch}
    && {(_work getOrDefault ["generation",-1]) == _generation}
    && {(_work getOrDefault ["handback",[]]) isNotEqualTo []}
    && {(_work getOrDefault ["handbackOwner",[]]) isEqualTo [clientOwner,_epoch,_generation]}
    && {(_work get "handbackOwner") isEqualTo ([_group] call CBE_fnc_DrivingOwnerReceipt)};
if (_live || {_pendingOwned}) exitWith {false};
if (_oldOwner == clientOwner && {!isNull _group}
    && {(_work getOrDefault ["token",""]) == _token}
    && {([_group] call CBE_fnc_DrivingOwnerReceipt) isEqualTo [clientOwner,_epoch,_generation]}) exitWith {
    [_vehicle,_group,"SAME_OWNER_RETIRED",true] call CBE_fnc_DrivingPassFinish
};
private _stop=_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]];
private _interrupted=_stop isEqualType [] && {count _stop == 5}
    && {(_stop select [0,3]) isEqualTo [_token,_epoch,_generation]};
private _successor=count _work > 0 && {(_work getOrDefault ["token",""]) != _token};
private _mayRetire={
    private _event=_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]];
    private _observedStop=_event isEqualType [] && {count _event == 5}
        && {(_event select [0,3]) isEqualTo [_token,_epoch,_generation]};
    !_observedStop && {!(_work getOrDefault ["interrupted",false])} && {!_successor} && {(_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap]) isEqualTo _work}
    && {["CBE_DrivingRecovery_Work","CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work"] findIf {
        count (_vehicle getVariable [_x,createHashMap]) > 0
    } < 0} && {
    local _vehicle && {!isNull _group} && {local _group} && {alive _vehicle} && {simulationEnabled _vehicle}
        && {!isObjectHidden _vehicle} && {!isNull _driver} && {!isNull _operator}
        && {driver _vehicle == _driver}
        && {(effectiveCommander _vehicle) in [_operator,objNull]}
        && {vehicle leader _group == _vehicle}
        && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
        && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}
        && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {[_group] call CBE_fnc_DrivingMovementAvailable}
        && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {(expectedDestination _driver) isEqualTo _driverCommand}
        && {(expectedDestination _operator) isEqualTo _command}
        && {[_driver,_operator] findIf {isNull _x || {!local _x} || {group _x != _group}
            || {vehicle _x != _vehicle} || {!simulationEnabled _x} || {isObjectHidden _x} || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
            || {fleeing _x} || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {[_x] call CBE_fnc_CortexActorMoveReserved}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {!(currentCommand _x in ["","MOVE","WAIT","STOP"])}} < 0}
        && {(_vehicle getVariable ["CBE_DrivingPass_Leg",[]]) isEqualTo _receipt}
    }
};
private _edge=_vehicle getVariable ["CBE_DrivingCap_LocalEdge",[]];
private _edgeOpen=_edge isEqualType [] && {count _edge == 3}
    && {(_edge select 0) isEqualType grpNull} && {isNull (_edge select 0) || {(_edge select 0) == _group}}
    && {[1,2] findIf {!((_edge select _x) isEqualType 0) || {!finite (_edge select _x)}} < 0}
    && {serverTime >= (_edge select 1)} && {serverTime < (_edge select 2)};
private _fact=_vehicle getVariable ["CBE_DrivingPass_Handover",createHashMap];
if !(_fact isEqualType createHashMap) exitWith {false};
private _adopted=false;private _retired=false;private _newOrderCap=false;
isNil {
    private _state=_fact getOrDefault ["state",[]];private _baseline=_fact getOrDefault ["baseline",[]];
    private _tasks=_fact getOrDefault ["tasks",[]];private _request=_fact getOrDefault ["handback",[]];
    private _created=_fact getOrDefault ["created",-1];private _started=_fact getOrDefault ["started",-1];
    private _driverNative=_fact getOrDefault ["driverCommand",[]];private _operatorNative=_fact getOrDefault ["command",[]];
    private _factValid=_edgeOpen && {_oldOwner != clientOwner}
        && {_group getVariable ["CBE_AIPass_Adopted",false]}
        && {(_fact getOrDefault ["leg",[]]) isEqualTo _receipt}
        && {(_fact getOrDefault ["issuer",[]]) isEqualTo [_oldOwner,_epoch,_generation]}
        && {(_fact getOrDefault ["deadline",-1]) isEqualTo _deadline}
        && {_created isEqualType 0} && {finite _created}
        && {_created >= (_edge select 1)-5} && {_created <= (_edge select 2)}
        && {_started isEqualType 0} && {finite _started} && {_started <= _created}
        && {_state isEqualType []} && {count _state in [4,11,12]} && {(_state select 3) == _group}
        && {(_state select 0) isEqualType 0} && {finite (_state select 0)} && {(_state select 0) >= 0}
        && {_baseline isEqualType []} && {count _baseline == 1}
        && {(_baseline select 0) isEqualType 0} && {finite (_baseline select 0)}
        && {(_baseline select 0) == -1 || {(_baseline select 0) >= 0}}
        && {_tasks isEqualType []} && {count _tasks == 2} && {_tasks findIf {!(_x isEqualType "")} < 0}
        && {_driverNative isEqualType []} && {_operatorNative isEqualType []}
        && {_request isEqualType []} && {count _request in [0,2]}
        && {_request isEqualTo [] || {(_request select 0) isEqualType "" && {(_request select 1) isEqualType true}}}
        && {count _brain == 0 || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}};
    if (_factValid) then {
        _driverCommand=+_driverNative;_command=+_operatorNative;
        private _privateState=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
        private _privateBaseline=_vehicle getVariable ["CBE_DrivingAssist_Restore",[]];
        if (call _mayRetire && {currentCommand _driver == (_tasks select 0)
                || {_request isNotEqualTo [] && {currentCommand _driver == "STOP"}}}
            && {currentCommand _operator == (_tasks select 1)
                || {_request isNotEqualTo [] && {currentCommand _operator == "STOP"}}}
            && {abs ((getForcedSpeed _vehicle)-(_state select 0)) <= 0.1}
            && {_privateState isEqualTo [] || {_privateState isEqualTo _state}}
            && {_privateBaseline isEqualTo [] || {_privateBaseline isEqualTo _baseline}}
            && {(_vehicle getVariable ["CBE_DrivingPass_Handover",createHashMap]) isEqualTo _fact}) then {
            // A private zero counter is cleanup identity, never a live FSM claim.
            if (isNil {_group getVariable "CBE_Driving_Generation"}) then {_group setVariable ["CBE_Driving_Generation",0]};
            private _owner=[_group] call CBE_fnc_DrivingOwnerReceipt;
            if (count _owner == 3 && {(_owner select 0) == clientOwner}) then {
                private _cleanup=createHashMapFromArray [
                    ["group",_group],["epoch",_owner select 1],["generation",_owner select 2],
                    ["driver",_driver],["operator",_operator],["route",+_route],["token",_token],["peer",_peer],
                    ["driverCommand",+_driverNative],["command",+_operatorNative],
                    ["phase","INHERITED_CLEANUP"],["issued",true],["interrupted",false],
                    ["started",_started],["deadline",_deadline],["inheritedLeg",+_receipt],["handbackOwner",+_owner]
                ];
                if (_request isNotEqualTo []) then {
                    _cleanup set ["handback",+_request];_cleanup set ["handbackTasks",+_tasks];
                    _cleanup set ["handbackCap",_state select 0];_cleanup set ["handbackBaseline",+_baseline];
                };
                _vehicle setVariable ["CBE_DrivingAssist_State",+_state];
                _vehicle setVariable ["CBE_DrivingAssist_Restore",+_baseline];
                _vehicle setVariable ["CBE_DrivingCap_Issuer",[+_owner,_driver,_operator]];
                _vehicle setVariable ["CBE_DrivingPass_Work",_cleanup];
                _vehicle setVariable ["CBE_DrivingPass_Handover",nil,true];
                _adopted=true;
                _retired=[_vehicle,_group,"INHERITED_RETURN",true] call CBE_fnc_DrivingPassFinish;
            };
        };
        // A newer native order revokes path cleanup, but cannot strand a proved old
        // zero cap. Offer only its original baseline to the existing cap-only adopter.
        private _nativeChanged=_sameSeats && {local _group} && {local _driver} && {local _operator}
            && {(expectedDestination _driver) isNotEqualTo _driverNative
                || {(expectedDestination _operator) isNotEqualTo _operatorNative}
                || {currentCommand _driver != (_tasks select 0)
                    && {!(_request isNotEqualTo [] && {currentCommand _driver == "STOP"})}}
                || {currentCommand _operator != (_tasks select 1)
                    && {!(_request isNotEqualTo [] && {currentCommand _operator == "STOP"})}}};
        if (!_adopted && {_nativeChanged}
            && {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo []}) then {
            if (isNil {_group getVariable "CBE_Driving_Generation"}) then {_group setVariable ["CBE_Driving_Generation",0]};
            private _issuer=[_oldOwner,_epoch,_generation];
            // Cap cleanup lifetime is anchored to the real source loss edge, never now.
            private _capFact=[+_state,+_baseline,_group,_epoch,_created+30,_driver,_operator,+_issuer,+_issuer];
            _vehicle setVariable ["CBE_DrivingCapRelease_Work",_capFact,true];
            if ([_vehicle] call CBE_fnc_DrivingCapReleaseAdopt) then {
                _capFact=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
                [_vehicle,_group,true,_capFact] call CBE_fnc_DrivingAssistRelease;
                [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
                _newOrderCap=true;
            } else {
                if ((_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo _capFact) then {
                    _vehicle setVariable ["CBE_DrivingCapRelease_Work",nil,true];
                };
            };
        };
    };
};
if (_adopted) exitWith {_retired};
// The group callback may precede the vehicle Local callback. No edge means no
// adoption, but must not erase still-current immutable proof before that event.
// Observation waits only to original expiry, or the already established edge end.
private _waitDriver=_driverCommand;private _waitOperator=_command;
if ((_fact getOrDefault ["leg",[]]) isEqualTo _receipt) then {
    private _factDriver=_fact getOrDefault ["driverCommand",[]];private _factOperator=_fact getOrDefault ["command",[]];
    if (_factDriver isEqualType [] && {_factOperator isEqualType []}) then {
        _waitDriver=+_factDriver;_waitOperator=+_factOperator;
    };
};
if (!_newOrderCap && {_sameSeats} && {!isNull _group} && {local _group} && {local _driver} && {local _operator}
    && {_edgeOpen || {_edge isEqualTo [] && {serverTime < _deadline}}}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
    && {(expectedDestination _driver) isEqualTo _waitDriver}
    && {(expectedDestination _operator) isEqualTo _waitOperator}) exitWith {false};
isNil {
    if ((_vehicle getVariable ["CBE_DrivingPass_Leg",[]]) isEqualTo _receipt) then {
        _vehicle setVariable ["CBE_DrivingPass_Leg",nil,true];
        _vehicle setVariable ["CBE_DrivingPass_Result",[
            ["INHERITED_UNRESOLVED","INHERITED_NEW_ORDER_CAP_CLEANUP"] select _newOrderCap,
            serverTime,"RETIRED",_peer,getPosASL _vehicle],true];
    };
    if ((_fact getOrDefault ["leg",[]]) isEqualTo _receipt
        && {(_vehicle getVariable ["CBE_DrivingPass_Handover",createHashMap]) isEqualTo _fact}) then {
        _vehicle setVariable ["CBE_DrivingPass_Handover",nil,true];
    };
    // A returning owner may retain private work from its previous ownership episode.
    if ((_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap]) isEqualTo _work
        && {(_work getOrDefault ["token",""]) == _token}
        && {(_work getOrDefault ["epoch",-1]) == _epoch}
        && {(_work getOrDefault ["generation",-1]) == _generation}) then {
        _vehicle setVariable ["CBE_DrivingPass_Work",nil];
    };
    false
};
[_group,_vehicle,createHashMapFromArray [["token",_token],["epoch",_epoch],["generation",_generation]],true]
    call CBE_fnc_DrivingPassCommandWatch;
if (_interrupted && {(_vehicle getVariable ["CBE_DrivingPass_Interrupted",[]]) isEqualTo _stop}) then {
    _vehicle setVariable ["CBE_DrivingPass_Interrupted",nil,true];
};
[_vehicle,_group,_token] call CBE_fnc_DrivingPassAgreementRelease;
true
