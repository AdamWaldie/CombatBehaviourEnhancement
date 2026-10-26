/*
 * Author: WaldoTheWarfighter
 * Purpose: Copy original actor setting baselines and clearance motion at the fenced producer.
 * Locality/authority: Read-only local metadata after actual group locality loss. Requires the
 * original BuildingProducerContext FROZEN fence and acknowledged original registration.
 * Never reads nonlocal native settings/destinations or grants incoming actor readiness.
 * Repeat/JIP: No mutation, command, timer, query, clock renewal or replay. At most64 unique
 * current/original-team actors and two canonical properties each. Unknown/deleted identity
 * refuses; absence is explicit. Canonical context, baseline, applied value and server retry
 * timestamp remain original; foreign setting issuers are copied, never claimed as clearance.
 * Arguments: 0 job HASHMAP default empty.
 * Return: ARRAY [1,visitContext,actorRows,originalRegistration] or[] on refusal.
 * Row [originalNetId,actor,canonicalSettingRows,motion,mirrorRows]. Canonical rows preserve
 * [context,[property,baseline,applied] rows,retryAtServer]. Mirrors retain [name,present,value].
 * Current callers: CortexLocality outgoing checkpoint before private producer retirement.
 * Example: private _actors=[_job] call CBE_fnc_BuildingActorJournal;
 */
params [["_job",createHashMap,[createHashMap]]];
private _result=[];
isNil {
    _result=call {
        if !(["FROZEN",_job] call CBE_fnc_BuildingProducerContext) exitWith {[]};
        private _group=_job get "group";
        private _visit=_job get "visitContext";
        private _registration=_job getOrDefault ["producerRegistration",[]];
        if (!(_registration isEqualType []) || {count _registration != 7}
            || {[0,1,2,3,4,5,6] findIf {isNil {_registration select _x}} >= 0}
            || {(_registration select [0,6]) isNotEqualTo [_group,clientOwner,_visit,
                _job get "ownerEpoch",_job get "generation",_job get "operationGeneration"]}) exitWith {[]};
        private _team=_job getOrDefault ["team",false];
        if (!(_team isEqualType []) || {count _team > 64}) exitWith {[]};
        private _actors=+_team;
        {_actors pushBackUnique _x} forEach units _group;
        if (count _actors > 64) exitWith {[]};
        private _vector={_this isEqualType [] && {count _this == 3}
            && {_this findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} < 0}};
        private _value={
            params ["_property","_data"];
            if (_property == "STANCE") exitWith {_data isEqualType "" && {_data in ["AUTO","UP","MIDDLE","DOWN"]}};
            _property == "SPEED" && {_data isEqualType 0} && {finite _data} && {_data == -1 || {_data >= 0}}
        };
        private _copyVisit={params ["_source"];[_source select 0,(_source select 1) apply {+_x},_source select 2,_source select 3]};
        private _copiedVisit=[_visit] call _copyVisit;
        private _rows=[];private _keys=[];private _valid=true;
        {
            private _actor=_x;
            if (isNil "_actor" || {!(_actor isEqualType objNull)} || {isNull _actor}) exitWith {_valid=false};
            private _key=netId _actor;
            if (_key in ["","0:0"] || {_key in _keys}) exitWith {_valid=false};
            _keys pushBack _key;
            private _canonical=_actor getVariable ["CBE_ActorSettings",[]];
            private _settings=[];
            if (!(_canonical isEqualType []) || {!(count _canonical in [0,3])}) exitWith {_valid=false};
            if (_canonical isNotEqualTo []) then {
                if ([0,1,2] findIf {isNil {_canonical select _x}} >= 0) exitWith {_valid=false};
                _canonical params ["_context","_owned","_retryAt"];
                if (!(_context isEqualType []) || {count _context != 5}
                    || {[0,1,2,3,4] findIf {isNil {_context select _x}} >= 0}
                    || {!((_context select 0) isEqualType grpNull)} || {isNull (_context select 0)}
                    || {!((_context select 1) isEqualType "")} || {(_context select 1) == ""}
                    || {[2,3] findIf {!((_context select _x) isEqualType 0) || {!finite (_context select _x)}
                        || {(_context select _x) < 0} || {(_context select _x) != floor (_context select _x)}} >= 0}
                    || {!((_context select 4) isEqualType 0)} || {!finite (_context select 4)} || {(_context select 4) < 0}
                    || {!(_retryAt isEqualType 0)} || {!finite _retryAt} || {_retryAt < 0}
                    || {!(_owned isEqualType createHashMap)} || {count _owned < 1} || {count _owned > 2}
                    || {keys _owned findIf {!(_x in ["STANCE","SPEED"])} >= 0}) exitWith {_valid=false};
                private _properties=[];
                {
                    private _property=_x;
                    if (_property in _owned) then {
                        private _pair=_owned get _property;
                        if (!(_pair isEqualType []) || {count _pair != 2}
                            || {[0,1] findIf {isNil {_pair select _x}} >= 0}
                            || {!([_property,_pair select 0] call _value)}
                            || {!([_property,_pair select 1] call _value)}) exitWith {_valid=false};
                        _properties pushBack [_property,_pair select 0,_pair select 1];
                    };
                } forEach ["STANCE","SPEED"];
                if (!_valid) exitWith {};
                _settings=[+_context,_properties,_retryAt];
            };
            if (!_valid) exitWith {};
            private _mirrors=[];
            {
                private _name=_x;
                private _present=!isNil {_actor getVariable _name};
                private _mirror=if (_present) then {_actor getVariable _name} else {[]};
                if (_present && {if (_name in ["CBE_Cortex_ClearStance","CBE_Cortex_ClearSettingToken"]) then {
                    !(_mirror isEqualType "")
                } else {!(_mirror isEqualType 0) || {!finite _mirror}}}) exitWith {_valid=false};
                _mirrors pushBack [_name,_present,_mirror];
            } forEach ["CBE_Cortex_ClearStance","CBE_Cortex_ClearForcedSpeed",
                "CBE_Cortex_ClearAppliedSpeed","CBE_Cortex_ClearSettingToken"];
            if (!_valid || {_settings isEqualTo [] && {_mirrors findIf {_x select 1} >= 0}}) exitWith {_valid=false};
            private _motion=_actor getVariable ["CBE_Cortex_ClearMotion",[]];
            private _copiedMotion=[];
            if (!(_motion isEqualType []) || {!(count _motion in [0,5])}) exitWith {_valid=false};
            if (_motion isNotEqualTo []) then {
                if ([0,1,2,3,4] findIf {isNil {_motion select _x}} >= 0
                    || {(_motion select 0) isNotEqualTo _group} || {(_motion select 1) isNotEqualTo _visit}
                    || {!((_motion select 2) in ["MOVE","HOLD"])} || {!((_motion select 3) call _vector)}
                    || {!((_motion select 4) isEqualType [])} || {!(count (_motion select 4) in [0,3])}) exitWith {_valid=false};
                private _triple=_motion select 4;
                if (_triple isNotEqualTo [] && {[0,1,2] findIf {isNil {_triple select _x}} >= 0
                    || {!( ["STANCE",_triple select 0] call _value)}
                    || {!( ["SPEED",_triple select 1] call _value)} || {!( ["SPEED",_triple select 2] call _value)}}) exitWith {_valid=false};
                _copiedMotion=[_group,[_visit] call _copyVisit,_motion select 2,+(_motion select 3),+_triple];
            };
            if (!_valid) exitWith {};
            _rows pushBack [_key,_actor,_settings,_copiedMotion,_mirrors];
        } forEach _actors;
        if (!_valid) exitWith {[]};
        private _copiedRegistration=+_registration;
        _copiedRegistration set [2,[_visit] call _copyVisit];
        [1,_copiedVisit,_rows,_copiedRegistration]
    };
    false
};
_result
