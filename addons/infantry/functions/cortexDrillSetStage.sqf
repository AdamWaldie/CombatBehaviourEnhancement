/*
 * Author: WaldoTheWarfighter
 * Changes one Cortex manoeuvre stage and publishes a bounded transition ledger for diagnostics.
 * Locality/authority: call only on the local group owner which owns the supplied drill HashMap.
 * Repeat/JIP: stale supplied generations/epochs and identical stages are ignored. The current transition and the newest 64 entries
 * are public for Zeus/JIP observers; no scheduled work or per-unit handler is installed.
 * Arguments:
 * 0: group <GROUP, default grpNull>
 * 1: drill <HASHMAP, default empty HashMap> - active flank, advance, assault or coordinated-bound state
 * 2: next stage <STRING, default ""> - START, MOVE, PAUSE, HOLD or ENDED
 * 3: reason <STRING, default ""> - concrete trigger or final outcome
 * Return Value: Boolean - true when the stage changed and was published
 * Current callers: CortexFlankStart, CortexAdvanceStart, CortexAssaultStart, CortexSupportBoundStart,
 * CortexFlankStep and CortexFlankEnd.
 * Example:
 * [_group, _drill, "MOVE", "BOUND_ISSUED"] call WAIT_fnc_CortexDrillSetStage;
 * Result: the owner enters MOVE and Zeus can distinguish a live bound from an idle controller.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_drill",createHashMap,[createHashMap]],
    ["_next","",[""]],
    ["_reason","",[""]]
];
if (isNull _group || {!local _group} || {count _drill == 0} || {_next == ""}) exitWith {false};
// Transition history is authoritative evidence too. A delayed old-owner/job callback
// cannot change its stage or overwrite the current operation's diagnostic transition.
private _generation=_drill getOrDefault ["operationGeneration",-1];
private _epoch=_drill getOrDefault ["ownerEpoch",-1];
if (_generation >= 0 && {_generation != (_group getVariable ["WAIT_OperationGeneration",0])}) exitWith {false};
if (_epoch >= 0 && {_epoch != (_group getVariable ["WAIT_AIPass_Epoch",0])}) exitWith {false};
private _previous=_drill getOrDefault ["stage",""];
if (_previous == _next) exitWith {false};
_drill set ["stage",_next];
// Publish semantic progress into the matching parent lifecycle only at a real stage change.
// ENDED belongs to release/cancellation; a child must never complete its coordinated parent.
if (_next in ["START","MOVE","PAUSE","HOLD"] && {_generation >= 0}) then {
    private _operation=_group getVariable ["WAIT_Operation",createHashMap];
    if ((_operation getOrDefault ["generation",-2]) == _generation
        && {(_operation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["WAIT_AIPass_Epoch",0])}) then {
        private _phase=switch (_next) do {
            case "PAUSE": {"SUPPORT"};
            case "HOLD": {"SECURITY"};
            default {
                private _point=(_drill getOrDefault ["points",[]]) param [_drill getOrDefault ["index",0],[]];
                ["MANOEUVRE","ASSAULT"] select ((_point param [1,"",[""]]) in ["ASSAULT","CLEAR"])
            };
        };
        if ((_operation getOrDefault ["phase",""]) != _phase) then {
            _operation set ["phase",_phase];
            _group setVariable ["WAIT_Operation",_operation,true];
        };
    };
};
private _entry=[
    serverTime,
    _drill getOrDefault ["token",""],
    _drill getOrDefault ["type",""],
    _previous,
    _next,
    _reason,
    _drill getOrDefault ["index",-1],
    _drill getOrDefault ["teamTurn",-1],
    _drill getOrDefault ["operationGeneration",-1],
    _drill getOrDefault ["ownerEpoch",-1]
];
private _history=_group getVariable ["WAIT_Cortex_DrillTransitions",[]];
_history pushBack _entry;
if (count _history > 64) then {_history deleteRange [0,count _history-64]};
_group setVariable ["WAIT_Cortex_DrillTransition",_entry,true];
_group setVariable ["WAIT_Cortex_DrillTransitions",_history,true];
true
