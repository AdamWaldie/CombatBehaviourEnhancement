/*
 * Author: WaldoTheWarfighter
 * Native flight, hidden actors and simulation dormancy veto recruitment and native commands.
 * Recruitment also respects unresolved flight journals and existing native MOVE/STOP orders.
 * An empty gunner seat with a living incoming assignment is not available. Discovery inspects
 * at most16 nearby static candidates; final unscheduled admission rechecks the original route,
 * epoch/operation, actor command and seat before assignment/boarding/publication.
 * A newer STOP yields cleanup without native unassign/GetOut writes.
 * A later native MOVE or changed FOLLOW anchor also yields without those writes. The original
 * observed follow anchor is captured once at admission; missing history never authorizes recall.
 * Exact original assignedVehicleRole, issuing clientOwner and locality epoch are also required
 * before native release. Same-vehicle role changes or owner migration retire metadata only;
 * no new owner reconstructs boarding authority from the old public journal.
 * Fresh crew selection prefers the nearest eligible RIFLE, then AT, then MG, then MEDIC.
 * Vanilla/ACE medical identity takes precedence over a dual MG/AT loadout for this choice.
 * At most64 nearest eligible actors are classified, once per fresh contact attempt; no role is excluded.
 * Purpose: Give one otherwise uncommitted infantry actor a finite chance to occupy a nearby useful
 * empty static weapon during confirmed contact, without taking the squad's movement operation. If
 * no existing emplacement is available, delegates compatible carried weapon bags to the finite
 * physical deployment state.
 * Locality / Authority: Runs on the current group owner. It issues a gunner assignment only to one
 * local AI actor and never moves, creates, repairs, rearms, teleports or changes the static weapon.
 * Repeat/JIP: One contact-episode lease records the exact actor, weapon and assignment. A contact is
 * sampled once after an eligible actor is available; temporary actor reservations remain retryable.
 * Failed physical attempts are not retried until a later contact. Locality change
 * discards engine commands and lets the new owner reassess. Cleanup cancels only CBE's exact still-
 * matching assignment; Zeus, player, specialist, medical, equipment and newer actor movement ownership are never overwritten.
 * Arguments: 0 group <GROUP>; 1 group state <HASHMAP>; 2 known enemies <ARRAY>.
 * 3 release only <BOOL>, false; 4 yield during release <BOOL>, false. Release-only never discovers
 * or advances a weapon/deployment; it retires just this emplacement assignment.
 * Return Value: STRING - DISABLED, IDLE, MOVING, ACTIVE, FAILED or YIELDED.
 * Current callers: CBE_fnc_CortexGroupTick during CONTACT; CortexRestoreCalm for release-only cleanup.
 * Example: [group player, [group player] call CBE_fnc_CortexGroupState, []] call CBE_fnc_CortexStaticSupport;
 */

params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_enemies",[],[[]]],["_releaseOnly",false,[true]],["_releaseExternal",false,[true]]];
if (isNull _group || {!local _group}) exitWith {"YIELDED"};
private _lease=_group getVariable ["CBE_Danger_StaticSupport",[]];
private _clearActorMove={
    params ["_actor"];
    if (!isNull _actor && {local _actor}) then {
        private _actorMove=_actor getVariable ["CBE_Cortex_ActorMove",[]];
        if (count _lease >= 7 && {(_lease select 1) == _actor}
            && {count _actorMove == 3} && {(_actorMove select 0) == "STATIC_SUPPORT"}
            && {(_actorMove select 2) == (_lease select 4)}) then {
            _actor setVariable ["CBE_Cortex_ActorMove",nil];
        };
    };
};
// This transaction never issues doMove or doFollow. A reported MOVE therefore belongs
// to another native task. Only the original observed FOLLOW anchor may remain while
// the one boarding order starts; missing history or a changed anchor grants no cleanup.
private _nativeMovementChanged={
    params ["_actor"];
    if (isNull _actor) exitWith {false};
    private _command=toUpperANSI currentCommand _actor;
    private _originalFollow=_lease param [7,objNull,[objNull]];
    _command == "MOVE" || {_command == "FOLLOW" && {
        isNull _originalFollow || {formLeader _actor != _originalFollow}
    }}
};
// A vehicle match alone cannot own a later cargo/turret reassignment. The original
// issuing machine, locality epoch and actual gunner role are sampled once after
// assignAsGunner; neither active observation nor a new owner can mint this receipt.
private _assignmentOwned={
    params ["_actor","_weapon"];
    private _receipt=_lease param [8,[],[[]]];
    if (isNull _actor || {isNull _weapon} || {count _receipt != 3}) exitWith {false};
    private _role=_receipt param [2,[],[[]]];
    (_receipt param [0,-1,[0]]) == clientOwner
        && {(_receipt param [1,-1,[0]]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {toUpperANSI (_role param [0,"",[""]]) in ["GUNNER","TURRET"]}
        && {assignedVehicle _actor == _weapon}
        && {assignedVehicleRole _actor isEqualTo _role}
};
private _release={
    params ["_external"];
    if (count _lease >= 7) then {
        private _actor=_lease param [1,objNull,[objNull]];
        private _weapon=_lease param [2,objNull,[objNull]];
        private _command=toUpperANSI currentCommand _actor;
        private _ownedBoarding=_command == "GET IN" && {!isNull _weapon}
            && {[_actor,_weapon] call _assignmentOwned};
        private _protectedTask=([_actor] call _nativeMovementChanged) || {!_ownedBoarding && {_command in ["STOP","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}};
        private _actorMove=_actor getVariable ["CBE_Cortex_ActorMove",[]];
        private _newMove=count _actorMove == 3 && {(_actorMove param [2,-1,[0]]) > time}
            && {(_actorMove select 0) != "STATIC_SUPPORT" || {(_actorMove select 2) != (_lease select 4)}};
        [_actor] call _clearActorMove;
        if (!_external && {!_protectedTask} && {!_newMove} && {!isNull _actor} && {alive _actor} && {local _actor}
            && {!isPlayer _actor} && {group _actor == _group}
            && {[_actor] call CBE_fnc_CortexCombatEffective}
            && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!fleeing _actor}
            && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
            && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
            && {[_actor,_weapon] call _assignmentOwned}) then {
            [_actor] orderGetIn false;
            unassignVehicle _actor;
            if (vehicle _actor == _weapon) then {_actor action ["GetOut",_weapon]};
        };
    };
    _group setVariable ["CBE_Danger_StaticSupport",nil,true];
};

// Both contact and CALM teardown share the same actor-task and assignment protections.
// Release-only is evaluated before feature gates, deployment and opportunity discovery.
if (_releaseOnly) exitWith {
    [_releaseExternal || {count _lease >= 7 && {[_group] call CBE_fnc_CortexExternalTakeover}}] call _release;
    "IDLE"
};

private _enabled=missionNamespace getVariable ["CBE_AIPass_Active",false]
    && {[_group,"CBE_AIPass_StaticSupport_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _external=[_group] call CBE_fnc_CortexExternalTakeover;
private _phase=toUpperANSI (_state getOrDefault ["phase","CALM"]);
private _holdFire=combatMode _group in ["BLUE","GREEN"];
if (!_enabled || {_phase != "CONTACT"} || {_holdFire} || {_enemies isEqualTo []} || {_external}) exitWith {
    [_external] call _release;
    // SECURITY owns the finite packing decision. A contact callback observing that transition
    // must not retire the carried deployment through this wrapper's default no-pack call.
    // Explicit disable, hold-fire and external takeover still clean up immediately.
    if (!(_phase == "SECURITY" && {_enabled} && {!_holdFire} && {!_external})) then {
        [_group,_state,[]] call CBE_fnc_CortexStaticDeployStep;
    };
    ["IDLE","YIELDED"] select _external
};

private _episode=_state getOrDefault ["phaseStart",time];
if ((_group getVariable ["CBE_Danger_StaticDeployment",[]]) isNotEqualTo []) exitWith {
    [_group,_state,_enemies] call CBE_fnc_CortexStaticDeployStep
};
if (count _lease >= 7) exitWith {
    _lease params ["_leaseEpisode","_actor","_weapon","_issuedAt","_deadline","_status","_startPosition"];
    if (!isNull _actor && {alive _actor} && {local _actor} && {!isNull _weapon}
        && {!([_actor,_weapon] call _assignmentOwned)}) exitWith {
        [true] call _release;
        "YIELDED"
    };
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _operationConflict=count _operation > 0 && {
        (_operation getOrDefault ["intent",""]) in ["WITHDRAW","VEHICLE_WITHDRAW"]
            || {_actor in (_operation getOrDefault ["participants",[]])}
    };
    if ([_actor] call _nativeMovementChanged || {_operationConflict} || {!isNull _actor && {fleeing _actor || {!simulationEnabled _actor} || {isObjectHidden _actor}}}
        || {!isNull _actor && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}}
        || {!isNull _actor && {currentCommand _actor in ["STOP","GET OUT","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED"]}}) exitWith {
        [true] call _release;
        "YIELDED"
    };
    if (!isNull _actor && {[_actor] call CBE_fnc_CompatibilityExternalControl}) exitWith {
        [true] call _release;
        "YIELDED"
    };
    if (_leaseEpisode != _episode || {isNull _actor} || {!alive _actor} || {!local _actor}
        || {isPlayer _actor} || {group _actor != _group} || {isNull _weapon} || {!alive _weapon}
        || {!(simulationEnabled _weapon)} || {isObjectHidden _weapon} || {assignedVehicle _actor != _weapon && {vehicle _actor != _weapon}}) exitWith {
        [false] call _release;
        "FAILED"
    };
    if (vehicle _actor == _weapon && {gunner _weapon == _actor}) exitWith {
        [_actor] call _clearActorMove;
        if (_status != "ACTIVE") then {
            _lease set [5,"ACTIVE"];
            _group setVariable ["CBE_Danger_StaticSupport",_lease,true];
        };
        "ACTIVE"
    };
    if (time >= _deadline) exitWith {
        [false] call _release;
        _group setVariable ["CBE_Danger_StaticAttempt",[_episode,"FAILED",serverTime],true];
        "FAILED"
    };
    "MOVING"
};

private _attempt=_group getVariable ["CBE_Danger_StaticAttempt",[]];
if ((_attempt param [0,-1,[0]]) == _episode) exitWith {_attempt param [1,"IDLE",[""]]};
// An existing group operation already owns its participant set. Static support is selected before a
// new manoeuvre starts and then composes beside it; it never removes an actor from a live operation.
if (count (_group getVariable ["CBE_Operation",createHashMap]) > 0) exitWith {
    // Temporary operation ownership is not a failed contact-episode attempt.
    "IDLE"
};
// Retry temporary reservations without repeatedly scanning nearby world objects.
// Existing seat/deployment leases were advanced above; only new opportunity discovery backs off.
private _retry=_group getVariable ["CBE_Danger_StaticRetry",[]];
if (count _retry == 2 && {(_retry select 0) == _episode} && {time < (_retry select 1)}) exitWith {"IDLE"};
private _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _anchor) then {_anchor=leader _group};
if (isNull _anchor) exitWith {"IDLE"};
// Preserve a native incoming gunner even before that actor reaches the weapon.
// Native fullCrew includes the assignment separately from actual seat occupancy.
private _seatAvailable={
    params ["_weapon"];
    private _seats=fullCrew [_weapon,"gunner",true];
    count _seats == 1 && {
        private _row=_seats select 0;
        count _row >= 6 && {isNull (_row select 0)} && {
            private _incoming=_row select 5;
            isNull _incoming || {!alive _incoming}
        }
    }
};
private _orderReceipt=[_group] call CBE_fnc_NativeOrderReceipt;
private _admissionEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _admissionGeneration=_group getVariable ["CBE_OperationGeneration",0];
private _sideIndex=switch (side _group) do {case west:{1}; case east:{0}; case independent:{2}; default {3}};
private _weapons=((nearestObjects [_anchor,["StaticWeapon"],75,true]) select [0,16]) select {
    // canFire requires an operator and cannot qualify an empty emplacement.
    alive _x && {simulationEnabled _x} && {!isObjectHidden _x} && {damage _x < 0.9} && {someAmmo _x}
        && {_x emptyPositions "gunner" > 0}
        && {crew _x isEqualTo []} && {locked _x < 2}
        && {getNumber (configOf _x >> "side") in [_sideIndex,3]}
        && {[_x] call _seatAvailable}
};
if (_weapons isEqualTo []) exitWith {
    private _deploy=[_group,_state,_enemies] call CBE_fnc_CortexStaticDeployStep;
    // Deployment owns its active phases; only terminal outcomes belong in this parent cache.
    if (_deploy in ["FAILED","NO_PRIMARY_BAG","NO_BASE_BAG","NO_SAFE_SECTOR"]) then {
        _group setVariable ["CBE_Danger_StaticAttempt",[_episode,_deploy,serverTime],true];
    } else {
        if (_deploy in ["IDLE","YIELDED"]) then {
            _group setVariable ["CBE_Danger_StaticRetry",[_episode,time+3]];
        };
    };
    _deploy
};
private _rankedWeapons=_weapons apply {[_anchor distance2D _x,_x]};
_rankedWeapons sort true;
private _weapon=(_rankedWeapons select 0) select 1;
private _candidates=(units _group) select {
    alive _x && {local _x} && {!isPlayer _x} && {_x != leader _group}
        && {simulationEnabled _x} && {!isObjectHidden _x} && {!fleeing _x}
        && {[_x] call CBE_fnc_CortexCombatEffective}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []} && {vehicle _x == _x}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
        && {isNull assignedVehicle _x}
        // Native contact commands such as TARGET and WATCH are transient observations, not an
        // external movement owner. Reject only concrete actor tasks which boarding would actually
        // interrupt; the group-level Zeus/mission-order gate above already protects authored work.
        && {!(toUpperANSI (currentCommand _x) in ["STOP","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
        && {(_x getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
        && {currentCommand _x != "MOVE"}
};
if (_candidates isEqualTo []) exitWith {
    private _potential=(units _group) findIf {
        alive _x && {local _x} && {!isPlayer _x} && {_x != leader _group}
            && {[_x] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _x}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
    } >= 0;
    if (_potential) exitWith {
        _group setVariable ["CBE_Danger_StaticRetry",[_episode,time+3]];
        "IDLE"
    };
    _group setVariable ["CBE_Danger_StaticAttempt",[_episode,"NO_ACTOR",serverTime],true];
    "IDLE"
};
private _rankedActors=_candidates apply {[_x distance2D _weapon,_x]};
_rankedActors sort true;
private _actor=(_rankedActors select 0) select 1;
// Keep scarce foot roles available when an eligible rifleman can crew the weapon.
// Inspect only the nearest64 eligible actors once per fresh contact attempt. Distance
// breaks ties within a role, and the nearest rifleman ends the pass immediately.
private _bestRolePriority=5;
{
    private _candidate=_x select 1;
    private _medic=_candidate getUnitTrait "Medic"
        || {(_candidate getVariable ["ace_medical_medicClass",0]) > 0};
    private _role=if (_medic) then {"MEDIC"} else {[_candidate] call CBE_fnc_CortexUnitRole};
    private _priority=switch (_role) do {
        case "RIFLE": {0};
        case "AT": {1};
        case "MG": {2};
        case "MEDIC": {3};
        default {4};
    };
    if (_priority < _bestRolePriority) then {_actor=_candidate;_bestRolePriority=_priority};
    if (_priority == 0) exitWith {};
} forEach (_rankedActors select [0,64]);
private _deadline=time+20;
private _commandReceipt=currentCommand _actor;
private _followReceipt=if (_commandReceipt == "FOLLOW") then {formLeader _actor} else {objNull};
private _issued=false;
isNil {
    if (!local _group || {!local _actor} || {group _actor != _group}
        || {!([_actor] call CBE_fnc_CortexCombatEffective)} || {isPlayer _actor}
        || {!simulationEnabled _actor} || {isObjectHidden _actor} || {fleeing _actor}
        || {currentCommand _actor != _commandReceipt}
        || {_commandReceipt == "FOLLOW" && {isNull _followReceipt || {formLeader _actor != _followReceipt}}}
        || {_commandReceipt in ["MOVE","STOP","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}
        || {!isNull assignedVehicle _actor} || {!isNull objectParent _actor}
        || {[_actor] call CBE_fnc_CortexActorMoveReserved}
        || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
        || {[_actor] call CBE_fnc_CompatibilityExternalControl}
        || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {!([_group,"CBE_AIPass_StaticSupport_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {_admissionEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {_admissionGeneration != (_group getVariable ["CBE_OperationGeneration",0])}
        || {_orderReceipt isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
        || {(_state getOrDefault ["phase",""]) != "CONTACT"}
        || {(_state getOrDefault ["phaseStart",-1]) != _episode}
        || {!alive _weapon} || {!simulationEnabled _weapon} || {isObjectHidden _weapon}
        || {crew _weapon isNotEqualTo []} || {locked _weapon >= 2}
        || {!([_weapon] call _seatAvailable)}) exitWith {};
    _actor assignAsGunner _weapon;
    private _assignmentReceipt=[clientOwner,_admissionEpoch,+(assignedVehicleRole _actor)];
    [_actor] orderGetIn true;
    _actor setVariable ["CBE_Cortex_ActorMove",["STATIC_SUPPORT",getPosATL _weapon,_deadline]];
    _lease=[_episode,_actor,_weapon,time,_deadline,"MOVING",getPosATL _actor,_followReceipt,_assignmentReceipt];
    _group setVariable ["CBE_Danger_StaticSupport",_lease,true];
    _group setVariable ["CBE_Danger_StaticAttempt",[_episode,"MOVING",serverTime],true];
    _issued=true;
};
if (!_issued) exitWith {
    _group setVariable ["CBE_Danger_StaticRetry",[_episode,time+3]];
    "IDLE"
};
"MOVING"
