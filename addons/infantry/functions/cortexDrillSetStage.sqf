/*
 * Author: WaldoTheWarfighter
 * Coordinated witnessed arrival transitions retain completed turns and team membership in the current parent.
 * Changes one Cortex manoeuvre stage and publishes a bounded transition ledger for diagnostics.
 * Locality/authority: call only on the local group owner which owns the supplied drill HashMap.
 * Repeat/JIP: stale supplied drill tokens/generations/epochs and identical stages are ignored.
 * Token/owner validation, stage/parent-phase edits and bounded transition publication share one
 * unscheduled transaction, so a previous child of the same coordinated parent cannot publish. The current transition and the newest 64 entries
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
 * [_group, _drill, "MOVE", "BOUND_ISSUED"] call CBE_fnc_CortexDrillSetStage;
 * Result: the owner enters MOVE and Zeus can distinguish a live bound from an idle controller.
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_drill",createHashMap,[createHashMap]],
    ["_next","",[""]],
    ["_reason","",[""]]
];
private _changed=false;
isNil {
if (isNull _group || {!local _group} || {count _drill == 0} || {_next == ""}) exitWith {false};
private _currentDrill=(_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["drill",createHashMap];
private _token=_drill getOrDefault ["token",""];
if (_token == "" || {(_currentDrill getOrDefault ["token",""]) != _token}) exitWith {false};
// Transition history is authoritative evidence too. A delayed old-owner/job callback
// cannot change its stage or overwrite the current operation's diagnostic transition.
private _generation=_drill getOrDefault ["operationGeneration",-1];
private _epoch=_drill getOrDefault ["ownerEpoch",-1];
if (_generation >= 0 && {_generation != (_group getVariable ["CBE_OperationGeneration",0])}) exitWith {false};
if (_epoch >= 0 && {_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {false};
private _previous=_drill getOrDefault ["stage",""];
if (_previous == _next) exitWith {false};
_drill set ["stage",_next];
// Publish semantic progress into the matching parent lifecycle only at a real stage change.
// ENDED belongs to release/cancellation; a child must never complete its coordinated parent.
if (_next in ["START","MOVE","PAUSE","HOLD"] && {_generation >= 0}) then {
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    if ((_operation getOrDefault ["generation",-2]) == _generation
        && {(_operation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
        // Only physically witnessed arrivals advance coordinated progress. Store this
        // before the PAUSE callback, so a child rebuilt between callbacks cannot repeat a completed turn.
        private _supportToken=_drill getOrDefault ["supportToken",""];
        if (_supportToken != "" && {_next == "PAUSE"} && {_reason in ["FIRE_TEAM_ARRIVED","BOUND_ARRIVED"]}
            && {(_operation getOrDefault ["supportToken",""]) == _supportToken}) then {
            private _progress=_operation getOrDefault ["boundProgress",[]];
            if (_progress isEqualType [] && {count _progress == 4}
                && {(_progress select 0) == (_drill get "supportSequence")}) then {
                _progress=[_progress select 0,+(_progress select 1),(_drill get "teams") apply {+_x},
                    (_progress select 3) max ((_drill get "teamTurn")+1)];
                _operation set ["boundProgress",_progress];
                _group setVariable ["CBE_Operation",_operation,true];
            };
        };
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
            _group setVariable ["CBE_Operation",_operation,true];
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
private _history=_group getVariable ["CBE_Cortex_DrillTransitions",[]];
_history pushBack _entry;
if (count _history > 64) then {_history deleteRange [0,count _history-64]};
_group setVariable ["CBE_Cortex_DrillTransition",_entry,true];
_group setVariable ["CBE_Cortex_DrillTransitions",_history,true];
_changed=true;
};
_changed
