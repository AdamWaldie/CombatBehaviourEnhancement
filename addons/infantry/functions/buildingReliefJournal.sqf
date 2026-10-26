/*
 * Author: WaldoTheWarfighter
 * Purpose: Validate/copy the original private finite casualty-relief attempt receipt.
 * Locality/authority: Pure data conversion. Caller owns preparation, current live work
 * or exact fenced source capture. No casualty/native/arrival or incoming authority.
 * Repeat/JIP: No mutation, command, query, timer or budget/deadline renewal. Empty
 * known receipt is distinct from absent/invalid[]. Old expired attempts remain spent.
 * Arguments: 0 job HASHMAP default empty; includes original reliefReceipt and context.
 * Return: ARRAY[visitContext,at most8 five-field attempts], or[] on refusal.
 * Current callers: CortexClearBuilding preflight/preparation, BuildingOperationStep
 * new-attempt admission and CortexLocality outgoing capture. Never native replay.
 * Example: private _receipt=[_job] call CBE_fnc_BuildingReliefJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        private _context=_job getOrDefault ["visitContext",[]];
        private _building=_job getOrDefault ["building",objNull];
        private _transform=_job getOrDefault ["buildingTransform",[]];
        private _hard=_job getOrDefault ["hardDeadline",-1];
        private _source=_job getOrDefault ["reliefReceipt",[]];
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} < 0}};
        if (!(_building isEqualType objNull) || {isNull _building}
            || {!(_hard isEqualType 0)} || {!finite _hard} || {_hard < 0}
            || {!(_transform isEqualType [])} || {count _transform != 3}
            || {_transform findIf {!(_x call _vector)} >= 0}
            || {!(_context isEqualType [])} || {count _context != 4}
            || {[0,1,2,3] findIf {isNil {_context select _x}} >= 0}
            || {(_context select 0) isNotEqualTo _building} || {(_context select 1) isNotEqualTo _transform}
            || {(_context select 2) isNotEqualTo _hard}
            || {!((_context select 3) isEqualType "")} || {(_context select 3) == ""}
            || {!(_source isEqualType [])} || {count _source != 2}
            || {isNil {_source select 0}} || {isNil {_source select 1}}
            || {(_source select 0) isNotEqualTo _context}
            || {!((_source select 1) isEqualType [])} || {count (_source select 1) > 8}) exitWith {[]};
        private _contextCopy=[_context select 0,(_context select 1) apply {+_x},_context select 2,_context select 3];
        if ((_source select 1) isEqualTo []) exitWith {[_contextCopy,[]]};
        private _entries=_job getOrDefault ["securityEntries",[]];
        if (!(_entries isEqualType []) || {count _entries > 16}) exitWith {[]};
        private _nativeValid={
            private _native=_this;
            _native isEqualType [] && {count _native in [0,3]} && {
                _native isEqualTo [] || {
                    [0,1,2] findIf {isNil {_native select _x}} < 0
                        && {(_native select 0) isEqualType ""} && {(_native select 2) isEqualType objNull}
                        && {private _destination=_native select 1;
                            _destination isEqualType [] && {count _destination == 3}
                                && {[0,1,2] findIf {isNil {_destination select _x}} < 0}
                                && {(_destination select 0) call _vector}
                                && {(_destination select 1) isEqualType ""}
                                && {(_destination select 2) isEqualType true}}
                }
            }
        };
        private _rows=[];private _workers=[];private _guards=[];private _valid=true;
        {
            private _row=_x;
            if (!(_row isEqualType []) || {count _row != 5}
                || {[0,1,2,3,4] findIf {isNil {_row select _x}} >= 0}) exitWith {_valid=false};
            _row params ["_worker","_guard","_exit","_until","_binding"];
            if (!(_worker isEqualType "") || {_worker in ["","0:0"]} || {_worker in _workers}
                || {!(_guard isEqualType "")} || {_guard in ["","0:0"]} || {_guard in _guards}
                || {!(_exit call _vector)} || {!(_exit in _entries)}
                || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0} || {_until > _hard}
                || {!(_binding isEqualType [])} || {count _binding != 5}
                || {[0,1,2,3,4] findIf {isNil {_binding select _x}} >= 0}) exitWith {_valid=false};
            _binding params ["_pair","_slot","_member","_stage","_native"];
            if (!(_pair isEqualType 0) || {!finite _pair} || {_pair != floor _pair} || {_pair < -1} || {_pair > 7}
                || {!(_slot isEqualType 0)} || {!(_slot in [0,1])} || {!(_member isEqualType objNull)}
                || {!(_stage isEqualType [])} || {count _stage != 7}
                || {[0,1,2,3,4,5,6] findIf {isNil {_stage select _x}} >= 0}
                || {!((_stage select 0) call _vector)} || {!((_stage select 1) isEqualType true)}
                || {!((_stage select 2) isEqualType "")} || {(_stage select 2) != "ARRIVED"}
                || {!((_stage select 3) isEqualType 0)}
                || {!finite (_stage select 3)} || {(_stage select 3) < 0}
                || {!((_stage select 4) isEqualType [])}
                || {(_stage select 4) isNotEqualTo [] && {!((_stage select 4) call _vector)}}
                || {(_stage select 5) isNotEqualTo _exit} || {!((_stage select 6) isEqualType true)}
                || {!(_native call _nativeValid)}) exitWith {_valid=false};
            private _stageCopy=+_stage;
            {_stageCopy set [_x,+(_stage select _x)]} forEach [0,4,5];
            private _nativeCopy=if (_native isEqualTo []) then {[]} else {
                [_native select 0,[+((_native select 1) select 0),(_native select 1) select 1,(_native select 1) select 2],_native select 2]
            };
            _workers pushBack _worker;_guards pushBack _guard;
            _rows pushBack [_worker,_guard,+_exit,_until,[_pair,_slot,_member,_stageCopy,_nativeCopy]];
        } forEach (_source select 1);
        if (!_valid) exitWith {[]};
        [_contextCopy,_rows]
    };
    false
};
_result
