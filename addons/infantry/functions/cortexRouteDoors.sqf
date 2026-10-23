/*
 * Author: WaldoTheWarfighter
 * Purpose: Let an ordinary authored foot MOVE use nearby unlocked doors without taking its route.
 * Locality/authority: Existing current group-owner tick only; the door helper rechecks actor,
 * plain current MOVE, owner epoch, feature, lock, approach geometry and visibility at animation.
 * Repeat/JIP: Owner-private minimum two-second observation gap at existing tick cadence and rotating sixteen-actor samples across at most64 members.
 * No persistent worker, movement command, route replacement, visit credit or JIP command replay.
 * Arguments: 0 group <GROUP, grpNull>; 1 current group state <HASHMAP, empty>.
 * Return: BOOL - one door opening requested, never routing, access or clearance success.
 * Cost: One3m geometry probe and at most four door visibility rays per sample; no radius query.
 * Current caller: CortexGroupTick CALM without active danger or group movement lease.
 * Example: private _opened=[group soldier1,_state] call CBE_fnc_CortexRouteDoors;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]]];
if (isRemoteExecuted || {isNull _group} || {!local _group}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {[_group] call CBE_fnc_CortexExternalTakeover} || {[_group] call CBE_fnc_CortexZeusHeld}
    || {behaviour leader _group in ["STEALTH","CARELESS"]}
    || {serverTime < (_state getOrDefault ["routeDoorNextAt",-1])}) exitWith {false};
private _index=currentWaypoint _group;
if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
private _waypoint=[_group,_index];
private _statements=waypointStatements _waypoint;
private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
if (waypointType _waypoint != "MOVE" || {_condition != "true"}
    || {((_statements param [1,""]) splitString (toString [32,9,13,10])) isNotEqualTo []}
    || {waypointScript _waypoint != ""} || {(waypointTimeout _waypoint param [2,0]) > 0}
    || {!isNull waypointAttachedVehicle _waypoint} || {!isNull waypointAttachedObject _waypoint}
    || {synchronizedWaypoints _waypoint isNotEqualTo []} || {synchronizedTriggers _waypoint isNotEqualTo []}) exitWith {false};
private _goal=waypointPosition _waypoint;
private _actors=(units _group) select [0,64];
if (_actors isEqualTo []) exitWith {false};
_state set ["routeDoorNextAt",serverTime+2];
private _cursor=(_state getOrDefault ["routeDoorCursor",0]) mod count _actors;
private _sampleCount=(count _actors) min 16;
// Advance even after an empty/nonlocal window; a fixed prefix starves later members.
_state set ["routeDoorCursor",(_cursor+_sampleCount) mod count _actors];
private _selected=objNull;
for "_offset" from 0 to (_sampleCount-1) do {
    private _i=(_cursor+_offset) mod count _actors;private _actor=_actors select _i;
    // Native destination is actor-local evidence; never query a migrating remote member.
    if (!local _actor) then {continue};
    private _target=(expectedDestination _actor) param [0,[],[[]]];
    if (local _actor && {!isPlayer _actor} && {isNull objectParent _actor}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {isNull remoteControlled _actor} && {behaviour _actor != "STEALTH"}
        && {isNull getAttackTarget _actor} && {isNull assignedTarget _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective} && {currentCommand _actor == "MOVE"}
        && {count _target == 3} && {_target vectorDistance _goal <= 3}
        && {[_actor] call CBE_fnc_IndoorActorGroupAvailable}
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}) exitWith {
        _selected=_actor;_state set ["routeDoorCursor",(_i+1) mod count _actors];
    };
};
if (isNull _selected) exitWith {false};
private _context=["ROUTE",_group getVariable ["CBE_AIPass_Epoch",0],_group];
// Radius searches use model centres and miss doors on large structures. Probe
// the actual near approach instead; a proxy may name its House through parentObject.
private _nativeGoal=(expectedDestination _selected) param [0,[],[[]]];
if (count _nativeGoal != 3) exitWith {false};
private _approach=(AGLToASL _nativeGoal) vectorDiff (getPosASL _selected);_approach set [2,0];
private _length=vectorMagnitude _approach;
if (!finite _length || {_length < 0.1}) exitWith {false};
private _eye=eyePos _selected;
private _hits=lineIntersectsSurfaces [_eye,
    _eye vectorAdd (_approach vectorMultiply ((3 min _length)/_length)),
    _selected,objNull,true,1,"GEOM","NONE"];
if (_hits isEqualTo []) exitWith {false};
private _hit=_hits select 0;
private _house=_hit select 2;
if (isNull _house || {!(_house isKindOf "House")}) then {_house=_hit select 3};
if (isNull _house || {!(_house isKindOf "House")}) exitWith {false};
[_selected,_house,_context] call CBE_fnc_CortexBuildingDoor
