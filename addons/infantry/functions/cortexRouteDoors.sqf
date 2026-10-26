/*
 * Author: WaldoTheWarfighter
 * Purpose: Let an ordinary authored foot MOVE use nearby unlocked doors without taking its route.
 * Locality/authority: Existing current group-owner tick only; the door helper rechecks actor,
 * plain current MOVE, owner epoch, feature, lock, approach geometry and visibility at animation.
 * Repeat/JIP: Owner-private minimum two-second observation gap at existing tick cadence and rotating sixteen-actor samples across at most64 members.
 * No persistent worker, movement command, route replacement, visit credit or JIP command replay.
 * Arguments: 0 group <GROUP, grpNull>; 1 current group state <HASHMAP, empty>.
 * Return: BOOL - one door opening requested, never routing, access or clearance success.
 * Cost: At most four3m approach probes and sixteen door visibility rays per callback;
 * stop after one opening request. Existing16-actor/64-member bounds and2s throttle remain.
 * No radius query, extra worker or early/distant door interaction.
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
private _opened=false;private _probes=0;
private _context=["ROUTE",_group getVariable ["CBE_AIPass_Epoch",0],_group];
for "_offset" from 0 to (_sampleCount-1) do {
    if (_probes >= 4) exitWith {};
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
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}) then {
        _probes=_probes+1;
        // Advance after each attempted actor, including empty/blocked approaches.
        _state set ["routeDoorCursor",(_i+1) mod count _actors];
        // Radius searches miss doors on large structures. Probe only the actual
        // near approach; each helper rechecks current native/task/door authority.
        private _approach=(AGLToASL _target) vectorDiff (getPosASL _actor);_approach set [2,0];
        private _length=vectorMagnitude _approach;
        if (!finite _length || {_length < 0.1}) then {continue};
        private _eye=eyePos _actor;
        private _hits=lineIntersectsSurfaces [_eye,
            _eye vectorAdd (_approach vectorMultiply ((3 min _length)/_length)),
            _actor,objNull,true,1,"GEOM","NONE"];
        if (_hits isEqualTo []) then {continue};
        private _hit=_hits select 0;private _house=_hit select 2;
        if (isNull _house || {!(_house isKindOf "House")}) then {_house=_hit select 3};
        if (isNull _house || {!(_house isKindOf "House")}) then {continue};
        _opened=[_actor,_house,_context] call CBE_fnc_CortexBuildingDoor;
    };
    if (_opened) exitWith {};
};
_opened
