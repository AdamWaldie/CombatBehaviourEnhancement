/*
 * Author: WaldoTheWarfighter
 * Gives an unarmed civilian one finite, priority-aware escape response away from nearby danger.
 * Three separated escape headings use the shared bounded terrain selector, then one safe-position
 * adjustment is accepted only when its complete route remains passable. This avoids sending a
 * civilian into water, a cliff or an abrupt grade without installing a continuous path controller.
 * It does not install an FSM, force an animation, reserve a vehicle or continually steer the unit.
 * Player, Zeus, specialist and neutral external-control ownership always takes priority.
 *
 * Locality / Authority: execute where the civilian is local. The reaction marker is public so a
 * locality transfer cannot immediately duplicate the same response.
 * Native tasks, actor reservations and unresolved restoration proof refuse new escape work.
 * The final write rechecks the observed command, destination and authored route atomically.
 * Repeat/JIP: reactions are generation owned and cooldown limited. A stronger danger may replace a
 * weaker active response; duplicate or weaker events cannot churn the route. JIP needs no replay.
 *
 * Arguments:
 * 0: civilian <OBJECT>, default objNull
 * 1: threat <OBJECT or ARRAY position>, default objNull
 * 2: cause <STRING>, default "MANUAL"
 * 3: priority <NUMBER>, default 1
 *
 * Return Value:
 * Boolean - true when a real flee order was issued.
 *
 * Current callers: FiredNear, Explosion and Hit handlers installed by CBE_fnc_CortexCivilianSetup,
 * plus the focused audit endpoint.
 *
 * Example:
 * [_civilian,_shooter] call CBE_fnc_CortexCivilianReact;
 * Result: the civilian runs to a safe point away from the shooter without a polling controller.
 */

params [["_unit",objNull,[objNull]],["_threat",objNull,[objNull,[]]],["_cause","MANUAL",[""]],["_priority",1,[0]]];
if (isNull _unit || {!local _unit} || {!([_unit] call CBE_fnc_CortexCombatEffective)} || {isPlayer _unit}
    || {side group _unit != civilian}
    || {primaryWeapon _unit != "" || {secondaryWeapon _unit != ""} || {handgunWeapon _unit != ""}}
    || {!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])}
    // This reaction is one direct movement order. Yield to the same broad boundary as combat,
    // convoy and aircraft work so an newer external ownership cannot be overwritten between
    // its event observation and this finite escape route.
    || {[group _unit] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _group=group _unit;
if (!local _group || {!simulationEnabled _unit} || {isObjectHidden _unit}
    || {!isNull objectParent _unit} || {!(_unit checkAIFeature "MOVE")} || {!(_unit checkAIFeature "PATH")}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {[_unit] call CBE_fnc_CortexActorMoveReserved}
    || {fleeing _unit}
    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {(_unit getVariable ["CBE_Cortex_CivilianRestorePending",[]]) isNotEqualTo []}) exitWith {false};
private _commandBefore=currentCommand _unit;
private _goalBefore=+(expectedDestination _unit);
private _orderBefore=[_group] call CBE_fnc_NativeOrderReceipt;
private _cooldown=missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Cooldown",20];
private _active=_unit getVariable ["CBE_Cortex_CivilianReaction",[]];
if (_active isNotEqualTo [] && {serverTime < (_active param [0,0,[0]])}
    && {_priority <= (_active param [1,0,[0]])}) exitWith {false};
// Ordinary native MOVE is mission ownership unless this exact active escape still owns its goal.
private _ownMove=_commandBefore == "MOVE" && {count _active == 7}
    && {serverTime < (_active param [0,0,[0]])}
    && {(_active param [2,-1,[0]]) == (_unit getVariable ["CBE_Cortex_CivilianGeneration",-2])}
    && {(_active param [6,[],[[]]]) isEqualTo _orderBefore}
    && {private _goal=_goalBefore param [0,[],[[]]];
        count _goal == 3 && {count (_active param [4,[],[[]]]) == 3}
            && {_goal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {(_active select 4) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_goal distance (_active select 4) <= 6}};
if (!(_commandBefore in ["","WAIT","FOLLOW"]) && {!_ownMove}) exitWith {false};
private _threatPos=if (_threat isEqualType objNull) then {
    if (isNull _threat) then {getPosATL _unit vectorAdd [sin (random 360),cos (random 360),0]} else {getPosATL _threat}
} else {+_threat};
private _origin=getPosATL _unit;
private _away=_origin vectorDiff _threatPos;
_away set [2,0];
if (vectorMagnitude _away < 1) then {_away=[sin (random 360),cos (random 360),0]};
_away=vectorNormalized _away;
private _distance=(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Distance",180])*(0.75+random 0.5);
private _escapeBearing=_origin getDir (_origin vectorAdd _away);
private _routes=[];
{_routes pushBack [[_origin getPos [_distance,_escapeBearing+_x]]]} forEach [0,-45,45];
private _threatObject=if (_threat isEqualType objNull) then {_threat} else {objNull};
private _route=[_origin,_routes,_threatPos,[],_threatObject,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {false};
private _routeDestination=+(_route select 0);
private _safeDestination=[_routeDestination,0,35,3,0,0.35,0,[],[_routeDestination,_routeDestination]] call BIS_fnc_findSafePos;
private _safeRoute=[_origin,[[_safeDestination]],_threatPos,[],_threatObject,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
private _destination=if (_safeRoute isEqualTo []) then {_routeDestination} else {+(_safeRoute select 0)};
private _issued=false;
isNil {
if (!local _unit || {!local _group} || {group _unit != _group}
    || {!simulationEnabled _unit} || {isObjectHidden _unit} || {!isNull objectParent _unit}
    || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {!(_unit checkAIFeature "MOVE")} || {!(_unit checkAIFeature "PATH")}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {[_unit] call CBE_fnc_CortexActorMoveReserved}
    || {fleeing _unit}
    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {(_unit getVariable ["CBE_Cortex_CivilianReaction",[]]) isNotEqualTo _active}
    || {currentCommand _unit != _commandBefore} || {(expectedDestination _unit) isNotEqualTo _goalBefore}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _orderBefore}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {};
private _generation=(_unit getVariable ["CBE_Cortex_CivilianGeneration",0])+1;
private _until=serverTime+(_cooldown max 2);
// A stronger event may replace an active route, but it inherits the values captured before CBE's
// first generation. Otherwise an Explosion replacing FiredNear would "restore" CARELESS/FULL/UP.
private _restore=if (_active isNotEqualTo []) then {
    _active param [5,[behaviour _unit,speedMode group _unit,unitPos _unit],[[]]]
} else {[behaviour _unit,speedMode group _unit,unitPos _unit]};
_unit setVariable ["CBE_Cortex_CivilianGeneration",_generation,true];
_unit setVariable ["CBE_Cortex_CivilianReactionUntil",_until,true];
_unit setVariable ["CBE_Cortex_CivilianReaction",[_until,_priority,_generation,toUpperANSI _cause,_destination,_restore,+_orderBefore],true];
_unit setBehaviour "CARELESS";
_unit setSpeedMode "FULL";
_unit setUnitPos "UP";
_unit doMove _destination;
[CBE_fnc_CortexCivilianStep,createHashMapFromArray [
    ["group",group _unit],["unit",_unit],["generation",_generation],["destination",_destination],
    ["until",_until],["restore",_restore],["nativeOrder",+_orderBefore],["lastPosition",_origin],["lastProgressAt",serverTime],
    ["reissued",false],["subsystem","TACTICS"]
],2,"CBE_CIVILIAN_"+netId _unit] call CBE_fnc_CortexQueueJob;
_issued=true;
};
_issued
