/*
 * Author: WaldoTheWarfighter
 * Initial active role allocation excludes hidden/simulation-disabled actors without treating them as casualties.
 * Eligible persistent buddies oppose mover/cover roles for synchronised bounds;
 * the fallback fire-team policy keeps buddies together where element capacity permits;
 * minimum mover/cover fire capacity and existing specialist-role preferences take priority.
 * Admission sizes the moving element from ammunition-qualified rifle capacity and retains
 * at least two such cover actors. Exactly two available armed actors may use 1+1
 * successive bounds, preserving their pair identity and limiting each bound to20m.
 * Three available armed actors may start a2+1 advance; the arrived pair covers its
 * singleton follower. Physical squad/cover membership stays separate.
 * Initial role capacity excludes protected native tasks and live actor reservations through
 * the shared task-availability gate; later executor checks remain authoritative.
 * Natural admission preserves native STOP unless exact completed CBE hold provenance permits transfer.
 * Starts a bounding advance: a squad under fire that still has somewhere to go pushes an element
 * forward in covered bounds instead of stalling.
 *
 * Uses bounded fire-team movement so that it cannot freeze or
 * undo itself. An optional CBE_AIPass_Advance_MinContactSeconds delay may be configured, but the
 * default starts as soon as confirmed knowledge and every physical/safety gate permit it. Its
 * current waypoint (MOVE, SAD or DESTROY, not a pass waypoint) must be more than 80 m away, or a squad
 * with no active waypoint must have fresh enemy knowledge that provides a finite contact objective.
 * Fresh foot-contact objectives close to the configured assault band (20..60m), rather than
 * using the authored-waypoint80m completion margin. Actual movers already within25m refuse
 * another approach; the existing close-assault/native layer owns that space.
 * Active HOLD, GUARD, SENTRY and other authored waypoint types are never replaced. The nearest known
 * enemy must be at least 60 m away, morale must be STEADY and no drill may be running.
 * CBE_fnc_CortexTacticalStart prefers this action for a live authored forward order and calls this
 * deterministic viability/start function. A bounded avenue selector compares the
 * direct route with four offset two-leg routes and samples screening once when the drill starts.
 * Two elements advance successively: riflemen
 * move first while the leader/support element covers, then hold while that element closes up.
 * Both elements must physically arrive before the next bound. Movers retain firing permission while the other element covers.
 * Actors completing a short grenade-evasion or anti-armour relocation lease are omitted from both
 * elements rather than having their destination replaced.
 * Group attack assignment remains enabled so the covering element can acquire and share targets;
 * only the current movers receive short, owned pursuit-feature leases in CortexFlankStep.
 * Fully armed4..16-actor elements use synchronised buddy roles, one actor per pair in each
 * element, with <=25m bounds. Other elements retain fire-team allocation. Arrival still uses
 * the existing finite role lifecycle; this is not independently timed pair leapfrog or coordination.
 * Locality and authority: call where the group is local.
 *
 * Each start gives its queued step a unique drill token.
 * Repeat/JIP: a running drill, shared movement lease or cooldown refuses duplicate starts; owner
 * migration retires local jobs. A rolling TACTICAL_DRILL lease makes direct fire-team movement
 * visible to reinforcement, vehicle and artillery behaviours until CortexFlankEnd releases it.
 * The drill heartbeat lets GroupTick restore every owned engine setting if its scheduler job stalls.
 * The latest changed refusal reason is public for diagnostics and is cleared when a drill starts;
 * repeated start checks do not rebroadcast an unchanged reason.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: enemies <ARRAY> - from CBE_fnc_CortexKnowledge
 * 3: optional explicit foot element <ARRAY of OBJECT, max64>. Only that roster supplies
 * movers, cover and replacements. Uses fresh contact rather than a mounted group route;
 * never changes native leadership or creates a group waypoint. Existing FSM owns cleanup.
 *
 * Return Value:
 * Boolean - true when an advance started
 *
 * Example:
 * [_group, _state, _enemies] call CBE_fnc_CortexAdvanceStart;
 * Result: a pinned squad advances two elements successively towards its authored or fresh-contact objective.
 *
 * Support integration: active reinforcement/assault responders decline new drills until released.
 * Current caller: CBE_fnc_CortexTacticalStart.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]], ["_element",[],[[]]]];
private _elementScoped=count _this > 3;
private _refuse={
    params ["_reason",["_detail",[]]];
    private _previous=_group getVariable ["CBE_Cortex_AdvanceRefusal",[]];
    if ((_previous param [0,""]) != _reason) then {
        _group setVariable ["CBE_Cortex_AdvanceRefusal",[_reason,serverTime,_detail],true];
    };
    false
};
if (_elementScoped && {count _element > 64}) exitWith {["ELEMENT_TOO_LARGE"] call _refuse};
// A live support assignment owns group movement until release; do not split its
// responders into a competing local drill when they acquire contact.
if (_state getOrDefault ["responding", false] || {_state getOrDefault ["assaulting", false]}) exitWith {["SUPPORT_OWNS_MOVEMENT"] call _refuse};
private _movementLease = _state getOrDefault ["movementLease",[]];
if (count _movementLease == 2 && {time < (_movementLease select 1)}) exitWith {["MOVEMENT_LEASE",_movementLease] call _refuse};
if (count (_state getOrDefault ["drill", createHashMap]) > 0) exitWith {["DRILL_ACTIVE"] call _refuse};
if ([_state, "advance"] call CBE_fnc_CortexCooldown) exitWith {["COOLDOWN"] call _refuse};
if ((_state getOrDefault ["moraleState", "STEADY"]) != "STEADY") exitWith {["MORALE",[_state getOrDefault ["moraleState","UNKNOWN"]]] call _refuse};
private _contactAge=time-(_state getOrDefault ["phaseStart",time]);
private _minimumContact=missionNamespace getVariable ["CBE_AIPass_Advance_MinContactSeconds", 0];
if (_contactAge < _minimumContact) exitWith {["CONTACT_DELAY",[_contactAge,_minimumContact]] call _refuse};
// Use a local combat-effective anchor so leader loss or reassignment does not suppress an otherwise viable manoeuvre.
private _leader = if (_elementScoped) then {[_group,_element] call CBE_fnc_CortexGroupAnchor}
    else {[_group] call CBE_fnc_CortexGroupAnchor};
if (isNull _leader && {!_elementScoped}) then {_leader=leader _group};
if (isNull _leader) exitWith {["NO_ELEMENT_ANCHOR"] call _refuse};
if (vehicle _leader != _leader) exitWith {["LEADER_MOUNTED"] call _refuse};
if (_enemies isEqualTo []) exitWith {["NO_TARGET"] call _refuse};

private _index = currentWaypoint _group;
private _hasAuthoredObjective = _index < count waypoints _group;
if (_hasAuthoredObjective && {
    waypointDescription [_group, _index] == "CBE AI PASS"
    || {!(waypointType [_group, _index] in ["MOVE", "SAD", "DESTROY"])}
}) exitWith {["AUTHORED_OBJECTIVE_TYPE",[waypointType [_group,_index],waypointDescription [_group,_index]]] call _refuse};
// A landed foot element cannot inherit the boat crew's destination as a ground objective.
// The unchanged authored receipt remains its interruption boundary; use fresh contact only.
if (_elementScoped) then {_hasAuthoredObjective=false};
// Contact-only infantry approach must meet the actual close-assault band. Keeping
// the authored objective's80m completion margin here left a60..80m refusal gap.
// Static/vehicle contacts and authored forward objectives retain their prior limits.
private _target=(_enemies select 0) select 0;
private _contactApproach=!_hasAuthoredObjective && {_target isKindOf "CAManBase"}
    && {isNull objectParent _target};
private _minimumDistance=if (_contactApproach) then {
    ((missionNamespace getVariable ["CBE_AIPass_Assault_Range",80]) min 60) max 20
} else {60};
if (((_enemies select 0) select 3) < _minimumDistance) exitWith {
    ["TARGET_TOO_CLOSE",[(_enemies select 0) select 3,_minimumDistance]] call _refuse
};
// A group whose ordinary movement order has completed should not become inert in a live firefight.
// Use only fresh engine knowledge and keep the objective inside this finite drill; do not manufacture
// a persistent waypoint that would outlive contact or compete with a later Zeus order.
if (!_hasAuthoredObjective && {((_enemies select 0) select 2) > 10}) exitWith {["STALE_CONTACT",[(_enemies select 0) select 2]] call _refuse};
private _objective = if (_hasAuthoredObjective) then {
    waypointPosition [_group, _index]
} else {
    (_enemies select 0) select 1
};
private _objectiveStop=if (_contactApproach) then {_minimumDistance} else {80};
if (_leader distance2D _objective <= _objectiveStop) exitWith {
    ["OBJECTIVE_REACHED",[_leader distance2D _objective,_objectiveStop]] call _refuse
};
private _onFoot = (units _group) select {
    [_x] call CBE_fnc_CortexCombatEffective && {local _x} && {simulationEnabled _x} && {!isObjectHidden _x} && {vehicle _x == _x}
        && {_x checkAIFeature "PATH"} && {_x checkAIFeature "MOVE"}
        && {[_x] call CBE_fnc_CortexActorFireTaskAvailable}
        && {!_elementScoped || {_x in _element}}
        && {currentCommand _x != "STOP" || {[_group,_state,_x] call CBE_fnc_CortexHolderRecallOwned}}
};
private _armedFoot=_onFoot select {unitCombatMode _x in ["YELLOW","RED"]
    && {_x checkAIFeature "FIREWEAPON"} && {[_x] call CBE_fnc_CortexPrimaryAmmoAvailable}};
private _buddyPair=count _onFoot == 2 && {count _armedFoot == 2};
private _smallElement=count _onFoot in [2,3] && {count _armedFoot == count _onFoot};
private _minimumElement=[2,1] select _buddyPair;
private _minimumCover=[2,1] select _smallElement;
private _riflemen = _armedFoot select {_x != _leader && {_buddyPair || {!(([_x] call CBE_fnc_CortexUnitRole) in ["MG", "AT", "LEADER"])}}};
private _candidates = [];
{_candidates pushBack [_x distance2D _objective, _forEachIndex]} forEach _riflemen;
_candidates sort true;
private _size = ((floor (count _armedFoot / 2)) min 5) min count _candidates;
if (_smallElement && {!_buddyPair}) then {_size=2 min count _candidates};
if (_size < _minimumElement) exitWith {[_state, "advance", 30] call CBE_fnc_CortexCooldown; ["NO_MANOEUVRE_ELEMENT",[count _onFoot,count _riflemen]] call _refuse};
private _rankedActors=(_candidates select [0,16]) apply {_riflemen select (_x select 1)};
private _buddyTeams=[];
if (count _onFoot >= 4 && {count _onFoot <= 16} && {count _armedFoot == count _onFoot}) then {
    private _pairs=[_group,_onFoot,false] call CBE_fnc_CombatPairs;
    _buddyTeams=[_group,_rankedActors+(_onFoot-_rankedActors),_pairs] call CBE_fnc_CombatPairElements;
};
private _buddyBounds=_buddyTeams isNotEqualTo [];
private _element=if (_buddyBounds) then {_buddyTeams select 0} else {
    [_group,_rankedActors,_size,_minimumElement] call CBE_fnc_CombatElementSelect
};
if (count _element < _minimumElement) exitWith {["NO_MANOEUVRE_ELEMENT",[count _element]] call _refuse};
private _coverElement = if (_buddyBounds) then {_buddyTeams select 1} else {_onFoot - _element};
private _coverRifles=_armedFoot-_element;
if (count _coverRifles < _minimumCover) exitWith {["NO_COVER_ELEMENT",[count _coverElement,count _coverRifles]] call _refuse};
private _start = [0, 0, 0];
{_start = _start vectorAdd getPosATL _x} forEach _element;
_start = _start vectorMultiply (1 / count _element);
private _bound = (missionNamespace getVariable ["CBE_AIPass_Flank_BoundDistance", 55]) max 15;
if (_smallElement) then {_bound=_bound min 20};
if (_buddyBounds) then {_bound=_bound min 25};
private _travel=(_start distance2D _objective)-20;
// A dispersed group can have its mover centroid already near the contact while
// the leader is farther away. A negative getPos distance would send those actors backwards.
if (_travel < 5) exitWith {["OBJECTIVE_REACHED",[_travel,"MOVER_ELEMENT_CLOSE"]] call _refuse};
private _goal = _start getPos [_travel min (_bound * 3), _start getDir _objective];
private _routeDistance=_start distance2D _goal;
private _axis=_start getDir _goal;
private _midDistance=_routeDistance*0.55;
private _offset=((_routeDistance*0.25) max 20) min 55;
private _candidateRoutes=[[_goal]];
{
    private _screen=(_start getPos [_midDistance,_axis]) getPos [_offset,_axis+_x];
    _candidateRoutes pushBack [_screen,_goal];
} forEach [90,-90,55,-55];
private _legs=[_start,_candidateRoutes,(_enemies select 0) select 1,[],(_enemies select 0) select 0]
    call CBE_fnc_CortexSelectAvenue;
if (_legs isEqualTo []) exitWith {[_state, "advance", 30] call CBE_fnc_CortexCooldown; ["NO_SAFE_AVENUE",[_start,_objective]] call _refuse};
private _points = [_start, _legs, "FINAL", _group,if (_smallElement) then {20} else {[0,25] select _buddyBounds}] call CBE_fnc_CortexPlanRoute;
// Do not suppress the whole squad's attack assignment. CortexFlankStep protects only
// the current moving element while the paired element continues native engagement.
private _serial = (missionNamespace getVariable ["CBE_Cortex_DrillSerial",0]) + 1;
missionNamespace setVariable ["CBE_Cortex_DrillSerial",_serial];
private _token = format ["%1:%2",clientOwner,_serial];
_group setVariable ["CBE_Cortex_DrillResult",[],true];
_group setVariable ["CBE_Cortex_DrillFailure",[],true];
_group setVariable ["CBE_Cortex_DrillReinforcements",[],true];
_state set ["drill", createHashMapFromArray [
    ["token",_token],["target",(_enemies select 0) select 0],
    ["teams",[_element,_coverElement]],["teamSizes",[count _element,count _coverElement]],["teamTurn",0],
    ["type", "ADVANCE"],["buddyBounds",_buddyBounds], ["units", _onFoot],
    ["elementScoped",_elementScoped],["elementRoster",if (_elementScoped) then {+_element} else {[]}], ["desiredStrength",count _onFoot], ["points", _points], ["index", 0], ["stage", ""],
    ["enemyPos", (_enemies select 0) select 1], ["disabled", []], ["spots", []], ["started", time], ["lastStep",time],
    ["boundStart", time], ["pauseUntil", 0]
]];
if !([_group,"TACTICAL_DRILL",true,serverTime+90] call CBE_fnc_CortexOwnershipLease) exitWith {
    _state deleteAt "drill";
    ["EXTERNAL_MOVEMENT_BUSY"] call _refuse
};
// Buddy bounds retain pair identity across mover/cover roles, not inside role partitions.
private _pairElements=if (_buddyPair || {_buddyBounds}) then {[]} else {[_element,_coverElement]};
private _operation=[_group,"ADVANCE",(_enemies select 0) select 0,_onFoot,_points apply {_x select 0},"MANOEUVRE",_pairElements] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"TACTICAL_DRILL",false] call CBE_fnc_CortexOwnershipLease;
    _state deleteAt "drill";
    ["OPERATION_OWNER_LOST"] call _refuse
};
(_state get "drill") set ["operationGeneration",_operation get "generation"];
(_state get "drill") set ["ownerEpoch",_operation get "ownerEpoch"];
(_state get "drill") set ["nativeAdmissionChecked",true];
[_group,_state get "drill","START","ADVANCE_ACCEPTED"] call CBE_fnc_CortexDrillSetStage;
_group setVariable ["CBE_Cortex_AdvanceRefusal",nil,true];
// Direct fire-team bounds are a group movement owner even though they do not
// create a CBE waypoint. Other behaviours must wait until CortexFlankEnd releases it.
_state set ["movementLease",["TACTICAL_DRILL",time+90]];
if !([_group,_token] call CBE_fnc_CortexDrillStart) exitWith {false};
if (missionNamespace getVariable ["CBE_AIPass_Debug", false]) then {
    diag_log format ["[CBE] %1 ADVANCE element=%2 points=%3", _group, count _element, count _points];
};
true
