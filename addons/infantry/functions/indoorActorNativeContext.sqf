/*
 * Author: WaldoTheWarfighter
 * Native planner data waits and delayed search retain ownership; no deadline is renewed.
 * Purpose: Classify an actor's native command as a replaceable idle/plain-route leg or a
 * same-contact native approach that must be observed without replaying movement.
 * Locality/authority: Read-only on actor/group owner. Actual engagement identity comes from
 * getAttackTarget; assignedTarget is only a conflicting mission-target veto. No hidden pose reads.
 * Native fleeing, INIT, INITFAILED, PLANNING, REPLAN and DELAY never grant permission to replace a route.
 * Repeat/JIP: Stateless; current waypoint metadata and native command are read each call,
 * Native group-ignored contacts refuse admission; at most one believed-position FIRE visibility query. No exact hostile transform is read.
 * Arguments: actor OBJECT objNull, contact OBJECT objNull, believed ATL ARRAY [], building OBJECT objNull;
 * optional preflight BOOL false checks native task compatibility before building discovery, with no
 * visibility or building geometry query. It requires a contact and returns only [PREFLIGHT],
 * never a movement/observation receipt; full classification is still required by the executor.
 * Return: ARRAY [ISSUE or OBSERVE STRING, native intent STRING, native destination ARRAY,
 * bound native-known contact OBJECT], or [] for protected/unknown context. Metadata is not access proof.
 * Current callers: IndoorActorOperation admission/pre-command validation; IndoorActorDispatch preflight.
 * Example: private _context=[soldier1,enemy1,[100,100,2],house1] call CBE_fnc_IndoorActorNativeContext;
 */
params [["_actor",objNull,[objNull]],["_contact",objNull,[objNull]],
    ["_belief",[],[[]]],["_building",objNull,[objNull]],["_preflight",false,[true]]];
if (isNull _actor || {!local _actor} || {!local group _actor} || {fleeing _actor}) exitWith {[]};
// Queued treatment precedes native HEAL; it forbids investigation admission and new legs.
if ((_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []) exitWith {[]};
if (_preflight && {isNull _contact}) exitWith {[]};
private _vectorValid={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _command=currentCommand _actor;
if !(_command in ["","MOVE","ATTACK","FIRE"]) exitWith {[]};
private _unitState=getUnitState _actor;
if (_unitState in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]) exitWith {[]};
private _engaging=getAttackTarget _actor;
private _assigned=assignedTarget _actor;
if (isNull _contact && {!isNull _engaging || {!isNull _assigned}}) exitWith {[]};
if (!isNull _contact && {(!isNull _engaging && {_engaging != _contact})
    || {!isNull _assigned && {_assigned != _contact}}}) exitWith {[]};
private _contactValid=!isNull _contact && {alive _contact} && {_contact isKindOf "CAManBase"}
    && {!captive _contact} && {!(_contact getVariable ["ace_captives_isSurrendering",false])}
    && {!(_contact getVariable ["ace_captives_isHandcuffed",false])}
    && {isNull objectParent _contact} && {(side group _actor) getFriend (side _contact) < 0.6}
    && {!((_actor targetKnowledge _contact) param [7,false,[true]])}
    && {_actor knowsAbout _contact >= 1} && {_belief call _vectorValid} && {_preflight || {!isNull _building}};
if (!isNull _contact && {!_contactValid}) exitWith {[]};
// A clear believed firing line is a veto on relocation, not proof of a hit or exact enemy pose.
private _nativeFiringClear=false;
if (!_preflight && {_contactValid} && {_engaging == _contact} && {_actor distance2D _belief <= 20}) then {
    _nativeFiringClear=([_actor,"FIRE",_contact] checkVisibility
        [eyePos _actor,(AGLToASL _belief) vectorAdd [0,0,1]]) >= 0.9;
};
if (_nativeFiringClear) exitWith {[]};
private _group=group _actor;
private _index=currentWaypoint _group;
private _authored=_index > 0 && {_index < count waypoints _group};
private _waypoint=[_group,_index];
if (_authored && {waypointType _waypoint != "MOVE" || {waypointScript _waypoint != ""}
    || {waypointDescription _waypoint == "CBE AI PASS"}
    || {(waypointStatements _waypoint) isNotEqualTo ["true",""]}
    || {(waypointTimeout _waypoint) findIf {_x != 0} >= 0}
    || {synchronizedWaypoints _waypoint isNotEqualTo []}
    || {synchronizedTriggers _waypoint isNotEqualTo []}
    || {!isNull waypointAttachedObject _waypoint}
    || {!isNull waypointAttachedVehicle _waypoint}}) exitWith {[]};
private _destination=(expectedDestination _actor) param [0,[],[[]]];
if (!(_destination call _vectorValid)) then {_destination=[]};
// Preserve a native combat approach already aimed into this house. The caller may observe
// progress and use scoped door interaction; this receipt grants no existing-leg cleanup rights.
private _observe=_contactValid && {_engaging == _contact} && {_command in ["MOVE","ATTACK"]}
    && {_destination isNotEqualTo []} && {_destination vectorDistance _belief <= 2.5};
// A matching approach is only a possible observation until actual roof/containment checks.
if (_observe && {_preflight}) exitWith {["PREFLIGHT"]};
if (_observe) then {
    private _bounds=boundingBoxReal _building;
    private _model=_building worldToModel _destination;
    private _low=_bounds select 0; private _high=_bounds select 1;
    _observe=(_model select 0) > (_low select 0) && {(_model select 0) < (_high select 0)}
        && {(_model select 1) > (_low select 1)} && {(_model select 1) < (_high select 1)}
        && {(_model select 2) >= (_low select 2)-0.5} && {(_model select 2) <= (_high select 2)};
};
if (_observe) exitWith {["OBSERVE","COMBAT_APPROACH",+_destination,_engaging]};
// A completed CBE search point can hand its exact native MOVE to the existing indoor FSM.
// Memory authorizes a position-only investigation, never a fresh hostile or arbitrary MOVE.
private _memoryState=_group getVariable ["CBE_AIPass_State",createHashMap];
private _nativeSearchMemory=_memoryState getOrDefault ["searchMemory",[]];
private _searchTransfer=[];
if (isNull _contact && {_command == "MOVE"} && {!isNull _building}
    && {_destination isNotEqualTo []} && {(_memoryState getOrDefault ["phase",""]) == "SEARCH"}
    && {_nativeSearchMemory isEqualType []} && {count _nativeSearchMemory == 4}
    && {(_nativeSearchMemory select 0) isEqualTo _belief}
    && {(_nativeSearchMemory select 3) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {(_nativeSearchMemory select 2) isEqualType 0} && {finite (_nativeSearchMemory select 2)}
    && {serverTime < (_nativeSearchMemory select 2)}
    && {(_nativeSearchMemory select 2) <= (_memoryState getOrDefault ["searchDeadline",-1])}
    && {_actor distance2D _destination <= 2}
    && {abs (((getPosATL _actor) select 2)-(_destination select 2)) <= 1.5}) then {
    private _searchRows=_memoryState getOrDefault ["searchMoveReceipts",[]];
    private _searchRoute=[_group] call CBE_fnc_NativeOrderReceipt;
    if (_searchRows isEqualType [] && {(_searchRows select [0,16]) findIf {
        _x isEqualType [] && {count _x in [3,4]} && {(_x select 0) == _actor}
            && {(_x select 1) isEqualType []} && {count (_x select 1) == 3}
            && {(_x select 1) vectorDistance _destination <= 0.25}
            && {(_x select 2) isEqualTo _searchRoute}
    } >= 0}) then {_searchTransfer=["ISSUE","SEARCH_MEMORY",+_destination,objNull]};
};
if (_searchTransfer isNotEqualTo []) exitWith {_searchTransfer};
if (_unitState == "BUSY") exitWith {[]};
private _mayIssue=_command == "" || {_command in ["ATTACK","FIRE"] && {_contactValid} && {_engaging == _contact}}
    || {_command == "MOVE" && {_authored} && {_destination isNotEqualTo []}
        && {_destination vectorDistance waypointPosition _waypoint <= 3}};
if (!_mayIssue) exitWith {[]};
if (_preflight) exitWith {["PREFLIGHT"]};
private _intent=if (_contactValid && {_command in ["","ATTACK","FIRE"]}) then {"CONTACT"} else {_command};
["ISSUE",_intent,+_destination,[_engaging,_contact] select _contactValid]
