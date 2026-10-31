/*
 * Author: WaldoTheWarfighter
 * Target identity respects native ignoreTarget policy; no ignore setting is changed.
 * Non-finite geometry/timestamps are rejected before selection or observation side effects.
 * Purpose: Coalesce observed danger into one finite group assessment FSM.
 * Locality / Authority: owner-local; never reveals targets or sends movement commands.
 * Repeat/JIP: generation-checked, machine-local state; new owners rebuild from new observations.
 * Invalid FSM startup is terminal for this owner epoch until observer cleanup/reset. No event-driven
 * retry loop is created; completed valid handles may drain normally without being marked failed.
 * Approximate updates retain, but never renew, the original two-second hostile identity expiry.
 * Arguments: 0: observer <OBJECT>, objNull; 1: cause <STRING>, GUNFIRE;
 * 2: approximate ATL position <ARRAY>, []; 3: engine-confirmed hostile source <OBJECT>, objNull.
 * 4: original local geometry expiry <NUMBER, -1>; 5: original identity expiry <NUMBER, -1>.
 * -1 means a fresh callback without an engine deadline; supplied expiries can only shorten
 * the two-second intake bound. Expired geometry refuses before cadence; expired identity
 * cannot acquire a new source lease. Existing independently valid witness proof may survive.
 * Return Value: Boolean - whether the observation was accepted.
 * Current callers: CBE engine danger intake, group EnemyDetected observer and CortexUAVApproach
 * (derived visible approach cue; it never masquerades as a native physical event).
 * Example: [leader _group,"HIT",getPosATL leader _group] call CBE_fnc_DangerRequest;
 */

params [["_actor",objNull,[objNull]],["_cause","GUNFIRE",[""]],["_position",[],[[]]],["_source",objNull,[objNull]],
    ["_geometryExpiry",-1],["_identityExpiry",-1]];
if (isNull _actor || {!local _actor} || {!([_actor] call CBE_fnc_CortexCombatEffective)} || {isPlayer _actor}
    || {!(_cause in ["HIT","EXPLOSION","SUPPRESSED","DETECTED","PROXIMITY","CANFIRE","GUNFIRE","CASUALTY","BODY_FOUND","SCREAM","UAV_APPROACH"])} || {count _position != 3} || {_position findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {false};
// Native queue delivery cannot give an old observation a fresh two-second life.
// -1 is reserved for a genuinely fresh callback with no supplied engine deadline.
if ([_geometryExpiry,_identityExpiry] findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0 && {_x != -1}}} >= 0) exitWith {false};
private _eventUntil=if (_geometryExpiry == -1) then {time+2} else {(time+2) min _geometryExpiry};
if (_eventUntil <= time) exitWith {false};
// Reject throttled duplicates before the more expensive group ownership scan. Rejected
// eligibility does not consume cadence; only an accepted observation advances it below.
private _cadence=_actor getVariable ["CBE_Danger_EventCadence",createHashMap];
if (time < (_cadence getOrDefault [_cause,-1])) exitWith {false};
private _group=group _actor;
if (!(missionNamespace getVariable ["CBE_AIPass_Active",false])
    || {!local _group}
    || {!([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!(_group getVariable ["CBE_AIPass_Managed",false])}
    || {[_group] call CBE_fnc_CortexExternalTakeover}
    || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _startupFailure=_group getVariable ["CBE_Danger_FSMFailure",[]];
if (_startupFailure isEqualType [] && {count _startupFailure == 3}
    && {(_startupFailure select 0) isEqualTo _epoch}) exitWith {false};
// Detection alone cannot override a mission's ignoreTarget instruction. Real hazards
// remain approximate alerts, with the ignored hostile identity omitted below.
private _sourceIgnored=!isNull _source && {(_actor targetKnowledge _source) param [7,false,[true]]};
if (_cause == "UAV_APPROACH" && {isNull _source || {!(_source isKindOf "Air")} || {!unitIsUAV _source}
    || {_sourceIgnored} || {!((_actor targetKnowledge _source) param [1,false,[true]])}}) exitWith {false};
if (_sourceIgnored && {_cause in ["DETECTED","PROXIMITY","CANFIRE"]}) exitWith {false};
// Eligibility was checked at observer installation and is rechecked before dispatch. Keep bullet
// callbacks cheap: cadence rejects duplicates before the ownership scan; accepted events are coalesced by cause and witness.
// One witness must not throttle or replace another witness in a different occupied domain.
_cadence set [_cause,time+0.25];
_actor setVariable ["CBE_Danger_EventCadence",_cadence];
private _events=_group getVariable ["CBE_Danger_Events",[]];
private _index=_events findIf {
    _x isEqualType [] && {count _x in [4,5,6,7,8]}
        && {(_x param [0,"",[""]]) == _cause}
        && {(_x param [5,objNull,[objNull]]) == _actor}
};
// Preserve identity only when the engine supplied a live hostile already known by this observer.
// The group layer revalidates the object against its native knowledge before using it. This is not
// reveal or target assignment; objNull remains the normal value for approximate hazards and reports.
private _hostileSource=objNull;
private _sourceObserver=_actor;
private _sourceUntil=if (_identityExpiry == -1) then {_eventUntil} else {_eventUntil min _identityExpiry};
if (_sourceUntil > time && {!isNull _source} && {!(_source isKindOf "Logic")} && {!(_source isKindOf "HeadlessClient_F")} && {alive _source} && {!captive _source}
    && {!(_source getVariable ["ace_captives_isSurrendering",false]) && {!(_source getVariable ["ace_captives_isHandcuffed",false])}} && {(side _group) getFriend (side _source) < 0.6}
    && {_actor knowsAbout _source > 0} && {!_sourceIgnored}) then {_hostileSource=_source};
if (isNull _hostileSource && {_index >= 0}) then {
    private _prior=_events select _index;
    private _priorSource=_prior param [4,objNull,[objNull]];
    private _priorObserver=_prior param [6,_prior param [5,objNull,[objNull]],[objNull]];
    private _priorUntil=_prior param [7,_prior param [3,-1,[0]],[0]];
    if (finite _priorUntil && {_priorUntil > time} && {(_prior param [3,-1,[0]]) > time} && {!isNull _priorSource} && {!(_priorSource isKindOf "Logic")} && {!(_priorSource isKindOf "HeadlessClient_F")} && {alive _priorSource} && {!captive _priorSource}
        && {!(_priorSource getVariable ["ace_captives_isSurrendering",false]) && {!(_priorSource getVariable ["ace_captives_isHandcuffed",false])}}
        && {[_priorObserver] call CBE_fnc_CortexCombatEffective} && {local _priorObserver} && {group _priorObserver == _group}
        && {(side _group) getFriend (side _priorSource) < 0.6}
        && {_priorObserver knowsAbout _priorSource > 0}
        && {!((_priorObserver targetKnowledge _priorSource) param [7,false,[true]])}) then {
        _hostileSource=_priorSource;
        _sourceObserver=_priorObserver;
        _sourceUntil=_priorUntil;
    };
};
// Retain the exact local observer which received the native danger event. A mixed crew/passenger
// or mounted/foot group cannot be classified from an arbitrary group anchor later: doing so turns
// vehicle danger into a foot response (or the reverse) whenever the selected anchor occupies a
// different domain. A separate source observer preserves the native witness when a newer
// approximate event inherits a still-live hostile identity from the previous coalesced record.
private _event=[_cause,+_position,time,_eventUntil,_hostileSource,_actor,_sourceObserver,_sourceUntil];
if (_index >= 0) then {_events set [_index,_event]} else {_events pushBack _event};
// Keep the queue bounded while preserving both fresh witnesses and its strongest hazard.
// Only overflow needs priority work: the normal coalesced path retains its cheap write.
if (count _events > 16) then {
    private _previousBest=[_events] call CBE_fnc_DangerSelect;
    private _strongest=[[_previousBest,_event]] call CBE_fnc_DangerSelect;
    _events=_events select [((count _events)-16) max 0,16];
    if (_strongest isNotEqualTo [] && {!(_strongest in _events)}) then {
        _events deleteAt 0;
        _events pushBack _strongest;
    };
};
_group setVariable ["CBE_Danger_Events",_events];
private _running=_group getVariable ["CBE_Danger_FSM",[]];
if (_running isEqualType [] && {count _running == 3} && {(_running select 0) isEqualTo _epoch}
    && {(_running select 1) isEqualTo (_group getVariable ["CBE_Danger_Generation",0])}
    && {(_running select 2) isEqualType 0} && {finite (_running select 2)}
    && {(_running select 2) >= 0} && {(_running select 2) == floor (_running select 2)}
    && {!completedFSM (_running select 2)}) exitWith {true};
private _generation=(_group getVariable ["CBE_Danger_Generation",0])+1;
_group setVariable ["CBE_Danger_Generation",_generation];
private _fsm=[_group,_epoch,_generation] execFSM "\z\cbe\addons\main\fsm\dangerAssessment.fsm";
if (!(_fsm isEqualType 0) || {!finite _fsm} || {_fsm < 0} || {_fsm != floor _fsm}) exitWith {
    _group setVariable ["CBE_Danger_FSM",nil];
    _group setVariable ["CBE_Danger_FSMFailure",[_epoch,_generation,serverTime]];
    diag_log format ["[CBE] Danger assessment startup failed for %1, epoch %2, generation %3; no automatic retry.",
        _group,_epoch,_generation];
    false
};
// A valid FSM may already have drained a forced/expired observation. Do not resurrect
// its handle or misclassify successful finite completion as a startup failure.
if (!completedFSM _fsm) then {_group setVariable ["CBE_Danger_FSM",[_epoch,_generation,_fsm]];};
true
