/*
 * Author: WaldoTheWarfighter
 * Coordinated recovery snapshots retain generic and per-server-bound refresh budgets; commands are not replayed.
 * Individual indoor work is cancelled on transfer; only an exact journal-owned native leg may
 * return to formation on the new owner. No indoor movement or deadline is replayed.
 * Passenger, naval landing, pending calm remount, active coordinated-support, post-contact movement
 * standalone manoeuvre and active withdrawal intent survive migration without replaying old owner jobs. Invalidates old jobs,
 * Checkpoint mover recall requires the exact issued native MOVE; later STOP/combat tasks and
 * durable clearance orders are never treated as inherited drill movement.
 * restores interrupted transient behaviour and resumes a bounded support assignment,
 * investigation, search, standalone manoeuvre or withdrawal after CBE or ACE migration. A Zeus hold or the
 * Both withdrawal kinds require their unchanged pre-cleanup native-order receipt. The
 * matching infantry-morale/vehicle-withdrawal gate cancels restoration so migration cannot revive
 * superseded work or incorrectly couple the two withdrawal types.
 * Coordinated support captures observed spent recovery counts and unavailable actors before
 * old-parent cancellation, bound to its exact token and original expiry.
 * Locality/authority: current group owner unless stated otherwise below.
 * Repeat/JIP: durable restoration data is public; local jobs are never replayed verbatim. A calm
 * remount keeps its original deadline and vehicle, and yields to Zeus or a newer assignment.
 * Combat-mode restoration checks the applied value before restoring, preserving newer ROE changes.
 * Aircraft occupants are restored from any earlier ground lease but are not adopted into ground
 * transitions; their dedicated flight controllers remain the sole movement owner.
 * Released queue-abort adoption captures the prior published identity at this group edge;
 * split vehicle/crew arrival uses the existing five-lookups service and original cleanup deadline.
 * Ordinary driving brains retire before the owner epoch changes; successor queued work starts
 * against the new epoch and does not inherit an exhausted old-owner receipt. Public pass-leg
 * cleanup may hand back only unchanged native commands; split vehicle locality waits for discovery.
 * Outgoing ENTRY/SWEEP lane capture is machine-private after fencing the actual old
 * producer, before pointer/epoch retirement. It is not a public seal or readiness receipt.
 * Arguments: 0: group <GROUP>, default grpNull; 1: gained locality <BOOL>, default false;
 * 2: resume pending artillery relocation <BOOL>, default true. Its own first admission passes
 * false to prevent synchronous re-entry before publishing its selected-crew journal.
 * Return Value: Nothing unless a value is explicitly returned below.
 * Current callers: group Local handler and discovery.
 * Example: [_group, local _group] call CBE_fnc_CortexLocality;
 * Result: the new owner releases stale transient controls and resumes one valid durable intent.
 * Danger assessment: bounded member events wake the generation-scoped group tactics FSM; handlers and
 * the old owner brain retire on membership/owner changes and shutdown. No second movement owner.
 */
params [["_group", grpNull, [grpNull]], ["_gained", false, [true]], ["_resumeArtilleryScoot",true,[true]]];
if (isNull _group) exitWith {};
[_group,true] call CBE_fnc_CortexIlluminationStep;
// Capture the previous published driving identity at the actual group locality edge,
// before retirement can overwrite it. This local proposal alone grants no commands.
private _abortSource=[];
private _priorDrivingStatus=_group getVariable ["CBE_Driving_State",[]];
if (_gained && {local _group} && {_priorDrivingStatus isEqualType []} && {count _priorDrivingStatus == 6}
    && {[1,4,5] findIf {private _value=_priorDrivingStatus select _x;
        !(_value isEqualType 0) || {!finite _value} || {_value < 0} || {_value != floor _value}} < 0}
    && {(_priorDrivingStatus select 4) != clientOwner}) then {
    _abortSource=[_priorDrivingStatus select 4,_priorDrivingStatus select 5,_priorDrivingStatus select 1];
};
private _firstAdoption=_gained && {local _group} && {(_group getVariable ["CBE_AIPass_Epoch",0]) == 0};
private _withdrawalIntent = _group getVariable ["CBE_Cortex_WithdrawalIntent",[]];
// Compare before old-operation cancellation removes its exact temporary route. Intent alone
// cannot authorize resumption after a mission script replaces the native order during transfer.
private _withdrawalOrder=_group getVariable ["CBE_Cortex_WithdrawalOrder",[]];
private _withdrawalOrderCurrent=count _withdrawalIntent == 7 && {count _withdrawalOrder == 2}
    && {(_withdrawalOrder select 0) isEqualTo (_withdrawalIntent select 4)}
    && {(_withdrawalOrder select 1) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)};
private _transitionIntent = _group getVariable ["CBE_Cortex_TransitionIntent",[]];
private _remountIntent = _group getVariable ["CBE_Cortex_Remount",[]];
private _supportLease = _group getVariable ["CBE_AIPass_SupportLease",[]];
private _supportStatus = _group getVariable ["CBE_AIPass_SupportStatus",[]];
private _navalIntent = _group getVariable ["CBE_Cortex_NavalOperation",[]];
// Retire the old owner's common operation before this owner rebuilds any durable semantic intent.
// Its public order remains available below (for example, a partially completed building clear),
// but no stale route can survive long enough to compete with the reconstructed operation.
private _inheritedAttackLease=[];
private _inheritedDrill=[];
private _inheritedSupportRecovery=[];
if (local _group) then {
    private _previousOperation=_group getVariable ["CBE_Operation",createHashMap];
    if (count _previousOperation > 0) then {
        if ((_previousOperation getOrDefault ["generation",-1]) == (_group getVariable ["CBE_OperationGeneration",-2])) then {
            _inheritedAttackLease=+((_previousOperation getOrDefault ["restore",createHashMap]) getOrDefault ["groupAttack",[]]);
            // Preserve consumed budgets before cancelling the exact old parent. No recovery
            // command, running timer or destination is replayed on the new owner.
            private _spent=_previousOperation getOrDefault ["recoveryAttempts",createHashMap];
            private _unavailable=_previousOperation getOrDefault ["unavailable",[]];
            private _boundSpent=_previousOperation getOrDefault ["boundRetryAttempts",createHashMap];
            private _boundProgress=_previousOperation getOrDefault ["boundProgress",[]];
            if (count _supportLease == 6 && {(_previousOperation getOrDefault ["intent",""]) == "COORDINATED_ASSAULT"}
                && {(_previousOperation getOrDefault ["supportToken",""]) == (_supportLease select 0)}
                && {(_previousOperation getOrDefault ["supportExpiry",-1]) == (_supportLease select 2)}
                && {_spent isEqualType createHashMap} && {count _spent <= 64}
                && {_unavailable isEqualType []} && {count _unavailable <= 64}
                && {_boundSpent isEqualType createHashMap} && {count _boundSpent <= 64}) then {
                _inheritedSupportRecovery=[_supportLease select 0,_previousOperation get "generation",
                    _previousOperation getOrDefault ["ownerEpoch",-1],_supportLease select 2,+_unavailable,
                    (keys _spent) apply {[_x,_spent get _x]},
                    (keys _boundSpent) apply {private _entry=_boundSpent get _x;
                        [_x,if (_entry isEqualType []) then {+_entry} else {_entry}]},
                    if (_boundProgress isEqualType []) then {_boundProgress apply {
                        if (_x isEqualType []) then {_x apply {if (_x isEqualType []) then {+_x} else {_x}}} else {_x}
                    }} else {_boundProgress},
                    _previousOperation getOrDefault ["supportAdoptionUntil",-1]];
            };
            private _checkpoint=createHashMapFromArray (_group getVariable ["CBE_AIPass_Checkpoint",[]]);
            private _candidate=_checkpoint getOrDefault ["drillIntent",[]];
            private _candidateModes=[_checkpoint getOrDefault ["restoreGroupCombatMode",[]],_checkpoint getOrDefault ["restoreGroupSpeedMode",[]]];
            if (count _candidate == 5 && {(_candidate select 0) == (_previousOperation get "generation")}
                && {[_group,_candidate,-1,true] call CBE_fnc_CortexDrillResume}
                && {!([_group] call CBE_fnc_CortexExternalTakeover)}
                && {count _inheritedAttackLease != 2 || {attackEnabled _group == (_inheritedAttackLease select 1)}}
                && {count (_candidateModes select 0) != 2 || {combatMode _group == ((_candidateModes select 0) select 1)}}
                && {count (_candidateModes select 1) != 2 || {speedMode _group == ((_candidateModes select 1) select 1)}}) then {
                _inheritedDrill=+_candidate;
            };

        };
        [_group,_previousOperation getOrDefault ["generation",-1],"OWNERSHIP_LOST"] call CBE_fnc_OperationCancel;
    };
};
[_group,true] call CBE_fnc_CortexHearingLocal;
[_group,true] call CBE_fnc_DangerSetup;
// Handler IDs are local; remove the prior owner's observer even after group locality is lost.
private _passWatch=_group getVariable ["CBE_DrivingPass_CommandWatch",[]];
if (count _passWatch == 6) then {
    [_group,_passWatch select 0,createHashMapFromArray [["token",_passWatch select 1],
        ["epoch",_passWatch select 2],["generation",_passWatch select 3]],true]
        call CBE_fnc_DrivingPassCommandWatch;
};
// Retire the exact previous driving receipt before changing its owner epoch.
private _drivingBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
if (count _drivingBrain > 0) then {[_drivingBrain,"LOCALITY_CHANGE"] call CBE_fnc_DrivingOperationFinish};
_group setVariable ["CBE_Driving_Brain",nil];
_group setVariable ["CBE_Driving_FSM",nil];
private _oldBrain=_group getVariable ["CBE_GroupBrain",createHashMap];
if (count _oldBrain > 0) then {
    _oldBrain set ["cancelled",true];
    _oldBrain set ["cancelReason","LOCALITY_CHANGE"];
    _oldBrain set ["wakeAt",time];
};
_group setVariable ["CBE_GroupBrain_Generation",(_group getVariable ["CBE_GroupBrain_Generation",0])+1];
_group setVariable ["CBE_GroupBrain",nil];
_group setVariable ["CBE_GroupBrain_FSM",nil];
_group setVariable ["CBE_Cortex_GroupJob",nil];
private _buildingBrain=_group getVariable ["CBE_BuildingBrain",createHashMap];
isNil {
    if ((_group getVariable ["CBE_BuildingBrain",createHashMap]) isNotEqualTo _buildingBrain) exitWith {};
    if (_gained && {local _group}) then {_group setVariable ["CBE_Cortex_ClearLaneCaptureLocal",nil]};
    if (count _buildingBrain > 0) then {
        private _captureOutgoing=!_gained && {!local _group}
            && {(_buildingBrain getOrDefault ["producerOwner",-1]) == clientOwner}
            && {!(_buildingBrain getOrDefault ["cancelled",false])}
            && {!(_buildingBrain getOrDefault ["finished",false])};
        // Fence this writer before the final local copy; no old tactical callback
        // may treat the snapshot as permission to resume. Other writer domains are separate.
        _buildingBrain set ["cancelled",true];
        _buildingBrain set ["cancelReason","LOCALITY_CHANGE"];
        _buildingBrain set ["completed",true];
        if (_captureOutgoing) then {
            private _clearJob=_buildingBrain getOrDefault ["job",createHashMap];
            private _lanes=["FROZEN",_clearJob] call CBE_fnc_BuildingLaneJournal;
            if (_lanes isEqualType [] && {count _lanes == 13}) then {
                _group setVariable ["CBE_Cortex_ClearLaneCaptureLocal",[1,clientOwner,
                    _clearJob get "generation",_clearJob get "ownerEpoch",_clearJob get "operationGeneration",
                    serverTime,_clearJob get "hardDeadline",_lanes]];
            };
        };
    };
    _group setVariable ["CBE_BuildingBrain",nil];
    _group setVariable ["CBE_BuildingBrain_FSM",nil];
};
{
        private _unit = _x;
        private _point=_unit getVariable ["CBE_PointActor_Brain",createHashMap];
        if (count _point > 0 || {(_unit getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo []}) then {
            ["TRANSFER",_unit,createHashMap] call CBE_fnc_PointActorOperation;
            if ((_unit getVariable ["CBE_PointActor_Brain",createHashMap]) isEqualTo _point) then {
                _unit setVariable ["CBE_PointActor_Brain",nil];_unit setVariable ["CBE_PointActor_FSM",nil];
            };
        };
        private _indoor=_unit getVariable ["CBE_IndoorActor_Brain",createHashMap];
        if (count _indoor > 0 || {(_unit getVariable ["CBE_IndoorActor_Order",[]]) isNotEqualTo []}
            || {!isNil {_unit getVariable "CBE_IndoorActor_FSM"}}) then {
            if (count _indoor > 0) then {_indoor set ["finished",true]};
            ["TRANSFER",_unit,createHashMap] call CBE_fnc_IndoorActorOperation;
            // Public cancellation may already have completed elsewhere. Retire this machine's
            // exact old pointer regardless; otherwise returning ownership blocks the next START.
            if ((_unit getVariable ["CBE_IndoorActor_Brain",createHashMap]) isEqualTo _indoor) then {
                _unit setVariable ["CBE_IndoorActor_Brain",nil];
                _unit setVariable ["CBE_IndoorActor_FSM",nil];
            };
        };
        // Event-handler IDs are machine-local. Retire this owner's listener on both
        // loss and gain; the old drill is cancelled, never replayed on the new owner.
        private _fragHandler = _unit getVariable ["CBE_Cortex_FragHandler",-1];
        if (_fragHandler >= 0) then {_unit removeEventHandler ["FiredMan",_fragHandler]};
        _unit setVariable ["CBE_Cortex_FragHandler",-1];
        private _throwTraceHandler=_unit getVariable ["CBE_Cortex_ThrowTraceHandler",-1];
        if (_throwTraceHandler >= 0) then {_unit removeEventHandler ["FiredMan",_throwTraceHandler]};
        _unit setVariable ["CBE_Cortex_ThrowTraceHandler",-1];
        _unit setVariable ["CBE_Cortex_ThrowTracePending",nil];
        {_unit removeEventHandler _x} forEach (_unit getVariable ["CBE_AIPass_GarrisonHandlerIds", []]);
        _unit setVariable ["CBE_AIPass_GarrisonHandlerIds", nil];
        _unit setVariable ["CBE_AIPass_GarrisonHandlers", nil];
        _unit setVariable ["CBE_AIPass_DuckUntil", nil];
        _unit setVariable ["CBE_Cortex_ActorMove",nil];
} forEach units _group;
_group setVariable ["CBE_AIPass_Epoch", (_group getVariable ["CBE_AIPass_Epoch", 0]) + 1];
_group setVariable ["CBE_DrivingAbort_Transfer",nil];
_group setVariable ["CBE_DrivingNative_Transfer",nil];
if (_abortSource isNotEqualTo []) then {
    if (isNil {_group getVariable "CBE_Driving_Generation"}) then {_group setVariable ["CBE_Driving_Generation",0]};
    _group setVariable ["CBE_DrivingAbort_Transfer",[_abortSource,_group getVariable ["CBE_AIPass_Epoch",0],serverTime+5]];
    _group setVariable ["CBE_DrivingNative_Transfer",[_abortSource select 0,_abortSource select 1,
        _group getVariable ["CBE_AIPass_Epoch",0],serverTime+5]];
};
// First adoption establishes this machine's epoch; it is not a transfer from another
// owner. Keep the existing map object so an initiating feature's local reference remains
// authoritative. Real owner changes rebuild state from the published checkpoint.
if (!_firstAdoption) then {_group setVariable ["CBE_AIPass_State", nil];};
_group setVariable ["CBE_AIPass_Managed", nil];
{_group setVariable [_x, nil]} forEach ["CBE_AIPass_GarrisonApplied", "CBE_AIPass_DefendApplied", "CBE_AIPass_ClearApplied"];
_group setVariable ["CBE_AIPass_Adopted", _gained];
// Native handler IDs stay on their machine; remove only this group's old local observer.
if (!_gained && {!local _group}) then {
    {
        private _reference=_group getVariable [_x,[]];
        private _platform=if (_reference isEqualType []) then {_reference param [0,objNull,[objNull]]} else {objNull};
        if (!isNull _platform) then {
            private _watch=_platform getVariable ["CBE_VehicleCrewMove_DeletedWatch",[]];
            if (_watch isEqualType [] && {count _watch == 8} && {(_watch select 1) isEqualTo _group}) then {
                [_platform,"RELEASE",_watch select 0] call CBE_fnc_VehicleCrewMoveDeletionWatch;
            };
        };
    } forEach ["CBE_ArtilleryCrew_Reference","CBE_VehicleTacticalMove_Reference"];
};

if (!_gained || {!local _group}) exitWith {};
// Resume only the original pending hold deadline; the executor rechecks actual actor ownership.
[_group] call CBE_fnc_CortexHolderRecallPending;
// Group and vehicle ownership need not arrive together; discovery retries the split case.
private _passVehicles=[];
{
    private _vehicle=vehicle _x;
    if (_vehicle != _x && {!(_vehicle in _passVehicles)}) then {
        _passVehicles pushBack _vehicle;
        [_vehicle,local _vehicle] call CBE_fnc_DrivingRecoveryAdopt;
        if (!isNil {_vehicle getVariable "CBE_DrivingPass_Leg"}) then {
            [_vehicle] call CBE_fnc_DrivingPassRetireInherited;
        };
    };
} forEach units _group;
// Completed clearance has no active operation/order, but native STOP survives migration.
// Adopt the public hold receipt into this owner's generation without replaying movement.
private _settingsGenerationBeforeAdopt=_group getVariable ["CBE_AIPass_ClearGeneration",0];
private _clearHold=_group getVariable ["CBE_Cortex_ClearHold",[]];
if (count _clearHold == 5) then {
    private _actors=_clearHold select 3;
    private _canAdopt=_actors isEqualType [] && {count _actors <= 16}
        && {(_clearHold select 0) isEqualType 0}
        && {(_clearHold select 4) isEqualType []} && {count (_clearHold select 4) <= 16}
        && {(_clearHold select 4) findIf {
            !(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}
                || {!((_x select 1) isEqualType [])} || {count (_x select 1) != 3}
                || {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        } < 0}
        && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
        && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo []}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)};
    if (_canAdopt) then {
        private _holdGeneration=((_group getVariable ["CBE_AIPass_ClearGeneration",0]) max (_clearHold select 0))+1;
        _group setVariable ["CBE_AIPass_ClearGeneration",_holdGeneration];
        private _adoptedHold=+_clearHold;
        _adoptedHold set [0,_holdGeneration];
        _adoptedHold set [1,_group getVariable ["CBE_AIPass_Epoch",0]];
        _adoptedHold set [3,_actors select {group _x == _group}];
        _adoptedHold set [4,(_clearHold select 4) select {(_x select 0) in ((_adoptedHold select 3) apply {netId _x})}];
        _group setVariable ["CBE_Cortex_ClearHold",_adoptedHold,true];
    } else {
        _group setVariable ["CBE_Cortex_ClearHold",nil,true];
    };
};
// Adopt only the original finite settings-cleanup window, with no control replay.
private _clearSettings=_group getVariable ["CBE_Cortex_ClearSettingsPending",[]];
if (_clearSettings isEqualType [] && {count _clearSettings == 4}) then {
    private _typed=[0,1,2,3] findIf {!((_clearSettings select _x) isEqualType 0)
        || {!finite (_clearSettings select _x)}} < 0;
    if (_typed && {(_clearSettings select 0) == _settingsGenerationBeforeAdopt}
        && {serverTime < (_clearSettings select 2)}
        && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo []}
        && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
        private _adoptedSettings=+_clearSettings;
        _adoptedSettings set [0,_group getVariable ["CBE_AIPass_ClearGeneration",0]];
        _adoptedSettings set [1,_group getVariable ["CBE_AIPass_Epoch",0]];
        _group setVariable ["CBE_Cortex_ClearSettingsPending",_adoptedSettings,true];
        [CBE_fnc_ActorSettingsCleanupStep,createHashMapFromArray [["group",_group],
            ["ownerEpoch",_adoptedSettings select 1],["generation",_adoptedSettings select 0],
            ["subsystem","SETTINGS_CLEANUP"]],0.25,"CLEAR_SETTINGS"] call CBE_fnc_CortexQueueJob;
        [] call CBE_fnc_SchedulerReconcile;
    } else {_group setVariable ["CBE_Cortex_ClearSettingsPending",nil,true]};
};
        private _garrisonCleanup=_group getVariable ["CBE_Cortex_GarrisonSettingsPending",[]];
        if (_garrisonCleanup isEqualType [] && {count _garrisonCleanup > 0} && {count _garrisonCleanup <= 64}) then {
            private _cleanupEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
            [CBE_fnc_ActorSettingsCleanupStep,createHashMapFromArray [["group",_group],
                ["ownerEpoch",_cleanupEpoch],["generation",_cleanupEpoch],["kind","GARRISON"],
                ["subsystem","SETTINGS_CLEANUP"]],0.25,"GARRISON_SETTINGS"] call CBE_fnc_CortexQueueJob;
        };
[] call CBE_fnc_SchedulerReconcile;
// Retire inherited simple driving before the new owner resumes the durable escape route.
private _reverseCleanup=_group getVariable ["CBE_VehicleReverse",[]];
if (count _reverseCleanup == 9) then {
    [_group,createHashMap,objNull,[],"RELEASE",_reverseCleanup select 1] call CBE_fnc_CortexVehicleReverseStep;
};
// Observation-only hearing has its own eligibility boundary and may coexist with a curator
// waypoint. Reinstall it on the new owner now instead of losing sound events until discovery.
[_group] call CBE_fnc_CortexHearingLocal;
// Recovery is cancelled by adoption, not silently resumed from stale diagnostics.
if ((_group getVariable ["CBE_Cortex_DrillRecovery",[]]) isNotEqualTo []) then {
    _group setVariable ["CBE_Cortex_DrillRecovery",["MIGRATED",[],-1],true];
};
private _restore = createHashMapFromArray (_group getVariable ["CBE_AIPass_Checkpoint", []]);
// A retired lease token cannot regain authority through delayed delivery on the new owner.
// This carries refusal metadata only; it grants no support task, cleanup or movement.
private _revokedSupportToken=_restore getOrDefault ["supportAuthoredRevokedToken",""];
if (_revokedSupportToken isEqualType "" && {_revokedSupportToken != ""}) then {
    ([_group] call CBE_fnc_CortexGroupState) set ["supportAuthoredRevokedToken",_revokedSupportToken];
};
// A locality callback may arrive after Zeus or another controller has claimed the group.  The
// old owner's checkpoint is then evidence only: never replay its follow, AI-feature or ROE cleanup
// into the new owner's task.  Eligible CBE groups still recover only the values CBE recorded.
private _restoreEligible=[_group,false,false,true] call CBE_fnc_CortexIsEligible;
// A disabled master is not a new controller. Restore this exact-owned native permission
// independently of movement eligibility, before a resumed operation captures its baseline.
// Direct player/specialist ownership still wins; a waypoint-only hold owns no attack flag.
if (count _inheritedAttackLease == 2 && {count units _group <= 64}
    && {!([_group,true] call CBE_fnc_CortexExternalTakeover)}
    && {(_inheritedAttackLease select 0) isEqualType true}
    && {(_inheritedAttackLease select 1) isEqualType true}
    && {attackEnabled _group == (_inheritedAttackLease select 1)}
    && {(_inheritedAttackLease select 0) != (_inheritedAttackLease select 1)}) then {
    _group enableAttack (_inheritedAttackLease select 0);
};
if (_restoreEligible) then {
    private _restoreActorEligible={
        params ["_unit"];
        !isNull _unit && {alive _unit} && {local _unit} && {group _unit == _group}
            && {!isPlayer _unit} && {isNull (remoteControlled _unit)}
            && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
    };
    // Locality can change before the engine elects a replacement leader. Restore only CBE-owned
    // followers toward a combat-effective local anchor, never an incapacitated former leader.
    private _restoreAnchor=[_group] call CBE_fnc_CortexGroupAnchor;
    if (isNull _restoreAnchor) then {_restoreAnchor=leader _group};
    // OperationStart can invoke locality adoption from a scheduled script. Keep the
    // bounded footprint read and these two native policy writes non-suspending.
    isNil {
        if (local _group && {[_group,false,false,true] call CBE_fnc_CortexIsEligible}
            && {!([_group] call CBE_fnc_CortexZeusHeld)}) then {
    // Group policy restoration uses the complete native-task footprint; this grants
    // no movement permission and must not veto eligible actors' separate cleanup.
    private _groupPolicyFree=[_group] call CBE_fnc_CortexGroupPostureTaskAvailable;
    private _groupModeLease = _restore getOrDefault ["restoreGroupCombatMode",[]];
    if (_groupPolicyFree && {count _groupModeLease == 2} && {combatMode _group == (_groupModeLease select 1)}) then {
        _group setCombatMode (_groupModeLease select 0);
    };
    private _groupSpeedLease = _restore getOrDefault ["restoreGroupSpeedMode",[]];
    if (_groupPolicyFree && {count _groupSpeedLease == 2} && {speedMode _group == (_groupSpeedLease select 1)}) then {
        _group setSpeedMode (_groupSpeedLease select 0);
    };
        };
    };
    {
        _x params ["_unit", "_feature"];
        if ([_unit] call _restoreActorEligible) then {_unit enableAI _feature};
    } forEach (_restore getOrDefault ["restoreDisabled", []]);
    {
        private _unit=_x;
        private _moveProof=_restore getOrDefault ["restoreMoveDestinations",[]];
        private _proofIndex=_moveProof findIf {(_x select 0) == _unit};
        // A checkpoint records issued drill destinations, not ownership of every later
        // STOP/combat/idle task. Durable clearance resumes through its own episode receipts.
        // PATH-held drill actors are released by their separate exact hold leases below.
        private _ownedMove=false;
        if (currentCommand _unit == "MOVE" && {_proofIndex >= 0}) then {
            private _spot=(_moveProof select _proofIndex) select 1;
            private _destination=(expectedDestination _unit) param [0,[],[[]]];
            _ownedMove=count _spot == 3 && {count _destination == 3}
                && {_spot findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {_destination findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {_destination vectorDistance _spot <= 0.25};
        };
        // Leave an exact current coordinated leg in the engine for the finite adoption
        // path. Generic cleanup must not issue doFollow before that path can observe it.
        private _coordinatedMove=false;
        private _supportProof=_restore getOrDefault ["supportHoldProof",[]];
        if (_inheritedSupportRecovery isNotEqualTo [] && {_supportProof isEqualType []} && {count _supportProof == 6}
            && {(_supportProof select 0) == (_supportLease select 0)}
            && {(_supportProof select 1) == (_inheritedSupportRecovery select 1)}
            && {(_supportProof select 2) == (_inheritedSupportRecovery select 2)}
            && {(_supportProof select 3) == (_supportLease select 2)} && {serverTime < (_supportLease select 2)}
            && {(_supportProof select 4) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
            && {(_supportProof select 5) isEqualType []} && {count (_supportProof select 5) <= 64}
            && {_supportLease isEqualTo (_group getVariable ["CBE_AIPass_SupportLease",[]])}) then {
            private _role=_group getVariable ["CBE_Cortex_SupportRole",[]];
            if (count _role == 5 && {(_role select 0) == (_supportLease select 0)} && {(_role select 2) == "MOVE"}) then {
                _coordinatedMove=(_supportProof select 5) findIf {
                    _x isEqualType [] && {count _x == 10} && {(_x select 0) isEqualTo _unit}
                        && {(_x select 4) isEqualTo (_role select 1)} && {currentCommand _unit == "MOVE"}
                        && {(expectedDestination _unit) isEqualTo (_x select 1)} && {formLeader _unit == (_x select 2)}
                } >= 0;
            };
        };
        if (!_coordinatedMove && {_inheritedDrill isEqualTo []} && {[_x] call _restoreActorEligible} && {_ownedMove} && {!isNull _restoreAnchor}
            && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo []}
            && {!([_unit] call CBE_fnc_CortexActorMoveReserved)}) then {_x doFollow _restoreAnchor};
    } forEach (_restore getOrDefault ["restoreMovers", []]);
    {
        _x params ["_unit","_mode",["_ownedMode","BLUE"]];
        if ([_unit] call _restoreActorEligible && {unitCombatMode _unit == _ownedMode}) then {_unit setUnitCombatMode _mode};
    } forEach (_restore getOrDefault ["restoreCombatModes",[]]);
    {
        _x params ["_unit","_previous","_owned"];
        if ([_unit] call _restoreActorEligible && {behaviour _unit == _owned}) then {_unit setCombatBehaviour _previous};
    } forEach (_restore getOrDefault ["restoreCombatBehaviours",[]]);
};
// Keep restoration intent, not engine commands, across HC ownership changes.
// A new assignment or Zeus takeover invalidates the old passenger episode.
private _passengers=(_restore getOrDefault ["dismounted",[]]) select {
    _x params ["_unit","_vehicle"];
    alive _unit && {group _unit == _group} && {alive _vehicle} && {vehicle _unit == _unit}
        && {isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}}
};
// Do not publish an artificial CALM between owners when a durable SEARCH/INVESTIGATE or RETREAT
// episode will resume immediately below. With no resumable semantic work, force a CALM record so
// diagnostics and JIP cannot retain the old owner's stale public phase.
private _transitionResumeEligible=count _transitionIntent == 6 && {serverTime < (_transitionIntent select 3)}
    && {[_group] call CBE_fnc_CortexIsEligible} && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {_withdrawalIntent isEqualTo []};
if (_transitionResumeEligible) then {
    private _resumePhase=_transitionIntent select 0;
    private _resumeAreaMode=_transitionIntent select 4;
    _transitionResumeEligible=switch (_resumePhase) do {
        case "INVESTIGATE": {
            private _sourceGate=["CBE_AIPass_ContactReports_Enable","CBE_AIPass_Hearing_Enable"] select (_resumeAreaMode == "SOUND");
            [_group,"CBE_AIPass_Investigate_Enable",true] call CBE_fnc_CortexFeatureEnabled
                && {_resumeAreaMode == "" || {[_group,_sourceGate,true] call CBE_fnc_CortexFeatureEnabled}}
        };
        case "SEARCH": {[_group,"CBE_AIPass_PostContact_Enable",true] call CBE_fnc_CortexFeatureEnabled};
        default {false};
    };
};
private _withdrawalKind=_withdrawalIntent param [0,""];
private _withdrawalGateOpen=switch (_withdrawalKind) do {
    case "INFANTRY": {[_group,"CBE_AIPass_Morale_Enable",true] call CBE_fnc_CortexFeatureEnabled};
    case "VEHICLE": {
        [_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled
            && {[_group,"CBE_AIPass_VehicleWithdraw_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    };
    default {false};
};
private _withdrawalResumeEligible=count _withdrawalIntent == 7
    && {(_withdrawalIntent select 0) in ["INFANTRY","VEHICLE"]}
    && {count (_withdrawalIntent select 2) >= 2}
    && {count (_withdrawalIntent select 3) >= 2}
    && {(_withdrawalIntent select 4) isEqualType 0} && {finite (_withdrawalIntent select 4)}
    && {(_withdrawalIntent select 4) >= 0} && {(_withdrawalIntent select 4) <= serverTime+1}
    && {serverTime-(_withdrawalIntent select 4) < 120}
    && {_withdrawalOrderCurrent}
    && {[_group] call CBE_fnc_CortexIsEligible}
    && {_withdrawalGateOpen}
    && {!([_group] call CBE_fnc_CortexZeusHeld)};
// A newly local group may already be under Zeus or an external controller. Treat the former
// owner's checkpoint as a release-only record in that case: cancelling CBE's own restrictions
// must not issue a fresh follow order or restore a speed/ROE value into the replacement task.
[_group, _restore, false, (!_restoreEligible || {_inheritedDrill isNotEqualTo []}), "OWNERSHIP_ADOPTED",!(_transitionResumeEligible || {_withdrawalResumeEligible}),_inheritedDrill isNotEqualTo []] call CBE_fnc_CortexRestoreCalm;
// The public token is semantic state only. CortexNavalAssault validates its unchanged deadline,
// plan owner and boat before issuing any replacement-owner command on the normal group tick.
if (count _navalIntent == 5 && {serverTime < (_navalIntent select 4)}
    && {[_group] call CBE_fnc_CortexIsEligible} && {!([_group] call CBE_fnc_CortexZeusHeld)}) then {
    private _adopted=[_group] call CBE_fnc_CortexGroupState;
    _adopted set ["navalOperation",+_navalIntent];
    _group setVariable ["CBE_AIPass_Checkpoint", [], true];
};
if ((_group getVariable ["CBE_Cortex_NavalOperation",[]]) isNotEqualTo []) exitWith {};
// Aircrew have dedicated flight, countermeasure and attack controllers. A Local event handler may
// survive from the group's earlier ground phase, but ownership migration must never reconstruct
// infantry transitions, remounts or building movement while any living member occupies an aircraft.
if ((units _group) findIf {
    alive _x && {vehicle _x != _x} && {vehicle _x isKindOf "Air"}
} >= 0) exitWith {};
// Resume the committed standalone drill before discovery can select a different manoeuvre.
// Coordinated bounds retain their existing authenticated server-role adoption path below.
if (_inheritedDrill isNotEqualTo [] && {_withdrawalIntent isEqualTo []} && {_transitionIntent isEqualTo []}
    && {[_group,_inheritedDrill] call CBE_fnc_CortexDrillResume}) exitWith {};
// The server-owned lease/status pair is the durable assignment. Reuse the normal support
// acceptance path so every feature gate, vehicle exclusion, COMPAT handover and movement flag keeps
// exactly one implementation. The new owner reconstructs semantics; it never replays an old job.
private _supportAdoptable=_withdrawalIntent isEqualTo [] && {_transitionIntent isEqualTo []}
    && {count _supportLease == 6} && {count _supportStatus == 4}
    && {(_supportLease select 0) == (_supportStatus select 0)}
    && {serverTime < (_supportLease select 2)} && {_supportStatus select 2}
    && {!([_group] call CBE_fnc_CortexZeusHeld)};
if (_supportAdoptable) then {
    [createHashMapFromArray [
        ["group",_group],["lease",_supportLease],["waitUntil",serverTime],["adopt",true],
        ["authoredOrder",_restore getOrDefault ["supportAuthoredOrder",[]]],
        ["authoredRevoked",_restore getOrDefault ["supportAuthoredRevoked",false]],
        ["holdProof",_restore getOrDefault ["supportHoldProof",[]]],
        ["recoveryProof",_inheritedSupportRecovery]
    ]] call CBE_fnc_CortexSupportApply;
};
if (([_group] call CBE_fnc_CortexGroupState) getOrDefault ["supportToken",""] != "") exitWith {
    _group setVariable ["CBE_AIPass_Checkpoint", [], true];
};
if (_passengers isNotEqualTo [] && {[_group] call CBE_fnc_CortexIsEligible}) then {
    private _adopted=[_group] call CBE_fnc_CortexGroupState;
    _adopted set ["dismounted",_passengers];
    _adopted set ["onboardContactUntil",serverTime+30];
};
// Restore semantic boarding intent after old-owner cleanup, never its engine command. Preserve
// the original deadline so repeated transfers cannot make remount immortal. A replacement vehicle
// assignment or Zeus takeover wins and removes that actor from this attempt.
if (count _remountIntent == 2 && {serverTime < (_remountIntent select 0)}
    && {[_group] call CBE_fnc_CortexIsEligible} && {!([_group] call CBE_fnc_CortexZeusHeld)}) then {
    if ([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled
        && {[_group,"CBE_AIPass_VehicleRemount_Enable",true] call CBE_fnc_CortexFeatureEnabled}) then {
        private _pendingRemount = (_remountIntent select 1) select {
            _x params ["_unit","_vehicle"];
            alive _unit && {local _unit} && {group _unit == _group} && {alive _vehicle}
                && {vehicle _unit == _unit}
                && {isNull assignedVehicle _unit || {assignedVehicle _unit == _vehicle}}
        };
        if (_pendingRemount isNotEqualTo []) then {
            _group setVariable ["CBE_Cortex_Remount",[_remountIntent select 0,+_pendingRemount],true];
        };
    };
};
// Rebuild semantic post-contact intent, not the old owner's commands or callbacks. The original
// deadline continues across migration, preventing transfer churn from extending an episode.
if (_transitionResumeEligible) then {
    _transitionIntent params ["_transitionPhase","_target","_startedAt","_deadline","_areaMode","_savedTeam"];
    private _transitionGateOpen = switch (_transitionPhase) do {
        case "INVESTIGATE": {
            private _sourceGate = ["CBE_AIPass_ContactReports_Enable","CBE_AIPass_Hearing_Enable"] select (_areaMode == "SOUND");
            [_group,"CBE_AIPass_Investigate_Enable",true] call CBE_fnc_CortexFeatureEnabled
                && {_areaMode == "" || {[_group,_sourceGate,true] call CBE_fnc_CortexFeatureEnabled}}
        };
        case "SEARCH": {[_group,"CBE_AIPass_PostContact_Enable",true] call CBE_fnc_CortexFeatureEnabled};
        default {false};
    };
    if (_transitionGateOpen && {_transitionPhase in ["INVESTIGATE","SEARCH"]} && {count _target >= 2}) then {
        private _adopted = [_group] call CBE_fnc_CortexGroupState;
        private _leader = [_group] call CBE_fnc_CortexGroupAnchor;
        if (isNull _leader) then {_leader=leader _group};
        private _team = _savedTeam select {alive _x && {group _x == _group} && {local _x} && {vehicle _x == _x}};
        if (_transitionPhase == "SEARCH" && {_team isEqualTo []}) then {
            private _riflemen = (units _group) select {alive _x && {local _x} && {_x != _leader} && {vehicle _x == _x} && {([_x] call CBE_fnc_CortexUnitRole) == "RIFLE"}};
            _team = _riflemen select [0,2];
            // Casualties may leave no separate search pair. Keep the physical check alive with
            // the leader instead of treating migration as successful completion.
            if (_team isEqualTo [] && {alive _leader} && {local _leader} && {vehicle _leader == _leader}) then {_team = [_leader]};
        };
        private _resumedSearchReceipts=[];
        if (_transitionPhase == "SEARCH") then {
            // A checkpoint is intent, not authority over a newly queued medical/native task.
            _team=_team select {
                simulationEnabled _x && {!isObjectHidden _x}
                    && {[_x] call CBE_fnc_CortexActorFireTaskAvailable}
                    && {[_group,_restore,_x] call CBE_fnc_CortexSearchMoveOwned
                        || {currentCommand _x == ""}
                        || {currentCommand _x == "FOLLOW" && {formLeader _x == _leader}}}
            };
        };
        if (_team isNotEqualTo []) then {
            private _resumedRoute=[_group] call CBE_fnc_NativeOrderReceipt;
            {
                private _goal=_target getPos [4+_forEachIndex*4,random 360];
                _x doMove _goal;
                _resumedSearchReceipts pushBack [_x,+_goal,+_resumedRoute];
            } forEach (_team select [0,16]);
        } else {
            if (_transitionPhase != "SEARCH") then {
                [_group,_target getPos [30,_target getDir _leader],25] call CBE_fnc_CortexGroupMove;
            };
        };
        _adopted set ["baseBehaviour",behaviour _leader];
        _adopted set ["baseSpeed",speedMode _group];
        _adopted set ["behaviourChanged",false];
        _adopted set ["speedChanged",false];
        isNil {
            if (local _group && {[_group,false,false,true] call CBE_fnc_CortexIsEligible}
                && {!([_group] call CBE_fnc_CortexZeusHeld)}
                && {behaviour _leader == "SAFE" && {[_group] call CBE_fnc_CortexGroupPostureTaskAvailable}}) then {
                _group setBehaviour "AWARE";
                if (behaviour _leader == "AWARE") then {_adopted set ["behaviourChanged",true]};
            };
        };
        [_group,_adopted,_transitionPhase,"OWNERSHIP_RESUME",time-((serverTime-_startedAt) max 0),true] call CBE_fnc_CortexSetPhase;
        _adopted set ["enemyPos",+_target];
        _adopted set ["searchTeam",_team];
        if (_transitionPhase == "SEARCH") then {
            _adopted set ["searchMoveReceipts",_resumedSearchReceipts];
            _adopted set ["searchDeadline",_deadline];
        };
        if (_areaMode != "") then {_adopted set ["areaInvestigation",_areaMode]};
        _group setVariable ["CBE_Cortex_TransitionIntent",[_transitionPhase,+_target,_startedAt,_deadline,_areaMode,+_team],true];
    } else {
        _group setVariable ["CBE_Cortex_TransitionIntent",nil,true];
    };
} else {
    _group setVariable ["CBE_Cortex_TransitionIntent",nil,true];
};
// The old owner's scheduled callbacks are invalid, but physical withdrawal intent is durable.
// Resume only a structurally valid, unfinished episode and let the common retreat controller
// reacquire all temporary settings. Its resume path does not repeat smoke or artillery effects.
if (_withdrawalResumeEligible) then {
    private _adopted = [_group] call CBE_fnc_CortexGroupState;
    if ((_withdrawalIntent select 0) == "INFANTRY") then {
        [_group,_adopted,_withdrawalIntent] call CBE_fnc_CortexRetreat;
    };
    if ((_withdrawalIntent select 0) == "VEHICLE") then {
        private _startedAt = _withdrawalIntent select 4;
        private _elapsed = (serverTime-_startedAt) max 0;
        private _target = +(_withdrawalIntent select 2);
        // Rebuild semantic ownership, never the previous owner's operation or native commands.
        // Keep the original episode end: transfer churn cannot buy a fresh minimum duration.
        private _remaining=120-_elapsed;
        if (_remaining <= 0) exitWith {};
        if !([_group,"VEHICLE_WITHDRAW",true,_startedAt+120] call CBE_fnc_CortexOwnershipLease) exitWith {
            _group setVariable ["CBE_Cortex_Withdrawal",["EXTERNAL_BUSY",_withdrawalIntent select 6,_withdrawalIntent select 5],true];
        };
        private _operation=[_group,"VEHICLE_WITHDRAW",_target,[],[_target],"MOVING"] call CBE_fnc_OperationStart;
        if (count _operation == 0) exitWith {
            [_group,"VEHICLE_WITHDRAW",false] call CBE_fnc_CortexOwnershipLease;
            _group setVariable ["CBE_Cortex_Withdrawal",["OPERATION_REFUSED",_withdrawalIntent select 6,_withdrawalIntent select 5],true];
        };
        private _generation=_operation get "generation";
        _operation set ["startedAt",time-_elapsed];
        _group setVariable ["CBE_Operation",_operation,true];
        private _waypoint=[_group,_target,40,"MOVE",_generation] call CBE_fnc_CortexGroupMove;
        private _moveIntent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
        if (isNull (_waypoint param [0,grpNull,[grpNull]])
            || {(_waypoint param [1,-1,[0]]) < 0}
            || {(_moveIntent getOrDefault ["operationGeneration",-1]) != _generation}
            || {(_moveIntent getOrDefault ["waypoint",[]]) isNotEqualTo _waypoint}) exitWith {
            [_group,_generation,"MOVEMENT_REJECTED"] call CBE_fnc_OperationCancel;
            [_group,"VEHICLE_WITHDRAW",false] call CBE_fnc_CortexOwnershipLease;
            _group setVariable ["CBE_Cortex_Withdrawal",["MOVEMENT_REJECTED",_withdrawalIntent select 6,_withdrawalIntent select 5],true];
        };
        _adopted set ["vehicleOperationGeneration",_generation];
        _adopted set ["movementLease",["VEHICLE_WITHDRAW",time+_remaining]];
        _adopted set ["enemyPos",+(_withdrawalIntent select 3)];
        _adopted set ["retreatStart",+(_withdrawalIntent select 1)];
        _adopted set ["retreatTarget",_target];
        _adopted set ["retreatProgress",[time,_withdrawalIntent select 6,_withdrawalIntent select 5]];
        [_group,_adopted,"RETREAT","VEHICLE_OWNERSHIP_RESUME",time-_elapsed,true] call CBE_fnc_CortexSetPhase;
        _group setVariable ["CBE_Cortex_WithdrawalIntent",_withdrawalIntent,true];
        _group setVariable ["CBE_Cortex_WithdrawalOrder",[_startedAt,
            [_group] call CBE_fnc_NativeOrderReceipt],true];
    };
};

// Maintain exact selected-platform native retirement independently of the normal group tick.
private _tacticalReference=_group getVariable ["CBE_VehicleTacticalMove_Reference",[]];
if (_tacticalReference isEqualType [] && {count _tacticalReference == 5}) then {
    private _tacticalPlatform=_tacticalReference param [0,objNull,[objNull]];
    if (!isNull _tacticalPlatform && {local _tacticalPlatform} && {local _group}) then {
        [_tacticalPlatform,_tacticalReference select 1,_tacticalReference select 2]
            call CBE_fnc_VehicleTacticalMoveRetire;
    };
};

// Retire only the original selected-gun journal when its owner-local executor ended or
// crossed this epoch. A live current worker is left alone; this does not cancel an active fire.
private _crewReference=_group getVariable ["CBE_ArtilleryCrew_Reference",[]];
if (count _crewReference == 5) then {
    private _crewBattery=_crewReference select 0;
    if (!isNull _crewBattery && {local _crewBattery} && {local _group}) then {
        private _executor=_crewBattery getVariable ["CBE_ArtilleryCrew_FSM",[]];
        private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
        private _live=count _executor == 5 && {(_executor select 0) == (_crewReference select 2)}
            && {(_executor select 2) == clientOwner} && {(_executor select 3) == _epoch}
            && {(_executor select 1) isEqualType 0} && {finite (_executor select 1)}
            && {(_executor select 1) >= 0} && {!completedFSM (_executor select 1)};
        if (!_live) then {
            [_crewBattery,_crewReference select 1,_crewReference select 2] call CBE_fnc_ArtilleryCrewMoveRetire;
        };
    };
};

// A pending shoot-and-scoot request is durable, but its queued callback belonged to the old owner.
// Resume it only after calm restoration has removed the old owner's waypoint and transient state;
// otherwise that cleanup would immediately delete the newly resumed relocation.
private _scootVehicles = [];
{
    private _vehicle = vehicle _x;
    if (_vehicle != _x && {!(_vehicle in _scootVehicles)}) then {
        _scootVehicles pushBack _vehicle;
        private _scootToken = _vehicle getVariable ["CBE_Cortex_ArtilleryScootToken",""];
        if (_resumeArtilleryScoot && {_scootToken != ""}) then {[_vehicle,_scootToken] call CBE_fnc_CortexArtilleryScoot};
    };
} forEach units _group;
_group setVariable ["CBE_AIPass_Checkpoint", [], true];
// Clear stale remnant reservations and airborne jobs; the normal discovery path reassesses them.
_group setVariable ["CBE_AIPass_RegroupQueued", nil];
_group setVariable ["CBE_AIPass_RegroupHost", nil];
_group setVariable ["CBE_AIPass_Dropping", nil];
