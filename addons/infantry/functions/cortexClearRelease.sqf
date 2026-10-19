/*
 * Author: WaldoTheWarfighter
 * Release commands preserve live or malformed actor reservations; only typed finite leases expire.
 * Cancels a clearing order immediately and resumes formation after doStop. Clearance does not own
 * group behaviour or combat mode, so release preserves any contact or Zeus change made during it.
 * Individual player, remote-control and external-owner actors never receive restoration commands.
 * A live MOVE is recalled only when its destination matches this clearance job receipt;
 * newer individual movement survives release even when the caller requests formation restoration.
 * Mounted actors never receive formation recall from their former on-foot clearance job.
 * FOLLOW, ATTACK, CBE and other native tasks do not grant recall authority; only idle actors, STOP
 * at this job's recorded same-floor hold, or MOVE to its recorded destination can resume formation.
 * Settings ownership alone cannot recall a stopped actor at a different location.
 * Exact exterior observation leases are retired; watching is cleared only for free native actors
 * under unchanged CBE authority, never a player, external takeover or replacement task.
 * Locality/authority: server authenticates dispatch; the current owner executes group commands.
 * Group retirement and per-actor cleanup recheck original generation/epoch so helper cleanup
 * cannot erase a successor clearance or its settings.
 * Repeat/JIP: request tokens are consumed once; no stale order is replayed for JIP.
 * Arguments: 0: group <GROUP>, default grpNull; 1: restore formation <BOOL>, default true. Pass
 * false when Zeus has already supplied a replacement order to prevent formation recall.
 * Unchanged CBE speed/posture leases are released independently for ordinary local actors.
 * Return Value: Boolean, a clearing order existed.
 * Current callers: AI Orders, replacement orders, Zeus release and stop.
 * Example: [_group] call CBE_fnc_CortexClearRelease;
 */
params [["_group", grpNull, [grpNull]],["_restore",true,[true]]];
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _order = +(_group getVariable ["CBE_AIPass_ClearOrder", []]);
if (_order isEqualTo []) exitWith {false};
// A disabled feature must still release CBE's own movement lease.  Only an actual player,
// Zeus, compatibility or specialist takeover suppresses a formation recall; broad eligibility
// also includes normal feature gates and would otherwise leave a released clear element stopped.
private _externalTakeover = [_group] call CBE_fnc_CortexExternalTakeover;
if (_restore && {_externalTakeover}) then {_restore=false};
private _buildingBrain=_group getVariable ["CBE_BuildingBrain",createHashMap];
private _entryClearGeneration=_group getVariable ["CBE_AIPass_ClearGeneration",0];
private _entryEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _releaseGeneration=_entryClearGeneration+1;
private _entryOperation=_group getVariable ["CBE_Operation",createHashMap];
private _entryOperationGeneration=_entryOperation getOrDefault ["generation",-1];
private _motionJob=createHashMapFromArray [["group",_group],["visitContext",+(_group getVariable ["CBE_Cortex_ClearVisitContext",[]])]];
private _retiredRoster=_group getVariable ["CBE_Cortex_ClearRoster",[]];
private _releaseJob=_buildingBrain getOrDefault ["job",createHashMap];
private _movementTargets=_releaseJob getOrDefault ["movementTargets",createHashMap];
private _releaseAdmitted=false;
isNil {
    if (local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_entryClearGeneration == (_group getVariable ["CBE_AIPass_ClearGeneration",0])}
        && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo _order}
        && {(_group getVariable ["CBE_BuildingBrain",createHashMap]) isEqualTo _buildingBrain}
        && {(_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isEqualTo (_motionJob get "visitContext")}) then {
        if (count _retiredRoster == 4 && {(_retiredRoster select 0) isEqualTo (_motionJob get "visitContext")}) then {
            _group setVariable ["CBE_Cortex_ClearRoster",nil,true];
        };
        if (count _buildingBrain > 0) then {
            _buildingBrain set ["cancelled",true];
            _buildingBrain set ["cancelReason","CLEAR_RELEASE"];
            _buildingBrain set ["completed",true];
        };
        _group setVariable ["CBE_AIPass_ClearGeneration",_releaseGeneration];
        _group setVariable ["CBE_BuildingBrain",nil];
        _group setVariable ["CBE_BuildingBrain_FSM",nil];
        _releaseAdmitted=true;
    };
};
if (!_releaseAdmitted) exitWith {false};
// A release often comes from a Zeus replacement order.  Invalidate the common operation now,
// rather than waiting for the low-frequency building job to notice the cleared flag.  Restrict
// this to CLEAR so a newer, externally owned operation cannot be cancelled by stale clear state.
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if ((_operation getOrDefault ["intent",""]) == "CLEAR"
    && {(_operation getOrDefault ["generation",-2]) == _entryOperationGeneration}
    && {_operation isEqualTo _entryOperation}) then {
    [_group,_operation getOrDefault ["generation",-1],"CLEAR_RELEASE"] call CBE_fnc_OperationCancel;
};
private _roomCount=count ((_order select 0) buildingPos -1);
private _groupRetired=false;
isNil {
    if (local _group && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_releaseGeneration == (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
        && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo _order}
        && {count (_group getVariable ["CBE_BuildingBrain",createHashMap]) == 0}) then {
_group setVariable ["CBE_Cortex_ClearResult",["CANCELLED",count (_order select 1),_roomCount],true];
_group setVariable ["CBE_Cortex_ClearEvidence",[+(_order param [1,[]]),+(_order param [4,[]]),+(_order param [5,[]]),+(_order param [6,[]]),_order param [2,serverTime],_order param [7,serverTime]],true];
_group setVariable ["CBE_AIPass_ClearOrder", nil, true];
_group setVariable ["CBE_Cortex_ClearFollowBudget",nil,true];
_group setVariable ["CBE_AIPass_ClearBuilding", nil, true];
_group setVariable ["CBE_Cortex_ClearEgress",nil,true];
_group setVariable ["CBE_Cortex_ClearEarlyExits",nil,true];
_group setVariable ["CBE_Cortex_ClearReserveAdmission",nil,true];
_group setVariable ["CBE_AIPass_ClearApplied", nil];
        _groupRetired=true;
    };
};
if (!_groupRetired) exitWith {false};
private _leader=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
{
    isNil {
    if (local _group && {local _x} && {!isPlayer _x} && {group _x == _group}
        && {_entryEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {_releaseGeneration == (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
        && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo []}
        && {count (_group getVariable ["CBE_BuildingBrain",createHashMap]) == 0}) then {
        _leader=[_group] call CBE_fnc_CortexGroupAnchor;
        if (isNull _leader) then {_leader=leader _group};
        private _heldByJob=[_x,_releaseJob] call CBE_fnc_BuildingActorHoldOwned;
        private _ownedActor=_heldByJob || !isNil {_x getVariable "CBE_Cortex_ClearStance"}
            || {!isNil {_x getVariable "CBE_Cortex_ClearForcedSpeed"}}
            || {private _stage=_x getVariable ["CBE_Cortex_ClearReserve",[]]; count _stage == 3
                && {(_stage select 0) == (_group getVariable ["CBE_AIPass_ClearGeneration",0])-1}
                && {(_stage select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}};
        [_x,_group,_releaseGeneration,_entryEpoch] call CBE_fnc_CortexClearSettingsRelease;
        private _free=!([_x] call CBE_fnc_CortexActorMoveReserved);
        private _taskFree=!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]);
        if (_ownedActor && {_free} && {_taskFree || {currentCommand _x == "JOIN"}}
            && {[_x] call CBE_fnc_CortexCombatEffective}
            && {isNull remoteControlled _x}
            && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}) then {
            // Release only unchanged CBE settings; never recall a replacement movement order.
            private _releaseOwnedSettings=!([_group,true,_x] call CBE_fnc_CortexExternalTakeover)
                && {isNull objectParent _x};

            private _exitWatch=_x getVariable ["CBE_Cortex_ClearExitWatch",[]];
            if (_releaseOwnedSettings && {_taskFree} && {currentCommand _x in ["","STOP"]}
                && {count _exitWatch == 3}
                && {(_exitWatch select 0) == (_group getVariable ["CBE_AIPass_ClearGeneration",0])-1}
                && {(_exitWatch select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}
                && {(_x getVariable ["CBE_Cortex_ClearExitWatchLocal",[]]) isEqualTo _exitWatch}) then {
                _x doWatch objNull;
            };
            private _issued=_movementTargets getOrDefault [netId _x,[]];
            private _destination=(expectedDestination _x) param [0,[]];
            private _movementOwned=currentCommand _x == ""
                || {[_x,_releaseJob] call CBE_fnc_BuildingActorHoldOwned}
                || {currentCommand _x == "MOVE" && {count _issued == 3 && {count _destination == 3}
                    && {_destination vectorDistance _issued <= 0.25}}};
            if (_restore && {_taskFree} && {_movementOwned} && {isNull objectParent _x}) then {
                _x setVariable ["CBE_Cortex_ClearRecall",[_group getVariable ["CBE_AIPass_ClearGeneration",0],_group getVariable ["CBE_AIPass_Epoch",0],_leader,time+5]];
                _x doFollow _leader;
            };
        };
        private _retiredWatch=_x getVariable ["CBE_Cortex_ClearExitWatch",[]];
        if (count _retiredWatch == 3
            && {(_retiredWatch select 0) == (_group getVariable ["CBE_AIPass_ClearGeneration",0])-1}
            && {(_retiredWatch select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
            _x setVariable ["CBE_Cortex_ClearExitWatch",nil,true];
            if ((_x getVariable ["CBE_Cortex_ClearExitWatchLocal",[]]) isEqualTo _retiredWatch) then {
                _x setVariable ["CBE_Cortex_ClearExitWatchLocal",nil];
            };
        };
        ["RETIRE",_x,_motionJob] call CBE_fnc_BuildingActorMotion;
        _x setVariable ["CBE_Cortex_ClearReserve",nil];
    };
    };
} forEach units _group;
true
