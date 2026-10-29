/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one finite area-patrol circuit through the existing group brain and
 * common operation/native waypoint owner. Combat pauses the circuit without renewing its
 * original task or leg deadline; a calm group can resume only the unchanged mission context.
 * Locality/authority: Internal current group owner or inherited authenticated server task context. Exact task identity,
 * owner epoch and common generation fence every leg. New native/Zeus/specialist work wins.
 * Repeat/JIP: START refuses existing work. STEP runs in CortexGroupTick, never its own job.
 * CANCEL releases only this task's operation/lease. Locality loss retires rather than replays;
 * passive status is diagnostic, not a transferable task. No flags, formation, skills or seats change.
 * Arguments: 0 mode STRING START|CHECK|STEP|CANCEL; 1 group GROUP,grpNull;
 * 2 payload ARRAY: START [centreATL,radius=100,nodes=4,duration=900 (30..1800 seconds)],
 * CHECK [] (deadline only), STEP [native danger active=false], CANCEL [reason=RELEASED]. One circuit, <=8 legs;
 * each leg has a distance-scaled <=900 seconds including combat suspension. No automatic recovery/retry.
 * Return: BOOL - START accepted, STEP task retained, CANCEL exact local task retired.
 * Current callers: CortexGroupTick, CortexReleaseGroup, CortexOrderLocal, owner-local script API.
 * Example: ["START",_group,[getMarkerPos "patrol",100,4,900]] call CBE_fnc_PatrolOperation;
 */
params [["_mode","",[""]],["_group",grpNull,[grpNull]],["_payload",[],[[]]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _group} || {!local _group}) exitWith {false};
private _result=false;
// Direct script calls may be scheduled. Admission through command commit and identity updates
// must be one unscheduled boundary, just like the group brain's normal scheduler callback.
isNil {
_result=call {
private _task=_group getVariable ["CBE_PatrolTask",createHashMap];
if (toUpperANSI _mode != "START" && {count _task == 0}) exitWith {false};
private _state=[_group] call CBE_fnc_CortexGroupState;
private _publish={
    params ["_phase","_reason"];
    _group setVariable ["CBE_Patrol_Status",[_phase,_reason,_task getOrDefault ["index",0],
        count (_task getOrDefault ["route",[]]),serverTime],true];
    private _hunt=_task getOrDefault ["hunt",createHashMap];
    if (count _hunt > 0) then {
        _group setVariable ["CBE_Hunt_Status",[_phase,_reason,_hunt get "updates",serverTime],true];
    };
};
private _dropLease={
    if ((_state getOrDefault ["movementLease",[]]) isEqualTo ["PATROL",_task getOrDefault ["deadline",-1]]) then {
        _state deleteAt "movementLease";
    };
    if ((_group getVariable ["CBE_Cortex_MovementLease",[]]) isEqualTo
        ["PATROL",_task getOrDefault ["serverDeadline",-1]]) then {
        [_group,"PATROL",false] call CBE_fnc_CortexOwnershipLease;
    };
};
private _finish={
    params ["_reason",["_complete",false]];
    if ((_group getVariable ["CBE_PatrolTask",createHashMap]) isNotEqualTo _task) exitWith {false};
    private _generation=_task getOrDefault ["generation",-1];
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _completed=false;
    if ((_operation getOrDefault ["intent",""]) == "PATROL"
        && {(_operation getOrDefault ["generation",-2]) == _generation}) then {
        if (_complete) then {
            _completed=[_group,_generation,"COMPLETE",_reason] call CBE_fnc_OperationRelease;
        } else {[_group,_generation,_reason] call CBE_fnc_OperationCancel};
    };
    call _dropLease;
    if (_complete && {!_completed}) then {_reason="COMPLETION_REFUSED"};
    [["CANCELLED","COMPLETE"] select _completed,_reason] call _publish;
    _group setVariable ["CBE_PatrolTask",nil];
    true
};
// Read only the original current mission node, plus waypoint count/current index. Future
// mission nodes are retained verbatim. Normalize only the index shift caused by our one
// temporary node, including same-group synchronization handles; never execute statements.
private _missionUnchanged={
    params [["_ownedIndex",-1]];
    private _baseline=_task getOrDefault ["mission",[]];
    private _count=count waypoints _group;
    if (_count-([0,1] select (_ownedIndex >= 0)) != (_baseline param [0,-1])) exitWith {false};
    private _original=_baseline param [1,-1];
    private _expected=_original+([0,1] select (_ownedIndex >= 0 && {_ownedIndex <= _original}));
    private _current=currentWaypoint _group;
    if (_original < 0) exitWith {
        private _implicit=_task get "missionCurrent";
        private _shifted=_implicit+([0,1] select (_ownedIndex >= 0 && {_ownedIndex <= _implicit}));
        _current == _ownedIndex || {_current == _shifted} || {_implicit >= (_baseline select 0) && {_current >= _count}}
    };
    if (!(_current in [_ownedIndex,_expected])) exitWith {false};
    private _row=([_group,"",false,_expected] call CBE_fnc_AuthoredRouteReceipt) param [0,[]];
    if (count _row != 22) exitWith {false};
    _row set [0,_original];
    if (_ownedIndex >= 0 && {(_row select 16) findIf {
        (_x select 0) == _group && {(_x select 1) == _ownedIndex}
    } >= 0}) exitWith {false};
    private _sync=(_row select 16) apply {
        private _link=+_x;
        if (_ownedIndex >= 0 && {(_link select 0) == _group} && {(_link select 1) >= _ownedIndex}) then {
            _link set [1,(_link select 1)-1];
        };
        _link
    };
    _row set [16,_sync];
    _row isEqualTo ((_baseline param [2,[]]) param [0,[]])
};
private _membersAvailable={
    params ["_members"];
    _members isNotEqualTo [] && {count _members <= 64} && {
        _members findIf {alive _x && {(!local _x) || {isPlayer _x} || {!isNull objectParent _x}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {currentCommand _x == "STOP"}}} < 0
    }
};
private _legDeadline={
    private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
    private _point=(_task get "route") select (_task get "index");
    private _distance=if (isNull _anchor) then {0} else {_anchor distance2D _point};
    // A budget, not a path/arrival prediction. Long walking legs need more than a fixed90s.
    (time+((30+_distance/0.8) max 90 min 900)) min (_task get "deadline")
};
private _startLeg={
    private _generation=_task getOrDefault ["generation",-1];
    private _waypoint=[_group,_generation,_task get "index"] call CBE_fnc_PatrolRouteCommit;
    if ((_waypoint param [0,grpNull]) != _group || {(_waypoint param [1,-1]) < 0}) exitWith {false};
    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
    private _destination=_intent getOrDefault ["position",[]];
    if (count _destination != 3) exitWith {false};
    _task set ["destination",+_destination];
    _task set ["waypoint",+_waypoint];
    _task set ["waypointReceipt",[_group,"",false,_waypoint select 1] call CBE_fnc_AuthoredRouteReceipt];
    _task set ["phase","MOVING"];
    _state set ["movementLease",["PATROL",_task get "deadline"]];
    ["MOVING","LEG_ISSUED"] call _publish;
    true
};
switch (toUpperANSI _mode) do {
    case "START": {
        _payload params [["_centre",[],[[]]],["_radius",100,[0]],["_nodes",4,[0]],["_duration",900,[0]]];
        if (count _task > 0 || {!finite _duration} || {_duration < 30} || {_duration > 1800}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {!([_group] call CBE_fnc_CortexIsEligible)}
            || {count waypoints _group > 128}
            || {(_group getVariable ["CBE_Operation",createHashMap]) isNotEqualTo createHashMap}
            || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}
            || {(_group getVariable ["CBE_Cortex_MovementLease",[]]) isNotEqualTo []}
            || {(_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap]) isNotEqualTo createHashMap}
            || {!([units _group] call _membersAvailable)}) exitWith {false};
        private _route=[_centre,_radius,_nodes] call CBE_fnc_PatrolRoutePlan;
        if (_route isEqualTo []) exitWith {false};
        if (!([_group,true] call CBE_fnc_GroupBrainStart)) exitWith {false};
        private _deadline=time+_duration;
        private _serverDeadline=serverTime+_duration;
        if (!([_group,"PATROL",true,_serverDeadline] call CBE_fnc_CortexOwnershipLease)) exitWith {false};
        private _operation=[_group,"PATROL",_centre,units _group,_route,"MOVING"] call CBE_fnc_OperationStart;
        if (count _operation == 0) exitWith {
            [_group,"PATROL",false] call CBE_fnc_CortexOwnershipLease;
            false
        };
        _operation set ["patrolDeadline",_deadline];
        _group setVariable ["CBE_Operation",_operation,true];
        _task=createHashMapFromArray [["epoch",_group getVariable ["CBE_AIPass_Epoch",-1]],
            ["generation",_operation get "generation"],["route",_route],["index",0],
            ["participants",units _group],["missionCurrent",currentWaypoint _group],["mission",[_group] call CBE_fnc_NativeOrderReceipt],
            ["deadline",_deadline],["serverDeadline",_serverDeadline]];
        _task set ["legDeadline",call _legDeadline];
        _group setVariable ["CBE_PatrolTask",_task];
        if (!(call _startLeg)) exitWith {["LEG_REFUSED"] call _finish; false};
        true
    };
    case "CANCEL": {
        if (count _task == 0) exitWith {false};
        [_payload param [0,"RELEASED",[""]]] call _finish
    };
    case "CHECK": {
        if (count _task == 0) exitWith {false};
        if (count (_task getOrDefault ["hunt",createHashMap]) > 0
            && {!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {
            ["HUNT_DISABLED"] call _finish; false
        };
        private _reason=if ((_task get "epoch") != (_group getVariable ["CBE_AIPass_Epoch",-1])) then {
            "OWNER_CHANGED"
        } else {
            if (time >= (_task get "deadline") || {time >= (_task get "legDeadline")}) then {
                "PATROL_TIMEOUT"
            } else {if ((units _group) findIf {alive _x} < 0) then {"NO_PARTICIPANTS"} else {""}}
        };
        if (_reason != "") exitWith {[_reason] call _finish; false};
        true
    };
    case "STEP": {
        if (count _task == 0) exitWith {false};
        if ((_task get "epoch") != (_group getVariable ["CBE_AIPass_Epoch",-1])) exitWith {
            ["OWNER_CHANGED"] call _finish; false
        };
        if (time >= (_task get "deadline") || {time >= (_task get "legDeadline")}) exitWith {
            ["PATROL_TIMEOUT"] call _finish; false
        };
        if (!(missionNamespace getVariable ["CBE_AIPass_Active",false])
            || {!([_group] call CBE_fnc_CortexIsEligible)}) exitWith {
            ["CONTROL_CHANGED"] call _finish; false
        };
        private _members=units _group;
        private _original=_task get "participants";
        if (_members findIf {!(_x in _original)} >= 0
            || {_original findIf {alive _x && {group _x != _group}} >= 0}) exitWith {["PARTICIPANTS_CHANGED"] call _finish; false};
        private _combat=(_payload param [0,false,[true]])
            || {(_state getOrDefault ["phase","CALM"]) in ["CONTACT","RETREAT"]};
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        private _generation=_task get "generation";
        if ((_task getOrDefault ["phase",""]) == "PAUSED") exitWith {
            if (_combat || {count _operation > 0}) exitWith {true};
            if (!([-1] call _missionUnchanged)) exitWith {["MISSION_CHANGED"] call _finish; false};
            if ((_state getOrDefault ["phase","CALM"]) != "CALM"
                || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}
                || {!([_members] call _membersAvailable)}) exitWith {true};
            if (!([_group,"PATROL",true,_task get "serverDeadline"] call CBE_fnc_CortexOwnershipLease)) exitWith {true};
            _operation=[_group,"PATROL",(_task get "route") select (_task get "index"),
                _members,_task get "route","MOVING"] call CBE_fnc_OperationStart;
            if (count _operation == 0) exitWith {call _dropLease; true};
            _operation set ["patrolDeadline",_task get "deadline"];
            _group setVariable ["CBE_Operation",_operation,true];
            _task set ["generation",_operation get "generation"];
            if (!(call _startLeg)) exitWith {["RESUME_REFUSED"] call _finish; false};
            true
        };
        if ((_operation getOrDefault ["intent",""]) != "PATROL"
            || {(_operation getOrDefault ["generation",-2]) != _generation}) exitWith {
            ["OPERATION_REPLACED"] call _finish; false
        };
        private _waypoint=_task get "waypoint";
        private _index=_waypoint select 1;
        private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
        if ((_intent getOrDefault ["operationGeneration",-2]) != _generation
            || {(_intent getOrDefault ["waypoint",[]]) isNotEqualTo _waypoint}
            || {([_group,"",false,_index] call CBE_fnc_AuthoredRouteReceipt) isNotEqualTo (_task get "waypointReceipt")}
            || {!([_index] call _missionUnchanged)}) exitWith {["MISSION_CHANGED"] call _finish; false};
        if (_combat) exitWith {
            if (!([_group,_generation,"PATROL_COMBAT_PAUSE"] call CBE_fnc_OperationCancel)) exitWith {
                ["PAUSE_REFUSED"] call _finish; false
            };
            call _dropLease;
            _task set ["phase","PAUSED"];
            ["PAUSED","COMBAT"] call _publish;
            true
        };
        if (!([_members] call _membersAvailable)) exitWith {["PARTICIPANTS_BUSY"] call _finish; false};
        private _point=_task get "destination";
        private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
        private _arrived=!isNull _anchor && {_anchor distance2D _point <= 6}
            && {abs (((getPosATL _anchor) select 2)-(_point select 2)) <= 1.5}
            && {_members findIf {alive _x && {_x distance2D _point > 25
                || {abs (((getPosATL _x) select 2)-(_point select 2)) > 1.5}}} < 0};
        if (!_arrived && {currentWaypoint _group != _index}) exitWith {
            ["NATIVE_ORDER_CHANGED"] call _finish; false
        };
        // A Hunt policy can suggest a bounded fresh-belief route, but only this existing
        // movement owner can commit it after the same native/mission proof above. Retargeting
        // spends the existing current-leg deadline; it cannot renew a retry or task window.
        private _pending=_task getOrDefault ["huntPending",[]];
        if (_pending isNotEqualTo []) exitWith {
            _task deleteAt "huntPending";
            if (time-(_pending select 1) > 120) exitWith {true};
            [_group,_generation] call CBE_fnc_CortexGroupMoveClear;
            if (!([-1] call _missionUnchanged)) exitWith {["MISSION_CHANGED"] call _finish; false};
            private _route=_pending select 0;
            _operation set ["route",_route];
            _group setVariable ["CBE_Operation",_operation,true];
            _task set ["route",_route];
            _task set ["index",0];
            if (!(call _startLeg)) exitWith {["HUNT_LEG_REFUSED"] call _finish; false};
            true
        };
        if (!_arrived) exitWith {true};
        [_group,_generation] call CBE_fnc_CortexGroupMoveClear;
        if (!([-1] call _missionUnchanged)) exitWith {["MISSION_CHANGED"] call _finish; false};
        private _next=(_task get "index")+1;
        if (_next >= count (_task get "route")) exitWith {["CIRCUIT_REACHED",true] call _finish; false};
        _task set ["index",_next];
        _task set ["legDeadline",call _legDeadline];
        if (!(call _startLeg)) exitWith {["LEG_REFUSED"] call _finish; false};
        true
    };
    default {false};
}
};
};
_result
