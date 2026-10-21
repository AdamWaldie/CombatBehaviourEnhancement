/*
 * Author: WaldoTheWarfighter
 * Purpose: Commits one CBE-owned temporary waypoint without replacing it again while the
 * requested destination, radius and mode remain materially the same. This avoids command churn
 * that makes an engine group stop, turn around or continuously re-form.
 * Locality/authority: Call on the current group owner. The function exits without issuing a
 * command if the group is not local or has become ineligible; addWaypoint and setCurrentWaypoint
 * must remain owner-local. A protected native task on a living member blocks a new group waypoint,
 * because a group waypoint cannot exclude that actor; independent actor operations remain available. The shared gate prevents delayed callbacks from adding a CBE route after
 * Zeus, a player, or an external controller has taken ownership.
 * Native fleeing and queued ACE treatment block route adoption/replacement; group waypoints
 * cannot exclude those actors. This does not change morale or independently eligible actor work.
 * Crewed ground platforms retain native BACK/direct-commander input and simple LEFT/RIGHT turns.
 * Existing admission/commit scans inspect each distinct platform once per boundary.
 * Native policy edits relinquish route ownership, including scripts, forced behaviour and attachments.
 * Repeat/JIP: The public intent record survives locality transfer. The new owner can reuse a
 * still-valid waypoint instead of injecting a duplicate. A materially changed request replaces
 * only the existing CBE waypoint; authored mission and Zeus waypoints are never removed.
 *
 * An inserted waypoint uses normal engine movement: the group moves in formation, and when it completes the waypoint it carries on with
 * its own patrol or task waypoints. CBE pass waypoints retain the CBE description marker so
 * existing saved operations and validation can identify them; the owning intent record is the
 * authoritative removal scope. Only one CBE pass waypoint exists per group at a time.
 *
 * Arguments:
 * 0: group <GROUP>
 * 1: position <ARRAY> - two or three numeric ATL coordinates; omitted height defaults to zero
 * 2: completion radius <NUMBER> - metres (optional, default: 25)
 * 3: type <STRING> - waypoint type, MOVE or SAD (optional, default: "MOVE")
 * 4: operation generation <NUMBER> - matching operation identity, -1 captures the current operation
 *    once. Mismatched generation/epoch refuses at adoption and atomic waypoint commit.
 *
 * Return Value:
 * Array - the waypoint [group, index], or [grpNull,-1] when refused before movement
 *
 * Example:
 * [_group, _rallyPoint] call CBE_fnc_CortexGroupMove;
 * Result: the group moves to the rally point, then resumes its own waypoints.
 *
 * Current callers: retreat, reinforcement, coordinated assault, investigation, vehicle withdrawal and
 * standoff, and shoot-and-scoot.
 */

params [["_group", grpNull, [grpNull]], ["_position", [], [[]]], ["_radius", 25, [0]], ["_type", "MOVE", [""]], ["_operationGeneration", -1, [0]]];
if (isNull _group || {!local _group} || {!(count _position in [2,3])}
    || {_position findIf {!(_x isEqualType 0)} >= 0}
    || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}) exitWith {[grpNull, -1]};
// A vehicle-specific driving controller need not own every actor in its crew group.
// A group waypoint still affects that vehicle. Declared driving owners and native ground input
// veto route adoption/insertion without disabling sensing, firing or independent actor domains.
private _vehicleDrivingBusy={
    private _movementMembers=units _group;
    private _seenVehicles=[];
    _movementMembers findIf {
        private _vehicle=objectParent _x;
        !isNull _vehicle && {!(_vehicle in _seenVehicles)}
            && {driver _vehicle in _movementMembers || {effectiveCommander _vehicle in _movementMembers}}
            && {
                _seenVehicles pushBack _vehicle;
                if (!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}) exitWith {true};
                if (!(_vehicle isKindOf "LandVehicle") || {_vehicle isKindOf "StaticWeapon"}) exitWith {false};
                private _input=vehicleMoveInfo _vehicle;
                toUpperANSI (_input param [0,"",[""]]) in ["BACK","DIRECTBYCOMANDER"]
                    || {toUpperANSI (_input param [1,"",[""]]) in ["LEFT","RIGHT"]}
            }
    } >= 0
};
if (call _vehicleDrivingBusy) exitWith {[grpNull,-1]};
// Establish the owner epoch before committing an unscoped route on a newly spawned
// group. Later periodic discovery must not treat this active route as pre-adoption work.
if !(_group getVariable ["CBE_AIPass_Adopted",false]) then {
    [_group,true] call CBE_fnc_CortexLocality;
};
if (!local _group || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}) exitWith {[grpNull,-1]};
// A group-wide route cannot preserve an individual boarding, treatment or supply command.
// Do not convert that native task into MOVE, even when the group's general eligibility is valid.
// This does not disable sensing, firing or independently eligible actor-level operations.
private _nativeTaskBusy={ (units _group) findIf {
    alive _x && {fleeing _x || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
        || {toUpperANSI (currentCommand _x) in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}}
} >= 0 };
if (call _nativeTaskBusy) exitWith {[grpNull,-1]};
// Callers do not need to thread an operation token through every tactical helper. When a common
// operation is active, bind this route to its current generation automatically; ordinary mission
// support moves remain intentionally unscoped.
if (_operationGeneration < 0) then {
    _operationGeneration=(_group getVariable ["CBE_Operation",createHashMap]) getOrDefault ["generation",-1];
};

private _entryEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _generationCurrent={
    private _live=_group getVariable ["CBE_Operation",createHashMap];
    local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {if (_operationGeneration >= 0) then {
            (_live getOrDefault ["generation",-2]) == _operationGeneration
                && {(_live getOrDefault ["ownerEpoch",-1]) == _entryEpoch}
                && {(_live getOrDefault ["phase",""]) != "CANCELLED"}
        } else {count _live == 0}}
};
if !(call _generationCurrent) exitWith {[grpNull,-1]};
private _desired = +_position;
if (count _desired == 2) then {_desired pushBack 0};
_desired resize 3;
_radius = _radius max 1;
_type = toUpper _type;
private _intent = _group getVariable ["CBE_Cortex_GroupMoveIntent", createHashMap];
private _previousWaypoint = _intent getOrDefault ["waypoint", []];
private _previousPosition = _intent getOrDefault ["position", []];
private _previousRadius = _intent getOrDefault ["radius", -1];
private _previousType = _intent getOrDefault ["type", ""];
private _hasOwnedWaypoint = count _previousWaypoint == 2
    && {(_previousWaypoint select 0) isEqualTo _group}
    && {(_previousWaypoint select 1) >= 0}
    && {(_previousWaypoint select 1) < count waypoints _group}
    && {waypointDescription _previousWaypoint == "CBE AI PASS"};

// Compare all non-geometric authored semantics, including statements and attachments, without
// executing any script. Unscheduled calls share this observation; scheduled callers re-read at
// the mutation boundary. Geometry keeps its existing engine-adjustment tolerances below.
private _readPolicy={
    private _rows=[_group,"",false,_previousWaypoint select 1] call CBE_fnc_AuthoredRouteReceipt;
    private _row=_rows param [0,[]];
    if (count _row < 7) exitWith {[]};
    [_row select 3,_row select [6]]
};
// Capture the entry execution context: isNil mutation blocks themselves cannot suspend.
private _scheduledPolicy=canSuspend;
private _previousPolicy=_intent getOrDefault ["nativePolicy",[]];
private _observedPolicy=if (_hasOwnedWaypoint) then {call _readPolicy} else {[]};
private _policyUnchanged={
    private _currentPolicy=if (_scheduledPolicy) then {call _readPolicy} else {_observedPolicy};
    _previousPolicy isNotEqualTo [] && {_currentPolicy isEqualTo _previousPolicy}
};

// The internal description is not sufficient ownership proof: Zeus or mission code can
// edit an existing CBE waypoint without changing its label. Treat that edit as a newer order
// before adopting this route or inserting another waypoint ahead of it.
if (_hasOwnedWaypoint && {!(call _policyUnchanged)
    || {count _previousPosition < 2}
    || {waypointPosition _previousWaypoint distance2D _previousPosition > 1}
    || {abs (((waypointPosition _previousWaypoint) param [2,0])-(_previousPosition param [2,0])) > 1.5}
    || {waypointType _previousWaypoint != _previousType}
    || {abs (waypointCompletionRadius _previousWaypoint-_previousRadius) > 0.1}}) exitWith {
    isNil {
        if (call _generationCurrent
            && {(_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap]) isEqualTo _intent}) then {
            [_group,true,_previousWaypoint select 1] call CBE_fnc_CortexZeusMark;
        };
    };
    [grpNull,-1]
};

// Re-read native waypoint fields inside the command boundary. The public intent map alone
// cannot detect an editor/Zeus edit that retains the original description and array identity.
private _routeUnchanged={
    (_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap]) isEqualTo _intent
        && {!_hasOwnedWaypoint || {
            (_previousWaypoint select 1) < count waypoints _group
                && {waypointDescription _previousWaypoint == "CBE AI PASS"}
                && {call _policyUnchanged}
                && {waypointPosition _previousWaypoint distance2D _previousPosition <= 1}
                && {abs (((waypointPosition _previousWaypoint) param [2,0])-(_previousPosition param [2,0])) <= 1.5}
                && {waypointType _previousWaypoint == _previousType}
                && {abs (waypointCompletionRadius _previousWaypoint-_previousRadius) <= 0.1}
        }}
};

// Keep an established engine route until a meaningful tactical change. Position drift inside the
// current completion radius and a small retask tolerance cannot justify a new waypoint.
private _sameDestination = count _previousPosition >= 2
    && {_desired distance2D _previousPosition <= ((_radius max _previousRadius) min 15)}
    && {abs ((_desired param [2,0])-(_previousPosition param [2,0])) <= 1.5};
private _sameRequest = _hasOwnedWaypoint
    && {_sameDestination}
    && {abs (_radius - _previousRadius) <= 2}
    && {_type == _previousType};
if (_sameRequest) exitWith {
    private _adopted=[grpNull,-1];
    isNil {
    if (call _generationCurrent && {!([_group] call CBE_fnc_CortexExternalTakeover)}
        && {!(call _vehicleDrivingBusy)} && {!(call _nativeTaskBusy)}
        && {call _routeUnchanged}) then {
    // A new operation may adopt the same committed route. Keep native movement uninterrupted,
    // but bind cleanup to its current generation; an unscoped old token otherwise survives cancel.
    if ((_intent getOrDefault ["operationGeneration",-1]) != _operationGeneration) then {
        _intent set ["operationGeneration",_operationGeneration];
        _group setVariable ["CBE_Cortex_GroupMoveIntent",_intent,true];
    };
    _adopted=_previousWaypoint;
    };
    };
    _adopted
};
// A curator, player or specialist can take the group after the earlier eligibility gate but before
// the waypoint write. Recheck at the mutation boundary so no delayed CBE route is inserted over it.
private _committed=[grpNull,-1];
isNil {
_committed=call {
if (!(call _generationCurrent) || {[_group] call CBE_fnc_CortexExternalTakeover} || {call _vehicleDrivingBusy}
    || {call _nativeTaskBusy} || {!(call _routeUnchanged)}) exitWith {[grpNull, -1]};
[_group] call CBE_fnc_CortexGroupMoveClear;
if (!(call _generationCurrent) || {[_group] call CBE_fnc_CortexExternalTakeover} || {call _vehicleDrivingBusy}
    || {call _nativeTaskBusy}) exitWith {[grpNull, -1]};
// Radius-zero placement may be adjusted by the engine. Explicit elevated destinations need
// exact ASL placement; ordinary ground routes retain native safe placement.
private _elevated=abs (_desired select 2) > 1.5;
private _placement=[_desired,ATLToASL _desired] select _elevated;
private _placementRadius=[0,-1] select _elevated;
private _waypoint = _group addWaypoint [_placement, _placementRadius, currentWaypoint _group];
_waypoint setWaypointType _type;
_waypoint setWaypointCompletionRadius _radius;
_waypoint setWaypointDescription "CBE AI PASS";
_group setCurrentWaypoint _waypoint;
private _committedRows=[_group,"",false,_waypoint select 1] call CBE_fnc_AuthoredRouteReceipt;
private _committedRow=_committedRows select 0;
_group setVariable ["CBE_Cortex_GroupMoveIntent", createHashMapFromArray [
    ["waypoint", _waypoint],
    ["nativePolicy",[_committedRow select 3,_committedRow select [6]]],
    ["position", waypointPosition _waypoint],
    ["requestedPosition", _desired],
    ["radius", _radius],
    ["type", _type],
    ["issuedAt", serverTime],
    ["operationGeneration", _operationGeneration]
], true];
_waypoint
};
};
_committed
