/*
 * Author: WaldoTheWarfighter
 * Building geometry identities include scale; stale geometry grants no current task or visit proof.
 * Purpose: Encode original early exits for live publication and outgoing capture.
 * Locality/authority: Pure local conversion. Caller owns live publication or verifies
 * the fenced original producer; no native command, arrival proof or replay authority.
 * Repeat/JIP: No mutation, observation, clock renewal, worker or public side effect.
 * PUBLIC stops after the existing bounded exit rows; CAPTURE also copies historical
 * motion/view clocks. Deleted actor references retain their original map key only.
 * Arguments: 0 mode STRING PUBLIC/CAPTURE/CHECK default CAPTURE; 1 job HASHMAP empty;
 * 2 received ARRAY default[] for CHECK only. Expected job context includes securityEntries.
 * Return: PUBLIC existing[visitContext,rows]; CAPTURE[1,visitContext,keyedRows,motionRows,
 * viewRows,viewCursor]. Those modes return[] on refusal. CHECK returns BOOL and
 * validates exact-context seven-field received rows through the same PUBLIC encoder.
 * CHECK requires original non-null unique actor identities; it grants no native readiness.
 * Current callers: BuildingOperationStep publication; CortexLocality capture;
 * CortexClearBuilding read-only resume preflight before operation startup.
 * Example: ["CAPTURE",_job] call CBE_fnc_BuildingEarlyExitJournal;
 */
params [["_mode","CAPTURE",[""]],["_job",createHashMap,[createHashMap]],["_received",[],[[]]]];
if (_mode == "CHECK") exitWith {
    private _accepted=false;
    isNil {
        _accepted=call {
            private _context=_job getOrDefault ["visitContext",[]];
            private _entries=_job getOrDefault ["securityEntries",[]];
            if (count _received != 2 || {isNil {_received select 0}} || {isNil {_received select 1}}
                || {(_received select 0) isNotEqualTo _context}
                || {!((_received select 1) isEqualType [])} || {count (_received select 1) > 8}
                || {!(_entries isEqualType [])} || {count _entries > 16}) exitWith {false};
            private _exits=createHashMap;private _valid=true;
            {
                private _receivedRow=_x;
                if (!(_x isEqualType []) || {count _x != 7}
                    || {[0,1,2,3,4,5,6] findIf {isNil {_receivedRow select _x}} >= 0}) exitWith {_valid=false};
                private _actor=_x select 0;
                if (!(_actor isEqualType objNull) || {isNull _actor} || {netId _actor == ""}
                    || {netId _actor in _exits}
                    || {(_x select 5) isNotEqualTo [] && {!((_x select 5) in _entries)}}) exitWith {_valid=false};
                _exits set [netId _actor,+_x];
            } forEach (_received select 1);
            if (!_valid) exitWith {false};
            // One bounded CHECK -> PUBLIC conversion validates the same row types,
            // geometry shapes, explicit retry flag and original clocks. No source mutation.
            private _candidate=createHashMapFromArray [
                ["building",_job getOrDefault ["building",objNull]],
                ["buildingTransform",_job getOrDefault ["buildingTransform",[]]],
                ["hardDeadline",_job getOrDefault ["hardDeadline",-1]],
                ["visitContext",_context],["earlyExits",_exits]];
            private _encoded=["PUBLIC",_candidate] call CBE_fnc_BuildingEarlyExitJournal;
            count _encoded == 2
        };
        false
    };
    _accepted
};
if (!(_mode in ["PUBLIC","CAPTURE"])) exitWith {[]};
private _result=[];
isNil {
    _result=call {
        private _context=_job getOrDefault ["visitContext",[]];
        private _building=_job getOrDefault ["building",objNull];
        private _transform=_job getOrDefault ["buildingTransform",[]];
        private _hard=_job getOrDefault ["hardDeadline",-1];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
        private _optionalVector={_this isEqualType [] && {_this isEqualTo [] || {_this call _vector}}};
        if (!(_building isEqualType objNull) || {isNull _building}
            || {!(_hard isEqualType 0)} || {!finite _hard} || {_hard < 0}
            || {!(_transform isEqualType [])} || {count _transform != 4}
            || {(_transform select [0,3]) findIf {!(_x call _vector)} >= 0}
            || {!((_transform select 3) isEqualType 0)} || {!finite (_transform select 3)}
            || {(_transform select 3) <= 0}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {(_context select 0) isNotEqualTo _building} || {(_context select 1) isNotEqualTo _transform}
            || {(_context select 2) isNotEqualTo _hard}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}) exitWith {[]};
        private _exits=_job getOrDefault ["earlyExits",false];
        if (!(_exits isEqualType createHashMap) || {count _exits > 8}) exitWith {[]};
        private _rows=[];private _keyedRows=[];private _valid=true;
        {
            private _key=_x;private _row=_exits get _key;
            if (!(_key isEqualType "") || {_key == ""} || {!(_row isEqualType [])}
                || {count _row != 7}
                || {[0,1,2,3,4,5,6] findIf {isNil {_row select _x}} >= 0}) exitWith {_valid=false};
            _row params ["_actor","_target","_until","_state","_retry","_entry","_watch"];
            if (!(_actor isEqualType objNull) || {!isNull _actor && {netId _actor isNotEqualTo _key}}
                || {!(_target call _vector)} || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0}
                || {!(_state in ["MOVING","ARRIVED","FAILED","DIVERTED"])}
                || {!(_retry isEqualType true)} || {!(_entry call _optionalVector)} || {!(_watch call _optionalVector)}
                || {(_entry isEqualTo []) isNotEqualTo (_watch isEqualTo [])}) exitWith {_valid=false};
            private _copy=[_actor,+_target,_until,_state,_retry,+_entry,+_watch];
            _rows pushBack _copy;_keyedRows pushBack [_key,_copy];
        } forEach keys _exits;
        if (!_valid) exitWith {[]};
        private _contextCopy=[_context select 0,(_context select 1) apply {if (_x isEqualType []) then {+_x} else {_x}},_context select 2,_context select 3];
        if (_mode == "PUBLIC") exitWith {[_contextCopy,_rows]};
        private _motion=_job getOrDefault ["earlyExitMotion",false];
        private _views=_job getOrDefault ["earlyExitViewChecks",false];
        private _cursor=_job getOrDefault ["earlyExitViewCursor",-1];
        if ([_motion,_views] findIf {!(_x isEqualType createHashMap) || {count _x > 64}} >= 0
            || {!(_cursor isEqualType 0)} || {!finite _cursor} || {_cursor < 0} || {_cursor != floor _cursor}) exitWith {[]};
        private _motionRows=[];private _viewRows=[];
        {
            private _row=_motion get _x;
            if (!(_x isEqualType "") || {_x == ""} || {!(_row isEqualType [])} || {count _row != 2}
                || {!((_row select 0) call _vector)} || {!((_row select 1) isEqualType 0)}
                || {!finite (_row select 1)} || {(_row select 1) < 0}) exitWith {_valid=false};
            _motionRows pushBack [_x,[+(_row select 0),_row select 1]];
        } forEach keys _motion;
        if (!_valid) exitWith {[]};
        {
            private _row=_views get _x;
            if (!(_x isEqualType "") || {_x == ""} || {!(_row isEqualType [])} || {count _row != 2}
                || {_row findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
                || {(_row select 0) < 0} || {(_row select 1) < -1}) exitWith {_valid=false};
            _viewRows pushBack [_x,+_row];
        } forEach keys _views;
        if (!_valid) exitWith {[]};
        [1,_contextCopy,_keyedRows,_motionRows,_viewRows,_cursor]
    };
    false
};
_result
