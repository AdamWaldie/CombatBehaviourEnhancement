/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe measured held-leaf travel and current full-hull room behind its parent.
 * Locality/authority: Parent vehicle/group owner only, exact private queue consent. Read-only;
 * this neither advances a dependency nor grants/replays movement. Native issue must resample.
 * Repeat/JIP: Original token/expiry/context only. No cache, state, timer or new lifetime.
 * Arguments: 0 parent OBJECT objNull; 1 agreement HASHMAP empty.
 * Return: ARRAY [clear BOOL, reason STRING, leaf travel m, body gap m, rear envelope ARRAY].
 * No movement target is retained or returned. HELD alone is not evidence of usable room.
 * Cost: At most two shared rear observations and eight hull transforms; no new query type.
 * Current callers: DrivingQueueAgreementOwner CHECK_ROOM and native parent issue in DrivingQueueReverseCommit.
 * Example: private _room=[truck1,_consent] call CBE_fnc_DrivingQueueParentRoom;
 */
params [["_parent",objNull,[objNull]],["_agreement",createHashMap,[createHashMap]]];
private _no={params ["_reason"];[false,_reason,0,-1,[]]};
private _vehicles=_agreement getOrDefault ["vehicles",[]];
private _dependencies=_agreement getOrDefault ["dependencies",[]];
private _context=_agreement getOrDefault ["context",[]];
private _parentIndex=_vehicles find _parent;
private _movingIndex=_agreement getOrDefault ["movingIndex",count _vehicles-1];
private _heldIndices=_agreement getOrDefault ["heldIndices",[]];
private _token=_agreement getOrDefault ["token",""];private _expires=_agreement getOrDefault ["expires",-1];
if (!(_vehicles isEqualType []) || {!(_dependencies isEqualType [])} || {!(_context isEqualType [])}
    || {isNull _parent} || {!local _parent} || {count _vehicles < 3} || {count _vehicles > 4}
    || {count _dependencies != count _vehicles} || {count _context != count _vehicles}
    || {_parentIndex < 1} || {_parentIndex >= count _vehicles-1}
    || {(_dependencies select _parentIndex) != _parentIndex+1}
    || {!(_parentIndex == _movingIndex-1 || {_parentIndex == _movingIndex && {_parentIndex+1 in _heldIndices}})}
    || {(_parent getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isNotEqualTo _agreement}
    || {!([_agreement,true] call CBE_fnc_DrivingQueueReverseCurrent)}) exitWith {["PARENT_CONTEXT"] call _no};
private _leaf=_vehicles select (_parentIndex+1);
private _work=_leaf getVariable ["CBE_DrivingRecovery_Work",createHashMap];
private _leafRow=_context select (_parentIndex+1);
private _identity=[_token,_expires,(_leafRow select 2) select 4,(_leafRow select 2) select 5];
if ((_work getOrDefault ["queueBinding",[]]) isNotEqualTo _identity
    || {(_work getOrDefault ["queuePhase",""]) != "HELD"}
    || {!(_work getOrDefault ["queueStopAcknowledged",false])}
    || {toUpperANSI ((vehicleMoveInfo _leaf) param [0,""]) != "STOP"}
    || {[_parent,_leaf] findIf {
        private _linear=vectorMagnitude velocity _x;private _angular=vectorMagnitude angularVelocity _x;
        !finite _linear || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
    } >= 0}) exitWith {["DEPENDENCY_NOT_HELD"] call _no};
private _origin=_work getOrDefault ["rearOriginASL",[]];
private _direction=_work getOrDefault ["rearDirection",[]];
private _envelope=_work getOrDefault ["rearEnvelope",[]];
private _requirements=_agreement get "rearRequirements";
private _leafRequired=_requirements select (_parentIndex+1);
if (!(_envelope isEqualTo _leafRequired || {_leafRequired isEqualTo [8,6] && {_envelope isEqualTo [3.5,2]}})
    || {[_origin,_direction] findIf {!(_x isEqualType []) || {count _x != 3}
        || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}} >= 0}
    || {abs ((vectorMagnitude _direction)-1) > 0.01}) exitWith {["DEPENDENCY_RECEIPT"] call _no};
private _travel=-(((getPosASL _leaf) vectorDiff _origin) vectorDotProduct _direction);
if (_travel < (_envelope select 1)-0.25) exitWith {[false,"NO_MEASURED_REAR_ROOM",_travel,-1,[]]};
private _axis=vectorDir _parent;private _parentOrigin=getPosWorld _parent;
private _parentHull=[_parent,_parentOrigin,_axis] call CBE_fnc_DrivingHullInterval;
private _leafHull=[_leaf,_parentOrigin,_axis] call CBE_fnc_DrivingHullInterval;
if (_parentHull isEqualTo [] || {_leafHull isEqualTo []}) exitWith {["UNKNOWN_HULL"] call _no};
private _gap=(_parentHull select 0)-(_leafHull select 1);
if (_gap < 3.5) exitWith {[false,"INSUFFICIENT_BODY_GAP",_travel,_gap,[]]};
private _plan=[_parent,[],24,_requirements select _parentIndex] call CBE_fnc_DrivingRearPlan;
private _clear=_plan select 0;private _parentEnvelope=_plan select 1;
if (!(_clear select 0) || {count (_clear param [4,[]]) != 3} || {_gap < (_parentEnvelope select 0)}) exitWith {
    [false,"PARENT_REAR_BLOCKED",_travel,_gap,+_parentEnvelope]
};
if (serverTime >= _expires
    || {(_parent getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isNotEqualTo _agreement}
    || {!([_agreement,true] call CBE_fnc_DrivingQueueReverseCurrent)}) exitWith {["ROOM_OBSERVATION_STALE"] call _no};
[true,"OBSERVED_ONLY",_travel,_gap,+_parentEnvelope]
