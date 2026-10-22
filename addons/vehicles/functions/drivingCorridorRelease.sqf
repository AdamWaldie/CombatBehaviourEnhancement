/*
 * Author: WaldoTheWarfighter
 * Queued ACE treatment revokes movement cleanup; treatment queues remain untouched.
 * Native crew flight vetoes new steering and route recall; exact cap-only release remains separate.
 * Purpose: Retires one controller-owned corridor episode and hands back only its unchanged command.
 * Locality / Authority: Vehicle/group owner only. Exact driver, native destination, route and
 * external/tactical ownership checks protect every stop and route-resume command.
 * Approach cleanup requires the recorded driver destination or exact entry-goal propagation;
 * a different driver MOVE revokes recall even when the commander is unchanged.
 * Crossing ownership includes both seat receipts. A separate same-vehicle driver rejoins only
 * its unchanged owned commander before native-route wakeup; other actors/features are untouched.
 * New individual reservations prevent movement cleanup; actor leases remain untouched.
 * Native BACK/direct-commander/turn input also revokes path cleanup, even with unchanged destinations.
 * Current work observation, native handback, cooldown/result and exact episode deletion share
 * one unscheduled transaction. APPROACH rejects STOP; CROSS retains its own stop admission.
 * No geometry/query or suspended work occurs inside the bounded retirement transaction.
 * Repeat/JIP: Retires public work once; retains a bounded 120-second context cooldown and terminal
 * diagnostic. No movement is replayed to joining clients or over a changed command/seat/route.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 group <GROUP, grpNull>; 2 reason <STRING, RELEASED>;
 * 3 resume <BOOL, true> - permit unchanged authored/native MOVE handback, never force it.
 * Native return retains its original recovery parent, requires both observed STOP tasks
 * and uses the existing finite both-seat original-goal acknowledgement journal.
 * 4 stopOnly <BOOL, false> - retire an exact owned path without waking a route (lead replacement).
 * Return Value: BOOL - whether this matching episode was retired, not physical success.
 * Current callers: DrivingCorridorStep, DrivingAssistRelease, ConvoyCrewLocal and ConvoyReleaseLocal.
 * Example: [truck1,group driver truck1,"AREA_CHANGED"] call CBE_fnc_DrivingCorridorRelease;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_reason","RELEASED",[""]],["_resume",true,[true]],["_stopOnly",false,[true]]];
private _retired=false;
// At most two actors and32 cooldown rows: command retirement and metadata deletion
// cannot suspend between reading the original work and retiring that exact episode.
isNil {
    _retired=call {
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle} || {isNull _group} || {!local _group}) exitWith {false};
private _work=_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap];
if (count _work == 0 || {(_work getOrDefault ["group",grpNull]) != _group}) exitWith {false};
private _driver=_work getOrDefault ["driver",objNull];
private _operator=_work getOrDefault ["operator",objNull];
private _route=_work getOrDefault ["route",[]];
// The commander owns the approach, not an arbitrary replacement driver MOVE.
// Native propagation may retain the driver's recorded destination or publish the
// exact entry goal. Any other driver destination revokes this temporary approach.
private _approachDriverReady={
    private _recorded=_work getOrDefault ["driverCommand",[]];
    if (_recorded isEqualTo []) exitWith {false};
    private _driverNative=expectedDestination _driver;
    if (_driverNative isEqualTo _recorded) exitWith {true};
    private _entryGoal=(_work getOrDefault ["points",[]]) param [0,[],[[]]];
    private _driverGoal=_driverNative param [0,[],[[]]];
    count _entryGoal == 3 && {count _driverGoal == 3}
        && {_entryGoal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_driverGoal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_driverGoal vectorDistance _entryGoal <= 0.25}
};

private _controller=_work getOrDefault ["controller",["ORDINARY",-1]];
private _convoy=(_controller param [0,""]) == "CONVOY";
private _currentConvoy=_group getVariable ["CBE_Convoy_Brain",createHashMap];
private _convoyConfiguration=_currentConvoy getOrDefault ["configuration",[]];
// Cleanup may follow deregistration. A different active revision is a successor, not ours.
private _successor=_convoy && {_convoyConfiguration isNotEqualTo []}
    && {(_convoyConfiguration param [0,-1]) != (_controller param [1,-2])}
    && {!(_currentConvoy getOrDefault ["cancelled",false])};
// Only the validated current executor's explicit transition may retire the previous revision.
// Generic old cleanup cannot stop a retained successor's path; exact native receipts still apply.
private _transition=_reason in ["CONTROLLER_CHANGED","CONVOY_LEAD_CHANGED"];
private _pathInput=vehicleMoveInfo _vehicle;
private _nativePathFree=!(toUpperANSI (_pathInput param [0,""]) in ["BACK","DIRECTBYCOMANDER"])
    && {!(toUpperANSI (_pathInput param [1,""]) in ["LEFT","RIGHT"])};
private _owned=_nativePathFree && {!isNull _driver} && {!isNull _operator} && {local _driver} && {local _operator}
    && {driver _vehicle isEqualTo _driver} && {effectiveCommander _vehicle isEqualTo _operator}
    && {group _driver == _group} && {group _operator == _group}
    && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
    && {(expectedDestination _operator) isEqualTo (_work getOrDefault ["command",[]])}
    && {(_work getOrDefault ["phase",""]) != "CROSS" || {
        (expectedDestination _driver) isEqualTo (_work getOrDefault ["driverCommand",[]])
    }}
    && {(_work getOrDefault ["phase",""]) != "APPROACH" || {call _approachDriverReady}}
    && {_convoy || {_transition} || {[_group] call CBE_fnc_DrivingMovementAvailable}}
    && {!_successor || {_transition}}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {_convoy || {_transition} || {!(_vehicle getVariable ["CBE_Convoy_Active",false])}}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {alive _vehicle} && {canMove _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle};
{
    private _actor=_x;
    _owned=_owned && {!fleeing _actor} && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)} && {!isPlayer _actor}
        && {isNull remoteControlled _actor}
        && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {toUpperANSI currentCommand _actor in
            (["","MOVE","WAIT"]+([[],["STOP"]] select ((_work getOrDefault ["phase",""]) == "CROSS")))}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
            "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
            "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])};
} forEach [_driver,_operator];
private _nativeRoute=(_route param [0,"",[""]]) == "NATIVE_MOVE";
private _nativeParent=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
private _nativeHard=_nativeParent getOrDefault ["hardDeadline",-1];
private _nativeParentCurrent=!_nativeRoute || {!_convoy
    && {_nativeHard isEqualType 0} && {finite _nativeHard}
    && {(_work getOrDefault ["recoveryParent",[]]) isEqualTo
        [_group,_route,_nativeHard,_nativeParent getOrDefault ["progressAnchor",[]]]}
    && {(_nativeParent getOrDefault ["driver",objNull]) == _driver}
    && {(_nativeParent getOrDefault ["operator",objNull]) == _operator}
    && {(_nativeParent getOrDefault ["kind",""]) in ["REFRESH","FINAL"]}
    && {(_nativeParent getOrDefault ["bypassSpent",false]) isEqualTo true}
    && {!(_nativeParent getOrDefault ["releasePending",false])}};
// The owned doStop cancels fixed steering; native-ready is not a path-completion receipt.
if (_owned && {_nativeParentCurrent} && {_resume || {_stopOnly}}) then {
    [_group,_vehicle] call CBE_fnc_ConvoyRetireMoveReceipt;
    doStop _driver;
    if (_operator != _driver) then {doStop _operator};
    if (_nativeRoute) then {
        // Stop acknowledgement is command proof only, not physical rest or passage.
        private _cap=(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) param [0,-1,[0]];
        if (_resume && {serverTime < _nativeHard} && {count waypoints _group <= 1}
            && {currentCommand _driver == "STOP"} && {currentCommand _operator == "STOP"}
            && {finite _cap} && {_cap >= 0} && {abs ((getForcedSpeed _vehicle)-_cap) <= 0.1}
            && {vehicle leader _group == _vehicle}
            && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _nativeParent}
            && {(_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap]) isEqualTo _work}) then {
            if (_driver != _operator) then {_driver doFollow _operator};
            private _returnBefore=[currentCommand _driver,+(expectedDestination _driver),
                currentCommand _operator,+(expectedDestination _operator)];
            private _returnGoal=+(_route select 6);
            _operator doMove _returnGoal;
            if (driver _vehicle == _driver && {effectiveCommander _vehicle == _operator}
                && {count waypoints _group <= 1}
                && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _nativeParent}
                && {(_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap]) isEqualTo _work}) then {
                private _returned=createHashMapFromArray ((keys _nativeParent) apply {[_x,_nativeParent get _x]});
                _returned set ["driverCommand",if (_driver == _operator) then {+(expectedDestination _driver)} else {+(_returnBefore select 1)}];
                _returned set ["command",+(expectedDestination _operator)];
                _returned set ["cap",_cap];
                _returned set ["request",[+_returnGoal,(serverTime+2) min _nativeHard,_returnBefore]];
                // Shared temporary-path return marker: the existing classifier requires
                // both seats at the original goal and retains the original request window.
                _returned set ["bypassReturn",["CORRIDOR",_work get "context"]];
                _vehicle setVariable ["CBE_DrivingRecovery_Work",_returned,true];
            };
        };
    } else {
    private _index=currentWaypoint _group;
    if (_resume && {_index > 0} && {_index < count waypoints _group}
        && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
        && {driver _vehicle isEqualTo _driver} && {effectiveCommander _vehicle isEqualTo _operator}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
        if (_convoy || {vehicle leader _group isEqualTo _vehicle}) then {
            // Rejoin only the same-vehicle owned commander before its unchanged native route.
            // A mounted driver must never be recalled toward an on-foot or remote leader.
            if (_driver != _operator && {vehicle _operator == _vehicle}) then {_driver doFollow _operator};
            _operator doMove waypointPosition [_group,_index];
        } else {
            if (leader _group != _driver && {vehicle leader _group isKindOf "LandVehicle"}) then {
                _driver doFollow leader _group;
            };
        };
    };
    };
};
// Native command callbacks must not let old retirement delete a successor episode.
if (!local _vehicle || {!local _group}
    || {(_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap]) isNotEqualTo _work}) exitWith {false};
private _key=_work get "context";
private _cooldown=(_vehicle getVariable ["CBE_DrivingCorridor_Cooldown",[]]) select {
    (_x select 1) > serverTime && {(_x select 0) isNotEqualTo _key}
};
if (count _cooldown >= 32) then {_cooldown deleteAt 0};
_cooldown pushBack [_key,serverTime+120];
_vehicle setVariable ["CBE_DrivingCorridor_Cooldown",_cooldown,true];
_vehicle setVariable ["CBE_DrivingCorridor_Result",[_reason,serverTime,_work get "area",_work get "phase"],true];
_vehicle setVariable ["CBE_DrivingCorridor_Work",nil,true];
true
    };
    false
};
_retired
