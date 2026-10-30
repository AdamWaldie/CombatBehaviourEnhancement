/*
 * Author: WaldoTheWarfighter
 * Purpose: Finite cautious foot approach to recent native ground-contact belief. Creep uses
 * PatrolOperation's existing waypoint owner with temporary limited pace and self-defence ROE.
 * Locality/authority: Current group owner or inherited authenticated server task context.
 * No hostile live position, reveal, attack order, per-actor movement, posture or formation write.
 * Repeat/JIP: One policy in the original patrol task, no new worker. Three approach legs,
 * <=4 material replans sampled >=10s apart, original30..300s task and leg clocks unchanged.
 * Recent actual nearby fire/hit/suppression interrupts; detection alone does not. Stand-off
 * releases original policies for native/contact decisions, never grants permission to fire.
 * Cleanup is PatrolOperation/OperationRestore plus CreepPolicy's finite owner retirement.
 * Arguments: 0 mode STRING START/STEP/UPDATE/CANCEL; 1 group GROUP,grpNull;
 * 2 payload ARRAY: START [knowledge range=800 (50..2000),duration=180 (30..300)],
 * STEP [] uses already-recorded native danger; UPDATE existing CortexKnowledge records <=8;
 * CANCEL [] releases only Creep. Foot/vehicle stand-offs40/150m plus belief uncertainty.
 * Return: BOOL task admitted/retained; not combat success, concealed travel or physical safety.
 * Current callers: CortexGroupTick, CortexOrderLocal, owner-local scripts.
 * Example: ["START",_group,[800,180]] call CBE_fnc_CreepOperation;
 */
params [["_mode","",[""]],["_group",grpNull,[grpNull]],["_payload",[],[[]]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _group} || {!local _group}) exitWith {false};
private _result=false;
isNil {
_result=call {
_mode=toUpperANSI _mode;
private _task=_group getVariable ["CBE_PatrolTask",createHashMap];
private _creep=_task getOrDefault ["creep",createHashMap];
private _cancel={params ["_reason"];["CANCEL",_group,[_reason]] call CBE_fnc_PatrolOperation;false};
if (_mode == "CANCEL") exitWith {
    if (count _creep == 0) exitWith {false};
    ["CANCEL",_group,["CREEP_RELEASE"]] call CBE_fnc_PatrolOperation
};
if (!(_mode in ["START","STEP","UPDATE"])) exitWith {false};
if (!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)) exitWith {
    if (count _creep > 0) then {["CREEP_DISABLED"] call _cancel};false
};
if (_mode != "START" && {count _creep == 0}) exitWith {false};
private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _anchor) exitWith {if (count _creep > 0) then {["NO_ANCHOR"] call _cancel};false};
private _origin=getPosATL _anchor;
private _compromised=(units _group) findIf {alive _x && {getSuppression _x > 0.2}} >= 0;
private _danger=_group getVariable ["CBE_Danger_Response",[]];
if (count _danger == 5 && {(_danger select 4) == (_group getVariable ["CBE_Danger_Generation",-1])}
    && {time < (_danger select 3)} && {(_danger select 0) in ["HIT","SUPPRESSED","EXPLOSION","GUNFIRE"]}
    && {(_danger select 1) distance2D _origin <= 80}) then {_compromised=true};
if (_compromised) exitWith {
    if (count _creep > 0) then {["CREEP_COMPROMISED"] call _cancel};false
};
if (_mode == "STEP") exitWith {
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    if (time-(_creep get "observedAt") > 45) exitWith {["CREEP_CONTACT_STALE"] call _cancel};
    if ((["CHECK",_group,_operation] call CBE_fnc_CreepPolicy) != "OWNED") exitWith {
        ["CREEP_POLICY_CHANGED"] call _cancel
    };
    if (_origin distance2D (_creep get "belief") <= (_creep get "standOff")+(_creep get "error")+8) exitWith {
        ["CREEP_STANDOFF_REACHED"] call _cancel
    };
    ["STEP",_group,[false]] call CBE_fnc_PatrolOperation
};
private _range=800;private _duration=180;private _records=[];
if (_mode == "START") then {
    _payload params [["_requestedRange",800,[0]],["_requestedDuration",180,[0]]];
    if (count _task == 0 && {finite _requestedRange} && {_requestedRange >= 50} && {_requestedRange <= 2000}
        && {finite _requestedDuration} && {_requestedDuration >= 30} && {_requestedDuration <= 300}
        && {behaviour _anchor != "CARELESS"}
        && {(([_group] call CBE_fnc_CortexGroupState) getOrDefault ["phase","CALM"]) == "CALM"}
        && {count (_group getVariable ["CBE_CreepPolicy",createHashMap]) == 0}) then {
        _range=_requestedRange min (missionNamespace getVariable ["CBE_AIPass_EngageRange",800]);
        _duration=_requestedDuration;
        _records=([_group,_range] call CBE_fnc_CortexKnowledge) select 0;
    };
} else {
    if (count _payload > 8 || {time < (_creep get "nextSample")}) exitWith {};
    _creep set ["nextSample",time+10];
    _range=_creep get "range";_records=_payload;
};
_records=(_records select [0,8]) select {
    _x isEqualType [] && {count _x == 6} && {(_x select 0) isEqualType objNull}
        && {!isNull (_x select 0)} && {(_x select 0) isKindOf "CAManBase" || {(_x select 0) isKindOf "LandVehicle"}}
        && {(_x select 1) isEqualType []} && {count (_x select 1) == 3}
        && {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {(_x select [2,4]) findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} < 0}
        && {(_x select 2) <= 30} && {(_x select 3) <= _range}
        && {(_x select 4) <= 100} && {(_x select 5) >= 1}
        && {count _creep == 0 || {(_x select 0) == (_creep get "target")}}
};
if (_records isEqualTo []) exitWith {false};
(_records select 0) params ["_target","_belief","_age","_distance","_error"];
private _observedAt=time-_age;
private _standOff=if (_target isKindOf "CAManBase") then {40} else {150};
if (_mode == "UPDATE") then {
    _creep set ["observedAt",(_creep get "observedAt") max _observedAt];
};
if (_origin distance2D _belief <= _standOff+_error+8) exitWith {
    if (count _creep > 0) then {["CREEP_STANDOFF_REACHED"] call _cancel};false
};
if (_mode == "UPDATE" && {(_task getOrDefault ["phase",""]) != "MOVING"
    || {(_task getOrDefault ["huntPending",[]]) isNotEqualTo []}
    || {_observedAt <= (_creep get "plannedObservedAt")+1}
    || {_belief distance2D (_creep get "plannedPosition") < 25}}) exitWith {true};
if (_mode == "UPDATE" && {(_creep get "updates") >= 4}) exitWith {["CREEP_UPDATE_LIMIT"] call _cancel};
private _route=[_origin,_belief,_standOff,_error] call CBE_fnc_CreepRoutePlan;
if (_route isEqualTo []) exitWith {
    if (count _creep > 0) then {["CREEP_ROUTE_UNAVAILABLE"] call _cancel};false
};
if (_mode == "START") exitWith {
    if (!(["START",_group,[_belief,100,3,_duration,_route]] call CBE_fnc_PatrolOperation)) exitWith {false};
    _task=_group getVariable ["CBE_PatrolTask",createHashMap];
    _creep=createHashMapFromArray [["target",_target],["range",_range],["belief",+_belief],
        ["standOff",_standOff],["error",_error],["observedAt",_observedAt],
        ["plannedObservedAt",_observedAt],["plannedPosition",+_belief],["updates",0],["nextSample",time+10]];
    _task set ["creep",_creep];
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    _operation set ["creep",true];_group setVariable ["CBE_Operation",_operation,true];
    if ((["APPLY",_group,_operation,_task get "serverDeadline"] call CBE_fnc_CreepPolicy) != "ACQUIRED") exitWith {
        ["CREEP_POLICY_REFUSED"] call _cancel
    };
    ["BEGIN",_group] call CBE_fnc_PatrolOperation
};
_creep set ["belief",+_belief];_creep set ["error",_error];
_creep set ["plannedObservedAt",_observedAt];_creep set ["plannedPosition",+_belief];
_creep set ["updates",(_creep get "updates")+1];
_task set ["huntPending",[_route,_observedAt]];
_group setVariable ["CBE_Creep_Status",["PENDING","FRESH_BELIEF",_creep get "updates",serverTime],true];
true
};
};
_result
