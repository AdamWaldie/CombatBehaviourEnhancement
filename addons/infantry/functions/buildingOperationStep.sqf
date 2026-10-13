/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one bounded physical building-clearance step for the owner-local building FSM.
 * Locality / Authority: Runs through WAIT's shared scheduler where the group is local. It checks the
 * operation generation, Zeus and external ownership before issuing any movement command.
 * Repeat/JIP: One-shot callback. Durable room progress is public; owner-local actor assignments are
 * generation scoped and reconstructed after locality migration. Each room, entrance and egress
 * leg has one generation-owned movement writer. Entry, room and recovery movement each issue one
 * native doMove path request without a second formation-planner destination override.
 * Entry and floor-changing mover handoffs retain a covered checkpoint and at most one floor-access
 * checkpoint. Already-entered movers request same-floor rooms without revisiting their buddy.
 * Supported raw transit positions are kept separate from covered clearance targets;
 * checkpoint arrival never substitutes for visiting the assigned room.
 * Room receipts/holds require an unobstructed target-building segment, with at most sixteen
 * geometry probes per callback, cached at the current pose and rotating worker observation order.
 * Egress assigns bounded distinct supported exterior slots and holds arrivals within one metre.
 * Successful egress additionally requires each active worker's successive physical visits.
 * Reserve stages use bounded nearby cover selection with shared destination exclusions,
 * exterior building bounds and entrance clearance; no fixed fan layout is generated.
 * Stage receipts distinguish REJECTED current-position holds, APPROACH and physical ARRIVED.
 * A bounded episode/transform-scoped array journal preserves search counts and tried candidates on resume.
 * Rejected selection retries after five seconds, at most three searches per actor with tried targets excluded.
 * A still-owned approach times out after sixty seconds and yields to an alternate or EXHAUSTED hold.
 * Reserve stage selection processes at most one pending actor per callback; other attempts remain pending.
 * Retired ordinary movers and reserves with rejected stage geometry receive one hold,
 * never a recurring formation recall around an interior leader. A failed native path's automatic
 * formation fallback is held once per owned request until the existing finite retry or handover.
 * A stalled optional raw transit candidate yields once to its original room without claiming a visit.
 * Arguments: 0: building brain <HASHMAP> created by WAIT_fnc_BuildingOperationStart.
 * Return Value: Number - always -1 because the FSM schedules each later step separately.
 * Current caller: WAIT_fnc_BuildingOperationQueue through WAIT_fnc_CortexQueueJob.
 * Example: [_brain] call WAIT_fnc_BuildingOperationStep;
 */

params [["_brain",createHashMap,[createHashMap]]];
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {-1};
private _job=_brain getOrDefault ["job",createHashMap];
private _group=_brain getOrDefault ["group",grpNull];
// Retire obsolete scheduled work before route observations or room assignment. Only the
// obsolete brain is changed; the successor's public order and physical progress survive.
if (isNull _group || {!local _group}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}
    || {(_group getVariable ["WAIT_BuildingBrain",createHashMap]) isNotEqualTo _brain}) exitWith {
    _brain set ["pending",false];
    _brain set ["completed",true];
    _brain set ["cancelled",true];
    _brain set ["cancelReason","REPLACED_OR_LOST_OWNER"];
    -1
};
private _delay=call {
    private _group = _job get "group";
    if (isNull _group || {!local _group}) exitWith {-1};
    if ((_group getVariable ["WAIT_AIPass_ClearGeneration", -1]) != (_job get "generation")) exitWith {-1};
    private _actorAvailable={
        params ["_actor"];
        private _reservation=_actor getVariable ["WAIT_Cortex_ActorMove",[]];
        private _free=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        [_actor] call WAIT_fnc_CortexCombatEffective && {local _actor} && {!isPlayer _actor}
            && {group _actor == _group} && {isNull objectParent _actor} && {_free}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {isNull (remoteControlled _actor)}
            && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
            && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _actorTaskFree={
        params ["_actor"];
        simulationEnabled _actor && {!isObjectHidden _actor}
            && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _rememberMove={
        params ["_actor","_target"];
        private _targets=_job getOrDefault ["movementTargets",createHashMap];
        _targets set [netId _actor,+_target];
        _job set ["movementTargets",_targets];
        // A new owned request retires the previous arrival hold, even when the next
        // leg fails before reaching another node. A historical hold is not a live stop.
        (_job getOrDefault ["roomHolds",createHashMap]) deleteAt (netId _actor);
        (_job getOrDefault ["formationFallbackHolds",createHashMap]) deleteAt (netId _actor);
    };
    private _ownsCurrentMove={
        params ["_actor"];
        private _issued=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _actor,[]];
        private _live=(expectedDestination _actor) param [0,[]];
        currentCommand _actor == "MOVE" && {count _issued == 3} && {count _live == 3}
            && {_live vectorDistance _issued <= 0.25}
    };
    private _activeOwnMove={
        params ["_actor"];
        if (!([_actor] call _ownsCurrentMove) || {unitReady _actor}) exitWith {false};
        private _issued=(_job get "movementTargets") get (netId _actor);
        (getPosASL _actor) vectorDistance (AGLToASL _issued) > 0.4
    };
    // Callback-local geometry cache and hard ray budget; no persistent observer.
    private _roomGeometryResults=createHashMap;
    private _roomGeometryBudget=16;
    private _roomSegmentClear={
        params ["_actor","_targetASL"];
        private _actual=getPosASL _actor;
        private _key=str [diag_frameNo,netId _actor,_actual,_targetASL];
        private _cached=_key in _roomGeometryResults;
        // A negative answer cannot grant a receipt. Avoid group/config ownership
        // scans for exhausted or already-rejected queries; positives remain live-gated.
        if (!_cached && {_roomGeometryBudget <= 0}) exitWith {false};
        if (_cached && {!(_roomGeometryResults get _key)}) exitWith {false};
        if (!(call _mayIssueMovement)) exitWith {false};
        if (_cached) exitWith {_roomGeometryResults get _key};
        _roomGeometryBudget=_roomGeometryBudget-1;
        private _hits=lineIntersectsSurfaces [_actual vectorAdd [0,0,0.6],
            _targetASL vectorAdd [0,0,0.6],_actor,objNull,true,8,"GEOM","NONE"];
        // A saturated result cannot prove that the target wall was examined.
        private _clear=count _hits < 8 && {_hits findIf {
            (_x select 2) == (_job get "building") || {(_x select 3) == (_job get "building")}
        } < 0};
        _roomGeometryResults set [_key,_clear];
        _job set ["roomGeometryChecksLast",16-_roomGeometryBudget];
        _clear
    };
    private _roomMovementPoint={
        params ["_index"];
        (_job get "positions") select _index
    };
    private _finish = {
        params [["_restore",true,[true]],["_reason","CANCELLED",[""]]];
        // Old-owner callbacks may finish their local FSM, but never retire a successor's
        // durable order, results, assignments or restoration evidence.
        if (isNull _group || {!local _group}
            || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["WAIT_AIPass_Epoch",0])}
            || {(_job getOrDefault ["generation",-1]) != (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}) exitWith {
            _job set ["finished",true];
            _job set ["finishReason","OWNERSHIP_LOST"];
            -1
        };
        _restore=_restore && {!([_group] call WAIT_fnc_CortexExternalTakeover)};
        _group setVariable ["WAIT_Cortex_ClearEvidence",[+(_job get "cleared"),+(_job get "unreachable"),+(_job get "retryCounts"),+(_job get "failedBy"),_job get "deadline",_job get "lastProgressAt"],true];
        private _result = ["INCOMPLETE","COMPLETE"] select (count (_job get "cleared") == count (_job get "positions") && {!(_job getOrDefault ["egressFailed",false])} && {!(_job getOrDefault ["entryFailed",false])});
        if (_reason != "COMPLETE") then {_result="CANCELLED"};
        private _handbacks=[];
        // One bounded terminal snapshot preserves the route which actually failed before cleanup
        // clears actors' destinations. No geometry query or recurring trace is added to the hot path.
        private _routeActors=(_job getOrDefault ["team",[]])+(_job getOrDefault ["securityActors",[]]);
        _routeActors=_routeActors arrayIntersect _routeActors;
        _routeActors resize ((count _routeActors) min 16);
        // Compact terminal causes remain readable when the longer route trace is truncated.
        // Counts are diagnostic only; they cannot add visits or clear failure flags.
        private _terminalVisits=_job getOrDefault ["actorVisits",createHashMap];
        private _terminalEntered=_job getOrDefault ["enteredActors",[]];
        diag_log format ["WAIT CLEAR TERMINAL CAUSES: %1",[_job get "generation",_result,_reason,
            _job getOrDefault ["entryFailed",false],_job getOrDefault ["egressFailed",false],
            _routeActors apply {[netId _x,count (_terminalVisits getOrDefault [netId _x,[]]),_x in _terminalEntered]},
            (_job getOrDefault ["egressAssignments",[]]) apply {[netId (_x select 0),_x param [2,false]]}]];
        private _routeStates=+(_job getOrDefault ["pairStates",[]]);
        _routeStates resize ((count _routeStates) min 8);
        private _stageRecords=_job getOrDefault ["reserveStages",createHashMap];
        private _stageCounts=_job getOrDefault ["reserveStageSearchCounts",createHashMap];
        private _stageEvidence=(keys _stageRecords select [0,16]) apply {
            [_x,+(_stageRecords get _x),_stageCounts getOrDefault [_x,0]]
        };
        private _routeEvidence=[serverTime,_result,_routeStates,_routeActors apply {
            [netId _x,getPosATL _x,currentCommand _x,expectedDestination _x,
                _x checkAIFeature "MOVE",_x checkAIFeature "PATH"]
        },_reason,_stageEvidence];
        _group setVariable ["WAIT_Cortex_ClearRouteEvidence",_routeEvidence,true];
        diag_log format ["WAIT CLEAR ROUTE END: %1",_routeEvidence];
        if (!isNull _group) then {
            private _leader = [_group] call WAIT_fnc_CortexGroupAnchor;
            if (isNull _leader) then {_leader=leader _group};
            {
                if (local _x && {!isPlayer _x} && {group _x == _group}) then {
                    if ([_x] call _actorAvailable) then {
                        // Releasing an unchanged cap is separate from recalling formation.
                        // A temporary curator hold keeps its new destination; direct player,
                        // specialist and explicit external ownership still prohibit writes.
                        private _releaseOwnedSettings=!([_group,true,_x] call WAIT_fnc_CortexExternalTakeover)
                            && {!(currentCommand _x in ["ACTION","SCRIPTED","HEAL","REARM","REPAIR","REFUEL","SUPPORT","GET IN","GET OUT","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};

                        // Preserve edited settings while releasing unchanged WAIT leases.
                        if (_releaseOwnedSettings && {unitPos _x == "UP"} && {!isNil {_x getVariable "WAIT_Cortex_ClearStance"}}) then {
                            _x setUnitPos (_x getVariable ["WAIT_Cortex_ClearStance","AUTO"]);
                        };
                        if (_releaseOwnedSettings && {!isNil {_x getVariable "WAIT_Cortex_ClearForcedSpeed"}} && {abs ((getForcedSpeed _x)-(_x getVariable ["WAIT_Cortex_ClearAppliedSpeed",getForcedSpeed _x])) <= 0.1}) then {
                            _x forceSpeed (_x getVariable ["WAIT_Cortex_ClearForcedSpeed",-1]);
                        };
                        // Native tasks keep movement ownership during terminal cleanup too.
                        // Releasing our unchanged settings must not cancel treatment, boarding
                        // or a specialist action with a formation recall.
                        if (_restore && {[_x] call _actorTaskFree}
                            && {currentCommand _x != "MOVE" || {[_x] call _ownsCurrentMove}}) then {
                            _x doWatch objNull;
                            if (_reason == "COMPLETE") then {
                                // Settlement retains actual positions even when participation failed.
                                // Recalling an incomplete team around an interior leader creates a wedge.
                                // A later native/Zeus order replaces this one-shot hold; no loop rewrites it.
                                doStop _x;
                            } else {
                                _x setVariable ["WAIT_Cortex_ClearRecall",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],_leader,time+5]];
                                _x doFollow _leader;
                            };
                        };
                    };
                    _x setVariable ["WAIT_Cortex_ClearForcedSpeed",nil,true];
                    _x setVariable ["WAIT_Cortex_ClearAppliedSpeed",nil,true];
                    _x setVariable ["WAIT_Cortex_ClearStance",nil,true];
                    _x setVariable ["WAIT_Cortex_ClearReserve",nil];
                };
            } forEach (((_job get "team") + (_job getOrDefault ["securityActors",[]])) arrayIntersect ((_job get "team") + (_job getOrDefault ["securityActors",[]])));
            _group setVariable ["WAIT_AIPass_ClearBuilding", nil, true];
            _group setVariable ["WAIT_Cortex_ClearEgress",nil,true];
            _group setVariable ["WAIT_AIPass_ClearOrder", nil, true];
            _group setVariable ["WAIT_Cortex_ClearFollowBudget",nil,true];
            _group setVariable ["WAIT_AIPass_ClearApplied", nil];
        };
        if (_reason == "COMPLETE" && {_restore}) then {
            _group setVariable ["WAIT_Cortex_ClearHold",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],[_group] call WAIT_fnc_NativeOrderReceipt,((_job get "team") + (_job getOrDefault ["securityActors",[]])) arrayIntersect ((_job get "team") + (_job getOrDefault ["securityActors",[]]))],true];
        };
        if (_reason == "NEW_ORDER" && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) then {
            // A native waypoint does not necessarily cancel an actor's explicit movement request.
            // Release only a MOVE still aimed at the destination this job actually issued.
            // A newer actor destination, service task or external controller remains untouched.
            private _targets=_job getOrDefault ["movementTargets",createHashMap];
            private _movers=(_job get "team")+(_job getOrDefault ["securityActors",[]]);
            {
                private _target=_targets getOrDefault [netId _x,[]];
                private _destination=(expectedDestination _x) param [0,[]];
                if (currentCommand _x == "MOVE" && {count _target == 3} && {count _destination == 3}
                    && {_destination vectorDistance _target <= 0.25}
                    && {[_x] call _actorAvailable} && {[_x] call _actorTaskFree}
                    && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
                    && {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}) then {
                    _handbacks pushBack [_x,"MOVE",+_target];
                };
            } forEach (_movers arrayIntersect _movers);
            // Native waypoint replacement must also release our finite pre-completion holds.
            // Release through this owner after cancellation; the ordinary group brain may
            // already have retired after a failed clearance and cannot be a required consumer.
            private _held=(_job getOrDefault ["accessHeld",[]])+(_job getOrDefault ["quarantineHeld",[]])+(_job getOrDefault ["securityActors",[]]);
            private _roomHolds=_job getOrDefault ["roomHolds",createHashMap];
            _held append ((_job get "team") select {netId _x in _roomHolds});
            private _fallbackHolds=_job getOrDefault ["formationFallbackHolds",createHashMap];
            _held append ((_job get "team") select {netId _x in _fallbackHolds});
            _held append ((_job getOrDefault ["egressAssignments",[]]) select {_x param [2,false,[true]]} apply {_x select 0});
            _held=(_held arrayIntersect _held) select {
                local _x && {group _x == _group} && {!isPlayer _x} && {currentCommand _x == "STOP"}
                    && {[_x] call _actorAvailable} && {!([_group,false,_x] call WAIT_fnc_CortexExternalTakeover)}
            };
            {_handbacks pushBack [_x,"STOP",[]]} forEach _held;
        };
        _group setVariable ["WAIT_Cortex_ClearResult",[_result,count (_job get "cleared"),count (_job get "positions")],true];
        _job set ["finished",true];
        _job set ["finishReason",_reason];
        _job set ["result",_result];
        _group setVariable ["WAIT_Cortex_ClearStatus",nil,true];
        private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
        if (_operationGeneration >= 0) then {
            if (_reason == "COMPLETE") then {
                private _outcomeReason=["CLEAR_INCOMPLETE","CLEAR_COMPLETE"] select (_result == "COMPLETE");
                [_group,_operationGeneration,_result,_outcomeReason] call WAIT_fnc_OperationRelease;
            } else {
                [_group,_operationGeneration,_reason] call WAIT_fnc_OperationCancel;
            };
        };
        if (_reason == "NEW_ORDER" && {local _group}
            && {(_brain get "ownerEpoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}
            && {(_group getVariable ["WAIT_BuildingBrain",createHashMap]) isEqualTo _brain}
            && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}) then {
            _group setVariable ["WAIT_Cortex_ClearHold",nil,true];
            {
                _x params ["_actor","_command","_target"];
                private _destination=(expectedDestination _actor) param [0,[]];
                if (local _group && {(_brain get "ownerEpoch") == (_group getVariable ["WAIT_AIPass_Epoch",0])}
                    && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}
                    && {count (_group getVariable ["WAIT_Operation",createHashMap]) == 0}
                    && {currentCommand _actor == _command}
                    && {_command == "STOP" || {count _destination == 3 && {_destination vectorDistance _target <= 0.25}}}
                    && {[_actor] call _actorAvailable} && {[_actor] call _actorTaskFree}
                    && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
                    && {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}) then {
                    (_job getOrDefault ["movementTargets",createHashMap]) deleteAt (netId _actor);
                    _actor setVariable ["WAIT_Cortex_ClearRecall",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],leader _group,time+5]];
                    if (_actor == leader _group) then {
                        // A stopped leader cannot resume an authored route by following itself.
                        // Only MOVE has a plain positional handback; other waypoint semantics
                        // remain with the engine and must not be replaced by a fabricated route.
                        private _waypointIndex=currentWaypoint _group;
                        private _waypoint=[_group,_waypointIndex];
                        if (_waypointIndex > 0 && {_waypointIndex < count waypoints _group}
                            && {waypointType _waypoint == "MOVE"}) then {
                            _actor doMove waypointPosition _waypoint;
                        };
                    } else {
                        _actor doFollow leader _group;
                    };
                };
            } forEach _handbacks;
        };
        diag_log format ["[WAIT] %1 clear building %2 (%3 of %4 positions)",_group,_result,count (_job get "cleared"),count (_job get "positions")];
        diag_log format ["WAIT CLEAR END TRACE: %1",[_reason,_operationGeneration,(_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1],_group getVariable ["WAIT_AIPass_Epoch",0],_brain getOrDefault ["ownerEpoch",-1]]];
        -1
    };
    if (isNull _group || {!local _group} || {!(_group getVariable ["WAIT_AIPass_ClearBuilding", false])}
        || {!alive (_job get "building")} || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])}) exitWith {[true,"CANCELLED"] call _finish};
    // This operation issues actor destinations, never native waypoints. Any authored
    // waypoint change supersedes it before observations, recovery or speed writes.
    private _nativeOrderReceipt=_job getOrDefault ["nativeOrderReceipt",[]];
    if (_nativeOrderReceipt isNotEqualTo []
        && {([_group] call WAIT_fnc_NativeOrderReceipt) isNotEqualTo _nativeOrderReceipt}) exitWith {
        private _result=[false,"NEW_ORDER"] call _finish;
        _group setVariable ["WAIT_OperationGeneration",(_group getVariable ["WAIT_OperationGeneration",0])+1,true];
        _result
    };
    private _building=_job get "building";
    private _buildingTransform=_job getOrDefault ["buildingTransform",[]];
    if (_buildingTransform isNotEqualTo []
        && {_buildingTransform isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}) exitWith {
        [true,"BUILDING_MOVED"] call _finish
    };
    private _operationGeneration=_job getOrDefault ["operationGeneration",-1];
    private _operationEndReason="";
    if (_operationGeneration >= 0) then {
        private _operationStatus=[_group,_operationGeneration,2,15] call WAIT_fnc_OperationStep;
        if (_operationStatus in ["LOST_OWNER","ZEUS","EXTERNAL","REPLACED"]) then {_operationEndReason=_operationStatus};
    };
    // Leave this callback before selecting lanes or issuing another room movement. The building
    // controller owns ordinary room/pair recovery, but it never owns a replaced or external order.
    if (_operationEndReason != "") exitWith {
        [false,_operationEndReason] call _finish
    };
    // Recovery belongs to the common operation lifecycle. A worker that has exhausted its
    // isolated recovery must not retain a clearance lane or keep receiving room orders.
    private _operation=_group getVariable ["WAIT_Operation",createHashMap];
    private _unavailable=if ((_operation getOrDefault ["generation",-1]) == _operationGeneration
        && {(_operation getOrDefault ["intent",""]) == "CLEAR"}) then {
        +(_operation getOrDefault ["unavailable",[]])
    } else {[]};
    // A fresh Zeus or script order immediately owns movement. Retire Cortex state without
    // a follow, stance or behaviour command that could overwrite that replacement order.
    if !([_group] call WAIT_fnc_CortexIsEligible) exitWith {[false,"EXTERNAL"] call _finish};
    // Check ownership at every local movement write as a Zeus, player or specialist controller
    // can take over during this queued callback after the operation-level eligibility check.
    private _emptyOperation=createHashMap;
    private _mayIssueMovement = {
        private _currentOperation=_group getVariable ["WAIT_Operation",_emptyOperation];
        local _group && {!(_brain getOrDefault ["cancelled",false])}
            && {!(_brain getOrDefault ["finished",false])}
            && {(_group getVariable ["WAIT_BuildingBrain",_emptyOperation]) isEqualTo _brain}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
            && {(_job get "generation") == (_group getVariable ["WAIT_AIPass_ClearGeneration",-1])}
            && {_operationGeneration < 0 || {(_currentOperation getOrDefault ["generation",-2]) == _operationGeneration}}
            && {!isNull _building} && {alive _building}
            && {!([_group] call WAIT_fnc_CortexExternalTakeover)}
            && {_buildingTransform isEqualTo []
                || {_buildingTransform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}}
            && {_nativeOrderReceipt isEqualTo []
                || {([_group] call WAIT_fnc_NativeOrderReceipt) isEqualTo _nativeOrderReceipt}}
    };
    // Before exterior actors commit to their first room, honour wholly locked access.
    // Native doMove can traverse a closed door without changing its lock variable.
    // Existing interior occupants are not frozen by this exterior admission barrier.
    if !(_job getOrDefault ["accessAdmitted",false]) then {
        private _probe=(_job get "team") param [0,objNull];
        if (isNil {_building getVariable "WAIT_Cortex_DoorDefinitions"}) then {
            [_probe,_building,["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
        };
        private _doors=_building getVariable ["WAIT_Cortex_DoorDefinitions",[]];
        private _allLocked=_doors isNotEqualTo [] && {_doors findIf {
            (_building getVariable [format ["bis_disabled_Door_%1",_x select 0],0]) isEqualTo 0
                || {_building animationSourcePhase (_x select 1) >= 0.8}
        } < 0};
        private _bounds=boundingBoxReal _building;
        private _inside=(_job get "team") findIf {
            private _position=_building worldToModel (getPosATL _x);
            private _minimum=_bounds select 0;
            private _maximum=_bounds select 1;
            (_position select 0) > (_minimum select 0) && {(_position select 0) < (_maximum select 0)}
                && {(_position select 1) > (_minimum select 1)} && {(_position select 1) < (_maximum select 1)}
                && {(_position select 2) > (_minimum select 2)} && {(_position select 2) < (_maximum select 2)}
        } >= 0;
        _job set ["accessBlocked",_allLocked && {!_inside} && {(_job getOrDefault ["phase",""]) != "EGRESS"}];
        if !(_job get "accessBlocked") then {
            _job set ["accessAdmitted",true];
            if (_job getOrDefault ["accessReported",false]) then {
                _group setVariable ["WAIT_Cortex_ClearStatus",["ENTRY",0,0,count (_job get "positions"),count (_job get "pairs"),serverTime],true];
            };
        };
    };
    if (_job getOrDefault ["accessBlocked",false]) exitWith {
        if (serverTime > ((_job get "deadline") min (_job getOrDefault ["hardDeadline",_job get "deadline"]))) exitWith {[true,"ACCESS_BLOCKED"] call _finish};
        private _held=_job getOrDefault ["accessHeld",[]];
        {
            if (!(_x in _held) && {[_x] call _actorAvailable} && {[_x] call _actorTaskFree}
                && {call _mayIssueMovement}) then {doStop _x; _held pushBackUnique _x};
        } forEach (_job get "team");
        _job set ["accessHeld",_held];
        if !(_job getOrDefault ["accessReported",false]) then {
            _job set ["accessReported",true];
            _group setVariable ["WAIT_Cortex_ClearStatus",["ACCESS_BLOCKED",0,0,count (_job get "positions"),count (_job get "pairs"),serverTime],true];
        };
        1.5
    };
    if ((_job getOrDefault ["phase","CLEAR"]) == "EGRESS") exitWith {
        private _assignments=(_job get "egressAssignments") select {
            _x params ["_unit"];
            [_unit] call _actorAvailable && {!(_unit in _unavailable)}
        };
        // A diverted/unavailable actor is no longer ours to route, but its unfinished exit
        // must remain visible instead of counting an empty eligible set as successful egress.
        if (count _assignments < count (_job get "egressAssignments")) then {_job set ["egressFailed",true]};
        private _outsideExit={
            params ["_assignment"];
            _assignment params ["_unit","_target"];
            // Physical exit is monotonic progress for this generation. Hold each arrival
            // once so native formation does not scatter it while partners descend stairs.
            if (_assignment param [2,false,[true]]) exitWith {false};
            // Retain observed arrivals, but frozen/hidden positions cannot establish a new exit.
            if (!(simulationEnabled _unit) || {isObjectHidden _unit}) exitWith {true};
            private _outside=_unit distance2D _target > 1
                || {abs (((getPosATL _unit) select 2)-(_target param [2,0])) > 1.5};
            if (!_outside) then {
                _assignment set [2,true];
                if ([_unit] call _actorAvailable && {[_unit] call _actorTaskFree}
                    && {call _mayIssueMovement}) then {
                    doStop _unit;
                };
            };
            _outside
        };
        // Matching a ground exit horizontally is insufficient when still upstairs.
        private _arrived=_assignments findIf {[_x] call _outsideExit} < 0;
        if (_arrived || {_assignments isEqualTo []} || {time >= (_job get "egressDeadline")}) then {
            if (!_arrived && {_assignments isNotEqualTo []}) then {
                _job set ["egressFailed",true];
                diag_log format ["[WAIT] %1 clear egress incomplete (%2 still inside)",_group,{[_x] call _outsideExit} count _assignments];
                // Preserve the last owned exit request before terminal cleanup erases it.
                // One compact record per missing receipt, bounded by the admitted worker cap.
                {
                    _x params ["_actor","_target"];
                    if !(_x param [2,false,[true]]) then {
                        private _key=netId _actor;
                        private _progress=(_job get "egressProgress") select {(_x select 0) == _actor};
                        diag_log format ["WAIT CLEAR EGRESS STALL: %1",[_job get "generation",_key,
                            getPosATL _actor,+_target,currentCommand _actor,expectedDestination _actor,
                            unitReady _actor,getUnitState _actor,simulationEnabled _actor,isObjectHidden _actor,
                            (_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [_key,[]],
                            _progress apply {[_x select 1,_x select 2,_x select 3]}]];
                    };
                } forEach (_assignments select [0,8]);
            };
            [true,"COMPLETE"] call _finish
        } else {
            if (call _mayIssueMovement) then {
                {
                    _x params ["_unit","_target"];
                    if ([_x] call _outsideExit && {simulationEnabled _unit} && {!isObjectHidden _unit}) then {
                        private _records=_job get "egressProgress";
                        private _recordIndex=_records findIf {(_x select 0) == _unit};
                        if (_recordIndex >= 0) then {
                            private _record=_records select _recordIndex;
                            private _checkpoint=_record param [4,[],[[]]];
                            if (_checkpoint isNotEqualTo [] && {[_unit] call _actorAvailable}
                                && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}) then {
                                private _atCheckpoint=(getPosASL _unit) vectorDistance (AGLToASL _checkpoint) <= 1.5
                                    && {abs (((getPosASL _unit) select 2)-((AGLToASL _checkpoint) select 2)) <= 0.75}
                                    && {[_unit,AGLToASL _checkpoint] call _roomSegmentClear};
                                if (_atCheckpoint || {time-(_record select 2) >= 8}) then {
                                    // A failed checkpoint also yields once to the original exit slot.
                                    // Neither case creates an exit receipt or renews the 45-second budget.
                                    _record set [4,[]];
                                    _unit doMove _target;
                                    [_unit,_target] call _rememberMove;
                                    _record set [1,(getPosATL _unit) vectorDistance _target];
                                    _record set [2,time];
                                    _checkpoint=[];
                                };
                            };
                            private _progressTarget=if (_checkpoint isEqualTo []) then {_target} else {_checkpoint};
                            private _remaining=(getPosATL _unit) vectorDistance _progressTarget;
                            if ((_record select 1)-_remaining >= 0.5) then {
                                _record set [1,_remaining];
                                _record set [2,time];
                            };
                            // Opening an unlocked door does not replace a moving route. The engine
                            // observes the opened door; only measured no-progress permits one retry.
                            [_unit,_job get "building",["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
                            if (time-(_record select 2) >= 8 && {(_record select 3) < 1}
                                && {[_unit] call _actorAvailable} && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}) then {
                                // Try one physically visited current-floor point nearer the exit.
                                // Native room points remain candidates; selection itself proves no path.
                                private _exitRooms=_job get "positions";
                                private _candidates=if (insideBuilding _unit <= 0) then {[]} else {((_job get "cleared") select [0,24]) select {
                                    private _point=_exitRooms select _x;
                                    abs (((getPosATL _unit) select 2)-(_point select 2)) <= 0.75
                                        && {_unit distance2D _point > 2}
                                }};
                                private _ranked=_candidates apply {
                                    private _point=_exitRooms select _x;
                                    [(_point distance2D _target)+0.25*(_unit distance2D _point),_x]
                                };
                                _ranked sort true;
                                private _retryTarget=+_target;
                                if (_ranked isNotEqualTo []) then {
                                    _retryTarget=+(_exitRooms select ((_ranked select 0) select 1));
                                    _record set [4,+_retryTarget];
                                    _record set [1,(getPosATL _unit) vectorDistance _retryTarget];
                                    _record set [2,time];
                                };
                                _unit doMove _retryTarget;
                                [_unit,_retryTarget] call _rememberMove;
                                _record set [3,1];
                                private _evidence=_group getVariable ["WAIT_Cortex_ClearEgressRetries",[]];
                                _evidence pushBack [serverTime,netId _unit,1,getPosATL _unit,+_target,_remaining];
                                _group setVariable ["WAIT_Cortex_ClearEgressRetries",_evidence,true];
                            };
                        };
                    };
                } forEach _assignments;
            };
            1.5
        }
    };
    private _positions = _job get "positions";
    private _cleared = _job get "cleared";
    private _unreachable = _job get "unreachable";
    private _assigned = _job get "assigned";
    private _retryCounts = _job get "retryCounts";
    private _failedBy = _job get "failedBy";
    private _retryChanged = false;
    private _pairs=_job get "pairs";
    private _pairStates=_job get "pairStates";
    // Refill casualties from soldiers that were deliberately left on exterior security. This is
    // evaluated in the existing building job, so it adds no per-unit scheduler or event-handler cost.
    private _reserved=[];
    {_reserved append _x} forEach _pairs;
    private _leader=[_group] call WAIT_fnc_CortexGroupAnchor;
    if (isNull _leader) then {_leader=leader _group};
    private _rotatedOut=_job getOrDefault ["rotatedOut",[]];
    {_rotatedOut pushBackUnique _x} forEach (_reserved select {_x in _unavailable});
    _job set ["rotatedOut",_rotatedOut];
    // Exhausted ordinary room movers remain owned by this operation until handover.
    // Retiring their lane must not send them into native formation around an interior leader.
    private _quarantineHeld=_job getOrDefault ["quarantineHeld",[]];
    {
        if (_x in _unavailable && {!(_x in _quarantineHeld)} && {[_x] call _actorAvailable}
            && {[_x] call _actorTaskFree} && {call _mayIssueMovement}) then {
            doStop _x;
            _quarantineHeld pushBackUnique _x;
            // Continuing with replacements cannot erase an ordinary stranded worker.
            _job set ["entryFailed",true];
        };
    } forEach (_rotatedOut select [0,16]);
    _job set ["quarantineHeld",_quarantineHeld];
    private _reserveReady={
        params ["_candidate"];
        private _reservation=_candidate getVariable ["WAIT_Cortex_ActorMove",[]];
        private _reservationFree=_reservation isEqualTo []
            || {_reservation isEqualType [] && {count _reservation == 3} && {(_reservation param [2,1e12,[0]]) <= time}};
        // Once staging has claimed this reserve, a different individual MOVE/FOLLOW
        // is a replacement order. Do not promote it and overwrite that live command.
        private _stageReceipt=_candidate getVariable ["WAIT_Cortex_ClearReserve",[]];
        private _stagedHere=count _stageReceipt == 3
            && {(_stageReceipt select 0) == (_job get "generation")}
            && {(_stageReceipt select 1) == (_group getVariable ["WAIT_AIPass_Epoch",0])};
        private _stageCommandFree=!_stagedHere
            || {!(currentCommand _candidate in ["MOVE","FOLLOW"])}
            || {[_candidate] call _ownsCurrentMove};
        [_candidate] call WAIT_fnc_CortexCombatEffective && {simulationEnabled _candidate}
            && {!isObjectHidden _candidate} && {_stageCommandFree} && {local _candidate} && {!isPlayer _candidate}
            && {isNull objectParent _candidate} && {!(_candidate in _reserved)} && {!(_candidate in _rotatedOut)}
            && {!(_candidate in _unavailable)} && {isNull (remoteControlled _candidate)}
            && {([_candidate] call WAIT_fnc_CortexExternalOwner) == ""}
            && {_reservationFree} && {_candidate checkAIFeature "MOVE"} && {_candidate checkAIFeature "PATH"}
            && {!([_candidate] call WAIT_fnc_CompatibilityExternalControl)}
            && {!(currentCommand _candidate in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
    };
    private _reserves=(units _group) select {[_x] call _reserveReady && {_x != _leader}};
    if (_reserves isEqualTo [] && {[_leader] call _reserveReady}) then {
        _reserves pushBack _leader;
    };
    // Reserves stage near the entry instead of following the native formation around the house.
    // This is one destination plus an arrival hold per actor, not a recurring movement rewrite.
    private _reserveStages=_job getOrDefault ["reserveStages",createHashMap];
    private _stageAttempts=_job getOrDefault ["reserveStageAttempts",[]];
    // Pending reserves do not consume attempts when another actor used this callback budget.
    private _stageSearchBudget=1;
    private _stageJournalChanged=false;
    private _stageSearchCounts=_job getOrDefault ["reserveStageSearchCounts",createHashMap];
    private _stageTriedTargets=_job getOrDefault ["reserveStageTriedTargets",createHashMap];
    {
        private _reserve=_x;
        private _key=netId _reserve;
        private _stage=_reserveStages getOrDefault [_key,[]];
        private _searchCount=_stageSearchCounts getOrDefault [_key,0];
        private _searchPending=(_stage isEqualTo [] && {!(_key in _stageAttempts)})
            || {(_stage param [2,""]) == "REJECTED" && {_searchCount < 3}
                && {serverTime >= (_stage param [3,1e12])}};
        if (_searchPending && {_stageSearchBudget > 0} && {call _mayIssueMovement}) then {
            _stageSearchBudget=_stageSearchBudget-1;
            _stageAttempts pushBackUnique _key;
            _stageSearchCounts set [_key,(_searchCount+1) min 3];
            _stageJournalChanged=true;
            // A rejected staging ray must not leave a reserve following the interior leader.
            // Hold the actual position first; replace it only with the one validated stage leg.
            if ([_reserve] call _reserveReady && {call _mayIssueMovement}) then {
                private _hold=getPosATL _reserve;
                doStop _reserve;
                _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_hold]];
                _stage=[+_hold,true,"REJECTED"];
                _stage set [3,serverTime+5];
                if ((_searchCount+1) >= 3) then {_stage set [2,"EXHAUSTED"]};
                _reserveStages set [_key,_stage];
                private _securityActors=_job getOrDefault ["securityActors",[]];
                _securityActors pushBackUnique _reserve;
                _job set ["securityActors",_securityActors];
            };
            private _entry=_job get "entry";
            if (_entry isNotEqualTo [] && {_searchCount < 3}) then {
                private _bounds=boundingBoxReal _building;
                private _centre=_building modelToWorld (((_bounds select 0) vectorAdd (_bounds select 1)) vectorMultiply 0.5);
                _centre set [2,0];
                private _outward=_centre getDir _entry;
                private _search=_entry getPos [7,_outward];
                private _taken=+(_stageTriedTargets getOrDefault [_key,[]]);
                private _liveReserveKeys=_reserves apply {netId _x};
                // Historical stage receipts remain diagnostic, but promoted/unavailable actors
                // no longer reserve a destination. Physical occupancy is checked by the selector.
                {
                    if (_x != _key && {_x in _liveReserveKeys}) then {
                        _taken pushBack ((_reserveStages get _x) select 0);
                    };
                } forEach keys _reserveStages;
                private _cover=[_search,_centre,12,_taken,_group] call WAIT_fnc_CortexFindCover;
                private _target=_cover select 0;
                if (_cover select 1) then {
                    private _tried=+(_stageTriedTargets getOrDefault [_key,[]]);
                    _tried pushBackUnique +_target;
                    _stageTriedTargets set [_key,_tried];
                };
                private _model=_building worldToModel _target;
                private _minimum=_bounds select 0;
                private _maximum=_bounds select 1;
                private _exterior=(_model select 0) < (_minimum select 0)-0.5
                    || {(_model select 0) > (_maximum select 0)+0.5}
                    || {(_model select 1) < (_minimum select 1)-0.5}
                    || {(_model select 1) > (_maximum select 1)+0.5};
                // Cover geometry is not a native path receipt. Exclude configured same-floor exit vicinity and
                // validate standing space at the endpoint. Native pathfinding may route around corners.
                private _blocksExit=(_job getOrDefault ["entries",[]]) findIf {
                    _target distance2D _x < 3 && {abs (((AGLToASL _target) select 2)-((AGLToASL _x) select 2)) <= 1}
                } >= 0;
                if ((_cover select 1) && {_exterior} && {!_blocksExit} && {_target distance2D _entry >= 3}
                    && {_target distance2D _entry <= 18} && {!surfaceIsWater _target}
                    && {((surfaceNormal _target) select 2) >= 0.65}
                    && {(lineIntersectsSurfaces [(AGLToASL _target) vectorAdd [0,0,0.15],
                        (AGLToASL _target) vectorAdd [0,0,1.8],_reserve,objNull,true,1,"GEOM","NONE"]) isEqualTo []}) then {
                    if ([_reserve] call _reserveReady && {call _mayIssueMovement}) then {
                        _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_target]];
                        _reserve doMove _target;
                        [_reserve,_target] call _rememberMove;
                        _stage=[+_target,false,"APPROACH"];
                        _stage set [3,serverTime+60];
                        _reserveStages set [_key,_stage];
                        private _securityActors=_job getOrDefault ["securityActors",[]];
                        _securityActors pushBackUnique _reserve;
                        _job set ["securityActors",_securityActors];
                    };
                };
            };
        };
        // Arrival proximity does not authorize cancelling a different live MOVE.
        // Preserve floor-aware native commitment just as for interior room holds.
        if (_stage isNotEqualTo [] && {!(_stage select 1)}
            && {(getPosASL _reserve) vectorDistance (AGLToASL (_stage select 0)) <= 2}
            && {abs (((getPosASL _reserve) select 2)-((AGLToASL (_stage select 0)) select 2)) <= 0.75}
            && {currentCommand _reserve in ["", "STOP"] || {[_reserve] call _ownsCurrentMove}}
            && {!([_reserve] call _activeOwnMove)}
            && {[_reserve] call _reserveReady} && {call _mayIssueMovement}) then {
            doStop _reserve;
            _stage set [1,true];
            _stage set [2,"ARRIVED"];
            _stageJournalChanged=true;
        };
        // A deadline may retire only the movement request this stage still owns. It does not
        // renew the clearance lifetime or turn a blocked approach into an arrival receipt.
        if ((_stage param [2,""]) == "APPROACH" && {serverTime >= (_stage param [3,1e12])}
            && {[_reserve] call _ownsCurrentMove} && {[_reserve] call _reserveReady}
            && {call _mayIssueMovement}) then {
            private _hold=getPosATL _reserve;
            doStop _reserve;
            (_job getOrDefault ["movementTargets",createHashMap]) deleteAt _key;
            _reserve setVariable ["WAIT_Cortex_ClearReserve",[_job get "generation",_group getVariable ["WAIT_AIPass_Epoch",0],+_hold]];
            _stage=[+_hold,true,"REJECTED"];
            _stage set [3,serverTime+5];
            if ((_stageSearchCounts getOrDefault [_key,0]) >= 3) then {_stage set [2,"EXHAUSTED"]};
            _reserveStages set [_key,_stage];
            _stageJournalChanged=true;
        };
    } forEach (_reserves select [0,8]);
    _job set ["reserveStages",_reserveStages];
    _job set ["reserveStageAttempts",_stageAttempts];
    _job set ["reserveStageSearchCounts",_stageSearchCounts];
    _job set ["reserveStageTriedTargets",_stageTriedTargets];
    // Build the migration journal only after an owned stage transition. Idle callbacks
    // retain the published receipt without copying every actor record again.
    if (_stageJournalChanged && {call _mayIssueMovement}) then {
        private _budgetRows=(keys _stageSearchCounts select [0,64]) apply {
            [_x,_stageSearchCounts get _x,+(_stageTriedTargets getOrDefault [_x,[]]),+(_reserveStages getOrDefault [_x,[]])]
        };
        private _stageBudget=[_building,_job get "hardDeadline",_job get "buildingTransform",_budgetRows];
        if ((_group getVariable ["WAIT_Cortex_ClearStageBudget",[]]) isNotEqualTo _stageBudget) then {
            _group setVariable ["WAIT_Cortex_ClearStageBudget",_stageBudget,true];
        };
    };
    private _pairRosterChanged=false;
    {
        private _pairIndex=_forEachIndex;
        private _pair=_x;
        private _state=_pairStates select _pairIndex;
        private _laneRosterChanged=false;
        for "_slot" from 0 to ((count _pair)-1) do {
            private _member=_pair select _slot;
            if ((!([_member] call _actorAvailable) || {_member in _unavailable}) && {_reserves isNotEqualTo []}) then {
                private _replacement=_reserves deleteAt 0;
                _pair set [_slot,_replacement];
                _pairRosterChanged=true;
                _laneRosterChanged=true;
                _rotatedOut pushBackUnique _member;
                private _team=_job get "team";
                _team pushBackUnique _replacement;
                // The pair and common lifecycle must account for the same replacement.
                // A reserve's real travel cannot renew progress while absent from this roster.
                private _liveOperation=_group getVariable ["WAIT_Operation",createHashMap];
                if ((_liveOperation getOrDefault ["generation",-1]) == _operationGeneration
                    && {(_liveOperation getOrDefault ["intent",""]) == "CLEAR"}
                    && {(_liveOperation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
                    private _participants=+(_liveOperation getOrDefault ["participants",[]]);
                    _participants=_participants-[_member];
                    _participants pushBackUnique _replacement;
                    private _progressRecords=(_liveOperation getOrDefault ["participantProgress",[]]) select {(_x select 0) != _member};
                    if (_progressRecords findIf {(_x select 0) == _replacement} < 0) then {
                        _progressRecords pushBack [_replacement,getPosATL _replacement];
                    };
                    // Retire only the removed actor's active observation. Its retry budget and
                    // unavailable status remain generation-owned, preventing reserve rotation from
                    // making a failed actor eligible for unlimited recovery attempts.
                    private _recovery=_liveOperation getOrDefault ["recovery",createHashMap];
                    _recovery deleteAt (netId _member);
                    _liveOperation set ["recovery",_recovery];
                    _liveOperation set ["participants",_participants];
                    _liveOperation set ["participantProgress",_progressRecords];
                    _group setVariable ["WAIT_Operation",_liveOperation,true];
                };
                (_job get "assigned") pushBack [];
                private _lastPositions=_state select 2;
                _lastPositions set [_slot,getPosATL _replacement];
                _state set [2,_lastPositions];
                _state set [3,time];
                _state set [4,0];
                _state set [5,-1];
                // A reserve starts at its own physical position. Do not compare its travel
                // against the removed actor's nearer best-distance baseline.
                _state set [13,1e12];
                _state set [14,[]];
                private _evidence=_group getVariable ["WAIT_Cortex_ClearReinforcements",[]];
                _evidence pushBack [serverTime,netId _member,netId _replacement,_pairIndex,_slot];
                _group setVariable ["WAIT_Cortex_ClearReinforcements",_evidence,true];
                diag_log format ["[WAIT] Clear pair %1 reinforced: %2 replaced %3",_pairIndex,_replacement,_member];
            };
        };
        // A wholly replaced exterior lane must establish its own physical entry.
        // Retain the original route, room coverage and deadline; an entered survivor
        // keeps its current interior progress and is never rallied outside.
        if (_laneRosterChanged && {_pair findIf {_x in (_job getOrDefault ["enteredActors",[]])} < 0}) then {
            _state set [0,0];
            _state set [8,-1];
            _state set [12,false];
        };
    } forEach _pairs;
    _job set ["rotatedOut",_rotatedOut];
    if (_pairRosterChanged) then {
        // Publish the actual lane partners, without rebuilding an active lane's route.
        private _pairSnapshot=_pairs apply {+_x};
        _group setVariable ["WAIT_CombatPairs",_pairSnapshot,true];
        private _liveOperation=_group getVariable ["WAIT_Operation",createHashMap];
        if ((_liveOperation getOrDefault ["generation",-1]) == _operationGeneration
            && {(_liveOperation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
            _liveOperation set ["pairs",_pairSnapshot];
            _group setVariable ["WAIT_Operation",_liveOperation,true];
        };
    };
    // Release reservations before selection so another soldier can visit a casualty's room.
    // Reassigned units belong to their new commander and must receive no further orders here.
    private _activeWorkers=(_job get "team") select {[_x] call _actorAvailable
        && {!(_x in _rotatedOut)} && {!(_x in _unavailable)}};
    // Every assigned lane gets a chance before a room is declared exhausted.
    // A fixed two-lane threshold abandoned rooms while a third capable pair existed.
    // The operation deadline and finite per-room recovery budget still bound retries.
    private _failureThreshold=(count (_job get "pairs")) max 1;
    {
        if (!([_x] call _actorAvailable) || {_x in _rotatedOut} || {_x in _unavailable}) then {
            _assigned set [_forEachIndex,[]];
        };
    } forEach (_job get "team");
    private _now = time;
    private _before = count _cleared;
    private _unreachableBefore = count _unreachable;
    // A worker may physically traverse another assigned position on the way to its own.
    // Check claimed rooms first, then rotate a fixed topology sample. This keeps physical arrival
    // authoritative without making every callback scale with every room and every worker.
    private _visitIndices=[];
    {
        private _claimed=(_x param [0,-1]);
        if (_claimed >= 0 && {_claimed < count _positions}) then {_visitIndices pushBackUnique _claimed};
    } forEach _assigned;
    private _visitBudget=(count _positions) min 24;
    private _visitCursor=(_job getOrDefault ["visitCursor",0]) mod (count _positions);
    for "_offset" from 0 to (_visitBudget-1) do {
        _visitIndices pushBackUnique ((_visitCursor+_offset) mod (count _positions));
    };
    _job set ["visitCursor",(_visitCursor+_visitBudget) mod (count _positions)];
    // Rotate first observer so budget exhaustion cannot always prefer one worker.
    private _actorCursor=(_job getOrDefault ["visitActorCursor",0]) mod ((count _activeWorkers) max 1);
    private _visitWorkers=(_activeWorkers select [_actorCursor]) + (_activeWorkers select [0,_actorCursor]);
    _job set ["visitActorCursor",(_actorCursor+1) mod ((count _activeWorkers) max 1)];
    _job set ["roomGeometryChecksLast",0];
    {
        private _visitor = _x;
        if ([_visitor] call WAIT_fnc_CortexCombatEffective && {simulationEnabled _visitor}
            && {!isObjectHidden _visitor} && {local _visitor} && {!isPlayer _visitor}
            && {isNull (remoteControlled _visitor)}
            && {([_visitor] call WAIT_fnc_CortexExternalOwner) == ""}
            && {!([_visitor] call WAIT_fnc_CompatibilityExternalControl)} && {group _visitor == _group}
            && {isNull objectParent _visitor}) then {
            private _actual = getPosASL _visitor;
            {
                private _positionIndex=_x;
                private _positionASL=AGLToASL (_positions select _positionIndex);
                private _atPosition=_actual vectorDistance _positionASL <= 1.5
                    && {abs ((_actual select 2)-(_positionASL select 2)) <= 0.75}
                    && {[_visitor,_positionASL] call _roomSegmentClear};
                if (_atPosition) then {
                    private _enteredActors=_job getOrDefault ["enteredActors",[]];
                    _enteredActors pushBackUnique _visitor;
                    _job set ["enteredActors",_enteredActors];
                    private _actorVisits=_job getOrDefault ["actorVisits",createHashMap];
                    private _visited=_actorVisits getOrDefault [netId _visitor,[]];
                    _visited pushBackUnique _positionIndex;
                    _actorVisits set [netId _visitor,_visited];
                    _job set ["actorVisits",_actorVisits];
                };
                if !(_positionIndex in _cleared) then {
                    if (_atPosition) then {
                        _cleared pushBackUnique _positionIndex;
                        private _failedIndex = _unreachable find _positionIndex;
                        if (_failedIndex >= 0) then {_unreachable deleteAt _failedIndex};
                        private _pendingIndex = (_job get "pending") find _positionIndex;
                        if (_pendingIndex >= 0) then {(_job get "pending") deleteAt _pendingIndex};
                        _failedBy set [_positionIndex,[]];
                    };
                };
            } forEach _visitIndices;
        };
    } forEach _visitWorkers;
    private _pairRoutes=_job get "pairRoutes";
    {
        private _pairIndex=_forEachIndex;
        private _pair=_x select {[_x] call _actorAvailable && {!(_x in _unavailable)}};
        if (_pair isEqualTo []) then {
            private _state=_pairStates select _pairIndex;
            private _route=_pairRoutes select _pairIndex;
            private _cursor=_state select 0;
            if (_cursor < count _route) then {
                private _abandoned=_route select _cursor;
                if !(_abandoned in (_cleared+_unreachable)) then {(_job get "pending") pushBackUnique _abandoned};
                _state set [0,count _route];
            };
        };
        if (_pair isNotEqualTo []) then {
            private _state=_pairStates select _pairIndex;
            _state params ["_cursor","_approachingEntry","_lastPositions","_lastProgress","_retries","_lastTarget","_startAt","_moverIndex","_previousPositionIndex","_entryIndex","_triedEntries","_roomsCleared","_entered"];
            if (_now >= _startAt) then {
                private _route=_pairRoutes select _pairIndex;
                // Shared coverage may retire work only after this lane has physically entered.
                private _laneEntered=_entered || {_pair findIf {_x in (_job getOrDefault ["enteredActors",[]])} >= 0};
                while {_cursor < count _route && {(_route select _cursor) in _unreachable || {(_route select _cursor) in _cleared && {_laneEntered} && {!([_pair select (_moverIndex mod count _pair)] call _activeOwnMove)}}}} do {
                    private _completedRoom=_route select _cursor;
                    // Physical visits are collected before this loop. Apply the room handoff
                    // here before skipping it, otherwise the mover never rotates and its
                    // partner keeps exterior security even after the first interior visit.
                    // Shared completion can belong to another lane. Only this pair's
                    // physical arrival proves its entry and interior support handoff.
                    if (_completedRoom in _cleared && {_pair findIf {
                        _completedRoom in ((_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [netId _x,[]])
                    } >= 0}) then {
                        _entered=true;
                        _previousPositionIndex=_completedRoom;
                        _roomsCleared=_roomsCleared+1;
                        if (count _pair > 1) then {
                            private _nextMover=(_moverIndex+1) mod count _pair;
                            // Entry receipts come only from the floor-aware visit collector above.
                            private _enteredActors=_job getOrDefault ["enteredActors",[]];
                            // A security partner still outside cannot inherit an interior leg.
                            // Keep the successful entrant moving while its partner follows the
                            // preceding room through the native entrance. Alternate only after
                            // that partner physically reaches the lane's first interior node.
                            if ((_pair select _nextMover) in _enteredActors) then {
                                _moverIndex=_nextMover;
                            };
                        };
                        _lastTarget=-1;
                        _retries=0;
                        _lastProgress=_now;
                    };
                    _cursor=_cursor+1;
                };
                // Partner entry recovery is independent of the lead's current room.
                // A finished room queue must not strand an unentered partner with an ended order.
                if (count _pair > 1 && {_route isNotEqualTo []}
                    && {str _pairIndex in (_job getOrDefault ["pairEntryTargets",createHashMap])}) then {
                    private _partner=_pair select ((_moverIndex+1) mod count _pair);
                    if !(_partner in (_job getOrDefault ["enteredActors",[]])) then {
                        private _entryTarget=(_job getOrDefault ["pairEntryTargets",createHashMap]) getOrDefault [str _pairIndex,_positions select (_route select 0)];
                        if (_entryTarget isEqualTo (_positions select (_route select 0))) then {
                            _entryTarget=[_route select 0] call _roomMovementPoint;
                        };
                        private _entryRecovery=_job getOrDefault ["entryRecovery",createHashMap];
                        private _key=netId _partner;
                        private _distance=(getPosASL _partner) vectorDistance (AGLToASL _entryTarget);
                        private _receipt=_entryRecovery getOrDefault [_key,[_distance,_now,false]];
                        if ((_receipt select 0)-_distance >= 1) then {
                            _receipt set [0,_distance]; _receipt set [1,_now];
                        };
                        if (!(_receipt select 2) && {_now-(_receipt select 1) >= 12}
                            && {[_partner] call _actorAvailable} && {[_partner] call _actorTaskFree}
                            && {call _mayIssueMovement}) then {
                            // A nearby candidate can have clear geometry but still lack a native
                            // entrance path. Once its lead has physically visited the lane anchor,
                            // retry the partner through that proven anchor rather than repeating
                            // the same unvisited candidate. This consumes the existing one-shot
                            // entry recovery; it cannot retire a room or fabricate partner entry.
                            private _anchorIndex=_route select 0;
                            private _anchor=_positions select _anchorIndex;
                            if (_anchorIndex in _cleared && {_entryTarget isNotEqualTo _anchor}) then {
                                _entryTarget=+_anchor;
                                (_job get "pairEntryTargets") set [str _pairIndex,+_anchor];
                                diag_log format ["WAIT CLEAR PARTNER ACCESS: %1",[_job get "generation",_pairIndex,netId _partner,+_anchor]];
                            };
                            private _recovery=[_group,_operationGeneration,_partner,_entryTarget] call WAIT_fnc_RecoveryStep;
                            if (_recovery == "RECOVERING") then {[_partner,_entryTarget] call _rememberMove};
                            if (_recovery in ["RECOVERING","EXHAUSTED","INVALID"]) then {
                                _receipt set [2,true];
                            };
                        };
                        _entryRecovery set [_key,_receipt];
                        _job set ["entryRecovery",_entryRecovery];
                    };
                };
                // Persist retirement even when no pending room can be claimed this step.
                _state set [0,_cursor]; _state set [3,_lastProgress];
                _state set [4,_retries]; _state set [5,_lastTarget];
                _state set [7,_moverIndex]; _state set [8,_previousPositionIndex];
                _state set [11,_roomsCleared]; _state set [12,_entered];
                // Claim the nearest room that this pair has not already failed. Claims are removed
                // from the shared queue immediately, preventing several pairs from crowding one node.
                if (_cursor >= count _route) then {
                    private _pending=_job get "pending";
                    private _pairId=format ["PAIR_%1",_pairIndex];
                    private _candidates=_pending select {!(_pairId in (_failedBy select _x))};
                    if (_candidates isNotEqualTo []) then {
                        // The shared queue's floor ordering must survive each actor's nearest-room
                        // ranking. Otherwise a close upstairs window can win before ground entry.
                        private _lowestFloor=1e12;
                        {_lowestFloor=_lowestFloor min ((_positions select _x) select 2)} forEach _candidates;
                        _candidates=_candidates select {abs (((_positions select _x) select 2)-_lowestFloor) < 1.8};
                        private _point=_pair select (_moverIndex mod count _pair);
                        private _ranked=_candidates apply {
                            private _candidate=_positions select _x;
                            [(_point distance2D _candidate)+(abs (((getPosATL _point) select 2)-(_candidate select 2))*2.5),_x]
                        };
                        _ranked sort true;
                        // Start an unentered lane in the model's interior-position order.
                        // Nearest Euclidean nodes can be windows behind a wall; they do not
                        // describe the native doorway route. Rank by distance only after a
                        // physical interior visit has established this lane's entry.
                        private _claimed=if (_entered) then {(_ranked select 0) select 1} else {
                            private _modelOrder=+_candidates;
                            _modelOrder sort true;
                            _modelOrder select 0
                        };
                        _pending deleteAt (_pending find _claimed);
                        _route pushBack _claimed;
                        _cursor=(count _route)-1;
                        _lastTarget=-1;
                        _retries=0;
                        _triedEntries=[];
                        // Keep this lane's chosen entrance between room claims. Re-select only
                        // when it has no valid entry; an entered lane must not rally outside again.
                        if ((_entryIndex < 0 || {_entryIndex >= count (_job get "entries")})
                            && {(_job get "entries") isNotEqualTo []}) then {
                            private _entryRanks=[];
                            {
                                _entryRanks pushBack [_point distance2D _x,_forEachIndex];
                            } forEach (_job get "entries");
                            _entryRanks sort true;
                            _entryIndex=(_entryRanks select 0) select 1;
                        };
                        // Let native interior planning choose its entrance for the first
                        // committed room. buildingExit nodes are recovery choices, not
                        // compulsory staging stops that can strand actors outside a wall.
                        _approachingEntry=false;
                    };
                };
                if (_cursor < count _route) then {
                    private _positionIndex=_route select _cursor;
                    private _entryTarget=if (_entryIndex >= 0 && {_entryIndex < count (_job get "entries")}) then {
                        (_job get "entries") select _entryIndex
                    } else {[]};
                    private _entryMover=_pair select (_moverIndex mod count _pair);
                    // Pair handoff may change the mover while an exterior approach is pending.
                    // A physically entered successor must retain interior progression, not
                    // inherit its buddy's entrance staging leg.
                    if (_approachingEntry && {_entryMover in (_job getOrDefault ["enteredActors",[]])}) then {
                        _approachingEntry=false;
                        _lastTarget=-1;
                    };
                    // The security partner deliberately holds outside the doorway. Its
                    // proximity cannot complete the assigned mover's physical approach.
                    if (_approachingEntry && {_entryTarget isNotEqualTo []}
                        && {_entryMover distance2D _entryTarget <= 3}
                        && {abs (((getPosATL _entryMover) select 2)-(_entryTarget select 2)) <= 1.5}) then {
                        _approachingEntry=false;
                        // Reaching the entrance only completes approach staging. Interior entry
                        // is established by a physically visited room below, never doorway proximity.
                        _triedEntries pushBackUnique _entryIndex;
                        _lastTarget=-1;
                        _retries=0;
                    };
                    private _target=[_positions select _positionIndex,_entryTarget] select _approachingEntry;
                    private _point=_pair select (_moverIndex mod count _pair);
                    // Native building positions remain the room destinations. A geometry-supported
                    // offset can project onto another navigation floor; do not cache it as a route.
                    // Preserve a physically established interior route across mover changes.
                    // A ground-level partner should regain the pair's visited target-floor node
                    // before requesting its next room, rather than approaching an upstairs window.
                    // One checkpoint per claimed room; ordinary recovery still bounds the leg.
                    private _approaches=_job getOrDefault ["interiorApproaches",createHashMap];
                    private _approachKey=format ["%1:%2",_pairIndex,netId _point];
                    private _approach=_approaches getOrDefault [_approachKey,[]];
                    private _targetFloor=(AGLToASL _target) select 2;
                    private _pointFloor=(getPosASL _point) select 2;
                    if (!_approachingEntry && {_entered || {abs (_pointFloor-_targetFloor) > 1.5}}
                        && {(_approach param [0,-1]) != _positionIndex}) then {
                        // Retain actor-specific entry and vertical access history. An actor
                        // already inside on the destination floor need not revisit its buddy's
                        // occupied security node before requesting the next room.
                        private _chain=[];
                        private _ownVisits=(_job getOrDefault ["actorVisits",createHashMap]) getOrDefault [netId _point,[]];
                        if (_previousPositionIndex >= 0 && {_previousPositionIndex != _positionIndex}
                            && {!(_previousPositionIndex in _ownVisits)}
                            && {!(_point in (_job getOrDefault ["enteredActors",[]]))
                                || {abs (_pointFloor-_targetFloor) > 1.5}}) then {
                            _chain pushBack (+(_positions select _previousPositionIndex));
                        };
                        private _checkpoint=if (_previousPositionIndex >= 0 && {_previousPositionIndex != _positionIndex}) then {
                            _positions select _previousPositionIndex
                        } else {[]};
                        // Pair history may contain only ground-floor nodes although another
                        // lane has physically reached the destination floor. Share that access
                        // evidence instead of repeatedly approaching an upstairs window outside.
                        // Search once per changed coverage snapshot, at most 24 proven nodes.
                        private _probeKey=format ["%1:%2",_approachKey,_positionIndex];
                        private _probes=_job getOrDefault ["interiorAccessProbes",createHashMap];
                        if ((_checkpoint isEqualTo [] || {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) > 1.5})
                            && {abs (_pointFloor-_targetFloor) > 1.5}
                            && {(_probes getOrDefault [_probeKey,-1]) != count _cleared}) then {
                            _probes set [_probeKey,count _cleared];
                            _job set ["interiorAccessProbes",_probes];
                            private _accessNodes=_cleared select [0,24];
                            private _nearest=1e12;
                            {
                                private _node=_positions select _x;
                                private _distance=_node vectorDistance _target;
                                if (_x != _positionIndex && {abs (((AGLToASL _node) select 2)-_targetFloor) <= 1.5}
                                    && {_distance < _nearest}) then {
                                    _checkpoint=+_node;
                                    _nearest=_distance;
                                };
                            } forEach _accessNodes;
                        };
                        // Exposed balconies/access positions are not rooms, but removing them
                        // from the coverage set must not erase possible native floor access.
                        // Use a supported transit candidate only when no visited same-floor access
                        // is available. Probe each floor bucket once.
                        if (abs (_pointFloor-_targetFloor) > 1.5
                            && {_checkpoint isEqualTo [] || {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) > 1.5}}) then {
                            private _floorKey=str round (_targetFloor*2);
                            private _accessCache=_job getOrDefault ["transitAccessCache",createHashMap];
                            if (!(_floorKey in _accessCache) && {count _accessCache < 8}) then {
                                private _access=[];
                                private _transit=(_job getOrDefault ["transitPositions",[]]) select [0,32];
                                {
                                    if (_access isNotEqualTo []) exitWith {};
                                    if (abs (((AGLToASL _x) select 2)-_targetFloor) <= 0.75) then {
                                        private _origin=AGLToASL _x;
                                        private _surfaces=lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,-1],_point,objNull,true,4,"GEOM","NONE"];
                                        private _supported=_surfaces findIf {
                                            ((_x select 1) select 2) >= 0.7
                                                && {(_x select 2) == _building || {(_x select 3) == _building}}
                                                && {abs (((_x select 0) select 2)-(_origin select 2)) <= 0.75}
                                        } >= 0;
                                        if (_supported) then {_access=+_x};
                                    };
                                } forEach _transit;
                                _accessCache set [_floorKey,_access];
                                _job set ["transitAccessCache",_accessCache];
                            };
                            private _access=_accessCache getOrDefault [_floorKey,[]];
                            if (_access isNotEqualTo []) then {_checkpoint=+_access};
                        };
                        if (abs (_pointFloor-_targetFloor) > 1.5
                            && {count _checkpoint == 3}
                            && {abs (((AGLToASL _checkpoint) select 2)-_targetFloor) <= 1.5}) then {
                            _chain pushBackUnique (+_checkpoint);
                        };
                        // At most two legs: the preceding covered node, then destination-floor
                        // access. Neither leg marks the assigned room visited.
                        if (_chain isNotEqualTo []) then {
                            private _first=_chain deleteAt 0;
                            _approach=[_positionIndex,+_first,false,_chain];
                            _approaches set [_approachKey,_approach];
                            _job set ["interiorApproaches",_approaches];
                            _lastTarget=-1;
                            diag_log format ["WAIT CLEAR INTERIOR ACCESS: %1",[_job get "generation",_pairIndex,netId _point,_positionIndex,+_first,+_target,+_chain]];
                        };
                    };
                    // A supported raw access point is a candidate, not a proven native route.
                    // Retire one stalled optional raw checkpoint for this actor/room claim,
                    // then let the original room request use the same movement writer.
                    // Covered buddy handoffs remain mandatory; no visit or progress lease
                    // is granted for retirement, and the existing retry count is preserved.
                    private _checkpointCommand=currentCommand _point;
                    private _checkpointDelay=[12,4] select (_checkpointCommand == "" || {_checkpointCommand == "STOP"});
                    private _checkpointCandidate=_approach param [1,[],[[]]];
                    private _checkpointReached=count _checkpointCandidate == 3
                        && {(getPosASL _point) vectorDistance (AGLToASL _checkpointCandidate) <= 1.5}
                        && {abs (((getPosASL _point) select 2)-((AGLToASL _checkpointCandidate) select 2)) <= 0.75}
                        && {!([_point] call _activeOwnMove)};
                    private _fallbackHold=(_job getOrDefault ["formationFallbackHolds",createHashMap]) getOrDefault [netId _point,[]];
                    private _issuedCheckpoint=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _point,[]];
                    private _ownedCheckpointStop=_checkpointCommand == "STOP" && {count _fallbackHold == 3}
                        && {_issuedCheckpoint isEqualTo _checkpointCandidate}
                        && {(getPosASL _point) vectorDistance (AGLToASL _fallbackHold) <= 1.5};
                    if (!_approachingEntry && {count _approach >= 3}
                        && {(_approach select 0) == _positionIndex} && {!(_approach select 2)}
                        && {(_approach select 1) in (_job getOrDefault ["transitPositions",[]])}
                        && {!_checkpointReached} && {_now-_lastProgress > _checkpointDelay}
                        && {[_point] call _actorAvailable} && {[_point] call _actorTaskFree}
                        && {_checkpointCommand == "" || {_checkpointCommand == "MOVE" && {[_point] call _ownsCurrentMove}} || {_ownedCheckpointStop}}
                        && {!([_group,false,_point] call WAIT_fnc_CortexExternalTakeover)}
                        && {call _mayIssueMovement}) then {
                        private _retired=+(_approach select 1);
                        // This tombstone prevents immediate recreation for the same claim.
                        // Its arrival flag stays false: an abandoned point was not visited.
                        _approach=[_positionIndex,[],false,[],"ABANDONED_TRANSIT"];
                        _approaches set [_approachKey,_approach];
                        _job set ["interiorApproaches",_approaches];
                        _lastTarget=-1;
                        diag_log format ["WAIT CLEAR TRANSIT RETIRED: %1",[_job get "generation",_pairIndex,netId _point,_positionIndex,_retired,+_target]];
                    };
                    if (!_approachingEntry && {count _approach >= 3}
                        && {(_approach select 0) == _positionIndex} && {!(_approach select 2)}
                        && {count (_approach select 1) == 3}) then {
                        private _checkpoint=_approach select 1;
                        if ((getPosASL _point) vectorDistance (AGLToASL _checkpoint) <= 1.5
                            && {abs (((getPosASL _point) select 2)-((AGLToASL _checkpoint) select 2)) <= 0.75}
                            && {!([_point] call _activeOwnMove)}) then {
                            private _remaining=_approach param [3,[]];
                            if (_remaining isEqualTo []) then {
                                _approach set [2,true];
                            } else {
                                private _next=_remaining deleteAt 0;
                                _approach set [1,+_next];
                                _approach set [3,_remaining];
                                _target=+_next;
                            };
                            _lastTarget=-1;
                            _retries=0;
                            _lastProgress=_now;
                        } else {
                            _target=+_checkpoint;
                        };
                    };
                    private _issue=_lastTarget != _positionIndex;
                    private _bestDistance=_state param [13,1e12,[0]];
                    private _bestTarget=_state param [14,[],[[]]];
                    if (_bestTarget isNotEqualTo _target) then {
                        _bestTarget=+_target;
                        _bestDistance=(getPosATL _point) vectorDistance _target;
                    };
                    private _supportTarget=[];
                    private _partner=_pair select ((_moverIndex+1) mod count _pair);
                    private _partnerEntered=_partner in (_job getOrDefault ["enteredActors",[]]);
                    if (count _pair > 1 && {!_partnerEntered} && {!_approachingEntry}) then {
                        // Commit both actors at initial entry. Select a nearby same-floor node
                        // connected by clear interior geometry, rather than holding outside until a visit.
                        private _entryTargets=_job getOrDefault ["pairEntryTargets",createHashMap];
                        private _entryKey=str _pairIndex;
                        _supportTarget=_entryTargets getOrDefault [_entryKey,[]];
                        if (_supportTarget isEqualTo []) then {
                            private _anchor=_positions select (_route select 0);
                            private _candidates=_positions select {
                                _x isNotEqualTo _anchor && {abs ((_x select 2)-(_anchor select 2)) <= 1.5}
                                    && {_x distance2D _anchor <= 8}
                            };
                            private _ranked=_candidates apply {[_x distance2D _anchor,_x]};
                            _ranked sort true;
                            _ranked resize ((count _ranked) min 24);
                            private _origin=(AGLToASL _anchor) vectorAdd [0,0,0.8];
                            private _connected=_ranked findIf {
                                (lineIntersectsSurfaces [_origin,(AGLToASL (_x select 1)) vectorAdd [0,0,0.8],objNull,objNull,true,1,"GEOM","NONE"]) isEqualTo []
                            };
                            _supportTarget=if (_connected >= 0) then {+((_ranked select _connected) select 1)} else {+_anchor};
                            _entryTargets set [_entryKey,+_supportTarget];
                            _job set ["pairEntryTargets",_entryTargets];
                        };
                    };
                    if (_supportTarget isEqualTo (_positions select (_route select 0))) then {
                        _supportTarget=[_route select 0] call _roomMovementPoint;
                    };
                    if (count _pair > 1 && {_supportTarget isEqualTo []}) then {
                        _supportTarget=if (_approachingEntry) then {
                            private _outward=(getPosATL (_job get "building")) getDir _entryTarget;
                            _entryTarget getPos [3,_outward]
                        } else {
                            if (_previousPositionIndex >= 0) then {[_previousPositionIndex] call _roomMovementPoint} else {
                                if (_entryTarget isEqualTo [] || {_entered}) then {_target} else {
                                    // Keep first-room security clear of the threshold. Standing on
                                    // the entrance can physically block the partner's only path inside.
                                    private _outward=(getPosATL (_job get "building")) getDir _entryTarget;
                                    _entryTarget getPos [3,_outward+60]
                                }
                            }
                        };
                        if (_supportTarget isEqualTo []) then {
                            private _outward=(getPosATL (_job get "building")) getDir _target;
                            _supportTarget=_target getPos [2.5,_outward];
                        };
                    };
                    {
                        private _unit=_x;
                        // Alternate entrance recovery belongs to exterior actors only. A
                        // physically entered buddy retains its current interior order and hold.
                        private _entryWorkerAllowed=!_approachingEntry || {_unit == _point}
                            || {!(_unit in (_job getOrDefault ["enteredActors",[]]))};
                        if (_entryWorkerAllowed) then {
                        // Opening a door does not replace an already committed native path.
                        [_unit,_job get "building",["CLEAR",_job get "generation"]] call WAIT_fnc_CortexBuildingDoor;
                        if (_issue && {call _mayIssueMovement} && {[_unit] call _actorTaskFree}) then {
                            private _started=_job get "started";
                            if !(_unit in _started) then {
                                doStop _unit;
                                // Preserve the original baseline across owner-local worker rebuilds.
                                // A later different setting becomes the new baseline, not old WAIT state.
                                private _priorStance=_unit getVariable ["WAIT_Cortex_ClearStance",unitPos _unit];
                                if (toUpperANSI (unitPos _unit) != "UP") then {_priorStance=unitPos _unit};
                                private _priorSpeed=_unit getVariable ["WAIT_Cortex_ClearForcedSpeed",getForcedSpeed _unit];
                                if (abs ((getForcedSpeed _unit)-(_unit getVariable ["WAIT_Cortex_ClearAppliedSpeed",getForcedSpeed _unit])) > 0.1) then {
                                    _priorSpeed=getForcedSpeed _unit;
                                };
                                _unit setVariable ["WAIT_Cortex_ClearStance",_priorStance,true];
                                _unit setVariable ["WAIT_Cortex_ClearForcedSpeed",_priorSpeed,true];
                                _unit setUnitPos "UP";
                                private _clearSpeed=4;
                                _unit setVariable ["WAIT_Cortex_ClearAppliedSpeed",_clearSpeed,true];
                                _unit forceSpeed _clearSpeed;
                                _started pushBack _unit;
                            };
                            private _unitTarget=if (_unit == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                            private _committedTarget=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _unit,[]];
                            private _sameActiveTarget=count _committedTarget == 3
                                && {_committedTarget vectorDistance _unitTarget <= 0.25}
                                && {[_unit] call _activeOwnMove};
                            if (!_sameActiveTarget && {call _mayIssueMovement} && {[_unit] call _actorTaskFree}) then {
                                // An unchanged active path or support hold already satisfies this handoff.
                                if (((_job getOrDefault ["roomHolds",createHashMap]) getOrDefault [netId _unit,[]]) isNotEqualTo _unitTarget
                                    || {currentCommand _unit != "STOP"}
                                    || {(getPosASL _unit) vectorDistance (AGLToASL _unitTarget) > 1.5}) then {
                                    _unit doMove _unitTarget;
                                    [_unit,_unitTarget] call _rememberMove;
                                };
                            };
                        };
                        // Slow the final indoor approach without replacing its destination.
                        // Update only our unchanged cap; an externally edited speed remains owned
                        // by that controller. Distance checks reuse the existing bounded pair step.
                        if (_unit in (_job get "started") && {call _mayIssueMovement}
                            && {[_unit] call _actorAvailable} && {[_unit] call _actorTaskFree}) then {
                            private _speedTarget=if (_unit == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                            private _applied=_unit getVariable ["WAIT_Cortex_ClearAppliedSpeed",-1];
                            private _desiredSpeed=[4,2] select (_unit distance2D _speedTarget < 5);
                            if (abs ((getForcedSpeed _unit)-_applied) <= 0.1
                                && {abs (_desiredSpeed-_applied) > 0.1}) then {
                                _unit forceSpeed _desiredSpeed;
                                _unit setVariable ["WAIT_Cortex_ClearAppliedSpeed",_desiredSpeed,true];
                            };
                            // A failed native path can silently return a worker to formation:
                            // command becomes empty and the planner reports its
                            // formation destination (planned or direct formation mode). Arrest that fallback once per owned request;
                            // the existing finite room retry is still the only recovery writer.
                            // Do not touch explicit FOLLOW, a newer MOVE or specialist commands.
                            private _nativeDestination=expectedDestination _unit;
                            private _fallbackHolds=_job getOrDefault ["formationFallbackHolds",createHashMap];
                            private _issued=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _unit,[]];
                            if (!_issue && {currentCommand _unit == ""}
                                && {(_nativeDestination param [1,"",[""]]) in ["DoNotPlanFormation","FORMATION PLANNED"]}
                                && {count _issued == 3} && {!(netId _unit in _fallbackHolds)}) then {
                                private _hold=getPosATL _unit;
                                doStop _unit;
                                _fallbackHolds set [netId _unit,+_hold];
                                _job set ["formationFallbackHolds",_fallbackHolds];
                            };
                            // Native formation must not reclaim a physically arrived room or
                            // support actor between pair handoffs. Hold once per target; a new
                            // room request replaces it through the existing movement writer.
                            private _roomHolds=_job getOrDefault ["roomHolds",createHashMap];
                            private _holdKey=netId _unit;
                            if ((_roomHolds getOrDefault [_holdKey,[]]) isNotEqualTo _speedTarget
                                && {(getPosASL _unit) vectorDistance (AGLToASL _speedTarget) <= 1.5}
                                && {abs (((getPosASL _unit) select 2)-((AGLToASL _speedTarget) select 2)) <= 0.75}
                                && {[_unit,AGLToASL _speedTarget] call _roomSegmentClear}
                                && {currentCommand _unit != "MOVE" || {[_unit] call _ownsCurrentMove}}
                                && {!([_unit] call _activeOwnMove)}) then {
                                doStop _unit;
                                _roomHolds set [_holdKey,+_speedTarget];
                                _job set ["roomHolds",_roomHolds];
                            };
                        };
                        _assigned set [(_job get "team") find _unit,[_positionIndex,_lastProgress,getPosATL _unit,_retries,_approachingEntry]];
                        };
                    } forEach _pair;
                    if (_issue) then {_lastTarget=_positionIndex; _lastProgress=_now; _lastPositions=_pair apply {getPosATL _x}};
                    // Once inside, only the assigned room mover proves progress toward this room.
                    // The security partner is expected to adjust cover and follow the previous room;
                    // counting that movement hid doorway stalls and prevented recovery indefinitely.
                    private _moverSlot=_moverIndex mod count _pair;
                    private _moverPrevious=_lastPositions param [_moverSlot,getPosATL _point];
                    private _moved=(getPosATL _point) vectorDistance _moverPrevious >= 1;
                    if (_approachingEntry && {!_moved}) then {
                        _moved=_pair findIf {
                            private _old=_lastPositions param [_forEachIndex,getPosATL _x];
                            (getPosATL _x) vectorDistance _old >= 1
                        } >= 0;
                    };
                    if (_moved) then {
                        _lastPositions=_pair apply {getPosATL _x};
                        // Walking can be legitimate navigation without approaching this node.
                        // Only new best approach progress renews retry and operation budgets;
                        // circles must eventually reach the bounded retry/recovery path.
                        private _targetDistance=(getPosATL _point) vectorDistance _target;
                        if (_bestDistance-_targetDistance >= 1) then {
                            _bestDistance=_targetDistance;
                            _lastProgress=_now;
                            _job set ["lastProgressAt",serverTime];
                            _job set ["deadline",(_job get "deadline") max (serverTime+120)];
                        };
                    };
                    if (_positionIndex in _cleared && {_laneEntered} && {!([_point] call _activeOwnMove)}) then {
                        _entered=true;
                        _previousPositionIndex=_positionIndex;
                        _cursor=_cursor+1;
                        _roomsCleared=_roomsCleared+1;
                        // Reserves replace casualties only. Routine rotation previously pulled a
                        // successful worker out mid-clear and introduced a new actor at the doorway,
                        // creating pauses and exterior congestion without improving room coverage.
                        if (count _pair > 1) then {_moverIndex=(_moverIndex+1) mod count _pair};
                        _lastTarget=-1;
                        _retries=0;
                        _lastProgress=_now;
                    } else {
                        // Only the assigned mover ending its order shortens the retry interval. A security partner may
                        // deliberately hold cover, so treating any pair member as stopped churns a working clear.
                        private _commandEnded=currentCommand _point in ["","STOP"];
                        private _retryDelay=[12,4] select _commandEnded;
                        if (_now-_lastProgress > _retryDelay && {[_point] call _actorTaskFree}) then {
                            if (_retries < 3 && {call _mayIssueMovement}) then {
                                {
                                    private _unitTarget=if (_x == _point || {_supportTarget isEqualTo []}) then {_target} else {_supportTarget};
                                    // Interior recovery belongs to the room mover. Keep the security
                                    // partner at its committed position instead of restarting its path.
                                    if ((_x == _point || {_approachingEntry && {!(_x in (_job getOrDefault ["enteredActors",[]]))}}) && {[_x] call _actorAvailable}
                                        && {call _mayIssueMovement} && {[_x] call _actorTaskFree}) then {
                                        _x doMove _unitTarget;
                                        [_x,_unitTarget] call _rememberMove;
                                    };
                                } forEach _pair;
                                _retries=_retries+1;
                                _lastProgress=_now;
                                _retryCounts set [_positionIndex,(_retryCounts param [_positionIndex,0])+1];
                            } else {
                                private _changedEntry=false;
                                if (!(_point in (_job getOrDefault ["enteredActors",[]])) && {(_job get "entries") isNotEqualTo []}) then {
                                    if (_approachingEntry) then {_triedEntries pushBackUnique _entryIndex};
                                    private _entryRanks=[];
                                    {
                                        if !(_forEachIndex in _triedEntries) then {
                                            _entryRanks pushBack [_point distance2D _x,_forEachIndex];
                                        };
                                    } forEach (_job get "entries");
                                    if (_entryRanks isNotEqualTo []) then {
                                        _entryRanks sort true;
                                        _entryIndex=(_entryRanks select 0) select 1;
                                        _approachingEntry=true;
                                        _lastTarget=-1;
                                        _lastProgress=_now;
                                        _lastPositions=_pair apply {getPosATL _x};
                                        _retries=0;
                                        _changedEntry=true;
                                    };
                                };
                                if (!_changedEntry) then {
                                    // A stalled worker gets one recovery attempt through the common operation
                                    // lifecycle before this pair gives up its room. Recovery is actor-scoped and
                                    // bounded; the other workers keep sweeping rather than waiting for it.
                                    // Durable room retries survive reserve replacement and owner replay.
                                    // A new actor must not reopen an exhausted room recovery budget.
                                    private _roomRetryBudget=3*_failureThreshold;
                                    private _recovery = if (_operationGeneration >= 0
                                        && {(_retryCounts param [_positionIndex,0]) <= _roomRetryBudget}) then {
                                        [_group,_operationGeneration,_point,_target] call WAIT_fnc_RecoveryStep
                                    } else {"EXHAUSTED"};
                                    if (_recovery in ["RECOVERING","YIELDED"]) then {
                                        if (_recovery == "RECOVERING") then {[_point,_target] call _rememberMove};
                                        _lastProgress=_now;
                                        _lastPositions=_pair apply {getPosATL _x};
                                        // A native task owns movement while yielding. Do not restart
                                        // its route or mark the room unreachable during that task.
                                        _retries=[0,3] select (_recovery == "YIELDED");
                                    } else {
                                        private _pairId=format ["PAIR_%1",_pairIndex];
                                        private _failures=_failedBy select _positionIndex;
                                        _failures pushBackUnique _pairId;
                                        _failedBy set [_positionIndex,_failures];
                                        // A failed entry lane cannot undo another worker's physical room visit.
                                        if (count _failures >= _failureThreshold && {!(_positionIndex in _cleared)}) then {
                                            _unreachable pushBackUnique _positionIndex;
                                        } else {
                                            // Return the room to the shared queue. Another pair must claim it;
                                            // this pair's failure identity prevents an immediate self-retry loop.
                                            if !(_positionIndex in _cleared) then {(_job get "pending") pushBackUnique _positionIndex};
                                        };
                                        _cursor=_cursor+1;
                                        _lastTarget=-1;
                                        _retries=0;
                                        _triedEntries=[];
                                    };
                                };
                            };
                            _retryChanged=true;
                        };
                    };
                    _state set [0,_cursor]; _state set [1,_approachingEntry]; _state set [2,_lastPositions];
                    _state set [3,_lastProgress]; _state set [4,_retries]; _state set [5,_lastTarget];
                    _state set [7,_moverIndex]; _state set [8,_previousPositionIndex];
                    _state set [9,_entryIndex]; _state set [10,_triedEntries];
                    _state set [11,_roomsCleared];
                    _state set [12,_entered];
                    _state set [13,_bestDistance]; _state set [14,_bestTarget];
                };
            };
        };
    } forEach _pairs;
    private _madeProgress=count _cleared != _before || {count _unreachable != _unreachableBefore};
    if (_pairStates findIf {_x param [12,false]} >= 0 && {(_job getOrDefault ["phase","ENTRY"]) == "ENTRY"}) then {_job set ["phase","SWEEP"]};
    if (_madeProgress) then {_job set ["phase","SWEEP"]} else {if (_retryChanged) then {_job set ["phase","REPLAN"]}};
    if (count _cleared != _before) then {
        // Physical room visits renew the safety lease. An unreachable classification advances
        // the finite queue but is not successful physical progress and cannot extend its budget.
        _job set ["lastProgressAt",serverTime];
        _job set ["deadline",(_job get "deadline") max (serverTime+120)];
    };
    if (_madeProgress || {_retryChanged}) then {
        _group setVariable ["WAIT_AIPass_ClearOrder", [_job get "building", +_cleared, _job get "deadline", _job get "baseBehaviour", +_unreachable, +_retryCounts, +_failedBy, _job get "lastProgressAt",_job getOrDefault ["baseAttack",true],_job getOrDefault ["nativeOrderReceipt",[]],_job getOrDefault ["hardDeadline",_job get "deadline"]], true];
        _group setVariable ["WAIT_Cortex_ClearStatus",[_job getOrDefault ["phase","SWEEP"],count _cleared,count _unreachable,count (_job get "positions"),count (_job get "pairs"),_job get "lastProgressAt"],true];
    };
    private _allWorkersEntered=_activeWorkers findIf {!(_x in (_job getOrDefault ["enteredActors",[]]))} < 0;
    private _actorVisits=_job getOrDefault ["actorVisits",createHashMap];
    private _requiredVisits=2 min count _positions;
    private _allWorkersProgressed=_activeWorkers findIf {
        count (_actorVisits getOrDefault [netId _x,[]]) < _requiredVisits
    } < 0;
    // Shared room coverage must not release a partner still parked at its first node.
    // Finish each active actor's finite interior follow-through before successful egress.
    if (count _cleared == count _positions && {!_allWorkersProgressed}
        && {serverTime <= (_job get "deadline")}
        && {serverTime <= (_job getOrDefault ["hardDeadline",_job get "deadline"])}
        && {call _mayIssueMovement}) then {
        private _follow=_job getOrDefault ["followThrough",createHashMap];
        private _followFailures=_job getOrDefault ["followThroughFailures",createHashMap];
        private _followExhausted=_job getOrDefault ["followThroughExhausted",[]];
        private _followBudgetChanged=false;
        {
            private _unit=_x;
            private _key=netId _unit;
            private _visited=_actorVisits getOrDefault [_key,[]];
            private _arrived=_follow getOrDefault [_key,[]];
            if (_arrived isNotEqualTo [] && {(_arrived select 0) in _visited}
                && {!(_arrived param [4,false,[true]])} && {[_unit] call _actorAvailable}
                && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}
                && {currentCommand _unit != "MOVE" || {[_unit] call _ownsCurrentMove}}
                && {!([_unit] call _activeOwnMove)}) then {
                doStop _unit;
                _arrived set [4,true];
            };
            // Keep an unentered actor's useful entry path intact. Once its one-shot entry
            // recovery has made no progress for 24 seconds, shared physical coverage offers
            // alternative native anchors. These use the same durable three-target budget;
            // choosing another destination never invents entry or renews common recovery.
            private _entryReceipt=(_job getOrDefault ["entryRecovery",createHashMap]) getOrDefault [_key,[]];
            private _entryExhausted=count _entryReceipt >= 3 && {_entryReceipt select 2}
                && {_now-(_entryReceipt select 1) >= 24};
            if (count _visited < _requiredVisits && {!(_unit in _followExhausted)}
                && {_unit in (_job getOrDefault ["enteredActors",[]]) || {_entryExhausted}}
                && {[_unit] call _actorAvailable}
                && {[_unit] call _actorTaskFree} && {call _mayIssueMovement}) then {
                private _record=_follow getOrDefault [_key,[]];
                if (_record isEqualTo [] || {(_record select 0) in _visited}) then {
                    // Select once per actual visit; native planning still owns the path.
                    // Prefer the current floor without inventing a building-specific route.
                    private _failedTargets=_followFailures getOrDefault [_key,[]];
                    private _candidates=if (count _failedTargets >= 3) then {[]} else {
                        (_cleared select {!(_x in _visited) && {!(_x in _failedTargets)}}) select [0,24]
                    };
                    private _ranked=_candidates apply {
                        private _position=_positions select _x;
                        [(_unit distance2D _position)+10*abs (((getPosATL _unit) select 2)-(_position select 2)),_x]
                    };
                    _ranked sort true;
                    if (_ranked isNotEqualTo []) then {
                        private _index=(_ranked select 0) select 1;
                        private _target=[_index] call _roomMovementPoint;
                        private _accessPoint=[];
                        if (!(_unit in (_job getOrDefault ["enteredActors",[]])) && {_failedTargets isNotEqualTo []}) then {
                            // Changing room alone may keep native planning on the same blocked door.
                            // Stage a later attempt at another existing entrance before its room leg.
                            // This is transit only, never an entry or room-clearance receipt.
                            private _entryRanks=(_job get "entries") apply {[_unit distance2D _x,_x]};
                            _entryRanks sort true;
                            if (count _entryRanks > 1) then {
                                _accessPoint=+((_entryRanks select ((count _failedTargets) mod count _entryRanks)) select 1);
                                _target=+_accessPoint;
                            };
                        };
                        _record=[_index,(getPosASL _unit) vectorDistance (AGLToASL _target),_now,false,false,_accessPoint];
                        _follow set [_key,_record];
                        _unit doMove _target;
                        [_unit,_target] call _rememberMove;
                    } else {
                        _followExhausted pushBackUnique _unit;
                        _followFailures set [_key,+_failedTargets];
                        _followBudgetChanged=true;
                        _job set ["entryFailed",true];
                    };
                } else {
                    private _target=[_record select 0] call _roomMovementPoint;
                    private _accessPoint=_record param [5,[],[[]]];
                    if (_accessPoint isNotEqualTo []) then {
                        if (_unit distance2D _accessPoint <= 3
                            && {abs (((getPosATL _unit) select 2)-(_accessPoint select 2)) <= 1.5}) then {
                            // Arrival at an entrance only releases the real interior movement leg.
                            _record set [5,[]];
                            _record set [1,(getPosASL _unit) vectorDistance (AGLToASL _target)];
                            _record set [2,_now];
                            _unit doMove _target;
                            [_unit,_target] call _rememberMove;
                        } else {_target=+_accessPoint};
                    };
                    private _remaining=(getPosASL _unit) vectorDistance (AGLToASL _target);
                    if ((_record select 1)-_remaining >= 1) then {
                        _record set [1,_remaining]; _record set [2,_now];
                    };
                    if (!(_record select 3) && {_now-(_record select 2) >= 12}) then {
                        private _recovery=[_group,_operationGeneration,_unit,_target] call WAIT_fnc_RecoveryStep;
                        if (_recovery == "RECOVERING") then {[_unit,_target] call _rememberMove};
                        if (_recovery in ["RECOVERING","EXHAUSTED","INVALID"]) then {_record set [3,true]};
                    };
                    // Retire this actor's failed destination, not the actor or a real visit.
                    // Changing room does not renew the common generation recovery budget.
                    if ((_record select 3) && {_now-(_record select 2) >= 24}) then {
                        private _failedTargets=_followFailures getOrDefault [_key,[]];
                        _failedTargets pushBackUnique (_record select 0);
                        _followFailures set [_key,_failedTargets];
                        _followBudgetChanged=true;
                        _follow set [_key,[]];
                    };
                };
            };
        } forEach _activeWorkers;
        _job set ["followThrough",_follow];
        _job set ["followThroughFailures",_followFailures];
        _job set ["followThroughExhausted",_followExhausted];
        if (_followBudgetChanged && {call _mayIssueMovement}) then {
            private _exhaustedIds=_followExhausted apply {netId _x};
            private _rows=(keys _followFailures select [0,64]) apply {
                [_x,+(_followFailures get _x),_x in _exhaustedIds]
            };
            _group setVariable ["WAIT_Cortex_ClearFollowBudget",[
                _building,_job get "hardDeadline",_job get "buildingTransform",_rows],true];
        };
    };
    // Complete physical coverage and participation retire obsolete owned room legs.
    // Egress is the next generation-owned request; native planner BUSY is not extra clearance evidence.
    if (((count _cleared + count _unreachable) >= count _positions && {_allWorkersProgressed || {_unreachable isNotEqualTo []}}) || {serverTime > (_job get "deadline")} || {serverTime > (_job getOrDefault ["hardDeadline",_job get "deadline"])} || {_activeWorkers isEqualTo []}) exitWith {
        // Room coverage does not prove that every active clearing actor entered.
        // A deadline may release the operation, but cannot convert missing participation to success.
        _job set ["entryFailed",(_job getOrDefault ["entryFailed",false]) || {!_allWorkersEntered} || {!_allWorkersProgressed}];
        private _active=[];
        {_active append _x} forEach (_job get "pairs");
        _active=_active arrayIntersect _active;
        _active=_active select {[_x] call _actorAvailable && {!(_x in _unavailable)}};
        private _entries=_job get "entries";
        private _buildingPos=getPosATL (_job get "building");
        private _claimedExitPoints=[];
        private _egressAssignments=_active apply {
            private _unit=_x;
            private _entry=_job get "entry";
            if (_entries isNotEqualTo []) then {
                private _ranked=_entries apply {[_unit distance2D _x,_x]};
                _ranked sort true;
                _entry=+((_ranked select 0) select 1);
            };
            if (_entry isEqualTo []) then {_entry=_buildingPos};
            private _outward=_buildingPos getDir _entry;
            // Each worker receives its own nearby exterior slot. An exit lane is shared,
            // but its consolidation destination is not; broad arrival radii caused piles.
            private _exitPoint=[];
            for "_slot" from 0 to 11 do {
                if (_exitPoint isNotEqualTo []) exitWith {};
                private _row=floor (_slot/3);
                private _side=(_slot mod 3)-1;
                private _candidate=(_entry getPos [10+3*_row,_outward]) getPos [3*_side,_outward+90];
                // Claimed/wet/steep slots cannot be selected; reject them before geometry.
                if (_claimedExitPoints findIf {_x distance2D _candidate < 3} < 0
                    && {!surfaceIsWater _candidate} && {(surfaceNormal _candidate) select 2 >= 0.85}) then {
                    private _ground=getTerrainHeightASL _candidate;
                    private _foot=[_candidate select 0,_candidate select 1,_ground];
                    private _blocked=lineIntersectsSurfaces [_foot vectorAdd [0,0,0.2],_foot vectorAdd [0,0,1.8],_unit,objNull,true,1,"GEOM","NONE"];
                    if (_blocked isEqualTo []) then {_exitPoint=ASLToAGL _foot};
                };
            };
            if (_exitPoint isEqualTo []) then {
                // No usable distinct slot is a failed consolidation, never a shared success.
                _job set ["egressFailed",true];
                _exitPoint=getPosATL _unit;
            } else {_claimedExitPoints pushBack +_exitPoint};
            [_unit,_exitPoint,false]
        };
        _job set ["phase","EGRESS"];
        _job set ["egressAssignments",_egressAssignments];
        _job set ["egressDeadline",time+45];
        _job set ["egressProgress",_egressAssignments apply {
            [_x select 0,(getPosATL (_x select 0)) vectorDistance (_x select 1),time,0]
        }];
        _group setVariable ["WAIT_Cortex_ClearEgressRetries",[],true];
        if (call _mayIssueMovement) then {
            {
                _x params ["_unit","_target"];
                if (call _mayIssueMovement && {[_unit] call _actorTaskFree}) then {
                    _unit doMove _target;
                    [_unit,_target] call _rememberMove;
                };
            } forEach _egressAssignments;
        };
        _group setVariable ["WAIT_Cortex_ClearEgress",["EGRESS",_egressAssignments apply {_x select 1},serverTime,_egressAssignments],true];
        _group setVariable ["WAIT_Cortex_ClearStatus",["EGRESS",count (_job get "cleared"),count (_job get "unreachable"),count (_job get "positions"),count (_job get "pairs"),serverTime],true];
        1.5
    };
    1.5
};
if (isNil "_delay" || {!(_delay isEqualType 0)}) then {_delay=-1};
private _phase=toUpperANSI (_job getOrDefault ["phase","ENTRY"]);
private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
if (count _currentOperation > 0 && {local _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_currentOperation getOrDefault ["generation",-1]) == (_job getOrDefault ["operationGeneration",-2])}
    && {(_currentOperation getOrDefault ["intent",""]) == "CLEAR"}
    && {(_currentOperation getOrDefault ["phase",""]) != _phase}) then {
    _currentOperation set ["phase",_phase];
    _group setVariable ["WAIT_Operation",_currentOperation,true];
};
_brain set ["phase",_phase];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["pending",false];
_brain set ["completed",true];
if (_delay < 0) then {
    _brain set ["finished",true];
    _brain set ["cancelReason",_job getOrDefault ["finishReason","FINISHED"]];
} else {
    _brain set ["nextAt",time+_delay];
};
if (!isNull _group && {local _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}
    && {(_job getOrDefault ["generation",-1]) == (_group getVariable ["WAIT_AIPass_ClearGeneration",0])}) then {
    _group setVariable ["WAIT_BuildingBrain_State",[
        _phase,
        _brain getOrDefault ["generation",-1],
        _brain getOrDefault ["ownerEpoch",-1],
        serverTime,
        _brain getOrDefault ["cancelReason",""],
        count (_job getOrDefault ["cleared",[]]),
        count (_job getOrDefault ["unreachable",[]]),
        count (_job getOrDefault ["positions",[]])
    ],true];
};
-1
