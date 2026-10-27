/*
 * Author: WaldoTheWarfighter
 * Advances one finite civilian danger escape through CBE's shared owner-local scheduler.
 * The step observes physical progress, permits one recovery reissue after a genuine stall and then
 * retires. Arrival needs less than two metres of 3D point proximity; the separate six-metre
 * native-goal matching tolerance does not establish arrival or material-cover protection.
 * New native tasks, routes or destinations end observation without a retry.
 * No temporary behaviour, group pace or posture is applied, so retirement restores no settings.
 * A superseding task retires only this generation's metadata; no restoration or movement replay.
 * Observation deadline or exhausted retry retains an exact ongoing escape MOVE receipt for
 * a later fresh danger event. Retention is not movement cancellation, completion or renewed work.
 * Original group identity prevents a joined civilian's old receipt from authorising that move.
 * Zeus, player, locality and specialist/external ownership cancel immediately without another command.
 *
 * Locality / Authority: runs only on the current owner of the civilian's group and unit.
 * Repeat/JIP: Owner/observer serial and shared retry-consumption receipt guard each callback.
 * A new owner adopts observation under the original deadline; no movement is replayed.
 * New local progress samples never extend that deadline or restore a consumed retry.
 *
 * Arguments:
 * 0: state <HASHMAP> containing unit, group, generation, destination and native order receipt
 *
 * Return Value:
 * Number - seconds until the next step, or -1 when the response is finished.
 *
 * Current callers: CBE_fnc_CortexCivilianAdopt through CBE_fnc_CortexQueueJob.
 *
 * Example:
 * [CBE_fnc_CortexCivilianStep,_state,2,"CBE_CIVILIAN_12"] call CBE_fnc_CortexQueueJob;
 * Result: the escape is observed without a private loop or repeated destination churn.
 */

params [["_state",createHashMap,[createHashMap]]];
private _unit=_state getOrDefault ["unit",objNull];
private _group=_state getOrDefault ["group",grpNull];
private _generation=_state getOrDefault ["generation",-1];
private _destination=_state getOrDefault ["destination",[]];
private _arrivalRadius=2;
private _observer=_unit getVariable ["CBE_Cortex_CivilianObserver",[]];
if ((_state getOrDefault ["observerOwner",-1]) != clientOwner || {count _observer != 5}
    || {(_observer select 3) != (_state getOrDefault ["observerSerial",-1])}
    || {_state getOrDefault ["cancelled",false]}) exitWith {-1};
private _completeObserver={
    _state set ["completed",true];
    // QueueJob can merge payload values into an existing map. Retire by the current
    // serial, not by assuming the private installer still holds that same map object.
    if (!isNull _unit && {local _unit}
        && {((_unit getVariable ["CBE_Cortex_CivilianObserver",[]]) param [3,-1])
            == (_state getOrDefault ["observerSerial",-2])}) then {
        _unit setVariable ["CBE_Cortex_CivilianObserver",nil];
    };
};
private _finish={
    params [["_reason","FINISHED",[""]]];
    call _completeObserver;
    if (!isNull _unit && {local _unit}
        && {_generation == (_unit getVariable ["CBE_Cortex_CivilianGeneration",-2])}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
        private _receipt=_unit getVariable ["CBE_Cortex_CivilianReaction",[]];
        private _currentGoal=(expectedDestination _unit) param [0,[],[[]]];
        private _retain=_reason in ["DEADLINE_EXPIRED","STALLED_AFTER_RETRY","FEATURE_DISABLED","RETRY_PROOF_MISSING"]
            && {count _receipt == 7} && {(_receipt select 2) == _generation}
            && {(_receipt select 6) == _group} && {group _unit == _group}
            && {(_receipt select 4) isEqualTo _destination}
            && {(_receipt select 5) isEqualTo _nativeOrder}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _nativeOrder}
            && {currentCommand _unit == "MOVE"}
            && {count _currentGoal == 3} && {count _destination == 3}
            && {_currentGoal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_destination findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_currentGoal distance _destination <= 6} && {_unit distance _destination >= _arrivalRadius};
        if (!_retain) then {
            _unit setVariable ["CBE_Cortex_CivilianReaction",[],true];
            _unit setVariable ["CBE_Cortex_CivilianReactionUntil",nil,true];
        };
        private _outcome=if (_retain) then {_reason+"_NATIVE_MOVE_RETAINED"} else {_reason};
        _unit setVariable ["CBE_Cortex_CivilianResult",[_generation,_outcome,serverTime],true];
    };
    -1
};
if (isNull _unit || {isNull _group} || {!local _unit} || {!local _group} || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {isPlayer _unit} || {_generation != (_unit getVariable ["CBE_Cortex_CivilianGeneration",-2])}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {
    call _completeObserver;-1
};
// Passive receipt comparisons precede every possible recovery write. An ordinary MOVE
// with a different goal belongs to the mission even when its command label is unchanged.
private _nativeOrder=_state getOrDefault ["nativeOrder",[]];
private _goal=(expectedDestination _unit) param [0,[],[[]]];
private _atDestination=count _destination == 3 && {_unit distance _destination < _arrivalRadius};
private _taskOwned=group _unit == _group && {simulationEnabled _unit} && {!isObjectHidden _unit}
    && {isNull objectParent _unit} && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
    && {!([_unit] call CBE_fnc_CortexActorMoveReserved)}
    && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
    && {!fleeing _unit}
    && {currentCommand _unit in ["","MOVE","WAIT"] || {_atDestination && {currentCommand _unit == "FOLLOW"}}}
    && {_nativeOrder isNotEqualTo []}
    && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _nativeOrder}
    && {count _destination == 3}
    && {_destination findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_atDestination && {currentCommand _unit in ["","WAIT","FOLLOW"]}
        || {count _goal == 3 && {_goal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_goal distance _destination <= 6}}};
if (!_taskOwned) exitWith {["NATIVE_TASK_OR_ORDER_CHANGED"] call _finish};
if (!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}) exitWith {["FEATURE_DISABLED"] call _finish};
if (_atDestination) exitWith {["ARRIVED"] call _finish};
if (_destination isEqualTo [] || {serverTime >= (_state getOrDefault ["until",0])}) exitWith {
    ["DEADLINE_EXPIRED"] call _finish
};

private _position=getPosATL _unit;
private _lastPosition=_state getOrDefault ["lastPosition",_position];
if (_position distance2D _lastPosition >= 3) then {
    _state set ["lastPosition",_position];
    _state set ["lastProgressAt",serverTime];
};
// A native ownership change cannot mint another retry. The public consumption receipt
// is written before issue and never reset by observer adoption or another event installer.
private _retryReceipt=[_generation,_state getOrDefault ["until",0],_group];
private _retry=_unit getVariable ["CBE_Cortex_CivilianRetrySpent",[]];
if (!(_retry isEqualType []) || {count _retry != 4}
    || {(_retry select [0,3]) isNotEqualTo _retryReceipt}
    || {!((_retry select 3) isEqualType true)}) exitWith {["RETRY_PROOF_MISSING"] call _finish};
if (_retry select 3) then {_state set ["reissued",true]};
private _stalled=serverTime-(_state getOrDefault ["lastProgressAt",serverTime]) >= 8;
// Finish at function scope; an exit inside the retry block would still return 2 below.
if (_stalled && {_state getOrDefault ["reissued",false]}) exitWith {["STALLED_AFTER_RETRY"] call _finish};
if (_stalled) then {
    // One engine-native retry is sufficient. A second stall is reported by retirement rather than
    // allowing a civilian to hold the shared queue or repeatedly overwrite movement.
    _unit setVariable ["CBE_Cortex_CivilianRetrySpent",_retryReceipt+[true],true];
    _state set ["reissued",true];
    _unit doMove _destination;
    _state set ["lastProgressAt",serverTime];
};
2
