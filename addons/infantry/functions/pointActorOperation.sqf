/*
 * Author: WaldoTheWarfighter
 * Late FINISH binds original actor/group/operation/deadline/route/target/lease and rejects
 * a different installed brain; generation/epoch alone cannot identify a cross-owner task.
 * Public-journal-only cleanup refuses while any private local controller remains installed.
 * Individual BLUE/GREEN orders defer new investigation and end active execution;
 * exact owned movement cleanup remains available without changing combat mode.
 * Native inventory callbacks may replace the visit. Original order/brain/epoch/route/lease
 * are rechecked after the action; superseded work publishes no result or formation return.
 * Equipment recovery issues at most one request per visit: empty-primary ammunition first,
 * otherwise existing missing-weapon recovery. Immediate nonconfirmation never permits a second request.
 * Purpose: Execute one finite investigation of an engine-observed own-group casualty location.
 * Locality/authority: Actor and group owner only; shared scheduler executes each bounded step.
 * Repeat/JIP: One actor per group, original twelve-second deadline, public cancellation journal.
 * Owner changes cancel rather than replay the task. Newer native/Zeus/specialist orders win.
 * Unacknowledged cancellation retains its public receipt for existing discovery/locality cleanup;
 * no replacement command or renewed deadline is inferred from unchanged pre-issue state.
 * Exact acknowledged cleanup may return to the saved native subformation only within the
 * original server deadline plus30s. Changed formation intent yields; no new return is issued
 * after that window. A dead/departed saved anchor may use the group leader before return issue.
 * A twelfth journal field retains return custody and the original visit reason. A self-anchor
 * issues no FOLLOW; it requires unitReady, rest and actual arrival at its retained point instead.
 * The same finite FSM observes return state every0.25s within the original cleanup window;
 * discovery may resume observation only once per owner/epoch/generation after its old FSM ends.
 * A resumed observer starts finished and cannot replay body work or extend the original window.
 * Finished/REAP/TRANSFER observe FOLLOW/formLeader or self-anchor idle proof, or newer
 * native ownership. No return replay, extra worker or renewed deadline is introduced.
 * Unknown return proof remains reserved after the window; repeated reports are coalesced.
 * Native FOLLOW acknowledgement does not prove physical travel or formation restoration.
 * Arguments: mode STRING START; actor OBJECT objNull; context/brain HASHMAP empty.
 * START context: optional body OBJECT objNull, observed ARRAY (native event position); engine caller supplies cause 5 only.
 * A bounded actual-death identity receipt can corroborate a missing source or detached corpse group.
 * Other modes: QUEUE/STEP/FINISH/TRANSFER/REAP use the current brain; TRANSFER may use journal alone.
 * Return: BOOL for admission/cleanup, NUMBER -1 for one queued STEP.
 * Current callers: DangerEngineAct, pointActor FSM, CortexDiscover/Locality/Stop,
 * CortexReleaseGroup and authenticated CortexOrderLocal RELEASE.
 * Example: ["START",soldier1,createHashMapFromArray [["body",casualty1],
 * ["observed",getPosATL casualty1]]] call CBE_fnc_PointActorOperation;
 * A VISITED result proves a position visit, never medical treatment or room safety.
 * At a verified visit, enabled ammunition sharing permits one native compatible-magazine pickup
 * for an empty primary weapon from the observed casualty clothing containers. No equipment is cloned.
 * Each admitted observation resets its generation-bound recovery record to NOT_ATTEMPTED.
 * Pickup rechecks proximity/LOS against the current body, not just the original observed goal.
 * Recovery journal records VERIFIED only for matching positive receiver/source round deltas;
 * command issue alone remains UNVERIFIED. The point result stays VISITED either way.
 * CBE accounting loops admit at most128 rows per snapshot; oversized pre-action inventories
 * defer pickup, oversized post-action evidence cannot verify it. Native snapshot cost is unmeasured.
 * Optional casualty equipment recovery may take one loaded rifle/launcher into an empty slot
 * through CasualtyWeaponRecover after the same physical visit. No backpack cloning/replacement.
 * No recovery timer, generic action cancellation or deadline extension.
 */
params [["_mode","START",[""]],["_actor",objNull,[objNull]],["_brain",createHashMap,[createHashMap]]];
if (isNull _actor || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _group=group _actor;
private _vector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _copy={_this apply {if (_x isEqualType []) then {_x call _copy} else {_x}}};
private _releaseAvailable={local _actor && {local _group} && {!isNull _group} && {!fleeing _actor}
    && {!isPlayer _actor} && {isNull remoteControlled _actor} && {isNull objectParent _actor}
    && {[_actor] call CBE_fnc_CortexCombatEffective} && {simulationEnabled _actor}
    && {!isObjectHidden _actor} && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
    && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
    && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
};
private _available={call _releaseAvailable && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {!([] call CBE_fnc_CortexIsPaused)}
    && {[_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible}
    && {[_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_Investigate_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {behaviour _actor in ["SAFE","AWARE"]} && {!fleeing _actor}
    && {combatMode _group in ["YELLOW","RED","WHITE"]} && {unitCombatMode _actor in ["YELLOW","RED","WHITE"]} && {getSuppression _actor < 0.25}
    && {isNull getAttackTarget _actor} && {isNull assignedTarget _actor}
    && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
    && {[_actor] call CBE_fnc_IndoorActorGroupAvailable}};
if (_mode in ["FINISH","TRANSFER"]) exitWith {
    private _retired=false;
    isNil {
    _retired=call {
    if (count _brain > 0) then {_brain set ["finished",true];_brain set ["pending",false];_brain set ["completed",true]};
    if (!local _actor || {!local _group}) exitWith {false};
    // A machine-local generation/epoch can collide with another owner's task.
    // Only this installed controller (or an absent pointer during transfer) may clean up.
    private _installed=_actor getVariable ["CBE_PointActor_Brain",createHashMap];
    if (count _installed > 0 && {count _brain == 0 || {_installed isNotEqualTo _brain}}) exitWith {false};
    private _order=_actor getVariable ["CBE_PointActor_Order",[]];
    if !(_order isEqualType [] && {count _order == 12}) exitWith {false};
    _order params ["_generation","_epoch","_oldGroup","_operation","_deadline","_route","_target","_lease","_issued","_before","_requestAt","_returning"];
    if (!(_generation isEqualType 0) || {!finite _generation} || {_generation < 1} || {_generation != floor _generation}
        || {!(_epoch isEqualType 0)} || {!finite _epoch} || {_epoch < 1} || {_epoch != floor _epoch}
        || {!(_oldGroup isEqualType grpNull)} || {!(_operation isEqualType 0)} || {!finite _operation} || {_operation < 0} || {_operation != floor _operation}
        || {!(_deadline isEqualType 0)} || {!finite _deadline}
        || {!(_route isEqualType [])} || {!(_target call _vector)}
        || {!(_lease isEqualType [])} || {count _lease != 3}
        || {(_lease select 0) isNotEqualTo format ["POINT_INVESTIGATE:%1:%2",_epoch,_generation]}
        || {(_lease select 1) isNotEqualTo _target}
        || {!((_lease select 2) isEqualType 0)} || {!finite (_lease select 2)}
        || {!(_issued isEqualType true)} || {!(_before isEqualType [])}
        || {!(_requestAt isEqualType 0)} || {!finite _requestAt}
        || {!(_returning isEqualType [])}
        || {_returning isNotEqualTo [] && {count _returning != 2 || {!_issued}
            || {!((_returning select 0) isEqualType objNull)} || {!((_returning select 1) isEqualType "")}}}
        || {_issued && {count _before != 3 || {!((_before select 0) isEqualType "")}
            || {!((_before select 1) isEqualType [])} || {!((_before select 2) isEqualType objNull)}
            || {_requestAt < 0}}}
        || {count _brain > 0 && {(_brain getOrDefault ["generation",-1]) != _generation
            || {(_brain getOrDefault ["ownerEpoch",-1]) != _epoch}
            || {(_brain getOrDefault ["actor",objNull]) isNotEqualTo _actor}
            || {(_brain getOrDefault ["group",grpNull]) isNotEqualTo _oldGroup}
            || {(_brain getOrDefault ["operationGeneration",-1]) != _operation}
            || {(_brain getOrDefault ["deadline",-1]) isNotEqualTo _deadline}
            || {(_brain getOrDefault ["route",[]]) isNotEqualTo _route}
            || {(_brain getOrDefault ["target",[]]) isNotEqualTo _target}
            || {(_brain getOrDefault ["lease",[]]) isNotEqualTo _lease}}}) exitWith {false};
    private _reservation=_actor getVariable ["CBE_Cortex_ActorMove",[]];
    private _destination=(expectedDestination _actor) param [0,[],[[]]];
    private _pending=_returning isEqualTo [] && {_issued} && {count _before == 3}
        && {currentCommand _actor in [_before select 0,"MOVE"]}
        && {(expectedDestination _actor) isEqualTo (_before select 1)}
        && {formLeader _actor isEqualTo (_before select 2)}
        && {!(_destination call _vector) || {_destination vectorDistance _target > 0.25}};
    // Cancellation does not turn a pending native request into a completed handback.
    // Keep its immutable receipt; discovery can reconcile later without another movement worker.
    if (_pending && {_oldGroup == _group}
        && {_reservation isEqualTo _lease || {_mode == "TRANSFER" && {_reservation isEqualTo []}}}
        && {_operation == (_group getVariable ["CBE_OperationGeneration",0])}
        && {_route isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}) exitWith {
        _actor setVariable ["CBE_PointActor_Result",[_generation,"CANCEL_PENDING",serverTime,+_target],true];
        false
    };
    private _resultReason=_brain getOrDefault ["reason","CANCELLED"];
    private _reportReturn={
        params ["_status","_anchor"];
        private _prior=_actor getVariable ["CBE_PointActor_ReturnStatus",[]];
        if (!(_prior isEqualType []) || {count _prior != 4}
            || {(_prior select [0,2]) isNotEqualTo [_generation,_status]}
            || {(_prior select 3) isNotEqualTo _anchor}) then {
            _actor setVariable ["CBE_PointActor_ReturnStatus",[_generation,_status,serverTime,_anchor],true];
        };
    };
    private _observeReturn={
        params ["_journal"];
        // Only discovery/transfer may restart observation after the old FSM ended.
        // FINISH inside an executing FSM never starts a second executor.
        if (_mode != "TRANSFER" || {serverTime >= _deadline+30}
            || {(_actor getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo _journal}) exitWith {};
        private _handle=_actor getVariable ["CBE_PointActor_FSM",-1];
        if (_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}) exitWith {};
        private _observer=_brain;
        if (count _observer == 0) then {
            _observer=createHashMapFromArray [["actor",_actor],["group",_oldGroup],
                ["generation",_generation],["ownerEpoch",_epoch],["operationGeneration",_operation],
                ["deadline",_deadline],["route",_route call _copy],["target",+_target],
                ["lease",_lease call _copy],["reason",(_journal select 11) select 1]];
        };
        private _observerEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
        private _ticket=[clientOwner,_observerEpoch,_generation];
        if ((_observer getOrDefault ["returnObserverTicket",[]]) isEqualTo _ticket) exitWith {};
        // Ticket precedes execFSM; a failed start cannot repeatedly spawn observers.
        _observer set ["returnObserverTicket",_ticket];
        _observer set ["returnObserverEpoch",_observerEpoch];
        _observer set ["finished",true];_observer set ["completed",true];
        _observer set ["pending",false];_observer set ["returnPending",true];
        _actor setVariable ["CBE_PointActor_Brain",_observer];
        private _returnHandle=[_actor,_observer] execFSM "\z\cbe\addons\main\fsm\pointActor.fsm";
        if ((_actor getVariable ["CBE_PointActor_Order",[]]) isEqualTo _journal
            && {(_actor getVariable ["CBE_PointActor_Brain",createHashMap]) isEqualTo _observer}) then {
            _actor setVariable ["CBE_PointActor_FSM",_returnHandle];
        };
    };
    private _retire={
        params ["_reason",["_status","",[""]],["_anchor",objNull,[objNull]]];
        if ((_actor getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo _order) exitWith {false};
        if (count _brain > 0) then {_brain set ["returnPending",false]};
        if (_status != "") then {[_status,_anchor] call _reportReturn};
        if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _lease) then {_actor setVariable ["CBE_Cortex_ActorMove",nil]};
        _actor setVariable ["CBE_PointActor_Result",[_generation,_reason,serverTime,+_target],true];
        _actor setVariable ["CBE_PointActor_Order",nil,true];
        if ((_actor getVariable ["CBE_PointActor_Brain",createHashMap]) isEqualTo _brain || {count _brain == 0}) then {
            _actor setVariable ["CBE_PointActor_Brain",nil];_actor setVariable ["CBE_PointActor_FSM",nil];
        };
        if ((_oldGroup getVariable ["CBE_PointActor_Actor",objNull]) == _actor) then {_oldGroup setVariable ["CBE_PointActor_Actor",nil,true]};
        true
    };
    if (_returning isNotEqualTo []) exitWith {
        _returning params ["_anchor","_originalReason"];
        private _nativeCommand=toUpperANSI currentCommand _actor;
        private _sameContext=_oldGroup == _group
            && {_operation == (_group getVariable ["CBE_OperationGeneration",0])}
            && {_route isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)};
        // A formation anchor cannot follow itself. No return command was issued
        // for that case; observe the original point leg settled at the visit instead.
        if (_sameContext && {_anchor == _actor} && {formLeader _actor == _actor}
            && {_nativeCommand in ["","MOVE"]} && {_destination call _vector}
            && {_destination vectorDistance _target <= 0.25} && {unitReady _actor}
            && {abs speed _actor < 0.5}
            && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 2}) exitWith {
            [_originalReason,"NATIVE_IDLE_AT_VISIT",_anchor] call _retire
        };
        if (_sameContext && {_anchor != _actor} && {!isNull _anchor} && {alive _anchor} && {group _anchor == _group}
            && {_nativeCommand == "FOLLOW"} && {formLeader _actor == _anchor}) exitWith {
            [_originalReason,"FOLLOW_OBSERVED",_anchor] call _retire
        };
        // A newer observable native task wins without a return replay or late reset.
        // Changed MOVE geometry alone may be our pending FOLLOW transitioning;
        // it is neither positive replacement nor native handback acknowledgement.
        if (!_sameContext || {!(_nativeCommand in ["","MOVE","FOLLOW"])}
            || {_nativeCommand == "FOLLOW" && {formLeader _actor != _anchor}}
            || {_anchor == _actor && {formLeader _actor != _actor}}
            || {_anchor == _actor && {_nativeCommand == "MOVE"} && {_destination call _vector}
                && {_destination vectorDistance _target > 0.25}}) exitWith {
            [_originalReason,"YIELDED_TO_NATIVE_ORDER",_anchor] call _retire
        };
        if (count _brain > 0) then {_brain set ["returnPending",true]};
        [["RETURN_PENDING","RETURN_UNRESOLVED"] select (serverTime >= _deadline+30),_anchor] call _reportReturn;
        [_order] call _observeReturn;
        (_actor getVariable ["CBE_PointActor_Order",[]]) isEqualTo []
    };
    private _owns=_issued && {serverTime < _deadline+30}
        && {_oldGroup == _group} && {call _releaseAvailable}
        && {formLeader _actor isEqualTo (_before select 2)}
        && {_reservation isEqualTo _lease || {_mode == "TRANSFER" && {_reservation isEqualTo []}}}
        && {_operation == (_group getVariable ["CBE_OperationGeneration",0])}
        && {[_actor] call CBE_fnc_IndoorActorGroupAvailable}
        && {_route isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        && {currentCommand _actor in ["MOVE",""]} && {isNull getAttackTarget _actor}
        && {isNull assignedTarget _actor} && {_destination call _vector}
        && {_destination vectorDistance _target <= 0.25};
    private _returnLeader=if (_issued) then {_before select 2} else {objNull};
    if (isNull _returnLeader || {group _returnLeader != _group}
        || {!([_returnLeader] call CBE_fnc_CortexCombatEffective)}) then {_returnLeader=leader _group};
    if (_owns && {!isNull _returnLeader} && {group _returnLeader == _group}
        && {[_returnLeader] call CBE_fnc_CortexCombatEffective}) exitWith {
        if ((_actor getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo _order) exitWith {false};
        // Persist before native issue; subsequent FINISH/TRANSFER calls only observe.
        private _returnOrder=_order call _copy;
        _returnOrder set [11,[_returnLeader,_resultReason]];
        if (count _brain > 0) then {_brain set ["returnPending",true]};
        _actor setVariable ["CBE_PointActor_Order",_returnOrder,true];
        _actor setVariable ["CBE_PointActor_Result",[_generation,_resultReason,serverTime,+_target],true];
        ["RETURN_PENDING",_returnLeader] call _reportReturn;
        if (_returnLeader != _actor) then {_actor doFollow _returnLeader};
        [_returnOrder] call _observeReturn;
        (_actor getVariable ["CBE_PointActor_Order",[]]) isEqualTo []
    };
    [_resultReason] call _retire
    };
    };
    _retired
};
if (_mode == "START") exitWith {
    private _body=_brain getOrDefault ["body",objNull];private _observed=_brain getOrDefault ["observed",[]];
    if (!(_body isEqualType objNull) || {!(_observed call _vector)}
        || {!(call _available)} || {currentCommand _actor != ""}
        || {getUnitState _actor in ["PLANNING","REPLAN","BUSY"]}
        || {[_actor] call CBE_fnc_CortexActorMoveReserved}
        || {(_actor getVariable ["CBE_PointActor_Order",[]]) isNotEqualTo []}
        || {!isNull (_group getVariable ["CBE_PointActor_Actor",objNull])}
        || {serverTime < (_group getVariable ["CBE_PointActor_After",-1])}
        || {(_group getVariable ["CBE_AIPass_Epoch",0]) <= 0}) exitWith {false};
    _body=[_actor,_observed,_body] call CBE_fnc_CasualtyObservationSelect;
    if (isNull _body || {_actor distance2D _body > 25} || {_actor distance2D _body < 2}) exitWith {false};
    private _route=[_group] call CBE_fnc_NativeOrderReceipt;
    if (count _route != 2 || {(_route select 1) != -1}) exitWith {false};
    private _goal=getPosATL _body;private _goalASL=getPosASL _body;
    if (!(_goal call _vector) || {!(_goalASL call _vector)}) exitWith {false};
    private _generation=(_actor getVariable ["CBE_PointActor_Generation",0])+1;
    private _deadline=serverTime+12;private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    private _lease=[format ["POINT_INVESTIGATE:%1:%2",_epoch,_generation],+_goal,time+12];
    _brain=createHashMapFromArray [["actor",_actor],["group",_group],["generation",_generation],
        ["ownerEpoch",_epoch],["operationGeneration",_group getVariable ["CBE_OperationGeneration",0]],
        ["deadline",_deadline],["route",_route call _copy],["target",+_goal],["goalASL",+_goalASL],
        ["body",_body],["lease",_lease call _copy],["issued",false],["phase","ISSUE"],
        ["progressAt",serverTime],["progressPosition",getPosASL _actor],["nextAt",time],
        ["finished",false],["pending",false],["completed",false],
        ["jobKey",format ["CBE_POINT_%1_%2",clientOwner,_actor]]];
    _actor setVariable ["CBE_PointActor_Generation",_generation];
    _actor setVariable ["CBE_PointActor_Recovery",[_generation,"NOT_ATTEMPTED",_body,"",0,serverTime],true];
    _actor setVariable ["CBE_PointActor_Equipment",[_generation,"NOT_ATTEMPTED",_body,"","",serverTime],true];
    _actor setVariable ["CBE_PointActor_Brain",_brain];
    _actor setVariable ["CBE_Cortex_ActorMove",_lease call _copy];
    _actor setVariable ["CBE_PointActor_Order",[_generation,_epoch,_group,_brain get "operationGeneration",
        _deadline,_route call _copy,+_goal,_lease call _copy,false,[],-1,[]],true];
    _group setVariable ["CBE_PointActor_Actor",_actor,true];
    _group setVariable ["CBE_PointActor_After",serverTime+30,true];
    private _handle=[_actor,_brain] execFSM "\z\cbe\addons\main\fsm\pointActor.fsm";
    _actor setVariable ["CBE_PointActor_FSM",_handle];
    private _started=_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}
        && {(_actor getVariable ["CBE_PointActor_Brain",createHashMap]) isEqualTo _brain}
        && {!(_brain getOrDefault ["finished",false])};
    if (!_started) then {_brain set ["reason","FSM_START_FAILED"];["FINISH",_actor,_brain] call CBE_fnc_PointActorOperation};
    _started
};
private _current=count _brain > 0 && {local _actor} && {local _group}
    && {(_actor getVariable ["CBE_PointActor_Brain",createHashMap]) isEqualTo _brain}
    && {(_brain getOrDefault ["group",grpNull]) == _group}
    && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])};
if (_mode == "REAP") exitWith {
    private _handle=_actor getVariable ["CBE_PointActor_FSM",-1];
    if (_handle isEqualType 0 && {finite _handle} && {_handle >= 0} && {!completedFSM _handle}) exitWith {false};
    // A completed old-epoch private FSM may retain the immutable public return.
    // Transfer cleanup validates that exact journal; it never resumes investigation.
    if (!_current) exitWith {["TRANSFER",_actor,_brain] call CBE_fnc_PointActorOperation};
    if !("reason" in _brain) then {_brain set ["reason","EXECUTOR_ENDED"]};
    ["TRANSFER",_actor,_brain] call CBE_fnc_PointActorOperation
};
if (_mode == "QUEUE") exitWith {
    if (!_current || {_brain getOrDefault ["finished",false]}) exitWith {false};
    if (_brain getOrDefault ["pending",false]) exitWith {true};
    _brain set ["pending",true];_brain set ["completed",false];
    [{params ["_job"];["STEP",_job get "actor",_job] call CBE_fnc_PointActorOperation},_brain,0,_brain get "jobKey"] call CBE_fnc_CortexQueueJob;
    true
};
if (_mode != "STEP") exitWith {false};
_brain set ["pending",false];_brain set ["completed",true];_brain set ["nextAt",time+0.5];
private _finish={params ["_reason"];_brain set ["reason",_reason];["FINISH",_actor,_brain] call CBE_fnc_PointActorOperation;-1};
if (!_current || {_brain getOrDefault ["finished",false]}) exitWith {-1};
private _handle=_actor getVariable ["CBE_PointActor_FSM",-1];
if (!(_handle isEqualType 0) || {!finite _handle} || {_handle < 0} || {completedFSM _handle}) exitWith {["EXECUTOR_ENDED"] call _finish};
if (serverTime >= (_brain get "deadline")) exitWith {["DEADLINE"] call _finish};
if (!(call _available)
    || {(_group getVariable ["CBE_OperationGeneration",0]) != (_brain get "operationGeneration")}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_brain get "route")}
    || {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo (_brain get "lease")}) exitWith {["PREEMPTED"] call _finish};
private _body=_brain get "body";
if (isNull _body || {alive _body} || {isObjectHidden _body} || {(getPosASL _body) vectorDistance (_brain get "goalASL") > 1}) exitWith {["BODY_CHANGED"] call _finish};
private _target=_brain get "target";
if ((_brain get "phase") == "ISSUE") exitWith {
    if (currentCommand _actor != "" || {getUnitState _actor in ["PLANNING","REPLAN","BUSY"]}) exitWith {["NATIVE_TASK"] call _finish};
    _brain set ["before",[currentCommand _actor,(expectedDestination _actor) call _copy,formLeader _actor]];
    _brain set ["requestAt",serverTime];
    _actor doMove _target;
    _brain set ["issued",true];_brain set ["phase","APPROACH"];
    private _order=+(_actor getVariable ["CBE_PointActor_Order",[]]);_order set [8,true];
    _order set [9,(_brain get "before") call _copy];_order set [10,_brain get "requestAt"];
    _actor setVariable ["CBE_PointActor_Order",_order,true];
    -1
};
private _destination=(expectedDestination _actor) param [0,[],[[]]];
private _ack=_destination call _vector && {_destination vectorDistance _target <= 0.25};
if (!_ack) exitWith {
    private _before=_brain get "before";
    if (serverTime-(_brain get "requestAt") < 2
        && {currentCommand _actor in [_before select 0,"MOVE"]}
        && {(expectedDestination _actor) isEqualTo (_before select 1)}
        && {formLeader _actor isEqualTo (_before select 2)}) then {-1} else {["NATIVE_TASK_OR_UNACKNOWLEDGED"] call _finish}
};
if (!(currentCommand _actor in ["","MOVE"])) exitWith {["NATIVE_TASK"] call _finish};
private _position=getPosASL _actor;
if (_position vectorDistance (_brain get "goalASL") <= 2
    && {!(lineIntersects [eyePos _actor,(_brain get "goalASL") vectorAdd [0,0,0.5],_actor,_body])}) exitWith {
    // Native TakeMagazine can act at arbitrary distance: only this physical visit grants it.
    // One equipment request per visit: an unconfirmed ammo action is still issued work.
    private _pointAmmoActionIssued=false;
    private _pointEquipmentSuperseded=false;
    private _pointPickupOrder=(_actor getVariable ["CBE_PointActor_Order",[]]) call _copy;
    private _pointPickupCurrent={
        count _pointPickupOrder == 11 && {local _actor} && {local _group} && {group _actor == _group}
            && {(_actor getVariable ["CBE_PointActor_Brain",createHashMap]) isEqualTo _brain}
            && {!(_brain getOrDefault ["finished",false])}
            && {(_actor getVariable ["CBE_PointActor_Order",[]]) isEqualTo _pointPickupOrder}
            && {(_group getVariable ["CBE_AIPass_Epoch",0]) isEqualTo (_pointPickupOrder select 1)}
            && {(_group getVariable ["CBE_OperationGeneration",0]) isEqualTo (_pointPickupOrder select 3)}
            && {serverTime < (_pointPickupOrder select 4)}
            && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo (_pointPickupOrder select 7)}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_pointPickupOrder select 5)}
    };
    // One attempt uses the existing observation lease/deadline, never a new rearm controller.
    if (primaryWeapon _actor != ""
        && {[_group,"CBE_AIPass_AmmoShare_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {!([_actor] call CBE_fnc_CortexPrimaryAmmoAvailable)}) then {
        private _weapon=primaryWeapon _actor;
        private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
        private _main=if ("this" in _muzzles) then {"this"} else {_muzzles param [0,"this"]};
        private _compatible=compatibleMagazines [_weapon,_main];
        private _supply=objNull; private _magazine=""; private _sourceBefore=0;
        {
            if (!isNull _x && {_compatible isNotEqualTo []}) then {
                private _cargo=magazinesAmmoCargo _x;
                if (count _cargo > 128) then {continue};
                private _index=(_cargo select [0,128]) findIf {
                    (_x select 1) > 0 && {(_x select 0) in _compatible} && {_actor canAdd (_x select 0)}
                };
                if (_index >= 0) exitWith {
                    _supply=_x; _magazine=(_cargo select _index) select 0;
                    {if ((_x select 0) == _magazine) then {_sourceBefore=_sourceBefore+(_x select 1)}} forEach _cargo;
                };
            };
        } forEach [uniformContainer _body,vestContainer _body,backpackContainer _body];
        if (!isNull _supply && {_weapon != ""}
            && {(getPosASL _actor) vectorDistance (getPosASL _body) <= 2}
            && {!(lineIntersects [eyePos _actor,(getPosASL _body) vectorAdd [0,0,0.5],_actor,_body])}) then {
            private _rounds={
                params ["_rows","_class"];
                if (count _rows > 128) exitWith {-1};
                private _total=0;
                {if ((_x select 0) == _class) then {_total=_total+(_x select 1)}} forEach _rows;
                _total
            };
            private _before=[magazinesAmmoFull _actor,_magazine] call _rounds;
            if (_before >= 0) then {
            _pointAmmoActionIssued=true;
            _actor action ["TakeMagazine",_supply,_magazine];
            // Native inventory callbacks may replace this visit synchronously.
            // No stale result or follow-through may be published into its successor.
            if !(call _pointPickupCurrent) exitWith {_pointEquipmentSuperseded=true};
            private _receiverAfter=[magazinesAmmoFull _actor,_magazine] call _rounds;
            private _sourceAfter=[magazinesAmmoCargo _supply,_magazine] call _rounds;
            private _gain=_receiverAfter-_before;
            private _removed=_sourceBefore-_sourceAfter;
            private _verified=_receiverAfter >= 0 && {_sourceAfter >= 0}
                && {_gain > 0 && {_gain == _removed}} && {primaryWeapon _actor == _weapon};
            _actor setVariable ["CBE_PointActor_Recovery",[_brain get "generation",
                ["UNVERIFIED","VERIFIED"] select _verified,_body,_magazine,
                [0,_gain] select _verified,serverTime],true];
            };
        };
    };
    if (_pointEquipmentSuperseded) exitWith {_brain set ["finished",true];-1};
    _brain set ["visitReached",true];
    // Urgent primary ammunition wins over a second weapon pickup in this callback.
    // An immediate UNVERIFIED result does not authorize replacing the pending action.
    if (!_pointAmmoActionIssued) then {[_actor,_body,_brain] call CBE_fnc_CasualtyWeaponRecover};
    if !(call _pointPickupCurrent) exitWith {_brain set ["finished",true];-1};
    ["VISITED"] call _finish
};
if (_position vectorDistance (_brain get "progressPosition") >= 1) then {
    _brain set ["progressPosition",_position];_brain set ["progressAt",serverTime];
};
if (serverTime-(_brain get "progressAt") >= 6 && {!(getUnitState _actor in ["PLANNING","REPLAN"])}) exitWith {["NO_PROGRESS"] call _finish};
-1
