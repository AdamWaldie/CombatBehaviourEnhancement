/*
 * Author: WaldoTheWarfighter
 * Advances one finite civilian danger escape through CBE's shared owner-local scheduler.
 * The step observes physical progress, permits one recovery reissue after a genuine stall and then
 * retires. New native tasks, routes or destinations end movement without a retry.
 * A superseding task retains passive restoration proof and blocks another automatic escape;
 * it is not permission to restore settings or claim native movement has stopped.
 * Normal completion restores only CARELESS/FULL/UP values still owned by this generation. Zeus, player,
 * locality and specialist/external ownership cancel immediately without issuing another command.
 *
 * Locality / Authority: runs only on the current owner of the civilian's group and unit.
 * Repeat/JIP: generation and locality scoped; stale or migrated jobs retire without replay.
 *
 * Arguments:
 * 0: state <HASHMAP> containing unit, group, generation, destination and restore values
 *
 * Return Value:
 * Number - seconds until the next step, or -1 when the response is finished.
 *
 * Current callers: CBE_fnc_CortexCivilianReact through CBE_fnc_CortexQueueJob.
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
private _finish={
    params [["_restoreAllowed",true,[true]],["_reason","FINISHED",[""]]];
    if (!isNull _unit && {local _unit}
        && {_generation == (_unit getVariable ["CBE_Cortex_CivilianGeneration",-2])}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
        private _restore=_state getOrDefault ["restore",[]];
        if (!_restoreAllowed && {count _restore == 3}) then {
            _unit setVariable ["CBE_Cortex_CivilianRestorePending",[_generation,_group,+_restore,_reason,serverTime],true];
        };
        if (_restoreAllowed && {group _unit == _group} && {count _restore == 3}) then {
            if (behaviour _unit == "CARELESS") then {_unit setBehaviour (_restore select 0)};
            if (speedMode _group == "FULL") then {_group setSpeedMode (_restore select 1)};
            if (unitPos _unit == "UP") then {_unit setUnitPos (_restore select 2)};
        };
        _unit setVariable ["CBE_Cortex_CivilianReaction",[],true];
        _unit setVariable ["CBE_Cortex_CivilianReactionUntil",nil,true];
        _unit setVariable ["CBE_Cortex_CivilianResult",[_generation,_reason,serverTime],true];
    };
    -1
};
if (isNull _unit || {isNull _group} || {!local _unit} || {!local _group} || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {isPlayer _unit} || {_generation != (_unit getVariable ["CBE_Cortex_CivilianGeneration",-2])}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {-1};
// Passive receipt comparisons precede every possible recovery write. An ordinary MOVE
// with a different goal belongs to the mission even when its command label is unchanged.
private _nativeOrder=_state getOrDefault ["nativeOrder",[]];
private _goal=(expectedDestination _unit) param [0,[],[[]]];
private _atDestination=count _destination == 3 && {_unit distance _destination < 6};
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
if (!_taskOwned) exitWith {[false,"NATIVE_TASK_OR_ORDER_CHANGED"] call _finish};
if (!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}) exitWith {[] call _finish};
if (_destination isEqualTo [] || {serverTime >= (_state getOrDefault ["until",0])}
    || {_atDestination}) exitWith {[] call _finish};

private _position=getPosATL _unit;
private _lastPosition=_state getOrDefault ["lastPosition",_position];
if (_position distance2D _lastPosition >= 3) then {
    _state set ["lastPosition",_position];
    _state set ["lastProgressAt",serverTime];
};
private _stalled=serverTime-(_state getOrDefault ["lastProgressAt",serverTime]) >= 8;
// Finish at function scope; an exit inside the retry block would still return 2 below.
if (_stalled && {_state getOrDefault ["reissued",false]}) exitWith {[] call _finish};
if (_stalled) then {
    // One engine-native retry is sufficient. A second stall is reported by retirement rather than
    // allowing a civilian to hold the shared queue or repeatedly overwrite movement.
    _unit doMove _destination;
    _state set ["reissued",true];
    _state set ["lastProgressAt",serverTime];
};
2
