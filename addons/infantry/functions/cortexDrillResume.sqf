/*
 * Author: WaldoTheWarfighter
 * Purpose: Reconstructs an unfinished standalone flank, advance or assault on its new owner.
 * Locality/authority: Current group owner only, after CortexLocality releases previous-owner leases.
 * Repeat/JIP: Source generation is consumed once. JIP observes checkpoints without starting work.
 * Committed route, actor destinations and absolute deadline survive; local commands and FSM handles do not.
 * Arguments: 0 group <GROUP, grpNull>; 1 checkpoint <ARRAY, []>; 2 retry deadline <NUMBER, -1>; 3 inspect only <BOOL, false>.
 * Return Value: BOOL - resumed or queued for bounded actor-locality settling; false when refused.
 * Current callers: CortexLocality and its finite shared-scheduler locality-settling callback.
 * Example: [_group,_checkpoint getOrDefault ["drillIntent",[]]] call WAIT_fnc_CortexDrillResume;
 */
params [["_group",grpNull,[grpNull]],["_checkpoint",[],[[]]],["_waitUntil",-1,[0]],["_inspectOnly",false,[true]]];
if (isNull _group || {!local _group} || {count _checkpoint != 5}
    || {_waitUntil >= 0 && {serverTime >= _waitUntil}}) exitWith {false};
_checkpoint params ["_sourceGeneration","_sourceToken","_pairs","_deadline","_pauseDeadline"];
if (_sourceGeneration != (_group getVariable ["WAIT_OperationGeneration",-1])
    || {!_inspectOnly && {count (_group getVariable ["WAIT_Operation",createHashMap]) > 0}}
    || {!([_group] call WAIT_fnc_CortexIsEligible)}
    || {[_group] call WAIT_fnc_CortexExternalTakeover}) exitWith {false};
private _drill=createHashMapFromArray _pairs;
private _type=_drill getOrDefault ["type",""];
private _target=_drill getOrDefault ["target",objNull];
private _gate=switch (_type) do {
    case "ADVANCE": {"WAIT_AIPass_Advance_Enable"};
    case "FLANK": {"WAIT_AIPass_Flank_Enable"};
    case "ASSAULT": {"WAIT_AIPass_Assault_Enable"};
    default {""};
};
if (_gate == "" || {!([_group,_gate,true] call WAIT_fnc_CortexFeatureEnabled)}
    || {isNull _target} || {!alive _target} || {_target isKindOf "Logic"}
    || {captive _target} || {(side _group) getFriend (side _target) >= 0.6}
    || {_target getVariable ["ace_captives_isSurrendering",false]}
    || {_target getVariable ["ace_captives_isHandcuffed",false]}) exitWith {false};
private _points=_drill getOrDefault ["points",[]];
private _index=_drill getOrDefault ["index",-1];
private _units=_drill getOrDefault ["units",[]];
private _savedStage=_drill getOrDefault ["stage",""];
if (count _points == 0 || {count _points > 64} || {_index < 0} || {_index >= count _points}
    || {count _units > 64} || {_savedStage in ["START","MOVE"] && {_deadline >= 0 && {serverTime >= _deadline}}}) exitWith {false};
private _waypoint=_drill getOrDefault ["boundWaypoint",[]];
if (count _waypoint == 2 && {currentWaypoint _group != (_waypoint select 0)
    || {waypointPosition [_group,_waypoint select 0] isNotEqualTo (_waypoint select 1)}}) exitWith {false};
if (_waypoint isEqualTo [] && {currentWaypoint _group < count waypoints _group}) exitWith {false};
if (_inspectOnly) exitWith {true};
// A group Local event may precede its members' Local events. Wait at most five seconds in the
// existing scheduler, retaining the source generation and deadline; never adopt a partial roster.
private _living=_units select {alive _x && {group _x == _group}};
if (_living findIf {!local _x} >= 0) exitWith {
    if (_waitUntil >= 0) exitWith {false};
    private _settleUntil=serverTime+5;
    if !([_group,"TACTICAL_DRILL",true,_settleUntil] call WAIT_fnc_CortexOwnershipLease) exitWith {false};
    private _state=[_group] call WAIT_fnc_CortexGroupState;
    _state set ["movementLease",["TACTICAL_DRILL",time+5]];
    _state set ["enemyPos",+(_drill get "enemyPos")];
    [_group,_state,"CONTACT","DRILL_LOCALITY_SETTLING",time,true] call WAIT_fnc_CortexSetPhase;
    [{
        params ["_job"];
        private _group=_job get "group";
        private _checkpoint=_job get "checkpoint";
        private _until=_job get "until";
        if ([_group,_checkpoint,_until] call WAIT_fnc_CortexDrillResume) exitWith {-1};
        if (local _group && {serverTime < _until}
            && {(_checkpoint select 0) == (_group getVariable ["WAIT_OperationGeneration",-1])}
            && {!([_group] call WAIT_fnc_CortexExternalTakeover)}) exitWith {0.2};
        if (local _group && {(_checkpoint select 0) == (_group getVariable ["WAIT_OperationGeneration",-1])}) then {
            [_group,"TACTICAL_DRILL",false] call WAIT_fnc_CortexOwnershipLease;
            private _state=[_group] call WAIT_fnc_CortexGroupState;
            _state deleteAt "movementLease";
            [_group,_state,false,[_group] call WAIT_fnc_CortexExternalTakeover,"DRILL_MIGRATION_REFUSED",true] call WAIT_fnc_CortexRestoreCalm;
        };
        -1
    },createHashMapFromArray [["group",_group],["checkpoint",_checkpoint],["until",_settleUntil]],0.2,
        format ["DRILL_ADOPT:%1",netId _group]] call WAIT_fnc_CortexQueueJob;
    true
};
private _capable=_living select {
    [_x] call WAIT_fnc_CortexCombatEffective && {isNull objectParent _x}
        && {!isPlayer _x} && {isNull remoteControlled _x}
        && {([_x] call WAIT_fnc_CortexExternalOwner) == ""}
        && {!([_x] call WAIT_fnc_CompatibilityExternalControl)}
};
if (count _capable < 2) exitWith {false};
if !([_group,"TACTICAL_DRILL",true,serverTime+90] call WAIT_fnc_CortexOwnershipLease) exitWith {false};
private _operationPhase=["MANOEUVRE","ASSAULT"] select (_type == "ASSAULT" || {_drill getOrDefault ["assaulting",false]});
private _operation=[_group,_type,_target,_capable,_points apply {_x select 0},_operationPhase] call WAIT_fnc_OperationStart;
if (count _operation == 0) exitWith {[_group,"TACTICAL_DRILL",false] call WAIT_fnc_CortexOwnershipLease; false};
_operation set ["unavailable",_drill getOrDefault ["resumeUnavailable",[]]];
_operation set ["recoveryAttempts",createHashMapFromArray (_drill getOrDefault ["resumeAttempts",[]])];
_group setVariable ["WAIT_Operation",_operation,true];
private _serial=(missionNamespace getVariable ["WAIT_Cortex_DrillSerial",0])+1;
missionNamespace setVariable ["WAIT_Cortex_DrillSerial",_serial];
private _token=format ["%1:%2",clientOwner,_serial];
private _stage=_drill getOrDefault ["stage","START"];
// Destinations and retry counts belong to the current moving bound only. A completed bound's
// spots must not pull a PAUSE/HOLD continuation back after its point or team turn advances.
if (_stage != "MOVE") then {
    _drill deleteAt "resumeSpots";
    _drill deleteAt "resumeRetries";
};
_drill set ["token",_token];
_drill set ["operationGeneration",_operation get "generation"];
_drill set ["ownerEpoch",_operation get "ownerEpoch"];
_drill set ["units",_capable];
_drill set ["disabled",[]];
_drill set ["spots",[]];
_drill set ["started",time];
_drill set ["lastStep",time];
_drill set ["boundStart",time];
_drill set ["pauseUntil",time+(_pauseDeadline-serverTime)];
if (_deadline >= 0) then {_drill set ["boundDeadline",time+(_deadline-serverTime)]};
_drill set ["recovery",(_drill getOrDefault ["resumeRecovery",[]]) apply {[_x select 0,_x select 1,time]}];
_drill set ["stage",""];
private _state=[_group] call WAIT_fnc_CortexGroupState;
_state set ["drill",_drill];
_state set ["enemyPos",+(_drill get "enemyPos")];
_state set ["movementLease",["TACTICAL_DRILL",time+90]];
[_group,_state,"CONTACT","DRILL_OWNERSHIP_RESUME",time,true] call WAIT_fnc_CortexSetPhase;
[_group,_drill,if (_stage in ["PAUSE","HOLD"]) then {_stage} else {"START"},"OWNERSHIP_RESUME"] call WAIT_fnc_CortexDrillSetStage;
[_group] call WAIT_fnc_CortexCheckpoint;
_group setVariable ["WAIT_Cortex_DrillMigration",[_sourceToken,_token,_sourceGeneration,_operation get "generation",serverTime,_index,_deadline],true];
[_group,_token] call WAIT_fnc_CortexDrillStart;
true
