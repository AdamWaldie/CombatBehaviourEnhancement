/*
 * Author: WaldoTheWarfighter
 * Gives capable dismounts one short move clear of vehicles, using cover during contact, then returns them to ordinary AI.
 * Locality/authority: orders execute only on each passenger owner, using the server's frozen halt report.
 * Repeat/JIP: public per-unit deadlines and destinations survive HC migration; release/resume clears this order.
 * Cover selection excludes only matching, unexpired convoy-revision destinations.
 * Release recalls only a matching 3D destination receipt; nearby successor destinations survive.
 * New native tasks and live actor reservations retire only convoy bookkeeping; no follow command overrides them.
 * Arguments: 0: convoy group <GROUP>; 1: ordered configuration <ARRAY>; 2: cleanup only <BOOL>, false.
 * Arguments: 3: full reservation cargo <ARRAY>, [] uses configuration cargo; read-only exclusion roster.
 * Return Value: Nothing. At most two new cover searches per convoy/owner/five-second crew step.
 * Current callers: ConvoyCrewLocal and ConvoySync cleanup.
 * Example: [_group, _configuration] call CBE_fnc_ConvoyDismountLocal;
 */
params ["_group", "_configuration", ["_cleanup", false, [true]],["_reservationCargo",[],[[]]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
_configuration params ["_revision", "", "", "", "", "_phase", "_cargo", "", ["_reason", "MANUAL"], ["_threat", []], ["_deadline", 0]];
private _budget = 2;
private _reserved = [];
if (_reservationCargo isEqualTo []) then {_reservationCargo=_cargo};
{
    private _job = (_x select 0) getVariable ["CBE_Convoy_Dismount", []];
    if (count _job == 4 && {(_job select 0) == _group} && {(_job select 1) == _revision}
        && {serverTime < (_job select 2)} && {(_job select 3) isNotEqualTo []}) then {_reserved pushBack (_job select 3)};
} forEach _reservationCargo;
{
    _x params ["_unit", "_vehicle"];
    if (local _unit && {!isPlayer _unit}) then {
        private _job = _unit getVariable ["CBE_Convoy_Dismount", []];
        private _ours = count _job == 4 && {(_job select 0) == _group} && {(_job select 1) == _revision};
        private _capable = alive _unit && {!(_unit getVariable ["ACE_isUnconscious", false])} && {lifeState _unit != "INCAPACITATED"};
        // Passenger cover is a temporary convoy-owned order. The common handover helper protects a
        // Zeus/player/specialist order on any member of this passenger group from a later convoy
        // release or remount cleanup, while this local flag still honours an explicit CBE disable.
        private _command=toUpperANSI currentCommand _unit;
        private _ownedExit=_ours && {_command == "GET OUT"} && {vehicle _unit == _vehicle}
            && {(_job select 3) isEqualTo []};
        private _nativeTask=!_ownedExit && {_command in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]};
        private _actorMove=_unit getVariable ["CBE_Cortex_ActorMove",[]];
        private _reservedMove=count _actorMove == 3 && {(_actorMove param [2,-1,[0]]) > time};
        private _operator = _nativeTask || {_reservedMove}
            || {[group _unit,false,_unit] call CBE_fnc_CortexExternalTakeover}
            || {"ALL" in ((group _unit) getVariable ["CBE_AIPass_DisabledFeatures",[]])};
        private _end = _cleanup || {!([group _unit,"CBE_Convoy_Cover_Enable",true] call CBE_fnc_CortexFeatureEnabled)} || {!([_group,"CBE_Convoy_Cover_Enable",true] call CBE_fnc_CortexFeatureEnabled)} || {_phase != "HALT"} || {serverTime >= _deadline}
            || {_operator} || {!_capable} || {vehicle _unit != _unit && {vehicle _unit != _vehicle || {_ours && {(_job select 3) isNotEqualTo []}}}};
        if (_end) then {
            if (_ours) then {
                private _destination = _job select 3;
                if (!_operator && {_capable} && {vehicle _unit == _unit} && {_destination isNotEqualTo []}
                    && {currentCommand _unit in ["MOVE","STOP",""]}
                    && {private _live=(expectedDestination _unit) param [0,[]];
                        count _live == 3 && {count _destination == 3} && {_live vectorDistance _destination <= 0.25}}) then {_unit doFollow leader group _unit};
                _unit setVariable ["CBE_Convoy_Dismount", nil, true];
                _unit setVariable ["CBE_Convoy_DismountApplied", nil];
            };
        } else {
            // CrewLocal creates this record before unassigning the passenger, protecting the handoff to cover.
            if (_ours && {vehicle _unit == _unit}) then {
                private _destination = _job select 3;
                if (_destination isEqualTo [] && {_budget > 0}) then {
                    _budget = _budget - 1;
                    private _anchor = getPosATL _unit;
                    if (_threat isNotEqualTo []) then {
                        private _away = _threat getDir _anchor;
                        private _search = _anchor getPos [8, _away + ((_forEachIndex mod 5) - 2) * 20];
                        ([_search, _threat, 12, _reserved, _group] call CBE_fnc_CortexFindCover) params ["_cover", "_found"];
                        if (_found && {_unit distance2D _cover <= 25} && {_vehicle distance2D _cover >= 6}) then {_destination = _cover};
                    };
                    // Without verified cover, disperse a short distance. Do not claim the fallback is protected.
                    if (_destination isEqualTo []) then {
                        private _bearing = if (_threat isEqualTo []) then {(_forEachIndex * 137) mod 360} else {(_threat getDir _anchor) + ((_forEachIndex mod 5) - 2) * 20};
                        private _candidate = (_anchor getPos [10, _bearing]) findEmptyPosition [0, 3, typeOf _unit];
                        if (_candidate isNotEqualTo [] && {!surfaceIsWater _candidate} && {!isOnRoad _candidate}
                            && {_reserved findIf {_x distance2D _candidate < 2} < 0} && {_vehicle distance2D _candidate >= 6}) then {_destination = _candidate};
                    };
                    if (_destination isEqualTo []) then {
                        // One search attempt per passenger; ordinary AI handles an obstructed dismount area.
                        _unit setVariable ["CBE_Convoy_Dismount", nil, true];
                    } else {
                        _job set [3, _destination];
                        _unit setVariable ["CBE_Convoy_Dismount", _job, true];
                        _reserved pushBack _destination;
                    };
                };
                if (_destination isNotEqualTo [] && {_unit distance2D _destination > 3}
                    && {(_unit getVariable ["CBE_Convoy_DismountApplied", []]) isNotEqualTo [_group, _revision, _destination]}
                    && {!([group _unit] call CBE_fnc_CortexExternalTakeover)}) then {
                    _unit doMove _destination;
                    _unit setVariable ["CBE_Convoy_DismountApplied", [_group, _revision, _destination]];
                };
            };
        };
    };
} forEach _cargo;
