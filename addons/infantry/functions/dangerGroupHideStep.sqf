/*
 * Author: WaldoTheWarfighter
 * Native initialization data waits and delayed search retain planner ownership.
 * Shared movement reservations include unresolved flight/naval cleanup; only a typed cover
 * lease without either pending journal permits restoration during reserved movement.
 * Native fleeing blocks both new weak posture and restoration; unchanged proof defers
 * through the finite actor cleanup instead of overwriting the native flight response.
 * New posture admission preserves native INIT/PLANNING/REPLAN movement preparation.
 * Purpose: Apply or release one finite squad-level low-profile response after immediate incoming danger without taking movement, target or firing ownership.
 * Locality / Authority: Runs only on the owner of the local AI group from the existing group-brain step. It changes weak stance only for local, idle, ordinary on-foot actors not reserved by another CBE operation.
 * Selection inspects at most 64 group members and applies posture to at most four actors.
 * Cleanup may restore its exact weak posture during ordinary movement or a CBE cover route;
 * it does not change that route. Starting a new group posture requires a stationary actor; native combat remains available.
 * Repeat/JIP: One generation-owned group lease records each actor's prior and applied weak stance, operation generation and owner epoch. Repeated calls retain that lease; release restores only an unchanged CBE-applied stance. Zeus, player, specialist, locality and newer-generation handover discard the lease without writing over the new owner.
 * Arguments: 0: group <GROUP>, grpNull; 1: danger generation <NUMBER>, -1; 2: active <BOOL>, false; 3: cause <STRING>, ""; 4: immediate observer <OBJECT>, objNull, excluded from new support posture leases.
 * Arguments: 5 optional release actor OBJECT objNull; with active=false, relinquish only that actor.
 * Return Value: BOOL - normal mode: leases remain active; release-actor mode: that actor retired/absent.
 * A blocked or unconfirmed actor release retains its row and refuses the incoming task.
 * Current callers: CBE_fnc_CortexGroupTick, CBE_fnc_CortexReleaseGroup and CBE_fnc_DangerSetup and IndoorActorOperation START.
 * Example: [group player,group player getVariable ["CBE_Danger_Generation",0],true,"HIT"] call CBE_fnc_DangerGroupHideStep;
 */

params [
    ["_group",grpNull,[grpNull]],
    ["_generation",-1,[0]],
    ["_active",false,[true]],
    ["_cause","",[""]],
    ["_observer",objNull,[objNull]],
    ["_releaseActor",objNull,[objNull]]
];
if (isNull _group) exitWith {false};

private _leases=_group getVariable ["CBE_Danger_GroupHideLeases",[]];
private _external=!local _group
    || {[_group] call CBE_fnc_CortexExternalTakeover}
    || {[_group] call CBE_fnc_CortexZeusHeld};
private _sameOwner={
    params ["_proof"];
    count _proof == 6 && {(_proof select 4) isEqualTo (_group getVariable ["CBE_OperationGeneration",0])
        && {(_proof select 5) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}}
};
private _mayRestore={
    params ["_proof"];
    private _unit=_proof param [0,objNull,[objNull]];
    private _move=_unit getVariable ["CBE_Cortex_ActorMove",[]];
    private _postureFree=!([_unit] call CBE_fnc_CortexActorMoveReserved);
    // Only a typed cover lease permits restoration during owned movement. Pending
    // flight/naval native cleanup still wins even when its ordinary marker is absent.
    if (!_postureFree && {_move isEqualType []} && {count _move == 3}
        && {(_move select 0) isEqualTo "DANGER_COVER"}
        && {(_move select 1) isEqualType []} && {count (_move select 1) == 3}
        && {(_move select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {(_move select 2) isEqualType 0} && {finite (_move select 2)}
        && {(_unit getVariable ["CBE_Danger_FlightLease",[]]) isEqualTo []}
        && {(_unit getVariable ["CBE_Cortex_NavalEgressMove",[]]) isEqualTo []}) then {
        _postureFree=true;
    };
    [_proof] call _sameOwner
        && {isNull remoteControlled _unit}
        && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
        && {[_unit] call CBE_fnc_CortexCombatEffective}
        && {simulationEnabled _unit} && {!isObjectHidden _unit} && {!fleeing _unit}
        && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {currentCommand _unit in ["","MOVE","ATTACK","FIRE","SUPPRESS"]}
        && {_postureFree}
        && {(_unit getVariable ["CBE_Danger_EngineStanceLease",[]]) isEqualTo []}
};
// Group posture can end while treatment/rearm/reservation blocks restoration. Transfer
// only unchanged same-owner proof to the existing actor cleanup; never replace its lease.
// The first transfer starts one finite restoration window, not another danger action.
private _deferRestore={
    params ["_proof"];
    private _unit=_proof param [0,objNull,[objNull]];
    private _prior=_proof param [1,"",[""]];private _applied=_proof param [2,"",[""]];
    if ([_proof] call _sameOwner && {!isNull _unit} && {local _unit} && {alive _unit}
        && {!isPlayer _unit} && {group _unit == _group} && {isNull objectParent _unit}
        && {isNull remoteControlled _unit} && {[_unit] call CBE_fnc_CortexExternalOwner == ""}
        && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
        && {_prior in ["AUTO","UP","MIDDLE","DOWN"]} && {_applied in ["AUTO","UP","MIDDLE","DOWN"]}
        && {_prior != _applied} && {toUpperANSI unitPos _unit == _applied}
        && {(_unit getVariable ["CBE_Danger_EngineStanceLease",[]]) isEqualTo []}) then {
        _unit setVariable ["CBE_Danger_EngineStanceLease",[_prior,_applied,time,
            _proof select 4,_proof select 5,_group]];
        [_unit] call CBE_fnc_DangerEngineRelease;
    };
};
// Individual handover leaves other soldiers' posture untouched. It uses the same
// exact owner/native-value rules as group cleanup, before the new task reserves movement.
if (!isNull _releaseActor) exitWith {
    private _released=false;
    isNil {
        _released=call {
            if (_active || {!local _group} || {!local _releaseActor} || {group _releaseActor != _group}
                || {[_group] call CBE_fnc_CortexExternalTakeover} || {[_group] call CBE_fnc_CortexZeusHeld}
                || {(_group getVariable ["CBE_Danger_GroupHideLeases",[]]) isNotEqualTo _leases}) exitWith {false};
            private _index=_leases findIf {(_x param [0,objNull,[objNull]]) isEqualTo _releaseActor};
            if (_index < 0) exitWith {true};
            private _proof=_leases select _index;
            if (count _proof != 6 || {isPlayer _releaseActor} || {!isNull objectParent _releaseActor}
                || {!([_releaseActor] call CBE_fnc_CortexCombatEffective)}
                || {[_releaseActor] call CBE_fnc_CompatibilityExternalControl}) exitWith {false};
            private _prior=_proof param [1,"",[""]];
            private _applied=_proof param [2,"",[""]];
            if (!(_prior in ["AUTO","UP","MIDDLE","DOWN"])
                || {!(_applied in ["AUTO","UP","MIDDLE","DOWN"])}) exitWith {false};
            if (toUpperANSI unitPos _releaseActor == _applied) then {
                if ([_proof] call _mayRestore) then {_releaseActor setUnitPosWeak _prior};
            };
            // Changed native stance is preserved. An unchanged un-restored value is pending.
            if (_prior != _applied && {toUpperANSI unitPos _releaseActor == _applied}) exitWith {false};
            private _remaining=+_leases;
            _remaining deleteAt _index;
            _group setVariable ["CBE_Danger_GroupHideLeases",_remaining];
            true
        };
    };
    _released
};
private _release={
    if (!_external) then {
        {
            _x params ["_unit","_prior","_applied"];
            if ([_x] call _mayRestore && {!isNull _unit} && {alive _unit} && {local _unit} && {!isPlayer _unit}
                && {group _unit == _group} && {isNull objectParent _unit}
                && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
                && {toUpperANSI (unitPos _unit) == _applied}) then {
                _unit setUnitPosWeak _prior;
            };
            [_x] call _deferRestore;
        } forEach _leases;
    };
    _group setVariable ["CBE_Danger_GroupHideLeases",nil];
    false
};

if (!_active || {_external}
    || {_generation != (_group getVariable ["CBE_Danger_Generation",0])}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {call _release};

if (_leases isNotEqualTo []) exitWith {
    {
        _x params ["_unit","_prior","_applied","_leaseGeneration"];
        // Generation replacement ends this finite posture. Dropping its record alone left
        // the old weak stance behind and made the next generation capture it as its baseline.
        if (_leaseGeneration != _generation && {[_x] call _mayRestore} && {!isNull _unit} && {alive _unit}
            && {local _unit} && {!isPlayer _unit} && {group _unit == _group}
            && {isNull objectParent _unit} && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
            && {toUpperANSI (unitPos _unit) == _applied}) then {
            _unit setUnitPosWeak _prior;
        };
        if (_leaseGeneration != _generation) then {[_x] call _deferRestore};
    } forEach _leases;
    private _valid=_leases select {
        _x params ["_unit","_prior","_applied","_leaseGeneration"];
        !isNull _unit && {alive _unit} && {local _unit} && {!isPlayer _unit}
            && {isNull remoteControlled _unit} && {group _unit == _group} && {isNull objectParent _unit}
            && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
            && {[_x] call _sameOwner} && {[_unit] call CBE_fnc_CortexCombatEffective}
            && {_leaseGeneration == _generation} && {toUpperANSI (unitPos _unit) == _applied}
    };
    if (count _valid != count _leases) then {
        // A newer actor-level or external stance decision invalidates only that actor's proof of
        // ownership. Retain the remaining exact leases without reapplying or expanding the set.
        _group setVariable ["CBE_Danger_GroupHideLeases",_valid];
    };
    _valid isNotEqualTo []
};

private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _reserved=if (count _operation > 0) then {
    (_operation getOrDefault ["participants",[]]) + (_operation getOrDefault ["unavailable",[]])
} else {[]};
private _members=(units _group) select [0,64];
private _candidates=_members select {
    _x != _observer && {local _x} && {alive _x} && {!isPlayer _x} && {isNull remoteControlled _x} && {isNull objectParent _x}
        && {[_x] call CBE_fnc_CortexCombatEffective}
        && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!(_x in _reserved)}
        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {simulationEnabled _x} && {!isObjectHidden _x} && {!fleeing _x}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {currentCommand _x in ["","ATTACK","FIRE","SUPPRESS"]}
        && {abs (speed _x) <= 0.5}
        && {!(getUnitState _x in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"])}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
        && {(_x getVariable ["CBE_Danger_EngineStanceLease",[]]) isEqualTo []}
};
// Preserve the squad's immediate anti-armour and anti-air answer. A low-profile danger response
// must not select the only launcher-capable actor merely because that actor appears early in group
// order. Rank ordinary riflemen first, then medics and automatic riflemen, and keep leaders plus
// loaded AT/AA gunners as the final fallback. The fallback still matters for very small specialist
// teams, where a finite weak stance is safer than manufacturing a movement response.
private _ranked=[];
{
    private _role=[_x] call CBE_fnc_CortexUnitRole;
    private _capabilities=[_x] call CBE_fnc_CortexCapabilities;
    private _readinessCost=switch (true) do {
        case (_capabilities isNotEqualTo []): {30};
        case (_role == "LEADER"): {20};
        case (_role == "MG"): {10};
        case (_role == "MEDIC"): {5};
        default {0};
    };
    _ranked pushBack [_readinessCost,_forEachIndex,_x];
} forEach _candidates;
_ranked sort true;
_candidates=_ranked apply {_x select 2};
// Bound work and avoid turning a whole platoon prone on one callback. Up to four idle actors lower
// their profile; active movers, native tasks and operation participants continue uninterrupted.
_candidates resize ((count _candidates) min 4);
private _newLeases=[];
{
    private _prior=toUpperANSI (unitPos _x);
    private _applied=["MIDDLE","DOWN"] select (getSuppression _x > 0.55 && {_cause in ["HIT","SUPPRESSED"]});
    if (_prior != _applied) then {
        _x setUnitPosWeak _applied;
        if (toUpperANSI unitPos _x == _applied) then {
            _newLeases pushBack [_x,_prior,_applied,_generation,
                _group getVariable ["CBE_OperationGeneration",0],_group getVariable ["CBE_AIPass_Epoch",0]];
        };
    };
} forEach _candidates;
if (_newLeases isEqualTo []) exitWith {false};
_group setVariable ["CBE_Danger_GroupHideLeases",_newLeases];
private _stats=_group getVariable ["CBE_Danger_EngineStats",createHashMap];
_stats set ["groupHideResponses",((_stats getOrDefault ["groupHideResponses",0])+1) min 100000];
_stats set ["lastGroupHideActors",_newLeases apply {_x select 0}];
_group setVariable ["CBE_Danger_EngineStats",_stats];
true
