/*
 * Author: WaldoTheWarfighter
 * Purpose: Verify the original private clearance producer for component serialization.
 * Locality/authority: Local read-only check. LIVE requires current group locality;
 * FROZEN requires actual locality loss, original producer identity and the existing
 * LOCALITY_CHANGE cancellation fence before private pointer/epoch retirement.
 * Repeat/JIP: No mutation, command, worker, publication or replay. The completed flag
 * is the callback fence, not proof that every old actor/settings writer has ended.
 * Arguments: 0 mode STRING LIVE/FROZEN default LIVE; 1 job HASHMAP default empty.
 * Return: BOOL exact producer/episode context; never incoming movement authority.
 * Current callers: BuildingLaneJournal EXPORT/FROZEN and CortexLocality capture.
 * Example: ["FROZEN",_job] call CBE_fnc_BuildingProducerContext;
 */
params [["_mode","LIVE",[""]],["_job",createHashMap,[createHashMap]]];
if (!(_mode in ["LIVE","FROZEN"]) || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _result=false;
isNil {
    _result=call {
        private _group=_job getOrDefault ["group",grpNull];
        private _building=_job getOrDefault ["building",objNull];
        private _context=_job getOrDefault ["visitContext",[]];
        private _phase=_job getOrDefault ["phase",""];
        private _frozen=_mode == "FROZEN";
        if (!(_group isEqualType grpNull) || {isNull _group}
            || {if (_frozen) then {local _group} else {!local _group}}
            || {!(_building isEqualType objNull)} || {isNull _building} || {!alive _building}
            || {!(_phase in ["ENTRY","SWEEP","REPLAN","EGRESS"])}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}
            || {_context isNotEqualTo (_group getVariable ["CBE_Cortex_ClearVisitContext",[]])}
            || {(_context select 0) isNotEqualTo _building}
            || {(_context select 1) isNotEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
            || {(_context select 2) isNotEqualTo (_job getOrDefault ["hardDeadline",-1])}) exitWith {false};
        private _until=if (_phase == "EGRESS") then {_job getOrDefault ["egressDeadlineServer",-1]}
            else {_job getOrDefault ["hardDeadline",-1]};
        if (!(_until isEqualType 0) || {!finite _until} || {serverTime >= _until}) exitWith {false};
        private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        if (!(_brain isEqualType createHashMap) || {!(_operation isEqualType createHashMap)}
            || {(_brain getOrDefault ["job",createHashMap]) isNotEqualTo _job}
            || {(_brain getOrDefault ["ownerEpoch",-1]) != (_job getOrDefault ["ownerEpoch",-2])}
            || {(_brain getOrDefault ["generation",-1]) != (_job getOrDefault ["generation",-2])}
            || {(_brain getOrDefault ["producerOwner",-1]) != clientOwner}
            || {_brain getOrDefault ["finished",false]}
            || {_job getOrDefault ["finished",false]}
            || {(_job getOrDefault ["generation",-1]) != (_group getVariable ["CBE_AIPass_ClearGeneration",-2])}
            || {(_job getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {(_operation getOrDefault ["generation",-2]) != (_job getOrDefault ["operationGeneration",-1])}
            || {(_operation getOrDefault ["ownerEpoch",-2]) != (_job getOrDefault ["ownerEpoch",-1])}
            || {(_operation getOrDefault ["intent",""]) != "CLEAR"}
            || {(_operation getOrDefault ["objective",objNull]) isNotEqualTo _building}
            || {(_operation getOrDefault ["phase",""]) == "CANCELLED"}
            || {if (_frozen) then {
                !(_brain getOrDefault ["cancelled",false])
                    || {(_brain getOrDefault ["cancelReason",""]) != "LOCALITY_CHANGE"}
                    || {!(_brain getOrDefault ["completed",false])}
            } else {_brain getOrDefault ["cancelled",false]}}) exitWith {false};
        true
    };
    false
};
_result
