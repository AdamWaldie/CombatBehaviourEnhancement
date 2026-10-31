/*
 * Author: WaldoTheWarfighter
 * Purpose: Guide one finite ground search sweep from native enemy belief, with bounded
 * fresh-observation retargeting. Reuses PatrolOperation's existing movement owner/cleanup.
 * Locality/authority: Current group owner, local or inherited authenticated server context;
 * not remotely registered. UPDATE consumes only CortexGroupTick's existing knowledge query.
 * Repeat/JIP: One private hunt policy inside the current patrol task, no second job/record owner.
 * At most four retarget plans, sampled no faster than10s, original task/leg deadlines unchanged.
 * No world target scan, hostile transform read, detection/reveal, flags, lights or free flares.
 * Arguments: 0 mode STRING START|UPDATE|CANCEL; 1 group GROUP,grpNull;
 * 2 payload ARRAY: START [range=800 (50..2000, capped by configured engagement range),
 * duration=900 (30..1800)]; UPDATE native CortexKnowledge records (<=8); CANCEL [].
 * Return: BOOL, accepted start/update/cancel; neither target neutralization nor room clearance.
 * Current callers: CortexGroupTick UPDATE; owner-local script START/CANCEL API.
 * Example: ["START",_group,[800,900]] call CBE_fnc_HuntOperation;
 */
params [["_mode","",[""]],["_group",grpNull,[grpNull]],["_payload",[],[[]]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _group} || {!local _group}) exitWith {false};
private _result=false;
isNil {
_result=call {
private _task=_group getVariable ["CBE_PatrolTask",createHashMap];
private _hunt=_task getOrDefault ["hunt",createHashMap];
_mode=toUpperANSI _mode;
if (_mode == "CANCEL") exitWith {
    if (count _hunt == 0) exitWith {false};
    ["CANCEL",_group,["HUNT_RELEASE"]] call CBE_fnc_PatrolOperation
};
if (!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)) exitWith {false};
if (_mode == "UPDATE" && {count _hunt == 0 || {count _payload > 8}
    || {time < (_hunt get "nextSample")}}) exitWith {false};
private _range=800;
private _duration=900;
private _records=[];
if (_mode == "START") then {
    _payload params [["_requestedRange",800,[0]],["_requestedDuration",900,[0]]];
    if (finite _requestedRange && {_requestedRange >= 50} && {_requestedRange <= 2000}
        && {finite _requestedDuration} && {_requestedDuration >= 30} && {_requestedDuration <= 1800}
        && {count _task == 0}) then {
        _range=_requestedRange min (missionNamespace getVariable ["CBE_AIPass_EngageRange",800]);
        _duration=_requestedDuration;
        _records=([_group,_range] call CBE_fnc_CortexKnowledge) select 0;
    };
} else {
    if (_mode == "UPDATE" && {count _hunt > 0} && {count _payload <= 8}
        && {time >= (_hunt get "nextSample")}) then {
        _hunt set ["nextSample",time+10];
        _range=_hunt get "range";
        _records=_payload;
    };
};
// Belief is an opaque native record: object, believed ATL, observation age, believed
// distance, error and confidence. No live enemy position is substituted for any field.
_records=(_records select [0,8]) select {
    _x isEqualType [] && {count _x == 6} && {(_x select 0) isEqualType objNull}
        && {!isNull (_x select 0)} && {!((_x select 0) isKindOf "Air")}
        && {(_x select 1) isEqualType []} && {count (_x select 1) == 3}
        && {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {(_x select [2,4]) findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} < 0}
        && {(_x select 2) <= 120} && {(_x select 3) <= _range} && {(_x select 5) >= 1}
};
if (_records isEqualTo []) exitWith {
    if (_mode == "UPDATE" && {count _hunt > 0} && {time-(_hunt get "observedAt") > 120}) then {
        ["CANCEL",_group,["HUNT_CONTACT_STALE"]] call CBE_fnc_PatrolOperation;
    };
    false
};
private _record=_records select 0;
if (count _hunt > 0) then {
    private _selected=_records findIf {(_x select 0) == (_hunt get "target")};
    if (_selected >= 0) then {_record=_records select _selected};
};
_record params ["_target","_belief","_age","_distance","_error"];
private _observedAt=time-_age;
private _radius=(_error max 25) min 300;
if (_mode == "START") exitWith {
    if (!(["START",_group,[_belief,_radius,3,_duration]] call CBE_fnc_PatrolOperation)) exitWith {false};
    _task=_group getVariable ["CBE_PatrolTask",createHashMap];
    _hunt=createHashMapFromArray [["target",_target],["range",_range],["observedAt",_observedAt],
        ["plannedTarget",_target],["plannedObservedAt",_observedAt],["plannedPosition",+_belief],["updates",0],["nextSample",time+10]];
    _task set ["hunt",_hunt];
    _group setVariable ["CBE_Hunt_Status",["MOVING","NATIVE_BELIEF",0,serverTime],true];
    true
};
if (_mode != "UPDATE" || {count _hunt == 0}) exitWith {false};
_hunt set ["observedAt",if (_target == (_hunt get "target")) then {
    (_hunt get "observedAt") max _observedAt
} else {_observedAt}];
_hunt set ["target",_target];
// Contact tactics may own actors while the sweep is suspended. Refresh observation age
// only from actual native evidence, but do not plan another leg under that controller.
private _material=_target != (_hunt get "plannedTarget")
    || {_observedAt > (_hunt get "plannedObservedAt")+1
        && {_belief distance2D (_hunt get "plannedPosition") >= 25}};
if ((_task getOrDefault ["phase",""]) != "MOVING"
    || {(_task getOrDefault ["huntPending",[]]) isNotEqualTo []}
    || {!_material}) exitWith {true};
if ((_hunt get "updates") >= 4) exitWith {
    ["CANCEL",_group,["HUNT_UPDATE_LIMIT"]] call CBE_fnc_PatrolOperation;
    false
};
private _route=[_belief,_radius,3] call CBE_fnc_PatrolRoutePlan;
if (_route isEqualTo []) exitWith {false};
_hunt set ["target",_target];
_hunt set ["observedAt",_observedAt];
_hunt set ["plannedTarget",_target];
_hunt set ["plannedObservedAt",_observedAt];
_hunt set ["plannedPosition",+_belief];
_hunt set ["updates",(_hunt get "updates")+1];
_task set ["huntPending",[_route,_observedAt]];
_group setVariable ["CBE_Hunt_Status",["PENDING","FRESH_BELIEF",_hunt get "updates",serverTime],true];
true
};
};
_result
