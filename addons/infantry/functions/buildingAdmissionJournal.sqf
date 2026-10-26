/*
 * Author: WaldoTheWarfighter
 * Purpose: Validate and copy original reserve native-order admission baselines.
 * Locality/authority: Pure data conversion; caller verifies preparation or fenced
 * original producer authority. This grants no native command or incoming readiness.
 * Repeat/JIP: No mutation, timer, query, budget renewal or replay. Unknown context
 * refuses; known empty history remains explicit. Historical original keys survive deletion.
 * Arguments: 0 mode STRING IMPORT/CAPTURE default IMPORT; 1 job HASHMAP default empty;
 * 2 public receipt ARRAY [visitContext,rows] default[] for IMPORT only.
 * Return: ARRAY [1,visitContext,keyedRows] or[] on invalid/unknown data; max64 rows.
 * Current callers: CortexClearBuilding preparation/resume and CortexLocality capture.
 * Example: private _snapshot=["CAPTURE",_job] call CBE_fnc_BuildingAdmissionJournal;
 */
params [["_mode","IMPORT",[""]],["_job",createHashMap,[createHashMap]],["_receipt",[],[[]]]];
private _result=[];
isNil {
    _result=call {
        if (!(_mode in ["IMPORT","CAPTURE"])) exitWith {[]};
        private _context=_job getOrDefault ["visitContext",[]];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} < 0}};
        if (!(_context isEqualType []) || {count _context != 4}
            || {[0,1,2,3] findIf {isNil {_context select _x}} >= 0}
            || {!((_context select 0) isEqualType objNull)} || {isNull (_context select 0)}
            || {!((_context select 1) isEqualType [])} || {count (_context select 1) != 3}
            || {(_context select 1) findIf {!(_x call _vector)} >= 0}
            || {!((_context select 2) isEqualType 0)} || {!finite (_context select 2)} || {(_context select 2) < 0}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}) exitWith {[]};
        private _capture=_mode == "CAPTURE";
        private _commands=_job getOrDefault ["reserveAdmissionCommands",createHashMap];
        private _source=[];
        if (_capture) then {
            if ((_job getOrDefault ["reserveAdmissionContext",[]]) isEqualTo _context
                && {_commands isEqualType createHashMap} && {count _commands <= 64}) then {
                _source=keys _commands;
            } else {_source=[nil]};
        } else {
            if (count _receipt == 2 && {!isNil {_receipt select 0}} && {!isNil {_receipt select 1}}
                && {(_receipt select 0) isEqualTo _context} && {(_receipt select 1) isEqualType []}
                && {count (_receipt select 1) <= 64}) then {_source=_receipt select 1} else {_source=[nil]};
        };
        private _rows=[];private _seen=[];private _valid=true;
        {
            if (isNil "_x") exitWith {_valid=false};
            private _key=if (_capture) then {_x} else {""};
            if (_capture && {!(_key isEqualType "") || {_key in ["","0:0"]}}) exitWith {_valid=false};
            private _row=if (_capture) then {_commands get _key} else {_x};
            if (!(_row isEqualType []) || {count _row != 4}
                || {[0,1,2,3] findIf {isNil {_row select _x}} >= 0}) exitWith {_valid=false};
            _row params ["_actor","_command","_destination","_formationLeader"];
            if (!(_actor isEqualType objNull) || {!_capture && {isNull _actor}}
                || {!(_command isEqualType "")} || {!(_formationLeader isEqualType objNull)}
                || {!(_destination isEqualType [])} || {count _destination != 3}
                || {[0,1,2] findIf {isNil {_destination select _x}} >= 0}
                || {!((_destination select 0) call _vector)}
                || {!((_destination select 1) isEqualType "")}
                || {!((_destination select 2) isEqualType true)}) exitWith {_valid=false};
            if (!_capture) then {_key=netId _actor};
            if (_key in ["","0:0"] || {_key in _seen}
                || {!isNull _actor && {netId _actor != _key}}) exitWith {_valid=false};
            _seen pushBack _key;
            _rows pushBack [_key,[_actor,_command,
                [+(_destination select 0),_destination select 1,_destination select 2],_formationLeader]];
        } forEach _source;
        if (!_valid) exitWith {[]};
        [1,[_context select 0,(_context select 1) apply {+_x},_context select 2,_context select 3],_rows]
    };
};
_result
