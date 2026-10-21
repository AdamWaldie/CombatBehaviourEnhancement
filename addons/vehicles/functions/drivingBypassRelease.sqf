/*
 * Author: WaldoTheWarfighter
 * Native flight revokes stop/route recall authority; exact unrelated cap release remains separate.
 * Purpose: Retires a controller-owned bypass and only its exact owned fixed path/native handback.
 * Locality / Authority: Current vehicle/group owner. Both seats, route, command receipts and
 * external/tactical ownership protect cleanup. Both native command types must also match;
 * matching destinations alone cannot recall a changed MOVE/STOP/FOLLOW command. Identical
 * repeated commands remain indistinguishable; missing legacy task receipts grant no recall.
 * New individual reservations prevent movement cleanup; actor leases remain untouched.
 * New native BACK, keyboard commander input or scripted LEFT/RIGHT revokes native path
 * cleanup too, even while both unit destination/task receipts remain unchanged.
 * Live episode/locality, controller revision, command admission and retirement share one
 * unscheduled section. Identity repeats after native commands before metadata deletion; a
 * replacement episode survives. No geometry or world query runs in this section.
 * Repeat/JIP: Public episode retires once; bounded 32-entry object/route cooldown lasts 120 s.
 * PLAN owns no movement and cannot stop native actors. Exact ordinary-parent child cleanup
 * may journal its newly issued native route request within two seconds/original parent expiry;
 * this carries the spent budget without renewing the episode or copying the fixed path. Local handles/code are never published.
 * QUEUE cleanup cannot resume a route until an explicit matching completed handback;
 * failed/expired owned paths stop, retain an observed exact STOP for separate finite safe handback,
 * then retire their exact original queue consent. Missing STOP acknowledgement grants no new authority.
 * A successor queue binding forbids native cleanup and survives metadata retirement.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 reason <STRING, RELEASED>; 3 resume <BOOL, true> permits exact unchanged authored-route handback.
 * 4 stopOnly <BOOL, false> stops exact-owned work without route recall;
 * 5 expected revision <NUMBER, -1> optionally limits convoy cleanup to its original revision.
 * Return Value: BOOL - matching episode retired, never proof of actual passage.
 * Current callers: DrivingBypassStep, DrivingAssistRelease, ConvoyTick, ConvoyCrewLocal and ConvoyReleaseLocal.
 * Example: [truck1,group driver truck1,"OBSTACLE_CHANGED"] call CBE_fnc_DrivingBypassRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]],["_stopOnly",false,[true]],["_expectedRevision",-1,[0]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle}
    || {isNull _group} || {!local _group}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
if (count _work == 0 || {(_work get "group") != _group}) exitWith {false};
private _retired=false;
isNil {
    if (!local _vehicle || {!local _group}
        || {(_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap]) isNotEqualTo _work}) exitWith {false};
    private _controller=_work getOrDefault ["controller",["ORDINARY",-1]];
    private _convoy=(_controller param [0,""]) == "CONVOY";
    private _queue=(_controller param [0,""]) == "QUEUE";
    private _queueBinding=_work getOrDefault ["queueCrossingBinding",[]];
    private _queueConsent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    private _queueMatches=_queue && {_queueBinding isEqualType []} && {count _queueBinding == 4}
        && {(_queueConsent getOrDefault ["crossingBinding",[]]) isEqualTo _queueBinding};
    private _queueMayRetire=!_queue || {count _queueConsent == 0 || {_queueMatches}};
    private _acceptedClearance=_queueBinding isEqualType [] && {count _queueBinding == 4}
        && {(_work getOrDefault ["queueClearanceAccepted",[]]) isEqualTo _queueBinding}
        && {_work getOrDefault ["queueCrossed",false]};
    private _queueMayResume=!_queue || {_queueMayRetire && {_acceptedClearance}
        && {_reason in ["QUEUE_COMPLETE","DRIVING_RELEASED"]}};
    if (_expectedRevision >= 0 && {(!_convoy) || {(_controller param [1,-2]) != _expectedRevision}}) exitWith {false};
    private _current=_group getVariable ["CBE_Convoy_Brain",createHashMap];
    private _currentConfiguration=_current getOrDefault ["configuration",[]];
    private _successor=_convoy && {_currentConfiguration isNotEqualTo []}
        && {(_currentConfiguration param [0,-1]) != (_controller param [1,-2])}
        && {!(_current getOrDefault ["cancelled",false])};
    private _haltCleanup=_reason == "CONVOY_HALT" && {_expectedRevision == (_controller param [1,-2])}
        && {(_currentConfiguration param [5,""]) == "HALT"}
        && {(missionNamespace getVariable ["CBE_Convoy_LocalRegistry",[]]) findIf {
            (_x select 0) == _group && {(_x select 1) isEqualTo _currentConfiguration}
        } >= 0};
    if (_successor && {!_haltCleanup} && {!(_reason in ["CONTROLLER_CHANGED","CONVOY_LEAD_CHANGED"])}) exitWith {false};
    private _driver=_work get "driver";private _operator=_work get "operator";private _route=_work get "route";
    private _pathInput=vehicleMoveInfo _vehicle;
    private _nativePathFree=!(toUpperANSI (_pathInput param [0,""]) in ["BACK","DIRECTBYCOMANDER"])
        && {!(toUpperANSI (_pathInput param [1,""]) in ["LEFT","RIGHT"])};
    private _owned=(_work get "phase") == "FOLLOW" && {_resume || {_stopOnly} || {_queue}} && {_queueMayRetire}
        && {!isNull _driver} && {!isNull _operator} && {local _driver} && {local _operator}
        && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
        && {group _driver == _group} && {group _operator == _group}
        && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {_nativePathFree}
        && {(expectedDestination _operator) isEqualTo (_work get "command")}
        && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
        && {(toUpperANSI currentCommand _driver) == (_work getOrDefault ["driverTask","__MISSING__"])}
        && {(toUpperANSI currentCommand _operator) == (_work getOrDefault ["operatorTask","__MISSING__"])}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {_convoy || {[_group] call CBE_fnc_DrivingMovementAvailable}}
        && {_convoy || {!(_vehicle getVariable ["CBE_Convoy_Active",false])}}
        && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}};
    {
        _owned=_owned && {!isNull _x} && {local _x} && {vehicle _x == _vehicle}
            && {!fleeing _x} && {[_x] call CBE_fnc_CortexCombatEffective}
            && {!([_x] call CBE_fnc_CortexActorMoveReserved)} && {!isPlayer _x} && {isNull remoteControlled _x}
            && {isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            && {simulationEnabled _x} && {!isObjectHidden _x}
            && {[_x] call CBE_fnc_CortexExternalOwner == ""}
            && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
            && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
                "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
    } forEach [_driver,_operator];
    if (_owned) then {
        [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
        doStop _driver;if (_operator != _driver) then {doStop _operator};
        if (_queue && {!_queueMayResume} && {_resume} && {!_stopOnly}
            && {currentCommand _driver == "STOP"} && {currentCommand _operator == "STOP"}) then {
            private _owner=[_group] call CBE_fnc_DrivingOwnerReceipt;
            if (_owner isNotEqualTo []) then {
                _vehicle setVariable ["CBE_DrivingAbort_Hold",createHashMapFromArray [
                    ["binding",+_queueBinding],["group",_group],["driver",_driver],["operator",_operator],
                    ["owner",_owner],["route",+_route],["deadline",(_work get "deadline")+15],
                    ["driverCommand",+(expectedDestination _driver)],["command",+(expectedDestination _operator)],
                    ["driverLeader",formLeader _driver],["operatorLeader",formLeader _operator]
                ],true];
            };
        };
        private _index=currentWaypoint _group;
        if (_resume && {_queueMayResume} && {_index > 0} && {_index < count waypoints _group}
            && {_convoy || {vehicle leader _group == _vehicle}}
            && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
            && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
            if (_driver != _operator) then {_driver doFollow _operator};
            private _returnBefore=[currentCommand _driver,+(expectedDestination _driver),
                currentCommand _operator,+(expectedDestination _operator)];
            private _returnGoal=waypointPosition [_group,_index];
            _operator doMove _returnGoal;
            private _parent=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
            private _parentBinding=_work getOrDefault ["recoveryParent",[]];
            private _hard=_parent getOrDefault ["hardDeadline",-1];
            private _cap=(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) param [0,-1,[0]];
            if (!_convoy && {!_queue} && {_parentBinding isNotEqualTo []}
                && {_hard isEqualType 0} && {finite _hard} && {serverTime < _hard}
                && {_parentBinding isEqualTo [_group,_route,_hard,_parent getOrDefault ["progressAnchor",[]]]}
                && {(_parent getOrDefault ["bypassSpent",false]) isEqualTo true}
                && {(_parent getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}
                && {(_parent getOrDefault ["driver",objNull]) == _driver}
                && {(_parent getOrDefault ["operator",objNull]) == _operator}
                && {!(_parent getOrDefault ["releasePending",false])}
                && {finite _cap} && {_cap >= 0} && {abs ((getForcedSpeed _vehicle)-_cap) <= 0.1}
                && {(_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap]) isEqualTo _work}
                && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}) then {
                private _returned=createHashMapFromArray ((keys _parent) apply {[_x,_parent get _x]});
                // A distinct driver retains its pre-commander-write receipt. An unrelated
                // driver order cannot become ours just because the commander acknowledged.
                _returned set ["driverCommand",if (_driver == _operator) then {+(expectedDestination _driver)} else {+(_returnBefore select 1)}];
                _returned set ["command",+(expectedDestination _operator)];
                _returned set ["cap",_cap];
                _returned set ["request",[+_returnGoal,(serverTime+2) min _hard,_returnBefore]];
                _returned set ["bypassReturn",_work get "context"];
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_returned,true];
            };
        };
    };
    // A synchronous native event may have published successor work during command handling.
    if (!local _vehicle || {!local _group}
        || {(_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap]) isNotEqualTo _work}) exitWith {false};
    private _context=_work get "context";
    private _cooldown=(_vehicle getVariable ["CBE_DrivingBypass_Cooldown",[]]) select {
        (_x select 1) > serverTime && {(_x select 0) isNotEqualTo _context}
    };
    if (count _cooldown >= 32) then {_cooldown deleteAt 0};
    _cooldown pushBack [_context,serverTime+120];
    _vehicle setVariable ["CBE_DrivingBypass_Cooldown",_cooldown,true];
    _vehicle setVariable ["CBE_DrivingBypass_Result",[_reason,serverTime,_work get "obstacle",_work get "index"],true];
    _vehicle setVariable ["CBE_DrivingBypass_Work",nil,true];
    if (_queueMatches && {((_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) getOrDefault ["crossingBinding",[]]) isEqualTo _queueBinding}) then {
        private _queueRows=_queueConsent getOrDefault ["context",[]];
        if (count _queueRows > 0 && {count (_queueRows select 0) == 6}
            && {count ((_queueRows select 0) select 2) == 11}) then {
            private _rootActor=(_queueRows select 0) select 2;
            [_vehicle,_group,_rootActor select 4,_rootActor select 5] call CBE_fnc_DrivingQueueAgreementRelease;
        };
    };
    _retired=true;
    false
};
_retired
