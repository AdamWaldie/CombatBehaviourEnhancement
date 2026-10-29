/*
 * Author: WaldoTheWarfighter
 * Purpose: Sequence a bounded building queue through the existing physical CLEAR owner.
 * Locality/authority: Current group owner; inherited authenticated server context is allowed.
 * No parent movement commands, separate scheduler, target scan or group/actor policy writer.
 * Repeat/JIP: One owner-local task, immutable server deadline and native mission receipt.
 * At most32 candidate houses inspected,1..8 selected. Child partial/refused/moved results
 * remain visible. A capped candidate set cannot report whole-area completion. Locality
 * retires the parent without replay; existing child ownership cleanup remains authoritative.
 * Arguments: 0 mode STRING START/CHECK/STEP/CANCEL; 1 group GROUP grpNull;
 * 2 payload ARRAY[]: START [centreATL,radius50,buildingLimit4,duration900]; CANCEL [reason].
 * Return: BOOL task admitted/serviced/retired; never hostile-room or area-safety proof.
 * Current callers: GroupBrainStep/CortexGroupTick, CortexReleaseGroup/Locality,
 * CortexOrderLocal and owner-local scripts.
 * Example: ["START",group soldier1,[getPosATL house1,50,4,900]] call CBE_fnc_ClearAreaOperation;
 */
params [["_mode","CHECK",[""]],["_group",grpNull,[grpNull]],["_payload",[],[[]]]];
if (isNull _group || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
_mode=toUpperANSI _mode;
private _answer=false;
isNil {
_answer=call {
private _task=_group getVariable ["CBE_ClearAreaTask",createHashMap];
if (_mode != "START" && {count _task == 0}) exitWith {false};
private _publish={
    params ["_phase","_reason"];
    if (local _group && {(_task get "ownerEpoch") == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
        _group setVariable ["CBE_ClearArea_Status",[_phase,_reason,+(_task get "results"),
            count (_task get "queue"),_task get "limited",serverTime],true];
    };
};
private _finish={
    params ["_reason",["_complete",false]];
    if ((_group getVariable ["CBE_ClearAreaTask",createHashMap]) isNotEqualTo _task) exitWith {false};
    private _child=_task getOrDefault ["child",[]];
    // Never cancel a replacement CLEAR, operation, owner or public visit.
    if (local _group && {(_task get "ownerEpoch") == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {count _child == 3}) then {
        _child params ["_brain","_generation","_visit"];
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        private _job=_brain getOrDefault ["job",createHashMap];
        if ((_group getVariable ["CBE_BuildingBrain",createHashMap]) isEqualTo _brain
            && {_generation == (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
            && {(_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isEqualTo _visit}
            && {(_operation getOrDefault ["intent",""]) == "CLEAR"}
            && {(_operation getOrDefault ["generation",-1]) == (_job getOrDefault ["operationGeneration",-2])}) then {
            [_group,false] call CBE_fnc_CortexClearRelease;
        };
    };
    private _phase="CANCELLED";
    if (_complete) then {
        _phase=if (_task get "limited" || {(_task get "results") findIf {(_x select 1) != "COMPLETE"} >= 0}) then {"PARTIAL"} else {"COMPLETE"};
    };
    [_phase,_reason] call _publish;
    _group setVariable ["CBE_ClearAreaTask",nil];
    true
};
if (_mode == "CANCEL") exitWith {[_payload param [0,"CANCELLED",[""]]] call _finish};
if (_mode == "START") exitWith {
    _payload params [["_centre",[],[[]]],["_radius",50,[0]],["_limit",4,[0]],["_duration",900,[0]]];
    if (!local _group || {count _task > 0} || {count _centre != 3}
        || {_centre findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        || {!finite _radius} || {_radius < 10} || {_radius > 150}
        || {!finite _limit} || {_limit != floor _limit} || {_limit < 1} || {_limit > 8}
        || {!finite _duration} || {_duration < 30} || {_duration > 1800}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {!([_group] call CBE_fnc_CortexIsEligible)}
        || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {(_group getVariable ["CBE_Operation",createHashMap]) isNotEqualTo createHashMap}
        || {(_group getVariable ["CBE_PatrolTask",createHashMap]) isNotEqualTo createHashMap}
        || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}
        || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
        || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}) exitWith {false};
    private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
    if (!((_state getOrDefault ["phase","CALM"]) in ["CALM","CONTACT"])
        || {count (_state getOrDefault ["drill",createHashMap]) > 0}
        || {(_state getOrDefault ["movementLease",[]]) isNotEqualTo []}
        || {(_group getVariable ["CBE_Cortex_MovementLease",[]]) isNotEqualTo []}
        || {(_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap]) isNotEqualTo createHashMap}) exitWith {false};
    private _members=units _group;
    if (count _members > 64 || {_members findIf {isPlayer _x || {alive _x && {!local _x || {!isNull objectParent _x}}}} >= 0}) exitWith {false};
    if ({[_x] call CBE_fnc_CortexCombatEffective} count _members < 2) exitWith {false};
    private _houses=nearestObjects [_centre,["House"],_radius,true];
    private _limited=count _houses > 32;
    private _eligible=[];
    {
        private _nodes=_x buildingPos -1;
        if (alive _x && {!isObjectHidden _x} && {count _nodes > 0} && {count _nodes <= 512}) then {
            _eligible pushBack [_x,[getPosWorld _x,vectorDir _x,vectorUp _x,getObjectScale _x]];
        };
    } forEach (_houses select [0,32]);
    if (_eligible isEqualTo []) exitWith {false};
    _limited=_limited || {count _eligible > _limit};
    _eligible resize ((count _eligible) min _limit);
    if (!([_group,true] call CBE_fnc_GroupBrainStart)) exitWith {false};
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    private _serial=(_group getVariable ["CBE_ClearAreaSerial",0])+1;
    _group setVariable ["CBE_ClearAreaSerial",_serial];
    _task=createHashMapFromArray [["token",format ["%1:%2:%3",clientOwner,_epoch,_serial]],
        ["ownerEpoch",_epoch],["deadline",serverTime+_duration],["native",[_group] call CBE_fnc_NativeOrderReceipt],
        ["members",+_members],["queue",_eligible],["results",[]],["index",0],["limited",_limited]];
    _group setVariable ["CBE_ClearAreaTask",_task];
    ["ACTIVE","QUEUED"] call _publish;
    true
};
if (!(_mode in ["CHECK","STEP"])) exitWith {false};
if (!local _group || {(_task get "ownerEpoch") != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {["OWNERSHIP_LOST"] call _finish};
if (serverTime >= (_task get "deadline")) exitWith {["TASK_EXPIRED"] call _finish};
if (!(missionNamespace getVariable ["CBE_AIPass_Active",false])
    || {[_group] call CBE_fnc_CortexExternalTakeover} || {[_group] call CBE_fnc_CortexZeusHeld}
    || {!([_group] call CBE_fnc_CortexIsEligible)}) exitWith {["CONTROL_CHANGED"] call _finish};
if (([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_task get "native")) exitWith {["NATIVE_ORDER_CHANGED"] call _finish};
private _members=units _group;
if (_members findIf {isPlayer _x || {alive _x && {!(_x in (_task get "members")) || {!local _x} || {!isNull objectParent _x}}}} >= 0) exitWith {["ROSTER_CHANGED"] call _finish};
private _child=_task getOrDefault ["child",[]];
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if (_child isNotEqualTo []) then {
    _child params ["_brain","_generation","_visit"];
    private _job=_brain getOrDefault ["job",createHashMap];
    if ((_group getVariable ["CBE_BuildingBrain",createHashMap]) isNotEqualTo _brain
        || {_generation != (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
        || {(_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isNotEqualTo _visit}
        || {count _operation > 0 && {(_operation getOrDefault ["generation",-1]) != (_job getOrDefault ["operationGeneration",-2])}}) exitWith {
        ["CHILD_REPLACED"] call _finish;
    };
    if (_job getOrDefault ["finished",false] && {count _operation == 0}) then {
        private _result=_job getOrDefault ["result","CANCELLED"];
        if (_result == "COMPLETE" && {(_job getOrDefault ["finishReason",""]) != "COMPLETE"}) then {_result="INCOMPLETE"};
        // Keep compact per-building failed-node evidence before the next child replaces
        // the ordinary single-building status. No actor/job graph is retained here.
        private _evidence=[count (_job getOrDefault ["cleared",[]]),count (_job getOrDefault ["positions",[]]),
            +(_job getOrDefault ["unreachable",[]]),_job getOrDefault ["entryFailed",false],_job getOrDefault ["egressFailed",false]];
        (_task get "results") pushBack [_job get "building",_result,_job getOrDefault ["finishReason","UNKNOWN"],_evidence];
        _task set ["index",(_task get "index")+1];
        _task deleteAt "child";
        ["ACTIVE","BUILDING_FINISHED"] call _publish;
    };
};
if ((_group getVariable ["CBE_ClearAreaTask",createHashMap]) isNotEqualTo _task) exitWith {true};
// A finished queue needs no new pair or movement permission. Do not leave an already
// completed result waiting on a later care/return task; new work alone needs strength.
if ((_task getOrDefault ["child",[]]) isEqualTo [] && {(_task get "index") >= count (_task get "queue")}) exitWith {
    ["SELECTED_BUILDINGS_FINISHED",true] call _finish
};
if ({[_x] call CBE_fnc_CortexCombatEffective} count _members < 2) exitWith {["INSUFFICIENT_STRENGTH"] call _finish};
if ((_task getOrDefault ["child",[]]) isNotEqualTo [] || {_mode == "CHECK"}) exitWith {true};
if (count (_group getVariable ["CBE_Operation",createHashMap]) > 0
    || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}
    || {count (_group getVariable ["CBE_PatrolTask",createHashMap]) > 0}
    || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}) exitWith {["NEW_TASK"] call _finish};
// Temporary native care/boarding/return work is not a failed building. Wait for
// a real pair under the same original area deadline, without planning or retry renewal.
private _ready=(units _group) select {[_x] call CBE_fnc_CortexCombatEffective
    && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
    && {[_x] call CBE_fnc_CortexActorFireTaskAvailable}};
if (count _ready < 2) exitWith {true};
private _index=_task get "index";
private _queue=_task get "queue";
private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
if (!isNull _anchor) then {
    private _best=_index;private _distance=1e12;
    for "_candidate" from _index to (count _queue-1) do {
        private _house=(_queue select _candidate) select 0;
        if (!isNull _house && {_anchor distance2D _house < _distance}) then {
            _best=_candidate;_distance=_anchor distance2D _house;
        };
    };
    if (_best != _index) then {private _first=_queue select _index;_queue set [_index,_queue select _best];_queue set [_best,_first]};
};
(_queue select _index) params ["_building","_transform"];
private _reason="";
if (isNull _building || {!alive _building}) then {_reason="BUILDING_REMOVED"} else {
    if ([getPosWorld _building,vectorDir _building,vectorUp _building,getObjectScale _building] isNotEqualTo _transform) then {_reason="BUILDING_MOVED"};
};
private _accepted=false;
private _priorFailure=_group getVariable ["CBE_Cortex_ClearAdmissionFailure",[]];
if (_reason == "") then {
    _accepted=[_group,_building,createHashMapFromArray [["preserveBrain",true],
        ["taskDeadline",_task get "deadline"],["areaTaskToken",_task get "token"],["minimumActors",2]]] call CBE_fnc_CortexClearBuilding;
};
if ((_group getVariable ["CBE_ClearAreaTask",createHashMap]) isNotEqualTo _task) exitWith {false};
if (_accepted) then {
    private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
    private _job=_brain getOrDefault ["job",createHashMap];
    _task set ["child",[_brain,_job get "generation",+(_job get "visitContext")]];
    ["ACTIVE","CLEARING_BUILDING"] call _publish;
} else {
    if (_reason == "") then {
        _reason="CLEAR_ADMISSION_REFUSED";
        private _failure=_group getVariable ["CBE_Cortex_ClearAdmissionFailure",[]];
        if (count _failure == 4 && {_failure isNotEqualTo _priorFailure}) then {_reason=_failure select 1};
    };
    (_task get "results") pushBack [_building,"INCOMPLETE",_reason,[]];
    _task set ["index",_index+1];
    ["ACTIVE",_reason] call _publish;
};
true
};
};
_answer
