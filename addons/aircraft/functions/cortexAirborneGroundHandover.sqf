/*
 * Author: WaldoTheWarfighter
 * Purpose: Form grounded original cargo into an independent squad when its aircraft crew
 * remains in the original group. This is an intentional post-insertion group change.
 * Locality/authority: Current insertion group owner and local passengers only. Remote calls
 * refuse. Admission, group creation and the native join run unscheduled in one bounded call.
 * At most64 original passengers; no world scan or new movement controller.
 * Repeat/JIP: The original episode and owner epoch bind the one-shot job receipt. JIP sees
 * passive group/result metadata only. Actual join acknowledgements are checked; partial joins
 * are retained and reported without rollback or another split. Empty failed groups are deleted.
 * Group-bound posture/pace receipts defer the join until existing exact cleanup retires them.
 * Protected native tasks defer group transfer; tasks raised by join handlers prevent SAD/brain startup.
 * Creation-handler changes to original passenger commands/destinations/form leaders prevent joining.
 * Job-local withdrawnCrew retains positively observed original passenger-to-crew transfers;
 * those actors never join this old insertion, even if subsequently returned to cargo.
 * Original crew, later arrivals and departed passengers never join. No actor is relocated,
 * re-equipped, revealed, force-seated or assigned new skills. Source flight waypoints are untouched.
 * Arguments: 0 insertion job HASHMAP, empty. Requires group/aircraft/episode/jumpers/target/deadline.
 * Return: ARRAY [status STRING, ground group GROUP, acknowledged actors ARRAY, brain live BOOL].
 * Status NOT_REQUIRED keeps cargo-only groups unchanged; DEFERRED waits within the original
 * insertion deadline. ASSIGNED proves group/waypoint assignment, not travel or combat success.
 * HANDED_OVER means every cargo actor joined and an existing authored ground route was retained.
 * PARTIAL retains the actual new squad and exposes an incomplete handover; no repeated join.
 * Current callers: CortexAirborneDropStep LAND on the owning shared scheduler.
 * Example: private _result=[_insertionJob] call CBE_fnc_CortexAirborneGroundHandover;
 */
params [["_job",createHashMap,[createHashMap]]];
private _handoverResult=["DEFERRED",grpNull,[],false];
isNil {
_handoverResult=call {
    private _group=_job getOrDefault ["group",grpNull];
    private _episode=_job getOrDefault ["episode",[]];
    private _aircraft=_job getOrDefault ["aircraft",objNull];
    private _deadline=_job getOrDefault ["deadline",-1];
    if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
        || {_episode isEqualTo []} || {_episode isNotEqualTo (_group getVariable ["CBE_AIPass_DropEpisode",[]])}
        || {(_job getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {!(_deadline isEqualType 0)} || {!finite _deadline} || {time >= _deadline}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}
        || {!(_job getOrDefault ["forced",false]) && {!([_group,"CBE_AIPass_Airborne_Enable",false] call CBE_fnc_CortexFeatureEnabled)}}) exitWith {["DEFERRED",grpNull,[],false]};
    private _previous=_job getOrDefault ["groundHandover",[]];
    if (_previous isNotEqualTo []) exitWith {+_previous};
    if (!([_group] call CBE_fnc_CortexIsEligible)) exitWith {["DEFERRED",grpNull,[],false]};
    private _roster=_job getOrDefault ["jumpers",[]];
    if (!(_roster isEqualType []) || {count _roster > 64}
        || {_roster findIf {!(_x isEqualType objNull)} >= 0}
        || {count (_roster arrayIntersect _roster) != count _roster}) exitWith {["DEFERRED",grpNull,[],false]};
    private _withdrawn=_job getOrDefault ["withdrawnCrew",[]];
    if (!(_withdrawn isEqualType []) || {count _withdrawn > 64}
        || {_withdrawn findIf {!(_x in _roster)} >= 0}) exitWith {["DEFERRED",grpNull,[],false]};
    _roster=_roster-_withdrawn;
    private _cargo=_roster select {alive _x && {group _x == _group}};
    if (_cargo isEqualTo []) exitWith {["NOT_REQUIRED",grpNull,[],false]};
    // Operating crew is distinct from cargo and person-turret/FFV passengers.
    private _mixed=!isNull _aircraft && {(fullCrew _aircraft) findIf {
        private _crewActor=_x select 0;
        alive _crewActor && {group _crewActor == _group} && {!(_crewActor in _roster)}
            && {toLowerANSI (_x select 1) != "cargo"} && {!(_x select 4)}
    } >= 0};
    if (!_mixed) exitWith {["NOT_REQUIRED",grpNull,[],false]};
    private _protectedCommands=["STOP","GET IN","GET OUT","ACTION","HEAL","REARM","JOIN",
            "REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID",
            "HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"];
    private _cargoReady={
        private _groupContext=[_group] call CBE_fnc_IndoorActorGroupContext;
        if (_groupContext isEqualTo []) exitWith {false};
        _cargo findIf {
        !local _x || {group _x != _group} || {!simulationEnabled _x} || {isObjectHidden _x}
        || {!isNull objectParent _x} || {!isTouchingGround _x}
        || {!([_x] call CBE_fnc_CortexCombatEffective)} || {fleeing _x}
        || {behaviour _x == "CARELESS"}
        || {(_x getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
        || {(_x getVariable ["CBE_ParachuteDeploy",[]]) isNotEqualTo []}
        || {[_x] call CBE_fnc_CortexActorMoveReserved}
        // A group change must not orphan the old group's exact restoration proof.
        || {(_x getVariable ["CBE_Danger_EngineStanceLease",[]]) isNotEqualTo []}
        || {(_x getVariable ["CBE_Danger_AttackPace",[]]) isNotEqualTo []}
        || {(_x getVariable ["CBE_Cortex_StanceReceipt",[]]) isNotEqualTo []}
        || {!([_x,_groupContext] call CBE_fnc_IndoorActorGroupAvailable)}
        || {toUpperANSI currentCommand _x in _protectedCommands}
        } < 0
    };
    if !(call _cargoReady) exitWith {["DEFERRED",grpNull,[],false]};
    private _target=_job getOrDefault ["target",[]];
    if (!(_target isEqualType []) || {!(count _target in [2,3])}
        || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {["DEFERRED",grpNull,[],false]};
    // Search the ground area below the insertion belief, not its aircraft/floor altitude.
    _target=(_target select [0,2])+[0];
    // Native mission handlers run synchronously during group creation. A newly
    // issued MOVE need not change feature/operation ownership, so bind its footprint too.
    private _cargoNative=_cargo apply {[_x,currentCommand _x,+(expectedDestination _x),formLeader _x]};
    private _ground=createGroup [side _group,true];
    if (isNull _ground) exitWith {["DEFERRED",grpNull,[],false]};
    // Publish a one-shot receipt before join can raise native group-change events.
    private _result=["PARTIAL",_ground,[],false];
    _job set ["groundHandover",_result];
    _ground setVariable ["CBE_Airborne_Origin",[_group,+_episode],true];
    if (!local _ground || {units _ground isNotEqualTo []} || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {[_ground] call CBE_fnc_CortexExternalTakeover}) exitWith {
        if (local _ground && {units _ground isEqualTo []}) then {deleteGroup _ground};
        _result
    };
    // Copy intent only, never transient FSMs, leases, checkpoints or flight waypoints.
    {
        private _value=_group getVariable _x;
        if (!isNil "_value" && {isNil {_ground getVariable _x}}) then {
            if (_value isEqualType []) then {_value=+_value};
            _ground setVariable [_x,_value,true];
        };
    } forEach ["CBE_AIPass_Profile","CBE_AIPass_DisabledFeatures","CBE_AI_Exclude","CBE_AIPass_Exclude",
        "Waldo_Headless_ExcludeGroup","acex_headless_blacklist"];
    // A creation handler supplying an authored ground route also owns its native
    // posture. Without that route, inherit the source's hold-fire/pace intent.
    if (count waypoints _ground <= 1) then {
        _ground setCombatMode (combatMode _group);
        _ground setCombatBehaviour (combatBehaviour _group);
        _ground setSpeedMode (speedMode _group);
        _ground setFormation (formation _group);
    };
    // GroupCreated mission handlers can synchronously replace authority; recheck before join.
    if (!local _group || {units _ground isNotEqualTo []} || {_episode isNotEqualTo (_group getVariable ["CBE_AIPass_DropEpisode",[]])}
        || {(_job get "ownerEpoch") != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {!([_group] call CBE_fnc_CortexIsEligible)} || {!(call _cargoReady)}
        || {_cargoNative findIf {
            _x params ["_actor","_command","_destination","_leader"];
            currentCommand _actor != _command || {(expectedDestination _actor) isNotEqualTo _destination}
                || {formLeader _actor != _leader}
        } >= 0}) exitWith {
        if (local _ground && {units _ground isEqualTo []}) then {deleteGroup _ground};
        _result
    };
    _cargo joinSilent _ground;
    private _joined=_cargo select {group _x == _ground};
    _result set [2,+_joined];
    if (_joined isEqualTo []) exitWith {
        if (local _ground && {units _ground isEqualTo []}) then {deleteGroup _ground};
        _group setVariable ["CBE_Airborne_GroundHandover",[+_episode,"PARTIAL",_ground,[],serverTime,false],true];
        _result
    };
    if (local _ground && {(units _ground) findIf {!(_x in _joined)} < 0}
        && {_joined findIf {toUpperANSI currentCommand _x in _protectedCommands} < 0}
        && {(_ground getVariable ["CBE_Airborne_Origin",[]]) isEqualTo [_group,_episode]}
        && {[_ground,false,true] call CBE_fnc_CortexIsEligible}) then {
        // Index zero is the engine initial waypoint. Added mission routes retain
        // their selected node and activation semantics; never append/select our SAD over them.
        if (count waypoints _ground > 1) then {
            if (count _joined == count _cargo) then {_result set [0,"HANDED_OVER"]};
        } else {
            private _waypoint=_ground addWaypoint [+_target,30];
            _waypoint setWaypointType "SAD";
            _ground setCurrentWaypoint _waypoint;
            if (count _joined == count _cargo && {waypointType _waypoint == "SAD"}
                && {currentWaypoint _ground == (_waypoint select 1)}) then {_result set [0,"ASSIGNED"]};
        };
        _result set [3,[_ground,true] call CBE_fnc_GroupBrainStart];
    };
    _group setVariable ["CBE_Airborne_GroundHandover",[+_episode,_result select 0,_ground,+_joined,serverTime,_result select 3],true];
    diag_log format ["[CBE] Airborne ground squad %1: source=%2 group=%3 joined=%4/%5 brainLive=%6. Assignment is not combat completion.",
        _result select 0,_group,_ground,count _joined,count _cargo,_result select 3];
    _result
};
};
_handoverResult
