/*
 * Author: WaldoTheWarfighter
 * Same-owner released queue-abort STOP cleanup may adopt this controlled epoch edge after exact baseline/native validation; no movement is issued here.
 * Finite individual indoor tasks retire their exact-owned native legs before other group cleanup.
 * A terminal post-clear hold remains cleanup work even after the active task/state is gone.
 * Stops Cortex on this machine and hands every affected group back to its own orders.
 *
 * Removes tactical event handlers and discards tactical jobs. Exact finite stance cleanup
 * survives the controlled same-owner epoch edge with its original expiry; no tactics restart.
 * The shared scheduler and skill jobs
 * remain while skill adjustment is enabled. Every locally managed
 * group is released (CBE_fnc_CortexReleaseGroup): drills end with only the AI features they
 * disabled re-enabled, pass waypoints are removed, behaviour and speed are restored and COMPAT group AI
 * is handed back. Survivors still walking to a host get doFollow. Defence, garrison and clear
 * orders are released on their owner so restarting cannot revive an order superseded while off.
 * Completed merges and surrenders are not undone.
 * Locality and authority: a direct server call requests disable through the CBA server layer.
 * CBA callbacks clean up on each owner; joining owners receive the disabled value from CBA.
 * Remote calls from anything other than the server are refused. Each machine handles its local groups.
 *
 * Repeat/JIP: Repeat calls clear pending startup and abandoned jobs. Owner-local release clears
 * public defence/garrison assignments and restores only Cortex-owned movement restrictions.
 * Restart and ownership adoption cannot replay cancelled orders; tracked aircraft handlers are removed.
 * Public support request/responder state, delayed artillery-relocation tokens and attack-run
 * presentation state are invalidated. An active aircraft lease restores its recorded native group
 * attack policy, deletes its finite native guidance target and named movement waypoint, and removes
 * its firing-solution telemetry and re-attack cooldown before the job is discarded.
 * Vehicle safe-stop retirement shares exact original crew and native-order proof, retaining unresolved evidence.
 * Vehicle safe-stop handshakes restore their prior forced speed only while their exact zero-speed
 * lease remains current; a newer vehicle controller's cap is preserved when tokens are cleared.
 * Ordinary driving FSM identities and terminal retry receipts are synchronously retired.
 * Ordinary unload-in-combat leases likewise restore only their exact unchanged applied value.
 * Vehicle cleanup runs on each actual owner, including interface owners before their early exit;
 * the server never clears a remote owner's restoration tokens in its vehicle pass.
 * Targetless onboard danger reports are also retracted before the scheduler is discarded.
 * Owner-local missile-warning generations are advanced before handlers are removed; an
 * old CBA callback cannot become valid again after a quick restart.
 * Civilian event handlers and their EntityCreated installer are removed; external addon state is
 * never cleared. external controller and COMPAT movement leases restore their captured baseline through group release.
 * Danger assessment: bounded member events use generation-scoped finite FSMs and only wake the existing
 * group decision job; handlers retire on membership/owner changes and shutdown. No second movement owner.
 *
 * Arguments: None.
 *
 * Return Value:
 * Nothing
 *
 * Example:
 * [] call CBE_fnc_CortexStop;
 * Result: no further pass behaviour runs anywhere until CBE_fnc_CortexInit is called again.
 *
 * Current callers: CBA setting callbacks.
 */

if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
if (isServer && {missionNamespace getVariable ["CBE_AIPass_Enable", false]}) exitWith {
    [createHashMapFromArray [["CBE_AIPass_Enable", false]]] call CBE_fnc_CortexTuning;
};
if (isServer) then {
    {
        private _job = _y;
        private _requester=_job getOrDefault ["requester",grpNull];
        if (!isNull _requester) then {
            private _brain=_requester getVariable ["CBE_Support_Brain",createHashMap];
            if (count _brain > 0) then {
                _brain set ["cancelled",true];
                _brain set ["cancelReason","CORTEX_STOPPED"];
            };
            _requester setVariable ["CBE_Cortex_SupportResponders",nil,true];
            _requester setVariable ["CBE_Cortex_SupportRequestState",nil,true];
        };
        {(_x select 0) setVariable ["CBE_AIPass_SupportLease",nil,true]} forEach (_job get "leases");
    } forEach (missionNamespace getVariable ["CBE_AIPass_SupportRequests",createHashMap]);
    missionNamespace setVariable ["CBE_AIPass_SupportRequests",createHashMap];
    missionNamespace setVariable ["CBE_AIPass_CounterGeneration", (missionNamespace getVariable ["CBE_AIPass_CounterGeneration", 0]) + 1,true];
    {missionNamespace setVariable [_x,(missionNamespace getVariable [_x,0])+1,true]}
        forEach ["CBE_ArtilleryScoot_SupportGeneration","CBE_ArtilleryScoot_CounterGeneration",
            "CBE_Artillery_SupportFireGeneration","CBE_Artillery_DangerFireGeneration","CBE_Artillery_SmokeFireGeneration"];
    {
        private _battery = _y get "battery";
        private _brain=_battery getVariable ["CBE_Artillery_Brain",createHashMap];
        if (count _brain > 0) then {
            _brain set ["cancelled",true];
            _brain set ["cancelReason","CORTEX_STOPPED"];
        };
        _battery setVariable ["CBE_AIPass_FireToken", nil, true];
        _battery setVariable ["CBE_AIPass_BusyUntil", nil, true];
    } forEach (missionNamespace getVariable ["CBE_AIPass_FireMissions", createHashMap]);
    missionNamespace setVariable ["CBE_AIPass_FireMissions", createHashMap];
    private _artilleryDeletedEH=missionNamespace getVariable ["CBE_Artillery_DeletedEH",-1];
    if (_artilleryDeletedEH >= 0) then {removeMissionEventHandler ["EntityDeleted",_artilleryDeletedEH]};
    missionNamespace setVariable ["CBE_Artillery_DeletedEH",nil];
};
// Each actual vehicle owner retires its own receipts before this machine discards tactics.
// Server-only token clearing could erase an HC owner's baseline before restoration. Interface
// owners participate before their early exit. This rare administrative pass adds no observer.
// Clearing an owned public token rejects its queued callbacks after Cortex restarts.
{
    private _vehicle=_x;
    isNil {
        if (!local _vehicle) exitWith {};
        private _stopProof=_vehicle getVariable ["CBE_Cortex_DismountStopReceipt",[]];
        private _stopGroup=if (_stopProof isEqualType [] && {count _stopProof == 8}
            && {(_stopProof select 0) isEqualType grpNull}) then {_stopProof select 0} else {group effectiveCommander _vehicle};
        [_vehicle,_stopGroup,"RELEASE",true] call CBE_fnc_CortexDismountStop;
        _vehicle setVariable ["CBE_Cortex_DismountStopRequest",nil,true];
        [_vehicle] call CBE_fnc_DrivingAssistRelease;
        _vehicle setVariable ["CBE_DrivingGate_Result",nil,true];
        _vehicle setVariable ["CBE_DrivingGate_Pending",nil,true];
        _vehicle setVariable ["CBE_DrivingGate_RequestState",nil];
        private _positionWork=_vehicle getVariable ["CBE_ArtilleryPosition_Work",createHashMap];
        if (count _positionWork > 0) then {
            [_vehicle,_positionWork get "token",_positionWork get "session",true] call CBE_fnc_CortexArtilleryPosition;
        };
        _vehicle setVariable ["CBE_ArtilleryPosition_Session",nil,true];
        _vehicle setVariable ["CBE_ArtilleryPosition_Attempt",nil,true];
        _vehicle setVariable ["CBE_ArtilleryPosition_Issued",nil,true];
        private _unloadLease=_vehicle getVariable ["CBE_Cortex_UnloadPolicyLease",[]];
        if (count _unloadLease == 5 && {local _vehicle}) then {
            [_vehicle,_unloadLease select 0,"RELEASE",true] call CBE_fnc_CortexVehicleUnloadPolicy;
        };
        _vehicle setVariable ["CBE_Cortex_OnboardDanger",nil,true];
        _vehicle setVariable ["CBE_Cortex_ArtilleryScootToken",nil,true];
        _vehicle setVariable ["CBE_Cortex_ArtilleryScootDeadline",nil,true];
        _vehicle setVariable ["CBE_Cortex_ArtilleryScootPurpose",nil,true];
        _vehicle setVariable ["CBE_Cortex_ArtilleryScootSession",nil,true];
        if (_vehicle isKindOf "Air") then {
            private _guidanceTarget=_vehicle getVariable ["CBE_Cortex_AirAttackGuidanceTarget",objNull];
            if (!isNull _guidanceTarget) then {deleteVehicle _guidanceTarget};
            _vehicle setVariable ["CBE_Cortex_AttackFlarePhase",nil,true];
            _vehicle setVariable ["CBE_Cortex_AttackFlareCooldown",nil,true];
            _vehicle setVariable ["CBE_Cortex_AirAttackPlan",nil,true];
            _vehicle setVariable ["CBE_Cortex_AirFireSolution",nil,true];
            _vehicle setVariable ["CBE_Cortex_AirAttackTarget",nil];
            _vehicle setVariable ["CBE_Cortex_AirAttackGuidedWeapon",nil];
            _vehicle setVariable ["CBE_Cortex_AirAttackGuidanceTarget",nil];
            _vehicle setVariable ["CBE_Cortex_AirAttackBlockedUntil",nil];
        };
    };
} forEach (vehicles select {local _x});
{[_x,true] call CBE_fnc_CortexAAObserve} forEach +(missionNamespace getVariable ["CBE_AA_ObservedVehicles",[]]);
missionNamespace setVariable ["CBE_AA_ObservedVehicles",[]];
if (hasInterface && {!isServer}) exitWith {};
missionNamespace setVariable ["CBE_AIPass_Active", false];
// Gate observation jobs never survive scheduler shutdown or replay a closure on restart.
if (isServer) then {
    missionNamespace setVariable ["CBE_DrivingGate_StopSerial",(missionNamespace getVariable ["CBE_DrivingGate_StopSerial",0])+1];
    {
        private _gate=_x getOrDefault ["gate",objNull];
        if (!isNull _gate && {(_gate getVariable ["CBE_DrivingGate_CloseWork",createHashMap]) isEqualTo _x}) then {
            _gate setVariable ["CBE_DrivingGate_CloseWork",nil];
            _gate setVariable ["CBE_DrivingGate_CloseResult",["STOPPED",serverTime,_x get "vehicle",_x get "until"],true];
        };
        _x set ["done",true];
    } forEach (missionNamespace getVariable ["CBE_DrivingGate_CloseJobs",[]]);
    missionNamespace setVariable ["CBE_DrivingGate_CloseJobs",[]];
};

missionNamespace setVariable ["CBE_AIPass_InitPending", false];

{
    private _handler = _x getVariable ["CBE_AIPass_FlaresHandler", -1];
    if (_handler >= 0) then {_x removeEventHandler ["IncomingMissile", _handler]};
    _x setVariable ["CBE_Cortex_FlareBurstGeneration",
        (_x getVariable ["CBE_Cortex_FlareBurstGeneration",0])+1];
    _x setVariable ["CBE_Cortex_MissileDefenceActive",nil];
    _x setVariable ["CBE_AIPass_FlaresHandler", nil];
    _x setVariable ["CBE_AIPass_FlaresInstalled", nil];
} forEach (missionNamespace getVariable ["CBE_AIPass_FlareVehicles", []]);
missionNamespace setVariable ["CBE_AIPass_FlareVehicles", []];

// Aircraft attack persistence now lives outside the recurring scheduler queue. Retire each local
// brain explicitly and let its bounded implementation perform the same owned-waypoint, handler,
// speed and operation cleanup it uses for every other authority loss.
{
    private _aircraft=_x;
    private _brain=_aircraft getVariable ["CBE_AirAttack_Brain",createHashMap];
    if (local _aircraft && {count _brain > 0}) then {
        _brain set ["cancelled",true];
        _brain set ["cancelReason","CORTEX_STOPPED"];
        private _attackJob=_brain getOrDefault ["job",createHashMap];
        if (count _attackJob > 0) then {[_attackJob] call CBE_fnc_CortexAirAttack};
        _aircraft setVariable ["CBE_AirAttack_BrainGeneration",(_aircraft getVariable ["CBE_AirAttack_BrainGeneration",0])+1];
        _aircraft setVariable ["CBE_AirAttack_Brain",nil];
        _aircraft setVariable ["CBE_AirAttack_Brain_FSM",nil];
        _aircraft setVariable ["CBE_Cortex_AirAttackJob",nil];
    };
} forEach (vehicles select {_x isKindOf "Air"});

{
    _x params ["_variable", "_event"];
    private _handler = missionNamespace getVariable _variable;
    if (!isNil "_handler") then {
        removeMissionEventHandler [_event, _handler];
        missionNamespace setVariable [_variable, nil];
    };
} forEach [
    ["CBE_AIPass_KilledHandler", "EntityKilled"],
    ["CBE_AIPass_ProjectileHandler", "ProjectileCreated"],
    ["CBE_AIPass_ArtilleryHandler", "ArtilleryShellFired"]
];
private _civilianCreated=missionNamespace getVariable "CBE_Cortex_CivilianCreatedHandler";
if (!isNil "_civilianCreated") then {
    removeMissionEventHandler ["EntityCreated",_civilianCreated];
    missionNamespace setVariable ["CBE_Cortex_CivilianCreatedHandler",nil];
};
{
    [_x,true] call CBE_fnc_CortexCivilianSetup;
    private _local=_x getVariable ["CBE_Cortex_CivilianLocalHandler",-1];
    if (_local >= 0) then {_x removeEventHandler ["Local",_local]};
    _x setVariable ["CBE_Cortex_CivilianLocalHandler",nil];
} forEach (allUnits select {side group _x == civilian});
{
    {
        private _point=_x getVariable ["CBE_PointActor_Brain",createHashMap];
        if (count _point > 0 || {(_x getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo []}) then {
            ["FINISH",_x,_point] call CBE_fnc_PointActorOperation;
        };
        private _indoor=_x getVariable ["CBE_IndoorActor_Brain",createHashMap];
        if (count _indoor > 0 || {(_x getVariable ["CBE_IndoorActor_Order",[]]) isNotEqualTo []}) then {
            ["FINISH",_x,_indoor] call CBE_fnc_IndoorActorOperation;
        };
    } forEach units _x;
    [_x,true] call CBE_fnc_CortexHearingLocal;
    [_x,true] call CBE_fnc_DangerSetup;
    private _drivingBrain=_x getVariable ["CBE_Driving_Brain",createHashMap];
    if (count _drivingBrain > 0) then {[_drivingBrain,"CORTEX_STOPPED"] call CBE_fnc_DrivingOperationFinish};
    _x setVariable ["CBE_Driving_Brain",nil];
    _x setVariable ["CBE_Driving_FSM",nil];
    private _brain=_x getVariable ["CBE_GroupBrain",createHashMap];
    if (count _brain > 0) then {
        _brain set ["cancelled",true];
        _brain set ["cancelReason","CORTEX_STOPPED"];
        _brain set ["wakeAt",time];
    };
    _x setVariable ["CBE_GroupBrain_Generation",(_x getVariable ["CBE_GroupBrain_Generation",0])+1];
    _x setVariable ["CBE_GroupBrain",nil];
    _x setVariable ["CBE_GroupBrain_FSM",nil];
    _x setVariable ["CBE_Cortex_GroupJob",nil];
    private _buildingBrain=_x getVariable ["CBE_BuildingBrain",createHashMap];
    if (count _buildingBrain > 0) then {
        _buildingBrain set ["cancelled",true];
        _buildingBrain set ["cancelReason","CORTEX_STOPPED"];
        _buildingBrain set ["completed",true];
    };
    _x setVariable ["CBE_BuildingBrain",nil];
    _x setVariable ["CBE_BuildingBrain_FSM",nil];
    if (local _x) then {_x setVariable ["CBE_AIPass_AreaReport",nil,true]};
    if (local _x && {count (_x getVariable ["CBE_AIPass_State", createHashMap]) > 0 || {_x getVariable ["CBE_AIPass_Managed", false]} || {(_x getVariable ["CBE_Cortex_Remount",[]]) isNotEqualTo []}
        || {(_x getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}
        || {(_x getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
        || {_x getVariable ["CBE_AIPass_ClearBuilding",false]}
        || {(_x getVariable ["CBE_Cortex_ClearHold",[]]) isNotEqualTo []}}) then {
        [_x,true,"CORTEX_STOPPED"] call CBE_fnc_CortexReleaseGroup;
    };
    if (local _x) then {
        [_x] call CBE_fnc_CortexDefendRelease;
        [_x] call CBE_fnc_CortexGarrisonRelease;
        [_x] call CBE_fnc_CortexClearRelease;
        _x setVariable ["CBE_Danger_BuildingClue",nil,true];
        _x setVariable ["CBE_Danger_BuildingClueSeen",nil,true];
        _x setVariable ["CBE_Danger_BuildingVisits",nil];
        _x setVariable ["CBE_Danger_Casualties",nil,true];
    };
    {
        private _unit = _x;
        {_unit removeEventHandler _x} forEach (_unit getVariable ["CBE_AIPass_GarrisonHandlerIds", []]);
        _unit setVariable ["CBE_AIPass_GarrisonHandlerIds", nil];
        _unit setVariable ["CBE_AIPass_GarrisonHandlers", nil];
        _unit setVariable ["CBE_AIPass_DuckUntil", nil];
    } forEach units _x;
    private _localHandler = _x getVariable ["CBE_AIPass_LocalHandler", -1];
    if (_localHandler >= 0) then {_x removeEventHandler ["Local", _localHandler]};
    _x setVariable ["CBE_AIPass_LocalHandler", nil];
    _x setVariable ["CBE_AIPass_Adopted", nil];
    private _stoppingGroup=_x;
    private _abortSourceOwner=[_stoppingGroup] call CBE_fnc_DrivingOwnerReceipt;
    private _postureOldEpoch=_stoppingGroup getVariable ["CBE_AIPass_Epoch",0];
    _x setVariable ["CBE_AIPass_Epoch", (_x getVariable ["CBE_AIPass_Epoch", 0]) + 1];
    // Carry only this same owner's finite terminal-hold retirement across the controlled stop edge.
    private _retireHold=_stoppingGroup getVariable ["CBE_Cortex_ClearHold",[]];
    private _retireWindow=_stoppingGroup getVariable ["CBE_Cortex_ClearHoldRetire",[]];
    if (local _stoppingGroup && {count _retireHold == 5} && {count _retireWindow == 4}
        && {(_retireHold select [0,2]) isEqualTo (_retireWindow select [0,2])}
        && {(_retireHold select 1) == _postureOldEpoch} && {(_retireWindow select 3) == clientOwner}
        && {serverTime < (_retireWindow select 2)}
        && {!([_stoppingGroup] call CBE_fnc_CortexExternalTakeover)}) then {
        _retireHold=+_retireHold;_retireWindow=+_retireWindow;
        _retireHold set [1,_stoppingGroup getVariable ["CBE_AIPass_Epoch",0]];
        _retireWindow set [1,_retireHold select 1];
        _stoppingGroup setVariable ["CBE_Cortex_ClearHold",_retireHold,true];
        _stoppingGroup setVariable ["CBE_Cortex_ClearHoldRetire",_retireWindow,true];
        [CBE_fnc_ClearHoldCleanupStep,createHashMapFromArray [["group",_stoppingGroup],
            ["ownerEpoch",_retireHold select 1],["generation",_retireHold select 0],
            ["window",+_retireWindow],["attempted",(_stoppingGroup getVariable ["CBE_Cortex_ClearHoldRetireAttempts",[]]) param [2,[]]],["subsystem","HOLD_CLEANUP"]],
            0.25,"CLEAR_HOLD_RETIRE"] call CBE_fnc_CortexQueueJob;
    };
    // This same-machine shutdown owns this epoch edge. Carry only exact deferred
    // weak-stance restoration, never an active danger response or tactical task.
    if (local _stoppingGroup && {!([_stoppingGroup] call CBE_fnc_CortexExternalTakeover)}
        && {!([_stoppingGroup] call CBE_fnc_CortexZeusHeld)}) then {
        private _garrisonCleanup=_stoppingGroup getVariable ["CBE_Cortex_GarrisonSettingsPending",[]];
        if (_garrisonCleanup isEqualType [] && {count _garrisonCleanup > 0} && {count _garrisonCleanup <= 64}) then {
            private _cleanupEpoch=_stoppingGroup getVariable ["CBE_AIPass_Epoch",0];
            [CBE_fnc_ActorSettingsCleanupStep,createHashMapFromArray [["group",_stoppingGroup],
                ["ownerEpoch",_cleanupEpoch],["generation",_cleanupEpoch],["kind","GARRISON"],
                ["subsystem","SETTINGS_CLEANUP"]],0.25,"GARRISON_SETTINGS"] call CBE_fnc_CortexQueueJob;
        };
        private _clearPending=_stoppingGroup getVariable ["CBE_Cortex_ClearSettingsPending",[]];
        if (_clearPending isEqualType [] && {count _clearPending == 4}
            && {[0,1,2,3] findIf {!((_clearPending select _x) isEqualType 0)
                || {!finite (_clearPending select _x)}} < 0}
            && {(_clearPending select 0) == (_stoppingGroup getVariable ["CBE_AIPass_ClearGeneration",-1])}
            && {(_clearPending select 1) == _postureOldEpoch} && {serverTime < (_clearPending select 2)}) then {
            private _carriedClear=+_clearPending;
            _carriedClear set [1,_stoppingGroup getVariable ["CBE_AIPass_Epoch",0]];
            _stoppingGroup setVariable ["CBE_Cortex_ClearSettingsPending",_carriedClear,true];
            [CBE_fnc_ActorSettingsCleanupStep,createHashMapFromArray [["group",_stoppingGroup],
                ["ownerEpoch",_carriedClear select 1],["generation",_carriedClear select 0],
                ["subsystem","SETTINGS_CLEANUP"]],0.25,"CLEAR_SETTINGS"] call CBE_fnc_CortexQueueJob;
        };
        private _posturePending=_stoppingGroup getVariable ["CBE_Danger_StancePendingActors",[]];
        if (_posturePending isEqualType [] && {count _posturePending <= 64}) then {
            {
                private _postureActor=_x;
                if (_postureActor isEqualType objNull) then {
                    private _postureProof=_postureActor getVariable ["CBE_Danger_EngineStanceLease",[]];
                    if (!isNull _postureActor && {local _postureActor} && {alive _postureActor}
                        && {!isPlayer _postureActor} && {group _postureActor == _stoppingGroup}
                        && {_postureProof isEqualType []} && {count _postureProof == 6}
                        && {(_postureProof select 0) in ["AUTO","UP","MIDDLE","DOWN"]}
                        && {(_postureProof select 1) in ["AUTO","UP","MIDDLE","DOWN"]}
                        && {(_postureProof select 2) isEqualType 0} && {finite (_postureProof select 2)}
                        && {time < (_postureProof select 2)+30}
                        && {(_postureProof select 3) == (_stoppingGroup getVariable ["CBE_OperationGeneration",0])}
                        && {(_postureProof select 4) isEqualTo _postureOldEpoch}
                        && {(_postureProof select 5) == _stoppingGroup}
                        && {toUpperANSI unitPos _postureActor == (_postureProof select 1)}
                        && {isNull remoteControlled _postureActor}
                        && {[_postureActor] call CBE_fnc_CortexExternalOwner == ""}
                        && {!([_postureActor] call CBE_fnc_CompatibilityExternalControl)}) then {
                        private _postureRebound=+_postureProof;
                        _postureRebound set [4,_stoppingGroup getVariable ["CBE_AIPass_Epoch",0]];
                        _postureActor setVariable ["CBE_Danger_EngineStanceLease",_postureRebound];
                        [_postureActor] call CBE_fnc_DangerEngineRelease;
                    };
                };
            } forEach +_posturePending;
        };
    };

    // Master stop owns this exact epoch edge. Retain only validated released STOP
    // cleanup on the same machine; no timer, command or deadline is restarted here.
    private _abortVehicles=[];
    {
        private _abortVehicle=vehicle _x;
        if (_abortVehicle != _x && {_abortVehicle isKindOf "LandVehicle"} && {!(_abortVehicle in _abortVehicles)}) then {
            _abortVehicles pushBack _abortVehicle;
            [_abortVehicle,_stoppingGroup,createHashMap,[],{false},_abortSourceOwner] call CBE_fnc_DrivingAbortHandback;
        };
    } forEach units _stoppingGroup;

} forEach allGroups;

private _jobs = (missionNamespace getVariable ["CBE_AIPass_Jobs", []]) + (missionNamespace getVariable ["CBE_AIPass_PendingJobs", []]);
{
    private _state=_x select 2;
    private _flareAircraft=_state getOrDefault ["aircraft",objNull];
    if (!isNull _flareAircraft) then {
        private _guidanceTarget=_flareAircraft getVariable ["CBE_Cortex_AirAttackGuidanceTarget",objNull];
        if (!isNull _guidanceTarget) then {deleteVehicle _guidanceTarget};
        _flareAircraft setVariable ["CBE_Cortex_AttackFlareJob",nil];
        _flareAircraft setVariable ["CBE_Cortex_AirAttackJob",nil];
        _flareAircraft setVariable ["CBE_Cortex_AirAttackToken",nil];
        _flareAircraft setVariable ["CBE_Cortex_AirAttackTarget",nil];
        _flareAircraft setVariable ["CBE_Cortex_AirAttackGuidedWeapon",nil];
        _flareAircraft setVariable ["CBE_Cortex_AirAttackGuidanceTarget",nil];
        _flareAircraft setVariable ["CBE_Cortex_AirAttackBlockedUntil",nil];
        private _airHandler=_state getOrDefault ["firedHandler",-1];
        if (_airHandler >= 0 && {local _flareAircraft}) then {_flareAircraft removeEventHandler ["Fired",_airHandler]};
        if (local _flareAircraft) then {
            // Negative limits can command helicopter reverse; restore the native positive default.
        _flareAircraft limitSpeed (2 * getNumber (configOf _flareAircraft >> "maxSpeed"));
            private _airGroup=group driver _flareAircraft;
            if (!isNull _airGroup) then {
                private _ownedWaypointName=_state getOrDefault ["ownedWaypointName",""];
                private _ownedWaypointIndex=(waypoints _airGroup) findIf {
                    _ownedWaypointName != "" && {waypointName _x == _ownedWaypointName}
                };
                if (_ownedWaypointIndex >= 0) then {
                    private _ownedWaypoint=(waypoints _airGroup) select _ownedWaypointIndex;
                    private _snapshot=_airGroup getVariable ["CBE_Cortex_ZeusOrderSnapshot",[]];
                    private _hold=_airGroup getVariable ["CBE_AIPass_ZeusHold",[]];
                    private _claimed=count _snapshot == 7 && {count _hold == 2}
                        && {(_snapshot select 0) == (_hold select 0)}
                        && {(_snapshot select 5) == (_ownedWaypoint select 1)};
                    if (_claimed) then {
                        _ownedWaypoint setWaypointName "";
                    } else {deleteWaypoint _ownedWaypoint};
                };
                _airGroup enableAttack (_state getOrDefault ["previousAttackEnabled",true]);
            };
        };
    };
    private _group = (_x select 2) getOrDefault ["group", grpNull];
    if (!isNull _group) then {
        // Shutdown clears only CBE work. A curator, player or external controller can claim a
        // group between the broad release above and this delayed-job cleanup, so never use a
        // stale regroup/clear record to issue formation or behaviour commands over that owner.
        private _canRestoreGroup=local _group && {[_group,false,false,true] call CBE_fnc_CortexIsEligible};
        if (_canRestoreGroup && {!isNull (_group getVariable ["CBE_AIPass_RegroupHost", grpNull])}
            && {(_state getOrDefault ["phase",""]) == "MOVE"}
            && {(_state getOrDefault ["ownerEpoch",-2])+1 == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_state getOrDefault ["operationGeneration",-1]) == (_group getVariable ["CBE_OperationGeneration",0])}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_state getOrDefault ["nativeOrderReceipt",[]])}) then {
            private _target=_state getOrDefault ["target",[]];
            if (count _target == 3) then {
                {
                    if (local _x && {group _x == _group} && {!isPlayer _x}
                        && {[_x] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _x}
                        && {simulationEnabled _x} && {!isObjectHidden _x} && {!fleeing _x}
                        && {isNull remoteControlled _x} && {currentCommand _x == "MOVE"}
                        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
                        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}) then {
                        private _destination=(expectedDestination _x) param [0,[]];
                        if (count _destination == 3 && {_destination vectorDistance _target <= 0.25}) then {
                            _x doFollow leader _group;
                        };
                    };
                } forEach (_state getOrDefault ["held",[]]);
            };
        };
        _group setVariable ["CBE_AIPass_Dropping", nil];
        // Current building jobs queue the FSM brain, not a legacy team-bearing callback.
        // CortexClearRelease above owns exact current clearance cleanup. Queued historical
        // metadata cannot authorise formation/behaviour writes or erase a successor's order.
        _group setVariable ["CBE_AIPass_GarrisonApplied", nil];
        _group setVariable ["CBE_AIPass_DefendApplied", nil];
        private _aircraft = (_x select 2) getOrDefault ["aircraft", objNull];
        private _airborneStopEpisode=(_x select 2) getOrDefault ["episode",[]];
        // A queued obsolete insertion must not clear a successor aircraft hold.
        if (_airborneStopEpisode isNotEqualTo []) then {
            if ((_group getVariable ["CBE_AIPass_DropEpisode",[]]) isEqualTo _airborneStopEpisode) then {
                _group setVariable ["CBE_AIPass_DropEpisode",nil,true];
            };
            if (!isNull _aircraft && {local _aircraft}
                && {(_aircraft getVariable ["CBE_AIPass_DropEpisode",[]]) isEqualTo _airborneStopEpisode}) then {
                _aircraft setVariable ["CBE_AIPass_DropUntil",nil];
                _aircraft setVariable ["CBE_AIPass_AirborneClimb",nil];
                _aircraft setVariable ["CBE_AIPass_DropEpisode",nil,true];
            };
        };
        _group setVariable ["CBE_AIPass_RegroupQueued", nil];
        _group setVariable ["CBE_AIPass_RegroupHost", nil];
    };
} forEach _jobs;
[] call CBE_fnc_SchedulerReconcile;
missionNamespace setVariable ["CBE_AIPass_DiscoveryQueued", false];
diag_log "[CBE] Stopped.";
