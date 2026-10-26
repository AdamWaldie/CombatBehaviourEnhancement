/*
 * Author: WaldoTheWarfighter
 * Native planner data waits and delayed search preserve existing intent and original budgets.
 * Purpose: Commits one short terrain-screened reposition when the current contact cannot support a useful assault, flank or advance.
 * Locality / Authority: Runs only on the current group owner after normal CBE eligibility checks. Zeus, players, authored HOLD/SENTRY orders, specialist owners and newer CBE operations take precedence.
 * A routine group-waypoint fallback yields to any live or malformed actor reservation;
 * native planning and protected native tasks also defer the group waypoint;
 * the earlier close-armour withdrawal retains survival priority. Other native/fire and
 * independently scoped manoeuvre paths remain available to unreserved actors.
 * Elevated-contact firing endpoints require a terrain- and FIRE-geometry-clear standing-height
 * ray to the recorded belief, never the target's live pose. Screened approach remains preferred.
 * Any cover-adjusted endpoint is revalidated through the same terrain/lane selector before use;
 * elevated firing relocation also retains its outbound ray. No endpoint proves native access,
 * squad-wide firing arcs, stance quality or future clearance. At most four initial firing rays
 * and one cover-candidate ray are added per elevated plan, not per actor or scheduler tick.
 * Repeat/JIP: One operation generation owns one waypoint. A public cooldown prevents route churn; locality migration retires the old generation and never replays its command blindly.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: ordered known enemies <ARRAY>; 3: selected target index <NUMBER, default 0>; 4: assessment reason <STRING>.
 * Return Value: Boolean - true only when a physical reposition or close-threat withdrawal started.
 * Current callers: CBE_fnc_CortexTacticalStart.
 * Example: private _started=[group player,_state,_contacts,0,"ARMOUR_OVERMATCH"] call CBE_fnc_CortexTacticalReposition;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_state",createHashMap,[createHashMap]],
    ["_enemies",[],[[]]],
    ["_targetIndex",0,[0]],
    ["_reason","NO_SAFE_MANOEUVRE",[""]]
];
if (isNull _group || {!local _group} || {_enemies isEqualTo []}
    || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
if (count (_state getOrDefault ["drill",createHashMap]) > 0
    || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}) exitWith {false};

// This is an infantry group destination, not a substitute vehicle escape controller.
if ((units _group) findIf {alive _x && {!isNull objectParent _x}} >= 0) exitWith {false};
private _leader=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
if (isNull _leader || {!alive _leader}) exitWith {false};
_targetIndex=(_targetIndex max 0) min ((count _enemies)-1);
private _record=_enemies select _targetIndex;
private _target=_record param [0,objNull,[objNull]];
private _threatPos=_record param [1,[],[[]]];
if (!isNull _target && {!alive _target || {captive _target}
    || {_target getVariable ["ace_captives_isSurrendering",false]}
    || {_target getVariable ["ace_captives_isHandcuffed",false]}
    || {(side _group) getFriend (side _target) >= 0.6}}) exitWith {false};
if (count _threatPos < 2 && {!isNull _target} && {_leader knowsAbout _target > 0}) then {
    // Missing shared geometry cannot grant an exact live target position. Native belief is
    // sufficient for a screened reposition; absent belief leaves ordinary combat authoritative.
    _threatPos=_leader getHideFrom (vehicle _target);
};
if (!(count _threatPos in [2,3]) || {_threatPos findIf {!(_x isEqualType 0)} >= 0}
    || {_threatPos isEqualTo [0,0,0]}) exitWith {false};
private _cooldown=_group getVariable ["CBE_Cortex_TacticalRepositionCooldown",[]];
if (count _cooldown == 3 && {time < (_cooldown select 0)}
    && {(_cooldown select 1) == _reason} && {(_cooldown select 2) isEqualTo _target}) exitWith {false};

private _origin=getPosATL _leader;
private _distance=_origin distance2D _threatPos;
// At hand-grenade distance from protected armour, remaining in place is not a credible option.
// Use the existing finite withdrawal controller; at all other ranges retain the engagement and
// make only a short screened positional improvement.
if (_reason == "ARMOUR_OVERMATCH" && {_distance <= 120}) exitWith {
    _state set ["enemyPos",+_threatPos];
    _state set ["withdrawReason","CLOSE_ARMOUR_OVERMATCH"];
    private _withdrawing=[_group,_state] call CBE_fnc_CortexRetreat;
    if (_withdrawing) then {
        _group setVariable ["CBE_Cortex_TacticalReposition",["WITHDRAW",_reason,_target,serverTime],true];
    };
    _withdrawing
};

// This fallback writes a group-wide waypoint. It cannot reserve only the remaining
// actors, so preserve finite actor work rather than stealing a grenade/AT/indoor leg.
// Initialization/data wait, planning and delayed re-search remain native path work. Preserve them
// before this routine fallback spends geometry or acquires a group movement lease.
// The close-armour withdrawal above retains its urgent survival priority.
if ((units _group) findIf {alive _x && {getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]
    || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}}} >= 0) exitWith {false};
private _toward=_origin getDir _threatPos;
private _away=_threatPos getDir _origin;
private _range=switch (_reason) do {
    case "ELEVATED_FIRE_POSITION": {45};
    case "AIR_OVERMATCH": {50};
    case "INSUFFICIENT_FIREPOWER": {30};
    case "MORALE_SHAKEN": {30};
    default {40};
};
private _headings=switch (_reason) do {
    case "ELEVATED_FIRE_POSITION": {[_toward+90,_toward-90,_away+45,_away-45]};
    case "AIR_OVERMATCH": {[_toward+90,_toward-90,_away+45,_away-45,_away]};
    case "INSUFFICIENT_FIREPOWER": {[_away+45,_away-45,_toward+90,_toward-90]};
    case "MORALE_SHAKEN": {[_toward+90,_toward-90,_away+45,_away-45]};
    default {[_away+35,_away-35,_toward+90,_toward-90,_away]};
};
private _candidates=[];
{
    private _intermediate=_origin getPos [_range*0.55,_x];
    private _goal=_origin getPos [_range,_x];
    _candidates pushBack [_intermediate,_goal];
} forEach _headings;
// A firing-position request cannot finish merely because the approach is screened.
// Observe the supplied belief point; reading a hidden target's current pose would disclose it.
private _needsFiringLane=_reason == "ELEVATED_FIRE_POSITION";
private _firingTargetASL=(AGLToASL [_threatPos select 0,_threatPos select 1,_threatPos param [2,0]]) vectorAdd [0,0,1.6];
private _firingLane={
    params ["_firingPoint"];
    private _firingOriginASL=(AGLToASL _firingPoint) vectorAdd [0,0,1.6];
    !terrainIntersectASL [_firingOriginASL,_firingTargetASL]
        && {(lineIntersectsSurfaces [_firingOriginASL,_firingTargetASL,_leader,_target,true,1,"FIRE","GEOM"]) isEqualTo []}
};
if (_needsFiringLane) then {
    _candidates=_candidates select {[_x select -1] call _firingLane};
};
private _route=[_origin,_candidates,_threatPos,[],_target,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {
    _group setVariable ["CBE_Cortex_TacticalReposition",["BLOCKED",_reason,_target,serverTime],true];
    _group setVariable ["CBE_Cortex_TacticalRepositionCooldown",[time+12,_reason,_target]];
    false
};
private _goal=+(_route select -1);
private _cover=[_goal,_threatPos,18,[],_group] call CBE_fnc_CortexFindCover;
if (_cover param [1,false,[false]]) then {
    private _coveredGoal=+(_cover select 0);
    if (!_needsFiringLane || {[_coveredGoal] call _firingLane}) then {
        // A nearby cover point can cross a ditch, steep ground or a protected lane.
        // Preserve the already validated route when that adjusted route is refused.
        private _coveredRoute=+_route;
        _coveredRoute set [(count _coveredRoute)-1,_coveredGoal];
        private _validatedCover=[_origin,[_coveredRoute],_threatPos,[],_target,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
        if (_validatedCover isNotEqualTo []) then {
            _route=_validatedCover;
            _goal=+(_route select -1);
        };
    };
};

if !([_group,"TACTICAL_REPOSITION",true,serverTime+30] call CBE_fnc_CortexOwnershipLease) exitWith {false};
private _participants=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {isNull objectParent _x}
        && {lifeState _x != "INCAPACITATED"}
};
private _objective=[_target,_threatPos] select isNull _target;
private _operation=[_group,"REPOSITION",_objective,_participants,_route,"MOVING"] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"TACTICAL_REPOSITION",false] call CBE_fnc_CortexOwnershipLease;
    false
};
private _generation=_operation get "generation";
private _waypoint=[_group,_route select 0,6,"MOVE",_generation] call CBE_fnc_CortexGroupMove;
if (isNull (_waypoint param [0,grpNull,[grpNull]]) || {(_waypoint param [1,-1,[0]]) < 0}) exitWith {
    // A native service task or newer owner can reject movement at the final boundary.
    // No waypoint means no started reposition: retire its exact operation and reservation now.
    [_group,_generation,"INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
    [_group,"TACTICAL_REPOSITION",false] call CBE_fnc_CortexOwnershipLease;
    _group setVariable ["CBE_Cortex_TacticalReposition",["BLOCKED",_reason,_target,serverTime],true];
    _group setVariable ["CBE_Cortex_TacticalRepositionCooldown",[time+12,_reason,_target]];
    false
};
_state set ["tacticalRepositionOperationGeneration",_generation];
_state set ["tacticalRepositionLeg",0];
_state set ["movementLease",["TACTICAL_REPOSITION",time+30]];
_group setVariable ["CBE_Cortex_TacticalReposition",[
    "MOVING",_reason,_target,serverTime,+_origin,+_goal,+_route,_generation
],true];
_group setVariable ["CBE_Cortex_TacticalRepositionCooldown",[time+75,_reason,_target]];
true
