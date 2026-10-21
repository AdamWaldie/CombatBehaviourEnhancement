/*
 * Author: WaldoTheWarfighter
 * Queued ACE treatment vetoes steering before the native medical task appears.
 * Either operating crew member entering native flight vetoes bypass steering.
 * Ordinary admission requires actual approach room before spending work; an inactive
 * result may include fifth HASHMAP field with a fresh BACKOFF diagnosis for the caller.
 * Purpose: Runs a finite ordinary/convoy-lead bypass or explicitly granted queue crossing through the existing controller.
 * QUEUE requires a private current CROSSING grant and frozen proposal. It rechecks path
 * geometry at issue, keeps original queue expiry, and holds at measured tail clearance.
 * Server grants require all-owner phase installation and path-publication acknowledgement.
 * The existing driving callback consumes this internal path; automatic queue admission remains off.
 * Locality / Authority: Internal synchronous owner callback only. Current driving brain and the
 * caller's fresh authority predicate and internal plain-route/crew gates protect every command. Never remote.
 * New PLAN acquisition preserves native STOP/FOLLOW/ATTACK/unowned CBE on either seat;
 * its two actors must be idle or moving to the full three-dimensional authored destination. Owned FOLLOW-phase
 * doStop receipts retain their separate retirement contract.
 * Individual actor reservations on either seat veto acquisition and every later command.
 * Independent native driving/turning refuses PLAN acquisition. During FOLLOW, a native
 * BACK, keyboard commander input or scripted turn yields without stopping/resuming that input.
 * Ordinary AI forward speed changes remain valid during the owned fixed path.
 * PLAN geometry stays outside a short unscheduled issue commit. Exact live episode/phase,
 * original deadline, proposal transforms, native seats/orders and caller authority repeat inside
 * that boundary before stop/path writes and FOLLOW publication; refused commits issue nothing.
 * Repeat/JIP: Public serializable work stores original 90-second deadline, two-side attempt budget,
 * or the shorter current ordinary-recovery parent deadline. A parent permits one bypass episode;
 * parent replacement/expiry ends its child and cannot renew either budget.
 * path/checkpoint/seat/route receipts. New owners adopt without command replay or clock renewal.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 brain <HASHMAP, empty>;
 * 3 fresh solid observation <ARRAY, []>; 4 authority predicate <CODE, {false}>, local only;
 * 5 controller <STRING, ORDINARY> - ORDINARY, CONVOY or internal QUEUE; followers never enter this executor.
 * Return Value: ARRAY [active BOOL, capMps NUMBER, phase STRING, sourceConstraintMayYield BOOL].
 * Bounds: one side proposal per callback (max two); FOLLOW validates one actual next segment
 * (at most 15 rays) and advances at most four ordered physical checkpoints per callback.
 * Capture uses current pose or a <=3-second, <=12-metre observed ASL segment; it is not
 * replayed across owner epochs or treated as proof of continuous collision-free travel. No new scheduler.
 * Full ordered checkpoint visit and actual tail clearance alone complete. Invalid geometry,
 * command/owner changes, obstacle crew/engine/attachment changes and deadline expiry retain failure; no elapsed-time or ready success.
 * Current callers: DrivingAssistStart and ConvoyTick. Convoy followers retain predecessor trails.
 * Neither path acceptance nor this API is physical QA.
 * Example: [_group,_vehicle,_brain,_solid,_mayRecoverRoute] call CBE_fnc_DrivingBypassStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_brain",createHashMap,[createHashMap]],
    ["_observed",[],[[]]],["_authority",{false},[{}]],["_controller","ORDINARY",[""]]];
private _inactive=[false,1e6,"",false];
if (isRemoteExecuted) exitWith {_inactive};
if (!(_controller in ["ORDINARY","CONVOY","QUEUE"])) exitWith {_inactive};
private _convoy=_controller == "CONVOY";
private _queue=_controller == "QUEUE";
private _queueAgreement=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
private _configuration=_brain getOrDefault ["configuration",[]];
private _controllerReceipt=[_controller,if (_convoy) then {_configuration param [0,-1]} else {-1}];
private _route=[_group] call CBE_fnc_DrivingRouteReceipt;
if ((_route param [0,"",[""]]) == "NATIVE_MOVE") exitWith {_inactive};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
private _seatsAvailable={
    [_driver,_operator] findIf {
        isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _vehicle}
            || {fleeing _x} || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
            || {[_x] call CBE_fnc_CortexActorMoveReserved} || {isPlayer _x}
            || {!isNull remoteControlled _x} || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
                "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
                "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
    } < 0
};
// This executor must enforce authored intent itself before it can be shared by another controller.
private _plainRoute={
    private _index=currentWaypoint _group;
    if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
    private _waypoint=[_group,_index];private _statements=waypointStatements _waypoint;
    private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
    waypointType _waypoint == "MOVE" && {_condition == "true"}
        && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
        && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
        && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
        && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []}
};
// Before any alternate movement exists, only idle or route-matching native MOVE
// commands authorize acquisition. STOP/FOLLOW/ATTACK and unowned CBE are not consent.
private _nativePathFree={
    private _pathInput=vehicleMoveInfo _vehicle;
    !(toUpperANSI (_pathInput param [0,""]) in ["BACK","DIRECTBYCOMANDER"])
        && {!(toUpperANSI (_pathInput param [1,""]) in ["LEFT","RIGHT"])}
};
private _nativeAdmissionReady={
    private _admissionInput=vehicleMoveInfo _vehicle;
    if (toUpperANSI (_admissionInput param [0,""]) in ["BACK","FORWARD","FAST","SLOW","DIRECTBYCOMANDER","SIMPLE","CONVOY"]
        || {toUpperANSI (_admissionInput param [1,""]) in ["LEFT","RIGHT"]}) exitWith {false};
    private _destination=waypointPosition [_group,currentWaypoint _group];
    [_driver,_operator] findIf {
        private _command=toUpperANSI currentCommand _x;
        private _target=(expectedDestination _x) param [0,[],[[]]];
        _command != "" && {_command != "MOVE" || {count _target != 3
            || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {_target vectorDistance _destination > 3}
        }}
    } < 0
};
private _queueCurrent={
    private _liveQueue=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    !_queue || {(_liveQueue getOrDefault ["motionStage",""]) == "CROSSING"
        && {_liveQueue getOrDefault ["crossingGranted",false]}
        && {(_liveQueue getOrDefault ["crossingBinding",[]]) isEqualTo (_queueAgreement getOrDefault ["crossingBinding",[]])}
        && {(_liveQueue getOrDefault ["crossingPath",[]]) isEqualTo (_queueAgreement getOrDefault ["crossingPath",[]])}
        && {[_liveQueue,true] call CBE_fnc_DrivingQueueReverseCurrent}}
};
private _obstacleAvailable={
    params ["_target"];
    if (_queue) exitWith {call _queueCurrent
        && {_target == ((_queueAgreement getOrDefault ["vehicles",[]]) param [1,objNull])}};
    [_target] call CBE_fnc_DrivingBypassObstacleAvailable
};
private _controllerCurrent={
    if (_convoy) exitWith {
        private _mobile=(_configuration param [4,[]]) select {
            alive _x && {canMove _x} && {[driver _x] call CBE_fnc_CortexCombatEffective}
                && {group driver _x == _group}
        };
        (_group getVariable ["CBE_Convoy_Brain",createHashMap]) isEqualTo _brain
            && {(_brain getOrDefault ["registryRevision",-1]) == (missionNamespace getVariable ["CBE_Convoy_ReceivedRevision",-2])}
            && {(_brain getOrDefault ["jobToken",""]) isEqualTo (_group getVariable ["CBE_Convoy_LocalJobToken",""])}
            && {(missionNamespace getVariable ["CBE_Convoy_LocalRegistry",[]]) findIf {
                (_x select 0) isEqualTo _group && {(_x select 1) isEqualTo _configuration}
            } >= 0}
            && {(_configuration param [5,""]) == "TRAVEL"}
            && {count (_configuration param [4,[]]) <= 20}
            && {_mobile isNotEqualTo []} && {(_mobile select 0) isEqualTo _vehicle}
            && {_mobile findIf {!local _x || {!local driver _x}} < 0}
            && {_vehicle getVariable ["CBE_Convoy_Active",false]}
            && {(_vehicle getVariable ["CBE_Convoy_Group",grpNull]) == _group}
            && {[_group,"CBE_Convoy_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
            && {[_group,false,false,true] call CBE_fnc_CortexIsEligible}
    };
    (_group getVariable ["CBE_Driving_Brain",createHashMap]) isEqualTo _brain
        && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_brain getOrDefault ["route",[]]) isEqualTo _route}
        && {[_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
        && {[_group] call CBE_fnc_DrivingMovementAvailable}
        && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
        && {vehicle leader _group isEqualTo _vehicle}
};
private _mayWrite={
    !isNull _group && {local _group} && {!isNull _vehicle} && {local _vehicle}
        && {call _controllerCurrent}
        && {!(_brain getOrDefault ["cancelled",false])}
        && {_route isNotEqualTo []} && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {call _plainRoute} && {call _authority} && {call _seatsAvailable} && {call _nativePathFree} && {call _queueCurrent}
        && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {alive _vehicle} && {canMove _vehicle} && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
        && {[_group,["CBE_AIPass_DrivingAssist_Recovery_Enable","CBE_Convoy_RouteRecovery_Enable"] select _convoy,true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
        && {isAISteeringComponentEnabled _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {isNil {_vehicle getVariable "CBE_DrivingCorridor_Work"}}
};
// An ordinary recovery parent narrows this executor; it grants no native command authority.
private _recoveryBinding={
    params ["_parent"];
    if (!(_parent isEqualType createHashMap) || {count _parent == 0}
        || {(_parent getOrDefault ["group",grpNull]) != _group}
        || {(_parent getOrDefault ["route",[]]) isNotEqualTo _route}
        || {(_parent getOrDefault ["driver",objNull]) != _driver}
        || {(_parent getOrDefault ["operator",objNull]) != _operator}) exitWith {[]};
    private _hard=_parent getOrDefault ["hardDeadline",-1];
    private _anchor=_parent getOrDefault ["progressAnchor",[]];
    if (!(_hard isEqualType 0) || {!finite _hard} || {serverTime >= _hard}
        || {!(_anchor isEqualType [])} || {count _anchor != 3}
        || {_anchor findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {[]};
    [_group,_route,_hard,+_anchor]
};
private _captureOwner=[clientOwner,_brain getOrDefault ["ownerEpoch",-1],_brain getOrDefault ["jobToken",""],_brain getOrDefault ["generation",-1]];
private _work=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
if (!(call _mayWrite)) exitWith {
    if ((_work getOrDefault ["controller",["ORDINARY",-1]]) isEqualTo _controllerReceipt) then {
        [_vehicle,_group,"AUTHORITY_ENDED"] call CBE_fnc_DrivingBypassRelease;
    };_inactive
};
if (count _work > 0 && {(_work get "group") != _group}) then {
    _vehicle setVariable ["CBE_DrivingBypass_Work",nil,true];_work=createHashMap;
};
if (count _work > 0 && {(_work getOrDefault ["controller",["ORDINARY",-1]]) isNotEqualTo _controllerReceipt}) then {
    [_vehicle,_group,"CONTROLLER_CHANGED",false,true] call CBE_fnc_DrivingBypassRelease;_work=createHashMap;
};
// Diagnose ordinary approach before publishing work, spending its parent or cooldown.
private _approach=createHashMap;
if (count _work == 0 && {!_convoy} && {!_queue} && {abs speed _vehicle <= 8}) then {
    _approach=[_vehicle,_observed] call CBE_fnc_DrivingBypassApproach;
};
if (count _work == 0 && {!_convoy || {isNil {_group getVariable "CBE_Convoy_BypassPassage"}}}) then {
    if (count _observed == 9 && {(_observed select 5) == "STATIC"} && {!isNull (_observed select 1)}
        && {abs speed _vehicle <= 8}
        // Actual hull/ramp room, not a fixed forward gap, defers ordinary acquisition.
        // Queue/convoy retain their existing plan and admission contracts.
        && {_queue || {_convoy} || {(_approach getOrDefault ["status",""]) == "ROOM"}}) then {
        private _context=[_group,_route,_observed select 1,_driver,_operator,_controllerReceipt];
        private _cooldown=_vehicle getVariable ["CBE_DrivingBypass_Cooldown",[]];
        private _command=expectedDestination _operator;
        private _parent=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        private _parentBound=!_convoy && {!_queue} && {!(_parent isEqualType createHashMap) || {count _parent > 0}};
        private _parentBinding=if (_parentBound) then {[_parent] call _recoveryBinding} else {[]};
        private _parentReady=!_parentBound || {_parentBinding isNotEqualTo []
            && {(_parent getOrDefault ["bypassSpent",false]) isEqualTo false}
            && {!(_parent getOrDefault ["releasePending",false])}
            && {(_parent getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}};
        private _deadline=if (_queue) then {_queueAgreement get "expires"} else {serverTime+90};
        if (_parentBound && {_parentReady}) then {_deadline=_deadline min (_parentBinding select 2)};
        if (_parentReady && {_cooldown findIf {(_x select 0) isEqualTo _context && {(_x select 1) > serverTime}} < 0}
            && {call _nativeAdmissionReady}) then {
            private _admissionWork=_work;
            isNil {
            if (!(call _mayWrite) || {!(call _nativeAdmissionReady)} || {serverTime >= _deadline}
                || {(_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap]) isNotEqualTo _admissionWork}) exitWith {false};
            if (_parentBound && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isNotEqualTo _parent
                || {([_parent] call _recoveryBinding) isNotEqualTo _parentBinding}
                || {!((_parent getOrDefault ["bypassSpent",false]) isEqualTo false)}}) exitWith {false};
            _work=createHashMapFromArray [["group",_group],["route",_route],["driver",_driver],["operator",_operator],
                ["context",_context],["controller",_controllerReceipt],["obstacle",_observed select 1],["transform",_observed select 8],
                ["deadline",_deadline],["side",1],["phase","PLAN"],["index",0],
                ["command",+_command],["driverCommand",+(expectedDestination _driver)],
                ["driverTask",toUpperANSI currentCommand _driver],["operatorTask",toUpperANSI currentCommand _operator]];
            if (_queue) then {
                _work set ["queueCrossingBinding",+(_queueAgreement get "crossingBinding")];
                _work set ["points",+(_queueAgreement get "crossingPath")];
            };
            if (_parentBound) then {
                private _spent=createHashMapFromArray ((keys _parent) apply {[_x,_parent get _x]});
                _spent set ["bypassSpent",true];
                _work set ["recoveryParent",_parentBinding];
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_spent,true];
            };
            _vehicle setVariable ["CBE_DrivingBypass_Work",_work,true];
            false
            };
        };
    };
};
if (count _work == 0) exitWith {
    if ((_approach getOrDefault ["status",""]) == "BACKOFF") then {
        [false,1e6,"BYPASS_APPROACH_REQUIRED",false,_approach]
    } else {_inactive}
};
private _parentCurrent={
    private _binding=_work getOrDefault ["recoveryParent",[]];
    _binding isEqualTo [] || {
        private _parent=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        ([_parent] call _recoveryBinding) isEqualTo _binding
            && {(_parent getOrDefault ["bypassSpent",false]) isEqualTo true}
            && {!(_parent getOrDefault ["releasePending",false])}
            && {(_parent getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}
    }
};
private _obstacle=_work get "obstacle";private _reason=if (call _parentCurrent) then {""} else {"RECOVERY_PARENT_CHANGED"};
if ((_work get "route") isNotEqualTo _route || {(_work get "driver") != _driver} || {(_work get "operator") != _operator}
    || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
    || {(expectedDestination _driver) isNotEqualTo (_work get "driverCommand")}
    || {(toUpperANSI currentCommand _driver) != (_work getOrDefault ["driverTask","__MISSING__"])}
    || {(toUpperANSI currentCommand _operator) != (_work getOrDefault ["operatorTask","__MISSING__"])}) then {_reason="COMMAND_CHANGED"};
if (_reason == "" && {(_work get "phase") == "PLAN"} && {!(call _nativeAdmissionReady)}) then {_reason="COMMAND_CHANGED"};
if (_reason == "" && {!([_obstacle] call _obstacleAvailable)
    || {[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle] isNotEqualTo (_work get "transform")}}) then {_reason="OBSTACLE_CHANGED"};
if (_reason == "" && {serverTime >= (_work get "deadline")}) then {_reason="TIMEOUT"};
if (_reason != "") exitWith {[_vehicle,_group,_reason,!(_reason in ["COMMAND_CHANGED","RECOVERY_PARENT_CHANGED"])] call CBE_fnc_DrivingBypassRelease;_inactive};
if ((_work get "phase") == "PLAN") exitWith {
    if (count _observed != 9 || {(_observed select 1) != _obstacle} || {(_observed select 8) isNotEqualTo (_work get "transform")}) exitWith {
        [_vehicle,_group,"OBSERVATION_CHANGED"] call CBE_fnc_DrivingBypassRelease;_inactive
    };
    private _envelope=[];private _columnLength=0;
    if (_convoy) then {
        _envelope=[0,0,0];
        {
            private _bounds=boundingBoxReal _x;private _lo=_bounds select 0;private _hi=_bounds select 1;
            _envelope set [0,(_envelope select 0) max ((abs (_lo select 0)) max (abs (_hi select 0)))];
            _envelope set [1,(_envelope select 1) max ((abs (_lo select 1)) max (abs (_hi select 1)))];
            _envelope set [2,(_envelope select 2) max ((_hi select 2)-(_lo select 2))];
            _columnLength=_columnLength+((_hi select 1)-(_lo select 1))+(_configuration param [2,30]);
        } forEach (_configuration param [4,[]]);
    };
    private _proposal=if (_queue) then {_queueAgreement getOrDefault ["crossingProposal",[]]} else {
        [_vehicle,_observed,_work get "side",_envelope] call CBE_fnc_DrivingBypassPlan
    };
    if (_queue && {count _proposal != 8 || {!(_proposal select 0)}
        || {(_proposal select 3) isNotEqualTo (_queueAgreement get "crossingPath")}
        || {(_proposal select 7) isNotEqualTo [_queueAgreement get "token",_queueAgreement get "expires",
            _queueAgreement get "phaseSerial",_queueAgreement getOrDefault ["crossingPoses",[]]]}}) exitWith {
        [_vehicle,_group,"QUEUE_PROPOSAL_CHANGED"] call CBE_fnc_DrivingBypassRelease;_inactive
    };
    if (!(_proposal select 0)) exitWith {
        if (!_queue && {(_work get "side") == 1}) then {
            _work set ["side",-1];_vehicle setVariable ["CBE_DrivingBypass_Work",_work,true];
            [true,8/3.6,"BYPASS_PLAN",false]
        } else {[_vehicle,_group,_proposal select 1] call CBE_fnc_DrivingBypassRelease;_inactive}
    };
    private _points=_proposal select 2;private _asl=_proposal select 3;
    private _destination=ATLToASL waypointPosition [_group,currentWaypoint _group];
    private _forward=vectorDir _vehicle;_forward set [2,0];_forward=vectorNormalized _forward;
    private _exit=_asl select ((count _asl)-1);
    if ((_destination vectorDiff _exit) vectorDotProduct _forward < _columnLength+(waypointCompletionRadius [_group,currentWaypoint _group] max 20)+10) exitWith {
        [_vehicle,_group,"DESTINATION_CLEARANCE"] call CBE_fnc_DrivingBypassRelease;_inactive
    };
    if (!(call _mayWrite) || {!([_obstacle] call _obstacleAvailable)} || {!(call _nativeAdmissionReady)} || {(expectedDestination _operator) isNotEqualTo (_work get "command")}
        || {(expectedDestination _driver) isNotEqualTo (_work get "driverCommand")}) exitWith {_inactive};
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;
    private _halfWidth=((abs (_low select 0)) max (abs (_high select 0))) max (_envelope param [0,0]);
    private _halfLength=((abs (_low select 1)) max (abs (_high select 1))) max (_envelope param [1,0]);
    private _radius=sqrt ((_halfWidth^2)+(_halfLength^2))+1;
    if (_queue) then {
        // A stored proposal never grants cached collision/support clearance.
        // Reuse the same bounded validator immediately before the native commit.
        private _freshGuide=+_asl;_freshGuide set [0,getPosASL _vehicle];
        private _fresh=[_vehicle,_freshGuide,_radius,((_high select 2)-(_low select 2))] call CBE_fnc_DrivingPathGeometry;
        if (!(_fresh select 0)) then {_proposal=[]} else {
            // Only the stationary start is normalised within the frozen pose tolerance.
            // Subsequent granted anchors and journal checkpoints remain unchanged.
            _points=+_points;_points set [0,ASLToATL (_freshGuide select 0)];
            _proposal=+_proposal;_proposal set [4,[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle]];
            _proposal set [5,[getPosWorld _vehicle,vectorDir _vehicle,vectorUp _vehicle]];
        };
    };
    if (_proposal isEqualTo []) exitWith {[_vehicle,_group,"QUEUE_PATH_BLOCKED"] call CBE_fnc_DrivingBypassRelease;_inactive};
    private _issued=false;
    isNil {
        if (call _mayWrite && {call _nativeAdmissionReady} && {call _parentCurrent}
            && {(_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap]) isEqualTo _work}
            && {(_work get "phase") == "PLAN"} && {serverTime < (_work get "deadline")}
            && {(expectedDestination _operator) isEqualTo (_work get "command")}
            && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
            && {[_obstacle] call _obstacleAvailable}
            && {[getPosWorld _obstacle,vectorDir _obstacle,vectorUp _obstacle] isEqualTo (_proposal select 4)}
            && {[getPosWorld _vehicle,vectorDir _vehicle,vectorUp _vehicle] isEqualTo (_proposal select 5)}) then {
            [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
            if (_operator != _driver) then {doStop _operator};doStop _driver;
            _vehicle setDriveOnPath _points;
            _work set ["phase","FOLLOW"];_work set ["points",_asl];_work set ["index",1];
            _work set ["capture",[getPosASL _vehicle,serverTime,+_captureOwner]];
            _work set ["radius",_radius];_work set ["height",((_high select 2)-(_low select 2)) max (_envelope param [2,0])];
            _work set ["tailDeadline",(_work get "deadline")+((_columnLength/(8/3.6)+60) min 1710)];
            _work set ["forward",_forward];_work set ["far",_exit vectorDiff (_forward vectorMultiply (_radius+10))];
            _work set ["command",+(expectedDestination _operator)];_work set ["driverCommand",+(expectedDestination _driver)];
            _work set ["driverTask",toUpperANSI currentCommand _driver];_work set ["operatorTask",toUpperANSI currentCommand _operator];
            _vehicle setVariable ["CBE_DrivingBypass_Work",_work,true];
            _issued=true;
        };
        false
    };
    if (!_issued) exitWith {_inactive};
    [true,if (_queue && {!((_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["crossingMotionGranted",false])}) then {0} else {8/3.6},"BYPASS_FOLLOW",false]
};
if (_queue) then {["PATH_READY",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueHold};
private _points=_work get "points";private _index=_work get "index";private _origin=getPosASL _vehicle;
// A callback can arrive after a checkpoint was passed. Capture only the next ordered
// prefix against a short observed movement segment, never an arbitrary nearest future point.
private _capture=_work getOrDefault ["capture",[]];
private _previous=+_origin;
if (count _capture == 3 && {(_capture select 2) isEqualTo _captureOwner}
    && {serverTime >= (_capture select 1)} && {serverTime-(_capture select 1) <= 3}
    && {_origin vectorDistance (_capture select 0) <= 12}) then {_previous=+(_capture select 0)};
private _sweep=_origin vectorDiff _previous;
private _sweepXY=+_sweep;_sweepXY set [2,0];
private _squared=_sweepXY vectorDotProduct _sweepXY;
private _lastFraction=0;
for "_i" from 1 to 4 do {
    if (_index >= count _points) exitWith {};
    private _point=_points select _index;
    private _offset=_point vectorDiff _previous;_offset set [2,0];
    private _fraction=if (_squared > 0.01) then {((_offset vectorDotProduct _sweepXY)/_squared) max 0 min 1} else {1};
    private _closest=_previous vectorAdd (_sweep vectorMultiply _fraction);
    if (_fraction < _lastFraction || {_closest distance2D _point > 2.5} || {abs ((_closest select 2)-(_point select 2)) > 2}) exitWith {};
    _lastFraction=_fraction;_index=_index+1;
};
_work set ["capture",[+_origin,serverTime,+_captureOwner]];
if (_index != (_work get "index")) then {_work set ["index",_index];_vehicle setVariable ["CBE_DrivingBypass_Work",_work,true]};
if (_index >= count _points) exitWith {
    private _box=boundingBoxReal _vehicle;private _low=_box select 0;private _high=_box select 1;private _clear=true;
    {private _xCoord=_x;{private _yCoord=_x;{
        private _corner=_vehicle modelToWorldWorld [_xCoord,_yCoord,_x];
        if ((_corner vectorDiff (_work get "far")) vectorDotProduct (_work get "forward") < 5) then {_clear=false};
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    if (_clear) then {
        if (_queue) then {
            // The sole speed writer consumes zero cap. Keep this path/native journal
            // until the server independently accepts CROSS_CLEAR and the root owner
            // records its exact completion binding. Cancellation grants no route resume.
            private _changed=false;private _reportClear=false;
            if (!(_work getOrDefault ["queueCrossed",false])) then {
                _work set ["queueCrossed",true];_work set ["queueCrossedAt",serverTime];_changed=true;
            };
            private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
            private _assist=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
            private _still=finite _linear && {finite _angular} && {_linear < 0.1} && {_angular < 0.01}
                && {(_assist param [3,grpNull]) == _group} && {(_assist param [0,-1]) == 0} && {abs getForcedSpeed _vehicle < 0.001};
            private _since=_work getOrDefault ["queueClearStillSince",-1];
            if (!_still) then {
                if (_since >= 0) then {_work set ["queueClearStillSince",-1];_changed=true};
            } else {
                if (_since < 0) then {_since=serverTime;_work set ["queueClearStillSince",_since];_changed=true};
                private _reports=_work getOrDefault ["queueClearReports",0];
                if (serverTime-_since >= 1 && {_reports < 2}
                    && {_reports == 0 || {serverTime-(_work getOrDefault ["queueClearReportedAt",-1]) >= 2}}) then {
                    _work set ["queueClearReports",_reports+1];_work set ["queueClearReportedAt",serverTime];
                    _changed=true;_reportClear=true;
                };
            };
            if (_changed) then {_vehicle setVariable ["CBE_DrivingBypass_Work",_work,true]};
            if (_reportClear) then {["CROSS_CLEAR",[_queueAgreement get "token",_vehicle,_work get "queueCrossingBinding"]]
                remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
            [true,0,"QUEUE_CROSSED_HOLD",false]
        } else {[_vehicle,_group,"PHYSICALLY_PASSED"] call CBE_fnc_DrivingBypassRelease;_inactive}
    }
    else {[true,if (_queue && {!((_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["crossingMotionGranted",false])}) then {0} else {8/3.6},"BYPASS_FOLLOW",false]}
};
private _next=_points select _index;
private _health=[_vehicle,[_origin,_next],_work get "radius",_work get "height"] call CBE_fnc_DrivingPathGeometry;
if (!(_health select 0)) exitWith {[_vehicle,_group,"LEG_"+(_health select 1)] call CBE_fnc_DrivingBypassRelease;_inactive};
[true,if (_queue && {!((_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["crossingMotionGranted",false])}) then {0} else {8/3.6},"BYPASS_FOLLOW",true]
