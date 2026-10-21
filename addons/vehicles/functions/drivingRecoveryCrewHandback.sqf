/*
 * Author: WaldoTheWarfighter
 * Purpose: Quiesces an acknowledged reverse after driver death, then returns its surviving
 * commander to the admitted native goal before the existing crew executor changes seats.
 * Locality/authority: Existing driving FSM, exact local group/vehicle/commander and cap issuer.
 * Never reads a dead driver's native command as proof. Pending reverse/return requests and
 * competing child controllers refuse admission. A changed mission command or cap wins.
 * Repeat/JIP: One stop and one goal command, each observed within two seconds and the
 * original recovery hard deadline. No new worker, renewed recovery budget or forced seats.
 * Cap zero is confirmed before native stop; measured rest and native stop acknowledgement
 * precede forward intent. Original baseline/anchor/spent flags survive conversion to FINAL.
 * A failed phase stays terminal in this journal. This is not physical recovery acceptance.
 * Arguments: 0 group <GROUP, grpNull>; 1 driving brain <HASHMAP, empty>.
 * Return: BOOL - true while this finite handback is pending; false permits existing crew logic.
 * Callers: DrivingOperationStep before DrivingCrewStep.
 * Example: private _pending=[group commander truck1,_brain] call CBE_fnc_DrivingRecoveryCrewHandback;
 */
params [["_group",grpNull,[grpNull]],["_brain",createHashMap,[createHashMap]]];
private _pending=false;
isNil {
    _pending=call {
        private _route=_brain getOrDefault ["route",[]];
        if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
            || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
            || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
            || {count _route != 9} || {(_route select 0) != "NATIVE_MOVE"}
            || {(_route select 7) isNotEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {(_route select 8) isNotEqualTo clientOwner}
            || {alive (_route select 3)}) exitWith {false};
        private _vehicle=_route select 2;
        if (isNull _vehicle || {!local _vehicle}) exitWith {false};
        private _entry=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        if (count _entry == 0 || {(_entry getOrDefault ["kind",""]) != "REVERSE"}
            || {_entry getOrDefault ["crewHandbackFailed",false]}) exitWith {false};
        private _journal=+_entry;
        private _fail={
            if ((_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _entry) then {
                _journal set ["crewHandbackFailed",true];
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_journal,true];
                _vehicle setVariable ["CBE_DrivingRecovery_Result",["CREW_HANDBACK_REFUSED",serverTime,_group,
                    "REVERSE",_entry getOrDefault ["hardDeadline",-1],"UNRESOLVED"],true];
            };
            false
        };
        private _operator=effectiveCommander _vehicle;
        private _driver=driver _vehicle;
        private _goal=_route select 6;
        private _hard=_entry getOrDefault ["hardDeadline",[]];
        private _cap=_entry getOrDefault ["cap",[]];
        private _baseline=_entry getOrDefault ["baseline",[]];
        private _issuer=_vehicle getVariable ["CBE_DrivingCap_Issuer",[]];
        private _assist=+(_vehicle getVariable ["CBE_DrivingAssist_State",[]]);
        private _mode=_entry getOrDefault ["commandMode",""];
        private _handback=_entry getOrDefault ["crewHandback",[]];
        private _crew=fullCrew [_vehicle,"",false];
        private _tasks=["STOP","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
        if (!alive _vehicle || {!canMove _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
            || {isNull _operator} || {!local _operator} || {!([_operator] call CBE_fnc_CortexCombatEffective)}
            || {!simulationEnabled _operator} || {isObjectHidden _operator} || {_operator != (_route select 4)}
            || {_operator == (_route select 3)} || {group _operator != _group} || {vehicle _operator != _vehicle}
            || {!isNull _driver && {_driver != (_route select 3) || {alive _driver}}}
            || {(_brain get "ownerEpoch") isNotEqualTo (_route select 7)}
            || {(_entry getOrDefault ["route",[]]) isNotEqualTo _route}
            || {(_entry getOrDefault ["group",grpNull]) != _group}
            || {(_entry getOrDefault ["driver",objNull]) isNotEqualTo (_route select 3)}
            || {(_entry getOrDefault ["operator",objNull]) != _operator}
            || {!(_mode in ["DESTINATION","SIMPLE_BACK"])}
            || {(_entry getOrDefault ["releasePending",false])}
            || {["request","nativeReturn","bypassReturn","queueBinding"] findIf {_x in _entry} >= 0}
            || {!(_hard isEqualType 0)} || {!finite _hard} || {serverTime >= _hard}
            || {!(_cap isEqualType 0)} || {!finite _cap} || {abs (getForcedSpeed _vehicle-_cap) > 0.1}
            || {count _baseline != 1} || {!((_baseline select 0) isEqualType 0)}
            || {!finite (_baseline select 0)} || {(_baseline select 0) < -1}
            || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo _baseline}
            || {count _issuer != 3} || {(_issuer select 0) isNotEqualTo [clientOwner,_brain get "ownerEpoch",_brain get "generation"]}
            || {(_issuer select 1) isNotEqualTo (_route select 3)} || {(_issuer select 2) != _operator}
            || {count _assist < 11} || {(_assist select 0) isNotEqualTo _cap}
            || {(_assist select 3) != _group} || {(_assist select 9) isNotEqualTo _route}
            || {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isNotEqualTo []}
            || {count _goal != 3} || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {count waypoints _group > 1} || {vehicle leader _group != _vehicle}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
            || {!([_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
            || {!([_group] call CBE_fnc_DrivingMovementAvailable)}
            || {[_group] call CBE_fnc_CortexZeusHeld} || {[_group] call CBE_fnc_CortexExternalTakeover}
            || {_vehicle getVariable ["CBE_Convoy_Active",false]} || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
            || {["CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work","CBE_DrivingPass_Work"] findIf {
                count (_vehicle getVariable [_x,createHashMap]) > 0} >= 0}
            || {count _crew > 20}
            || {_crew findIf {
                private _actor=_x select 0;
                isPlayer _actor || {!isNull remoteControlled _actor}
                    || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                    || {[_actor] call CBE_fnc_CortexExternalOwner != ""}
                    || {alive _actor && {!local _actor || {group _actor != _group} || {fleeing _actor}
                        || {!([_actor] call CBE_fnc_CortexCombatEffective)}
                        || {[_actor] call CBE_fnc_CortexActorMoveReserved}
                        || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
                        || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")}
                        || {currentCommand _actor in _tasks && {!(_actor == _operator && {_handback isNotEqualTo []}
                            && {currentCommand _actor == "STOP"})}}}}
            } >= 0}) exitWith {call _fail};
        // A different living leader's MOVE is mission intent, not our reverse receipt.
        private _leader=leader _group;
        private _leaderTarget=if (_leader != _operator && {currentCommand _leader == "MOVE"}) then {
            (expectedDestination _leader) param [0,[],[[]]]
        } else {+_goal};
        if (count _leaderTarget != 3 || {_leaderTarget findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_leaderTarget vectorDistance _goal > 3}) exitWith {call _fail};
        private _native=expectedDestination _operator;
        private _task=currentCommand _operator;
        private _info=vehicleMoveInfo _vehicle;
        private _rest=finite (vectorMagnitude velocity _vehicle) && {finite (vectorMagnitude angularVelocity _vehicle)}
            && {vectorMagnitude velocity _vehicle < (1/3.6)} && {vectorMagnitude angularVelocity _vehicle < 0.01};
        if (_handback isEqualTo []) exitWith {
            private _exact=_native isEqualTo (_entry getOrDefault ["command",[]]) && {_task in ["","MOVE","WAIT"]};
            if (_mode == "SIMPLE_BACK") then {
                _exact=_exact && {_entry getOrDefault ["simpleAcknowledged",false]}
                    && {toUpperANSI (_info param [0,""]) == "BACK"}
                    && {(_info param [1,""]) isEqualTo ((_entry getOrDefault ["simpleBefore",[]]) param [1,"MISSING"])};
            } else {_exact=_exact && {toUpperANSI (_info param [0,""]) != "BACK"}};
            if (!_exact) exitWith {call _fail};
            _vehicle forceSpeed 0;
            if (abs (getForcedSpeed _vehicle) > 0.1) exitWith {call _fail};
            _journal set ["cap",0];_assist set [0,0];
            _journal set ["crewHandback",["STOP",(serverTime+2) min _hard,_task,+_native,+_info]];
            _vehicle setVariable ["CBE_DrivingRecovery_Work",_journal,true];
            _vehicle setVariable ["CBE_DrivingAssist_State",_assist];
            if (_mode == "SIMPLE_BACK") then {_vehicle sendSimpleCommand "STOP"} else {doStop _operator};
            true
        };
        if (count _handback != 5 || {!((_handback select 1) isEqualType 0)}
            || {!finite (_handback select 1)} || {serverTime >= (_handback select 1)}
            || {(_handback select 1) > _hard}) exitWith {call _fail};
        private _phase=_handback select 0;
        if (_phase == "STOP") exitWith {
            private _stopped=if (_mode == "SIMPLE_BACK") then {
                toUpperANSI (_info param [0,""]) == "STOP"
                    && {(_info param [1,""]) isEqualTo ((_handback select 4) param [1,"MISSING"])}
                    && {_native isEqualTo (_handback select 3)} && {_task == (_handback select 2)}
            } else {_task == "STOP"};
            if (!_stopped) exitWith {
                if (_native isNotEqualTo (_handback select 3) || {_task != (_handback select 2)}
                    || {_mode == "SIMPLE_BACK" && {_info isNotEqualTo (_handback select 4)}}) exitWith {call _fail};
                true
            };
            if (!_rest) exitWith {true};
            _operator doMove _goal;
            _journal set ["crewHandback",["GOAL",(serverTime+2) min _hard,_task,+_native,+_info]];
            _vehicle setVariable ["CBE_DrivingRecovery_Work",_journal,true];
            true
        };
        if (_phase != "GOAL") exitWith {call _fail};
        private _target=_native param [0,[],[[]]];
        private _ack=_task == "MOVE" && {count _target == 3}
            && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0} && {_target vectorDistance _goal <= 0.25}
            && {toUpperANSI (_info param [0,""]) != "BACK"};
        if (!_ack) exitWith {
            if (!(_task in [_handback select 2,"MOVE"]) || {_native isNotEqualTo (_handback select 3)}) exitWith {call _fail};
            true
        };
        if (!_rest) exitWith {true};
        _journal set ["kind","FINAL"];_journal set ["commandMode","DESTINATION"];
        _journal set ["command",+_native];_journal set ["deadline",_hard];
        _journal deleteAt "crewHandback";
        _assist set [6,3];_assist set [7,time+(_hard-serverTime)];_assist set [8,"CREW_REVERSE_HANDBACK"];
        _assist set [10,false];
        _vehicle setVariable ["CBE_DrivingRecovery_Work",_journal,true];
        _vehicle setVariable ["CBE_DrivingAssist_State",_assist];
        false
    };
};
_pending
