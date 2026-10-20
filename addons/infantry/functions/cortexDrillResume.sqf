/*
 * Author: WaldoTheWarfighter
 * Purpose: Reconstructs an unfinished standalone flank, advance or assault on its new owner.
 * Locality/authority: Current group owner only, after CortexLocality releases previous-owner leases.
 * Repeat/JIP: Source generation is consumed once. JIP observes checkpoints without starting work.
 * Committed route, actor destinations and absolute deadline survive; local commands and FSM handles do not.
 * Full original authored waypoint metadata must still match before inspect or resume admission.
 * Only matching passive source HOLD proof can admit native STOP after actual actor locality settles.
 * No source MOVE or acknowledgement grace is replayed; reserved/unavailable/service actors stay excluded.
 * Resumed team partitions seed pair repair without mixing mover/cover identity or renewing time.
 * Hidden or simulation-disabled actors and medics with queued treatment stay in the living roster
 * but cannot be recruited into the resumed movement operation; treatment queues are never changed.
 * Arguments: 0 group <GROUP, grpNull>; 1 checkpoint <ARRAY, []>; 2 retry deadline <NUMBER, -1>; 3 inspect only <BOOL, false>.
 * Return Value: BOOL - resumed or queued for bounded actor-locality settling; false when refused.
 * Current callers: CortexLocality and its finite shared-scheduler locality-settling callback.
 * Example: [_group,_checkpoint getOrDefault ["drillIntent",[]]] call CBE_fnc_CortexDrillResume;
 */
params [["_group",grpNull,[grpNull]],["_checkpoint",[],[[]]],["_waitUntil",-1,[0]],["_inspectOnly",false,[true]]];
if (isNull _group || {!local _group} || {count _checkpoint != 5}
    || {_waitUntil >= 0 && {serverTime >= _waitUntil}}) exitWith {false};
_checkpoint params ["_sourceGeneration","_sourceToken","_pairs","_deadline","_pauseDeadline"];
if (_sourceGeneration != (_group getVariable ["CBE_OperationGeneration",-1])
    || {!_inspectOnly && {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}}
    || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _drill=createHashMapFromArray _pairs;
private _type=_drill getOrDefault ["type",""];
private _target=_drill getOrDefault ["target",objNull];
private _gate=switch (_type) do {
    case "ADVANCE": {"CBE_AIPass_Advance_Enable"};
    case "FLANK": {"CBE_AIPass_Flank_Enable"};
    case "ASSAULT": {"CBE_AIPass_Assault_Enable"};
    default {""};
};
if (_gate == "" || {!([_group,_gate,true] call CBE_fnc_CortexFeatureEnabled)}
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
private _authoredOrder=_drill getOrDefault ["authoredOrder",[]];
if (_authoredOrder isEqualTo [] || {
    _authoredOrder isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)
}) exitWith {false};
if (_inspectOnly) exitWith {true};
// A group Local event may precede its members' Local events. Wait at most five seconds in the
// existing scheduler, retaining the source generation and deadline; never adopt a partial roster.
private _living=_units select {alive _x && {group _x == _group}};
if (_living findIf {!local _x} >= 0) exitWith {
    if (_waitUntil >= 0) exitWith {false};
    private _settleUntil=serverTime+5;
    if !([_group,"TACTICAL_DRILL",true,_settleUntil] call CBE_fnc_CortexOwnershipLease) exitWith {false};
    private _state=[_group] call CBE_fnc_CortexGroupState;
    _state set ["movementLease",["TACTICAL_DRILL",time+5]];
    _state set ["enemyPos",+(_drill get "enemyPos")];
    [_group,_state,"CONTACT","DRILL_LOCALITY_SETTLING",time,true] call CBE_fnc_CortexSetPhase;
    [{
        params ["_job"];
        private _group=_job get "group";
        private _checkpoint=_job get "checkpoint";
        private _until=_job get "until";
        if ([_group,_checkpoint,_until] call CBE_fnc_CortexDrillResume) exitWith {-1};
        if (local _group && {serverTime < _until}
            && {(_checkpoint select 0) == (_group getVariable ["CBE_OperationGeneration",-1])}
            && {!([_group] call CBE_fnc_CortexExternalTakeover)}) exitWith {0.2};
        if (local _group && {(_checkpoint select 0) == (_group getVariable ["CBE_OperationGeneration",-1])}) then {
            [_group,"TACTICAL_DRILL",false] call CBE_fnc_CortexOwnershipLease;
            private _state=[_group] call CBE_fnc_CortexGroupState;
            _state deleteAt "movementLease";
            [_group,_state,false,[_group] call CBE_fnc_CortexExternalTakeover,"DRILL_MIGRATION_REFUSED",true] call CBE_fnc_CortexRestoreCalm;
        };
        -1
    },createHashMapFromArray [["group",_group],["checkpoint",_checkpoint],["until",_settleUntil]],0.2,
        format ["DRILL_ADOPT:%1",netId _group]] call CBE_fnc_CortexQueueJob;
    true
};
// Old passive holds require current actual-owner proof; a checkpoint alone cannot
// recruit a stopped actor. The source token/generation must match this exact intent.
private _resumeCommands=createHashMap;
private _holdRows=_drill getOrDefault ["resumeNativeHolds",[]];
private _holdIssuer=_drill getOrDefault ["resumeHoldIssuer",[]];
private _holdIssuerValid=_holdIssuer isEqualType [] && {count _holdIssuer == 4}
    && {(_holdIssuer select 0) isEqualTo _sourceToken} && {_sourceToken != ""}
    && {(_holdIssuer select 3) isEqualTo _sourceGeneration}
    && {[1,2] findIf {private _n=_holdIssuer select _x;
        !(_n isEqualType 0) || {!finite _n} || {_n != floor _n} || {_n < 0}} < 0}
    && {(_holdIssuer select 1) > 0};
if (_holdIssuerValid && {_holdRows isEqualType []} && {count _holdRows <= 64}) then {
    {
        if (_x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualType objNull}
            && {(_x select 1) isEqualType []} && {count (_x select 1) == 3}
            && {(_x select 2) isEqualType objNull}) then {
            _x params ["_heldActor","_heldNative","_heldLeader"];
            if (_heldActor in _living && {local _heldActor} && {currentCommand _heldActor == "STOP"}
                && {(expectedDestination _heldActor) isEqualTo _heldNative}
                && {formLeader _heldActor == _heldLeader}) then {
                _resumeCommands set [netId _heldActor,[_heldActor,"HOLD",+_heldNative,_heldLeader,-1,[],[]]];
            };
        };
    } forEach _holdRows;
};
private _resumeUnavailable=_drill getOrDefault ["resumeUnavailable",[]];
private _capable=_living select {
    simulationEnabled _x && {!isObjectHidden _x}
        && {(_x getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {[_x] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _x}
        && {!isPlayer _x} && {isNull remoteControlled _x}
        && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
        && {!(_x in _resumeUnavailable)} && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
        && {!([_x] call CBE_fnc_CortexActorMoveReserved)}
        && {!(currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
        && {currentCommand _x != "STOP" || {netId _x in _resumeCommands}}
};
if (count _capable < 2) exitWith {false};
if !([_group,"TACTICAL_DRILL",true,serverTime+90] call CBE_fnc_CortexOwnershipLease) exitWith {false};
private _operationPhase=["MANOEUVRE","ASSAULT"] select (_type == "ASSAULT" || {_drill getOrDefault ["assaulting",false]});
private _pairElements=(_drill getOrDefault ["teams",[]]) apply {_x select {_x in _capable}};
// Two advance actors retain one buddy identity across the singleton movement roles.
if (_type == "ADVANCE" && {count _capable == 2}) then {_pairElements=[]};
private _operation=[_group,_type,_target,_capable,_points apply {_x select 0},_operationPhase,_pairElements] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {[_group,"TACTICAL_DRILL",false] call CBE_fnc_CortexOwnershipLease; false};
_operation set ["unavailable",_drill getOrDefault ["resumeUnavailable",[]]];
_operation set ["recoveryAttempts",createHashMapFromArray (_drill getOrDefault ["resumeAttempts",[]])];
_group setVariable ["CBE_Operation",_operation,true];
private _serial=(missionNamespace getVariable ["CBE_Cortex_DrillSerial",0])+1;
missionNamespace setVariable ["CBE_Cortex_DrillSerial",_serial];
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
{if (!(((_resumeCommands get _x) select 0) in _capable)) then {_resumeCommands deleteAt _x}} forEach (keys _resumeCommands);
_drill set ["nativeAdmissionChecked",true];
_drill set ["nativeCommands",_resumeCommands];
_drill deleteAt "resumeNativeHolds";
_drill deleteAt "resumeHoldIssuer";
_drill set ["disabled",[]];
_drill set ["spots",[]];
_drill set ["started",time];
_drill set ["lastStep",time];
_drill set ["boundStart",time];
_drill set ["pauseUntil",time+(_pauseDeadline-serverTime)];
if (_deadline >= 0) then {_drill set ["boundDeadline",time+(_deadline-serverTime)]};
_drill set ["recovery",(_drill getOrDefault ["resumeRecovery",[]]) apply {[_x select 0,_x select 1,time]}];
_drill set ["stage",""];
private _state=[_group] call CBE_fnc_CortexGroupState;
_state set ["drill",_drill];
_state set ["enemyPos",+(_drill get "enemyPos")];
_state set ["movementLease",["TACTICAL_DRILL",time+90]];
[_group,_state,"CONTACT","DRILL_OWNERSHIP_RESUME",time,true] call CBE_fnc_CortexSetPhase;
[_group,_drill,if (_stage in ["PAUSE","HOLD"]) then {_stage} else {"START"},"OWNERSHIP_RESUME"] call CBE_fnc_CortexDrillSetStage;
[_group] call CBE_fnc_CortexCheckpoint;
_group setVariable ["CBE_Cortex_DrillMigration",[_sourceToken,_token,_sourceGeneration,_operation get "generation",serverTime,_index,_deadline],true];
if !([_group,_token] call CBE_fnc_CortexDrillStart) exitWith {false};
true
