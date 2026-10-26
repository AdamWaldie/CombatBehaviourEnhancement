/*
 * Author: WaldoTheWarfighter
 * Purpose: Save/adopt a clearance lane journal or export current producer lane data without publication.
 * Locality/authority: Current group owner and current CLEAR generation/epoch. CHECK validates
 * prospective resume data before an operation exists; SAVE/ADOPT/EXPORT require its exact operation.
 * EXPORT additionally requires this machine's current uncancelled building brain/job. It is
 * current-owner-only. FROZEN is read-only after actual locality loss, before private pointer
 * retirement: the same local producer must be fenced by LOCALITY_CHANGE. Neither is a
 * complete transfer seal or network/replay interface.
 * Adoption retains lane-bound buddy destination proposals as well as request ages and progress.
 * It changes job metadata, never native commands, visits, settings or deadlines.
 * Repeat/JIP: Episode/transform and exact node/roster identity bind the public snapshot.
 * Local progress/start clocks are transported as server time and rebased once on adoption.
 * Original native issue times are observations only; adoption never starts a new grace window.
 * Missing, malformed or mismatched snapshots refuse adoption rather than invent progress.
 * At most8 lanes,2 actors per lane and512 nodes; SAVE is limited to one sample per1.5s
 * on the existing job and phase, including refused samples; a phase transition or committed
 * lane-roster change invalidates that sample. The new phase must not retain an old-phase snapshot.
 * Changed-only publication. No worker, world query or retry renewal.
 * Arguments: 0 mode STRING SAVE/ADOPT/CHECK/EXPORT/FROZEN; 1 job HASHMAP empty.
 * Return: BOOL - CHECK validity without mutation, latest SAVE result or metadata adopted;
 * throttling retains the prior SAVE result. EXPORT returns an independently copied13-field
 * ARRAY or [] on refusal (also FROZEN), bypassing SAVE throttling without changing its budgets. CHECK and
 * EXPORT never publish or change job metadata. Exported clocks use original server time.
 * Never native acknowledgement, valid-current-snapshot proof or physical continuity.
 * Callers: CortexClearBuilding and BuildingOperationStep SAVE/ADOPT/CHECK; internal producer
 * checkpoint preparation may call EXPORT while local; CortexLocality calls FROZEN only
 * between fencing its original private producer and clearing that pointer.
 * Example: ["SAVE",_job] call CBE_fnc_BuildingLaneJournal;
 */
params [["_mode","SAVE",[""]],["_job",createHashMap,[createHashMap]]];
private _frozen=_mode == "FROZEN";
private _export=_mode in ["EXPORT","FROZEN"];
private _encoding=_mode in ["SAVE","EXPORT","FROZEN"];
private _refused=if (_export) then {[]} else {false};
if (!(_mode in ["SAVE","ADOPT","CHECK","EXPORT","FROZEN"]) || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {_refused};
private _group=_job getOrDefault ["group",grpNull];
private _ownerContext={if (_frozen) then {!local _group} else {local _group}};
if (isNull _group || {!(call _ownerContext)}) exitWith {_refused};
private _phase=_job getOrDefault ["phase","ENTRY"];
if (!(_phase in ["ENTRY","SWEEP"])) exitWith {if (_export) then {[]} else {_mode == "ADOPT"}};
if (_mode == "SAVE" && {serverTime < (_job getOrDefault ["laneJournalAfter",-1])}
    && {_phase isEqualTo (_job getOrDefault ["laneJournalPhase",""])}) exitWith {_job getOrDefault ["laneJournalLastResult",false]};
private _result=false;
isNil {
_result=call {
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _context=_job getOrDefault ["visitContext",[]];
    private _building=_job getOrDefault ["building",objNull];
    if (!(call _ownerContext) || {!(_context isEqualType [])} || {count _context != 4}
        || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""} || {isNull _building} || {!alive _building}
        || {_context isNotEqualTo (_group getVariable ["CBE_Cortex_ClearVisitContext",[]])}
        || {(_context select 0) isNotEqualTo _building}
        || {(_context select 1) isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
        || {(_context select 2) isNotEqualTo (_job getOrDefault ["hardDeadline",-1])}
        || {serverTime >= (_job getOrDefault ["hardDeadline",-1])}
        || {(_job getOrDefault ["generation",-1]) != (_group getVariable ["CBE_AIPass_ClearGeneration",-2])}
        || {(_job getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
    if (_mode != "CHECK" && {
        (_operation getOrDefault ["generation",-2]) != (_job getOrDefault ["operationGeneration",-1])
        || {(_operation getOrDefault ["ownerEpoch",-2]) != (_job getOrDefault ["ownerEpoch",-1])}
        || {(_operation getOrDefault ["intent",""]) != "CLEAR"}
        || {(_operation getOrDefault ["phase",""]) == "CANCELLED"}
    }) exitWith {false};
    // Budget this admitted observation even when its data later refuses. A bad lane
    // cannot turn every short callback into another complete snapshot validation.
    if (_mode == "SAVE") then {
        _job set ["laneJournalAfter",serverTime+1.5];
        _job set ["laneJournalPhase",_phase];
        _job set ["laneJournalLastResult",false];
    };
    if (_export && {
        private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
        !(_brain isEqualType createHashMap)
            || {(_brain getOrDefault ["job",createHashMap]) isNotEqualTo _job}
            || {(_brain getOrDefault ["ownerEpoch",-1]) != (_job getOrDefault ["ownerEpoch",-2])}
            || {(_brain getOrDefault ["generation",-1]) != (_job getOrDefault ["generation",-2])}
            || {(_brain getOrDefault ["producerOwner",-1]) != clientOwner}
            || {_brain getOrDefault ["finished",false]}
            || {if (_frozen) then {
                !(_brain getOrDefault ["cancelled",false])
                    || {(_brain getOrDefault ["cancelReason",""]) != "LOCALITY_CHANGE"}
                    || {!(_brain getOrDefault ["completed",false])}
            } else {_brain getOrDefault ["cancelled",false]}}
    }) exitWith {false};
    private _positions=_job getOrDefault ["positions",[]];
    private _pairs=_job getOrDefault ["pairs",[]];
    private _routes=_job getOrDefault ["pairRoutes",[]];
    private _states=_job getOrDefault ["pairStates",[]];
    private _pending=_job getOrDefault ["pending",[]];
    private _entryNodes=_job getOrDefault ["entries",[]];
    private _entryGoal=_job getOrDefault ["entry",[]];
    private _snapshot=if (_export) then {[]} else {_group getVariable ["CBE_Cortex_ClearLanes",[]]};
    if (_mode == "CHECK" && {_snapshot isNotEqualTo (_job getOrDefault ["expectedSnapshot",[]])}) exitWith {false};
    if (_mode in ["ADOPT","CHECK"]) then {
        if (!(_snapshot isEqualType []) || {count _snapshot != 13}
            || {(_snapshot select 0) != 1} || {(_snapshot select 1) isNotEqualTo _group}
            || {(_snapshot select 2) isNotEqualTo _context}
            || {(_snapshot select 3) isNotEqualTo _positions}
            || {(_snapshot select 4) isNotEqualTo _pairs}
            || {!((_snapshot select 8) in ["ENTRY","SWEEP"])}) exitWith {_routes=[]};
        _routes=_snapshot select 5;_states=_snapshot select 6;_pending=_snapshot select 7;
        _phase=_snapshot select 8;
        _entryNodes=_snapshot select 9;_entryGoal=_snapshot select 10;
    };
    private _nodeCount=count _positions;
    private _laneCount=count _pairs;
    private _nodeValid={_this isEqualType 0 && {finite _this} && {_this == floor _this}
        && {_this >= 0} && {_this < _nodeCount}};
    private _vectorValid={_this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
    // Entry arrays are re-sorted around the new leader during preparation. Lane indices
    // must retain their original ordered nodes, not index into that new nearest-door list.
    private _availableEntries=_job getOrDefault ["securityEntries",[]];
    if (!(_entryNodes isEqualType []) || {count _entryNodes > 4}
        || {_entryNodes findIf {!(_x call _vectorValid) || {!(_x in _availableEntries)}} >= 0}
        || {count (_entryNodes arrayIntersect _entryNodes) != count _entryNodes}
        || {!(_entryGoal isEqualType [])}
        || {_entryNodes isEqualTo [] && {_entryGoal isNotEqualTo []}}
        || {_entryNodes isNotEqualTo [] && {!(_entryGoal in _entryNodes)}}) exitWith {false};
    if (_nodeCount < 1 || {_nodeCount > 512} || {_laneCount < 1} || {_laneCount > 8}
        || {!(_routes isEqualType [])} || {count _routes != _laneCount}
        || {!(_states isEqualType [])} || {count _states != _laneCount}
        || {!(_pending isEqualType [])} || {count _pending > _nodeCount}
        || {_pending findIf {!(_x call _nodeValid)} >= 0}) exitWith {false};
    private _copyStates=[];private _copyRoutes=[];private _roster=[];
    private _remaining=+_pending;private _valid=true;
    private _retired=(_job getOrDefault ["cleared",[]])+(_job getOrDefault ["unreachable",[]]);
    {
        private _pair=_x;private _slot=_forEachIndex;
        private _route=_routes select _slot;private _state=_states select _slot;
        if (!(_pair isEqualType []) || {!(count _pair in [1,2])}
            || {count (_pair arrayIntersect _pair) != count _pair}
            || {_pair findIf {!(_x isEqualType objNull) || {isNull _x} || {group _x != _group} || {_x in _roster}} >= 0}
            || {!(_route isEqualType [])} || {count _route > 512}
            || {_route findIf {!(_x call _nodeValid)} >= 0}
            || {!(_state isEqualType [])} || {!(count _state in [13,15])}) exitWith {_valid=false};
        _roster append _pair;
        private _row=+_state;
        if (count _row == 13) then {_row append [1e12,[]]};
        if ([0,3,4,5,6,7,8,9,11,13] findIf {!((_row select _x) isEqualType 0) || {!finite (_row select _x)}} >= 0
            || {[0,4,5,7,8,9,11] findIf {(_row select _x) != floor (_row select _x)} >= 0}
            || {(_row select 0) < 0} || {(_row select 0) > count _route}
            || {(_row select 4) < 0} || {(_row select 7) < 0} || {(_row select 7) >= count _pair}
            || {(_row select 11) < 0} || {(_row select 13) < 0}
            || {[1,12] findIf {!((_row select _x) isEqualType true)} >= 0}
            || {!((_row select 2) isEqualType [])} || {count (_row select 2) != count _pair}
            || {(_row select 2) findIf {!(_x call _vectorValid)} >= 0}
            || {!((_row select 10) isEqualType [])} || {count (_row select 10) > count _entryNodes}
            || {(_row select 10) findIf {!(_x isEqualType 0) || {!finite _x} || {_x != floor _x}
                || {_x < 0} || {_x >= count _entryNodes}} >= 0}
            || {(_row select 9) < -1} || {(_row select 9) >= count _entryNodes}
            || {[5,8] findIf {(_row select _x) != -1 && {!((_row select _x) call _nodeValid)}} >= 0}
            || {(_row select 14) isNotEqualTo [] && {!((_row select 14) call _vectorValid)}}) exitWith {_valid=false};
        _row set [2,(_row select 2) apply {+_x}];_row set [10,+(_row select 10)];_row set [14,+(_row select 14)];
        if (_encoding) then {
            _row set [3,serverTime-(time-(_row select 3))];
            _row set [6,serverTime+((_row select 6)-time)];
        } else {
            if ((_row select 3) < 0 || {(_row select 3) > serverTime+1}
                || {(_row select 6) < 0} || {(_row select 6) > (_job get "hardDeadline")}) exitWith {_valid=false};
            _row set [3,time-(serverTime-(_row select 3))];
            _row set [6,time+((_row select 6)-serverTime)];
        };
        _remaining append (_route select [_row select 0]);
        _copyStates pushBack _row;_copyRoutes pushBack (+_route);
    } forEach _pairs;
    if (!_valid) exitWith {false};
    private _retiredSet=createHashMap;
    {_retiredSet set [str _x,true]} forEach _retired;
    _remaining=_remaining select {!(str _x in _retiredSet)};
    private _claimed=createHashMap;
    {
        private _key=str _x;
        if (_key in _claimed) exitWith {_valid=false};
        _claimed set [_key,true];
    } forEach _remaining;
    if (!_valid) exitWith {false};
    for "_index" from 0 to (_nodeCount-1) do {
        private _key=str _index;
        if (!(_key in _retiredSet) && {!(_key in _claimed)}) exitWith {_valid=false};
    };
    if (!_valid) exitWith {false};
    // Keep the selected buddy destination with its exact lane/roster, rather than
    // rebuilding it while retaining the old native request age and recovery budget.
    // This is a proposal cache only, not an owned MOVE or physical entry receipt.
    private _entryTargets=[];
    if (_encoding) then {
        private _targets=_job getOrDefault ["pairEntryTargets",createHashMap];
        if (!(_targets isEqualType createHashMap) || {count _targets > _laneCount}) exitWith {_valid=false};
        for "_slot" from 0 to (_laneCount-1) do {
            private _key=str _slot;
            if (_key in _targets) then {_entryTargets pushBack [_slot,_targets get _key]};
        };
        if (count _entryTargets != count _targets) then {_valid=false};
    } else {_entryTargets=_snapshot select 12};
    if (!_valid || {!(_entryTargets isEqualType [])} || {count _entryTargets > _laneCount}) exitWith {false};
    private _copyEntryTargets=createHashMap;
    {
        if (!(_x isEqualType []) || {count _x != 2}) exitWith {_valid=false};
        _x params ["_slot","_target"];
        if (!(_slot isEqualType 0) || {!finite _slot} || {_slot != floor _slot}
            || {_slot < 0} || {_slot >= _laneCount} || {str _slot in _copyEntryTargets}
            || {!(_target call _vectorValid)}) exitWith {_valid=false};
        _copyEntryTargets set [str _slot,+_target];
    } forEach _entryTargets;
    if (!_valid) exitWith {false};
    // Keep request age with the matching lane allocation. This map never supplies an
    // owned MOVE target: BuildingActorMotion still needs actual native acknowledgement.
    private _requests=[];
    if (_encoding) then {
        private _requestTimes=_job getOrDefault ["movementRequestTimes",createHashMap];
        {
            private _request=_requestTimes getOrDefault [netId _x,[]];
            if (_request isNotEqualTo []) then {_requests pushBack [_x,+_request]};
        } forEach _roster;
    } else {_requests=_snapshot select 11};
    if (!(_requests isEqualType []) || {count _requests > count _roster}) exitWith {false};
    private _requestTimes=createHashMap;
    {
        if (!(_x isEqualType []) || {count _x != 2}) exitWith {_valid=false};
        _x params ["_actor","_request"];
        if (!(_actor isEqualType objNull) || {!(_actor in _roster)}
            || {netId _actor in _requestTimes}
            || {!(_request isEqualType [])} || {count _request != 2}
            || {!((_request select 0) call _vectorValid)}
            || {!((_request select 1) isEqualType 0)} || {!finite (_request select 1)}
            || {(_request select 1) < 0} || {(_request select 1) > serverTime+1}
            || {(_request select 1) > (_job get "hardDeadline")}) exitWith {_valid=false};
        _requestTimes set [netId _actor,[+(_request select 0),_request select 1]];
    } forEach _requests;
    if (!_valid) exitWith {false};
    if (_mode == "CHECK") exitWith {true};
    if (_mode == "ADOPT") exitWith {
        _job set ["pairEntryTargets",_copyEntryTargets];
        _job set ["movementRequestTimes",_requestTimes];
        _job set ["pairRoutes",_copyRoutes];_job set ["pairStates",_copyStates];
        _job set ["pending",+_pending];_job set ["phase",_phase];
        _job set ["entries",_entryNodes apply {+_x}];_job set ["entry",+_entryGoal];true
    };
    // Export must not alias the producer's nested building-transform vectors.
    private _contextCopy=[_context select 0,(_context select 1) apply {+_x},_context select 2,_context select 3];
    private _journal=[1,_group,_contextCopy,_positions apply {+_x},_pairs apply {+_x},_copyRoutes,_copyStates,+_pending,_phase,_entryNodes apply {+_x},+_entryGoal,
        _requests apply {[_x select 0,[+((_x select 1) select 0),(_x select 1) select 1]]},
        _entryTargets apply {[_x select 0,+(_x select 1)]}];
    if (_export) exitWith {_journal};
    _job set ["laneJournalLastResult",true];
    if (_snapshot isNotEqualTo _journal) then {_group setVariable ["CBE_Cortex_ClearLanes",_journal,true]};
    true
};
false
};
if (_export && {!(_result isEqualType [])}) then {[]} else {_result}
