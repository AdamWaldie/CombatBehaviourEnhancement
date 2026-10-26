/*
 * Author: WaldoTheWarfighter
 * Resume startup refuses known actor settings/motion adoption failures; this is not
 * complete cross-owner readiness or proof that missing inherited records never existed.
 * Fresh startup also consumes settings PREPARE results; pending predecessor restoration
 * refuses worker startup and uses the existing scoped release/cleanup service.
 * Exterior resume accepts a settled idle/WAIT end of its original approach only through
 * the existing exact-context native motion check; it never restarts movement or a clock.
 * True resume gives its episode-bound lane pairs precedence over lagging general buddy
 * metadata. Pair identity never bypasses current participant or actor admission.
 * Version4 exit journals retain server-time progress/motion clocks and the ASL motion
 * anchor. Adoption observes the existing leg; it never issues it or renews stall grace.
 * Locality resume reconstructs exit distance and same-floor settlement in ASL; saved
 * native destinations stay AGL. No physical arrival or renewed retry is inferred from transfer.
 * Native fleeing retains movement authority through admission, execution and cleanup.
 * Group attack permission is acquired through OperationAttackPolicy; a refused or changed
 * policy ends admission rather than allowing unowned autonomous attack delegation.
 * Egress adoption preserves original allocation attempt counts and retry times; it never grants a fresh budget.
 * Repeat/JIP: A fresh task replaces the prior episode only after admission checks. A matching
 * owner resume retains original deadlines, shared room coverage and validated individual visit
 * receipts. Fresh-task tokens reject historical participation from earlier clearances. JIP
 * receives public progress; movement remains with the current group owner.
 * Durable order field13 binds shared room indices to the admission transform. Changed or
 * unproven resume transforms refuse before handoff; explicit fresh orders reset coverage.
 * Geometry is captured before queries and rechecked before replacement and publication.
 * The worker retains that original snapshot, never a recaptured post-planning pose.
 * Resume is adoption only: missing, replaced or different-target orders never become fresh tasks.
 * Discovery supplies its exact durable order/generation; admission rechecks them before handoff.
 * Prepared worker startup retains the admitted operation epoch. Refusal reports false and
 * retires only this still-owned clear; a new owner or successor retains its durable state.
 * Post-admission preparation commits are short unscheduled blocks, rechecking original
 * operation/epoch/generation, target, native intent and deadlines. Route planning stays scheduled.
 * Task handoff validates entry owner/native/feature identities before one unscheduled
 * release/publication commit. It does not serialize geometry or room-route planning.
 * Orders an AI group to clear a building room by room.
 *
 * Admission excludes queued ACE treatment actors before allocating entry lanes or reserve slots;
 * running-task ownership and cleanup remain independently checked by the executor.
 * Admission validates finite, distinct model positions with a 512-position budget before
 * geometry queries and replacement cleanup. Reported points still do not prove native access.
 * A squad-aware interior element, including the leader when needed, joins the clear up to a bounded
 * capacity. Each interior lane has a lead and security partner, receives a distinct viable entrance
 * where the topology provides one, then draws the nearest unclaimed room from a
 * shared low-floor-first queue. Only roofed interior positions are clearance objectives; exposed
 * balconies and roof posts belong to garrisoning. This avoids a support partner waiting outside while only one soldier
 * attempts every room, and makes a large squad flow through the building instead of parking around it.
 * Final egress journals pending native-leg receipts and assigned exits across owner
 * migration; planning and travel share the original finite exit deadline.
 * Owner adoption retains validated known-casualty post history for the same episode/transform;
 * this metadata grants no live observation, movement, settings or renewed search budget.
 * Exterior reserves consider up to sixteen already-discovered native exits independently of
 * the four nearest interior entry choices; this does not establish complete building isolation.
 * Resumed exterior obstruction history requires exact original post/watch coordinates and finite
 * original timestamps. It restores no visibility proof and only follows a successful role commit.
 * Delayed reserve admission retains original native command/formation-leader receipts across
 * the same episode; a new individual task is not claimed before first staging.
 * Spare members above the entry capacity remain an actual reserve and replace unavailable interior
 * workers without pausing the other lanes. In a two-person entry lane, exterior security remains at the entry until the lead has physically crossed it, then follows into the first reached room and trails subsequent rooms. A worker tries its room directly
 * first, then uses a bounded set of alternate real entrances only after the direct route stalls. A
 * blocked room returns to the shared queue for another worker before it can be marked unreachable.
 * Committed units move upright at a bounded assault speed. CBE
 * records a room only after a physical 1.5 m visit and never teleports a stuck soldier or clears a
 * room from outside. A position is visited only when a soldier physically reaches it within
 * 1.5 m. Each callback checks claimed rooms immediately and rotates a bounded remainder of the
 * topology, preventing a large building from multiplying clearance cost per worker. A casualty or incapacitation is replaced from the uncommitted reserve; without a replacement,
 * other active workers continue claiming the remaining rooms. A worker quarantined by common recovery is rotated out of its clearance lane and replaced from reserve where possible. Timeouts never clear rooms.
 * After all rooms are visited or attempted, the clearing element exits through the building entry
 * to an exterior release point before formation control is restored. This explicit egress avoids
 * abandoning soldiers on interior path nodes and provides the same entry-through-exit primitive used
 * by later movement actions. The order has a progress-renewed safety lease rather than a fixed
 * performance deadline. It preserves the group's current behaviour and combat mode: aware squads
 * remain responsive to the route, while squads already fighting keep engaging. Cleanup therefore
 * cannot overwrite a later contact or Zeus behaviour change. While clearing, the squad does not
 * flank, retreat or search, and
 * is not sent to reinforce others.
 * CBE owns building clearance. External danger or building controllers are not co-owners of this
 * operation; specialist ownership and Zeus still invalidate it through the common eligibility gate.
 * Locality and authority: call where the group is local, or on the server, which forwards to the
 * owner. Non-server, non-owner copies do nothing.
 *
 * Review contract: Local job generations prevent replaced jobs from issuing orders. Eligibility is checked before dispatch and on each step. Public visited and unreachable position indices, retry/failure evidence, progress-renewed stall deadline, immutable episode deadline and original behaviour survive handover; matching coherent lane snapshots are adopted without a fresh progress age; missing entry/sweep snapshots refuse startup. The admitted lane journal is rechecked before
 * operation startup; a changed journal defers rather than consuming the durable order.
 *
 * Arguments:
 * 0: group <GROUP or OBJECT> - the group, or a unit in it
 * 1: target <OBJECT or ARRAY> - the building, or a position (the nearest building is used)
 * 2: options <HASHMAP> (optional) - resume (default false), preserveBrain (default false for an
 *    explicit order) and operation-specific controls. Internal resumeOrder (ARRAY) and
 *    resumeGeneration (NUMBER) default to the entry snapshot; discovery passes its observed
 *    order/generation. A cancelled or replaced snapshot refuses without retiring a successor.
 *    Natural contact entry uses preserveBrain so
 *    live fire control and contact transitions continue around the single building movement owner.
 *    continueRoute (BOOL, default false) returns a safely exited clear to its unchanged plain MOVE;
 *    incomplete room coverage remains INCOMPLETE and failed egress never qualifies;
 *    natural contact callers opt in. Failed/gated/no-route work retains post-clear settlement.
 *    The choice is durable on owner resume and grants no hostile-room safety claim.
 *    minimumActors (NUMBER, default 1) requires 1..16 integer task-free actors before handoff.
 *    Natural contact requests 4; explicit/resume calls retain the historical default.
 *    contactBelief (default []) is [believed position AGL ARRAY, observed serverTime NUMBER].
 *    A finite hint inside the building and at most five seconds old seeds one floor route.
 *    Its timestamp survives adoption; it never supplies live target tracking or visit credit.
 *
 * Return Value:
 * Boolean - true when the order was applied or forwarded
 *
 * Example:
 * [group this, nearestBuilding this] call CBE_fnc_CortexClearBuilding;
 * Result: an entry element attempts successive building positions; unreachable positions leave an INCOMPLETE result.
 *
 * Current callers: mission scripts, CortexOrderLocal and building-contact/locality continuation.
 * CBE-owned garrison post holds may enter a new clear after physical validation; the handoff
 * restores those holds without injecting a JOIN recall ahead of the new building executor.
 * Expired episodes and changed resume-order receipts are rejected before garrison/defence
 * or autonomous-task handoff; late common-operation refusal remains separately handled.
 */

params [["_group", grpNull, [grpNull, objNull]], ["_target", objNull, [objNull, []]], ["_options", createHashMap, [createHashMap]]];
if (_group isEqualType objNull) then {_group = group _group};
if (isNull _group) exitWith {false};
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (!local _group) exitWith {
    if (isServer) then {[_group, _target, _options] remoteExecCall ["CBE_fnc_CortexClearBuilding", groupOwner _group]; true} else {false};
};
private _refuse={
    params ["_reason"];
    private _actors=(units _group) select [0,16];
    private _evidence=[serverTime,_reason,groupOwner _group,_actors apply {
        [netId _x,currentCommand _x,getUnitState _x,local _x,isPlayer _x,
            _x checkAIFeature "MOVE",_x checkAIFeature "PATH",
            _x getVariable ["CBE_Cortex_ActorMove",[]],
            [_x] call CBE_fnc_CortexCombatEffective]
    }];
    _group setVariable ["CBE_Cortex_ClearAdmissionFailure",_evidence,true];
    diag_log format ["CBE CLEAR ADMISSION REFUSED: %1",_evidence];
    false
};
if !([_group] call CBE_fnc_CortexIsEligible) exitWith {["GROUP_INELIGIBLE"] call _refuse};
if (_target isEqualType [] && {!(count _target in [2,3])
    || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) exitWith {["INVALID_TARGET_POSITION"] call _refuse};
private _admissionEpoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _admissionNativeReceipt=[_group] call CBE_fnc_NativeOrderReceipt;
private _entryOperation=_group getVariable ["CBE_Operation",createHashMap];
private _admissionOperationIdentity=[_entryOperation getOrDefault ["generation",-1],
    _entryOperation getOrDefault ["ownerEpoch",-1],_entryOperation getOrDefault ["intent",""]];
private _admissionGarrison=+(_group getVariable ["CBE_AIPass_Garrison",[]]);
private _admissionDefend=+(_group getVariable ["CBE_AIPass_Defend",[]]);
private _admissionGeneration=_group getVariable ["CBE_AIPass_ClearGeneration",0];
private _previous = _group getVariable ["CBE_AIPass_ClearOrder", []];
private _resumeRequested=_options getOrDefault ["resume",false];
if !(_resumeRequested isEqualType true) exitWith {["INVALID_RESUME"] call _refuse};
private _expectedOrder=_options getOrDefault ["resumeOrder",_previous];
private _expectedGeneration=_options getOrDefault ["resumeGeneration",_admissionGeneration];
private _resumeCurrent={
    local _group && {_previous isNotEqualTo []}
        && {_expectedOrder isEqualTo _previous} && {_expectedGeneration isEqualTo _admissionGeneration}
        && {(_group getVariable ["CBE_AIPass_ClearGeneration",-1]) == _admissionGeneration}
        && {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isEqualTo _previous}
};
private _retireResume={
    params [["_restore",true,[true]]];
    isNil {
        if (_resumeRequested && {call _resumeCurrent}
            && {_admissionEpoch == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
            [_group,_restore] call CBE_fnc_CortexClearRelease;
        };
    };
};
if (_resumeRequested && {!(call _resumeCurrent)}) exitWith {["RESUME_ORDER_CHANGED"] call _refuse};
private _building = if (_target isEqualType objNull) then {_target} else {nearestBuilding _target};
if (_resumeRequested && {(_previous param [0,objNull,[objNull]]) != _building}) exitWith {
    ["RESUME_TARGET_CHANGED"] call _refuse
};
if (isNull _building) exitWith {
    [] call _retireResume;
    ["TARGET_ABSENT"] call _refuse
};
if (!alive _building) exitWith {
    [] call _retireResume;
    ["TARGET_DESTROYED"] call _refuse
};
if !(missionNamespace getVariable ["CBE_AIPass_Active", false]) exitWith {
    diag_log format ["[CBE] %1 clear building refused: the Smart AI Pass is not running on this machine.", _group];
    false
};
// Bind geometry and durable visit indices to this actual object pose, not a later resume pose.
private _admissionTransform=[getPosWorld _building,vectorDir _building,vectorUp _building];
if (_resumeRequested && {(_previous param [13,[],[[]]]) isNotEqualTo _admissionTransform}) exitWith {
    // Unknown/changed pose cannot carry old room visits into a new world location.
    // Retire only the order this call actually observed, never a successor clear.
    [] call _retireResume;
    ["RESUME_TRANSFORM_MISMATCH"] call _refuse
};
// A durable resume is the same visit, never permission to mint a new nonce while
// its separately delivered context is absent. Defer through existing discovery without
// starting an operation, replaying movement or replenishing per-visit recovery history.
private _resumeRosterContext=_group getVariable ["CBE_Cortex_ClearVisitContext",[]];
if (_resumeRequested && {serverTime >= ((_previous param [2,-1,[0]]) min (_previous param [10,-1,[0]]))}) exitWith {
    [] call _retireResume;false
};
if (_resumeRequested && {!(_resumeRosterContext isEqualType [])
        || {count _resumeRosterContext != 4}
        || {(_resumeRosterContext select [0,3]) isNotEqualTo [_building,_admissionTransform,_previous param [10,-1,[0]]]}
        || {!((_resumeRosterContext select 3) isEqualType "")} || {(_resumeRosterContext select 3) == ""}
}) exitWith {["RESUME_CONTEXT_PENDING"] call _refuse};
if (_resumeRosterContext isEqualType []) then {_resumeRosterContext=+_resumeRosterContext};
private _admissionStable={
    !isNull _building && {alive _building}
        && {_admissionTransform isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
};
private _allPositions = _building buildingPos -1;
if (count _allPositions > 512) exitWith {["POSITION_BUDGET_EXCEEDED"] call _refuse};
private _seenPositions=createHashMap;
private _roofTop=[_building] call CBE_fnc_BuildingRoofTop;
private _positions = _allPositions select {
    private _position=_x;
    private _valid=_position isEqualType [] && {count _position == 3}
        && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {[AGLToASL _position,_seenPositions,0.5] call CBE_fnc_PositionBucketAdmit};
    if (!_valid) exitWith {false};
    private _positionASL=AGLToASL _position;
    if (_roofTop <= (_positionASL select 2)+0.5) exitWith {false};
    private _roofHits=lineIntersectsSurfaces [
        _positionASL vectorAdd [0,0,0.5],[_positionASL select 0,_positionASL select 1,_roofTop],objNull,objNull,true,4,"GEOM","NONE"
    ];
    _roofHits findIf {(_x select 2) == _building || {(_x select 3) == _building}} >= 0
};
// Exposed posts remain garrison/transit candidates. A missing owned roof is not
// permission to advertise every model position as a verified interior room.
if (_positions isEqualTo []) exitWith {
    ["NO_VALID_ROOFED_POSITIONS"] call _refuse
};
private _leader = [_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _leader) then {_leader=leader _group};
// Entry selection must use the same capable/task-free contract as casualty reserves.
// An unavailable actor must not consume a lane until the later callback discovers it.
// Only a short-lived recall issued by CBE's own completed/released clear is replaceable.
// Native JOIN from another task remains protected; locality and leader changes revoke this receipt.
private _ownedRecall={
    params ["_actor","_clearGeneration"];
    private _recall=_actor getVariable ["CBE_Cortex_ClearRecall",[]];
    currentCommand _actor == "JOIN" && {count _recall == 4}
        && {(_recall select 0) == _clearGeneration}
        && {(_recall select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_recall select 2) == _leader} && {time < (_recall select 3)}
};
private _resume = _resumeRequested;
// An explicit new CLEAR may replace this addon's exact indoor actor jobs. Admission remains
// read-only: only the existing validated group handoff below retires those journals.
private _replaceIndoor=!_resume && {(_options getOrDefault ["preserveBrain",false]) isEqualTo false};
private _actorAdmissible={
    params ["_actor"];
    private _posted=_actor getVariable ["CBE_AIPass_GarrisonPos",[]];
    private _ownedPost=(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []
        && {_group getVariable ["CBE_AIPass_GarrisonApplied",false]}
        && {_actor getVariable ["CBE_AIPass_GarrisonDisabledPath",false]}
        && {!(_actor checkAIFeature "PATH")} && {_posted isNotEqualTo []}
        && {currentCommand _actor in ["","STOP","ATTACK","FIRE","SUPPRESS"]}
        && {[_actor,_posted] call CBE_fnc_CortexGarrisonArrived};
    private _canMove=_actor checkAIFeature "MOVE" && {_actor checkAIFeature "PATH" || {_ownedPost}};
    private _reservation=_actor getVariable ["CBE_Cortex_ActorMove",[]];
    private _reservationFree=!([_actor] call CBE_fnc_CortexActorMoveReserved);
    if (!_reservationFree && {_replaceIndoor}) then {
        private _indoor=_actor getVariable ["CBE_IndoorActor_Brain",createHashMap];
        private _journal=_actor getVariable ["CBE_IndoorActor_Order",[]];
        _reservationFree=count _indoor > 0 && {count _journal == 10}
            && {(_journal select 9) isEqualType objNull}
            && {!(_indoor getOrDefault ["finished",true])}
            && {(_indoor getOrDefault ["group",grpNull]) == _group}
            && {(_indoor getOrDefault ["generation",-1]) == (_journal select 0)}
            && {(_indoor getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_journal select 1) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_journal select 2) == _group}
            && {(_journal select 7) isEqualTo _reservation}
            && {(_indoor getOrDefault ["lease",[]]) isEqualTo _reservation};
    };
    _canMove && {[_actor] call CBE_fnc_CortexCombatEffective} && {local _actor} && {group _actor == _group} && {!isPlayer _actor} && {!fleeing _actor}
        && {isNull objectParent _actor} && {_reservationFree}
        && {_resume || {simulationEnabled _actor && {!isObjectHidden _actor}}}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {isNull (remoteControlled _actor)}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])
            || {[_actor,_admissionGeneration] call _ownedRecall}}
};
private _available = (units _group) select {[_x] call _actorAdmissible};
// Natural contact requires reserve strength beyond the pair. Validate its requested minimum
// against the real task-free roster, not preliminary live headcount, before any handoff.
// Explicit calls retain their historical default; resumes can continue with surviving actors.
private _minimumActors=_options getOrDefault ["minimumActors",1];
if (!(_minimumActors isEqualType 0) || {!finite _minimumActors}
    || {_minimumActors < 1} || {_minimumActors > 16} || {_minimumActors != floor _minimumActors}) exitWith {
    ["INVALID_ACTOR_MINIMUM"] call _refuse
};
if (count _available < _minimumActors) exitWith {["INSUFFICIENT_ELIGIBLE_ACTORS"] call _refuse};
// Existing intact eligible pairs retain admission priority; remaining actors fill capacity.
private _team = +_available;
if (_team isEqualTo []) exitWith {["NO_ELIGIBLE_ACTORS"] call _refuse};
// Keep enough distinct lanes for a real squad clear without crowding every reported room node.
// The roof filter can undercount valid interior lanes on some models, so capacity uses the full
// engine position set as well as squad strength. Admit the full capable squad within the
// eight-actor concurrent limit; do not silently reserve half of a clearing squad outside.
private _squadElement = count _available;
private _topologyElement = ((count _allPositions) max 2) min 8;
private _entryCapacity = ((2 max _squadElement) min _topologyElement) min 8;
_entryCapacity = _entryCapacity min (count _team);
// Prefer intact eligible buddies before applying concurrency capacity. Selection is
// read-only here; a refused start must not publish a new pairing receipt.
// During true resume, the common CLEAR roster is published with casualty replacements
// before the separate CombatPairs variable. Prefer its eligible members so a late pair
// update cannot silently replace a promoted actor with an idle exterior reserve.
private _resumeParticipants=+(_entryOperation getOrDefault ["participants",[]]);
private _resumePairs=(_entryOperation getOrDefault ["pairs",[]]) apply {+_x};
private _resumeUnavailable=+(_entryOperation getOrDefault ["unavailable",[]]);
private _useResumeRoster=_resume && {(_entryOperation getOrDefault ["intent",""]) == "CLEAR"}
    && {(_entryOperation getOrDefault ["objective",objNull]) isEqualTo _building}
    && {count _resumeRosterContext == 4}
    && {(_resumeRosterContext select [0,3]) isEqualTo [_building,_admissionTransform,_previous param [10,-1]]};
// Locality cleanup cancels the common operation before discovery resumes. Its
// episode-bound roster journal survives that cancellation; it grants selection priority only.
private _resumeRosterJournal=+(_group getVariable ["CBE_Cortex_ClearRoster",[]]);
private _useRosterJournal=_resume && {count _resumeRosterJournal == 4}
    && {(_resumeRosterJournal select 0) isEqualTo _resumeRosterContext}
    && {count _resumeRosterContext == 4}
    && {(_resumeRosterContext select [0,3]) isEqualTo [_building,_admissionTransform,_previous param [10,-1]]}
    && {(_resumeRosterJournal select 1) isEqualType []}
    && {(_resumeRosterJournal select 2) isEqualType []}
    && {(_resumeRosterJournal select 3) isEqualType []};
if (_useRosterJournal) then {
    _resumeParticipants=+(_resumeRosterJournal select 1);
    _resumePairs=(_resumeRosterJournal select 2) select {_x isEqualType [] && {count _x in [1,2]}} apply {+_x};
    _resumeUnavailable=+(_resumeRosterJournal select 3);
    _useResumeRoster=true;
};
private _admissionPairs=if (_useResumeRoster) then {_resumePairs} else {_group getVariable ["CBE_CombatPairs",[]]};
private _pairedAdmission=[];
private _remainingAdmission=+_team;
{
    if (_x isEqualType [] && {count _x == 2}) then {
        private _pair=(_x arrayIntersect _x) select {_x in _remainingAdmission};
        if (count _pair == 2) then {
            _pairedAdmission append _pair;
            _remainingAdmission=_remainingAdmission-_pair;
        };
    };
} forEach (_admissionPairs select [0,16]);
if (_useResumeRoster) then {
    private _preferred=(_pairedAdmission+_remainingAdmission) select {_x in _resumeParticipants && {!(_x in _resumeUnavailable)}};
    _team=(_preferred+((_pairedAdmission+_remainingAdmission)-_preferred)) select [0,_entryCapacity];
} else {
    _team = (_pairedAdmission+_remainingAdmission) select [0,_entryCapacity];
};
// A one-time native belief may seed a floor's route, never track an unseen live target.
// Preserve the original timestamp across owner adoption; a stale hint is not renewed.
private _contactBelief=if (_resume) then {+(_previous param [11,[],[[]]])} else {_options getOrDefault ["contactBelief",[]]};
private _validBelief=_contactBelief isEqualType [] && {count _contactBelief == 2}
    && {(_contactBelief select 0) isEqualType []} && {count (_contactBelief select 0) == 3}
    && {(_contactBelief select 0) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {(_contactBelief select 1) isEqualType 0} && {finite (_contactBelief select 1)}
    && {serverTime-(_contactBelief select 1) >= 0} && {serverTime-(_contactBelief select 1) <= 5};
if (_validBelief) then {
    private _bounds=boundingBoxReal _building;
    private _model=_building worldToModelVisual (_contactBelief select 0);
    private _low=_bounds select 0;private _high=_bounds select 1;
    _validBelief=(_model select 0) >= (_low select 0)-1 && {(_model select 0) <= (_high select 0)+1}
        && {(_model select 1) >= (_low select 1)-1} && {(_model select 1) <= (_high select 1)+1}
        && {(_model select 2) >= (_low select 2)-1} && {(_model select 2) <= (_high select 2)+1};
};
if (!_validBelief) then {_contactBelief=[]} else {_contactBelief=[+(_contactBelief select 0),_contactBelief select 1]};
private _baseBehaviour = if (_previous isEqualTo []) then {behaviour _leader} else {_previous select 3};
private _cleared = if (_resume) then {+(_previous select 1)} else {[]};
private _unreachable = if (_resume) then {+(_previous param [4, []])} else {[]};
private _retryCounts = if (_resume) then {+(_previous param [5, []])} else {[]};
private _failedBy = if (_resume) then {+(_previous param [6, _positions apply {[]}])} else {_positions apply {[]}};
if (count _failedBy != count _positions) then {_failedBy = _positions apply {[]}};
private _lastProgressAt = if (_resume) then {_previous param [7,serverTime]} else {serverTime};
private _deadline = if (_resume) then {_previous select 2} else {serverTime + 240};
// Genuine approach progress may renew the stall lease, but never the episode lifetime.
// Retain the absolute server-clock boundary across HC resume; legacy orders keep their
// already published deadline rather than gaining a fresh lifetime on each owner.
private _lifetime = (240 max (60*count _positions)) min 900;
private _hardDeadline = if (_resume) then {_previous param [10,_deadline,[0]]} else {serverTime+_lifetime};
if (_resume && {!(call _resumeCurrent)}) exitWith {["RESUME_ORDER_CHANGED"] call _refuse};
if (serverTime >= (_deadline min _hardDeadline)) exitWith {[] call _retireResume; false};
// Validate the new building/team before one release/publication commit. A fresh request
// may supersede the observed task, never a later task which appeared during preparation.
if !(call _admissionStable) exitWith {["TARGET_CHANGED_DURING_ADMISSION"] call _refuse};
private _baseAttack=if (_resume) then {_previous param [8,attackEnabled _leader,[true]]} else {attackEnabled _leader};
private _nativeOrderReceipt=[_group] call CBE_fnc_NativeOrderReceipt;
if (_resume && {(_previous param [9,_nativeOrderReceipt,[[]]]) isNotEqualTo _nativeOrderReceipt}) exitWith {
    [false] call _retireResume;
    false
};
if !([_group,false,false,true] call CBE_fnc_CortexIsEligible) exitWith {["GROUP_INELIGIBLE"] call _refuse};
private _preserveBrain=_options getOrDefault ["preserveBrain",false];
private _continueRoute=if (_resume) then {_previous param [12,false,[true]]} else {_options getOrDefault ["continueRoute",false]};
if (!(_continueRoute isEqualType true)) exitWith {["INVALID_CONTINUATION"] call _refuse};
if (!(_preserveBrain isEqualType true)) exitWith {["INVALID_PRESERVE_BRAIN"] call _refuse};
// A delayed lane/roster publication must not consume the durable order by entering
// setup and failing adoption afterward. Discovery retries this read-only admission under
// the original stall/hard deadlines above. Completed room work uses its separate exit journal.
// Read the existing bounded exit inventory before resume journal validation/startup.
private _entries=[];
private _securityEntries=[];
for "_exitIndex" from 0 to 15 do {
    private _candidate=_building buildingExit _exitIndex;
    // Model exit nodes can be buried below terrain after placement. Do not
    // make one an obligatory recovery destination or flatten it into a fake exit.
    private _candidateASL=AGLToASL _candidate;
    private _aboveTerrain=(_candidateASL select 2) >= (getTerrainHeightASL _candidate)-0.05;
    if (_candidate isNotEqualTo [0,0,0] && {_candidate distance2D _building < 50}
        && {_aboveTerrain}
        && {_entries findIf {_x distance2D _candidate < 1} < 0}) then {
        _entries pushBack _candidate;
    };
};
if (_entries isNotEqualTo []) then {
    private _entryOrigin=getPosATL _leader;
    _entries=[_entries,[],{_x distance2D _entryOrigin},"ASCEND"] call BIS_fnc_sortBy;
    // Interior entry remains bounded to four nearby choices. Exterior observation must
    // retain the other native exits already discovered, rather than silently dropping them.
    _securityEntries=+_entries;
    _entries resize ((count _entries) min 4);
};
// Nonempty phase journals must belong to this exact visit, not only a matching
// building/deadline. Defer before startup rather than silently resetting spent budgets.
private _resumePhaseReceipts=[];
private _resumePhasePending=false;
if (_resume) then {
    private _contextValid=_resumeRosterContext isEqualType [] && {count _resumeRosterContext == 4}
        && {(_resumeRosterContext select [0,3]) isEqualTo [_building,_admissionTransform,_hardDeadline]}
        && {(_resumeRosterContext select 3) isEqualType ""} && {(_resumeRosterContext select 3) != ""};
    {
        _x params ["_key","_size","_contextIndex"];
        private _receipt=_group getVariable [_key,[]];
        _resumePhaseReceipts pushBack [_key,_receipt];
        if (_receipt isNotEqualTo []) then {
            if (!_contextValid || {!(_receipt isEqualType [])} || {count _receipt != _size}
                || {(_receipt select _contextIndex) isNotEqualTo _resumeRosterContext}) then {
                _resumePhasePending=true;
            } else {
                private _identity=if (_key == "CBE_Cortex_ClearEgress") then {
                    (_receipt select 0) == "EGRESS" && {(_receipt select 10) == 5}
                        && {(_receipt select [4,3]) isEqualTo [_building,_admissionTransform,_hardDeadline]}
                } else {
                    if (_key in ["CBE_Cortex_ClearEarlyExits","CBE_Cortex_ClearReserveAdmission",
                        "CBE_Cortex_ClearYield","CBE_Cortex_ClearRelief"]) then {
                        (_receipt select 1) isEqualType []
                            && {count (_receipt select 1) <= (if (_key in ["CBE_Cortex_ClearEarlyExits","CBE_Cortex_ClearRelief"]) then {8} else {64})}
                    } else {
                        (_receipt select [0,3]) isEqualTo [_building,_hardDeadline,_admissionTransform]
                    }
                };
                if (_identity && {_key == "CBE_Cortex_ClearEarlyExits"}) then {
                    private _earlyCheck=createHashMapFromArray [
                        ["building",_building],["buildingTransform",_admissionTransform],
                        ["hardDeadline",_hardDeadline],["visitContext",_resumeRosterContext],
                        ["securityEntries",_securityEntries]];
                    _identity=["CHECK",_earlyCheck,_receipt] call CBE_fnc_BuildingEarlyExitJournal;
                };
                if (_identity && {_key == "CBE_Cortex_ClearRelief"}) then {
                    private _reliefCheck=createHashMapFromArray [
                        ["building",_building],["buildingTransform",_admissionTransform],
                        ["hardDeadline",_hardDeadline],["visitContext",_resumeRosterContext],
                        ["securityEntries",_securityEntries],["reliefReceipt",_receipt]];
                    _identity=count ([_reliefCheck] call CBE_fnc_BuildingReliefJournal) == 2;
                };
                if (!_identity) then {_resumePhasePending=true};
            };
        };
    } forEach [["CBE_Cortex_ClearEgress",14,13],["CBE_Cortex_ClearFollowBudget",5,4],
        ["CBE_Cortex_ClearStageBudget",5,4],["CBE_Cortex_ClearEarlyExits",2,0],
        ["CBE_Cortex_ClearReserveAdmission",2,0],["CBE_Cortex_ClearYield",2,0],
        ["CBE_Cortex_ClearRelief",2,0]];
};
if (_resumePhasePending) exitWith {false};
private _resumeLaneReceipt=[];
private _resumeLanePending=false;
if (_resume && {count ((_cleared+_unreachable) arrayIntersect (_cleared+_unreachable)) < count _positions}) then {
    private _resumeLanes=_group getVariable ["CBE_Cortex_ClearLanes",[]];
    _resumeLanePending=!_useResumeRoster
        || {!(_resumeLanes isEqualType [])} || {count _resumeLanes != 13}
        || {(_resumeLanes select 0) != 1}
        || {(_resumeLanes select 1) isNotEqualTo _group}
        || {(_resumeLanes select 2) isNotEqualTo _resumeRosterContext}
        || {(_resumeLanes select 3) isNotEqualTo _positions}
        || {(_resumeLanes select 4) isNotEqualTo _resumePairs};
    if (!_resumeLanePending) then {
        private _laneCheck=createHashMapFromArray [["group",_group],["building",_building],
            ["visitContext",_resumeRosterContext],["hardDeadline",_hardDeadline],
            ["generation",_admissionGeneration],["ownerEpoch",_admissionEpoch],
            ["positions",_positions],["pairs",_resumePairs],["securityEntries",_securityEntries],
            ["expectedSnapshot",_resumeLanes],
            ["cleared",_cleared],["unreachable",_unreachable]];
        _resumeLanePending=!( ["CHECK",_laneCheck] call CBE_fnc_BuildingLaneJournal );
        if (!_resumeLanePending) then {_resumeLaneReceipt=+_resumeLanes};
    };
};
if (_resumeLanePending) exitWith {false};
private _generation=-1;
private _operation=createHashMap;
private _handoffAccepted=false;
private _handoffFailure="HANDOFF_CHANGED";
isNil {
    private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
    private _liveIdentity=[_liveOperation getOrDefault ["generation",-1],
        _liveOperation getOrDefault ["ownerEpoch",-1],_liveOperation getOrDefault ["intent",""]];
    private _liveClear=_group getVariable ["CBE_AIPass_ClearOrder",[]];
    if (!local _group || {_admissionEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {_admissionGeneration != (_group getVariable ["CBE_AIPass_ClearGeneration",0])}
        || {_liveIdentity isNotEqualTo _admissionOperationIdentity}
        || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo _admissionGarrison}
        || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo _admissionDefend}
        || {(_liveClear isEqualTo []) isNotEqualTo (_previous isEqualTo [])}
        || {_liveClear isNotEqualTo [] && {(_liveClear param [0,objNull]) != (_previous param [0,objNull])}}
        || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _admissionNativeReceipt}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {serverTime >= (_deadline min _hardDeadline)}
        || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}) exitWith {};
    if (_resume && {!(call _resumeCurrent)}) exitWith {_handoffFailure="RESUME_ORDER_CHANGED"};
    if !(call _admissionStable) exitWith {_handoffFailure="TARGET_CHANGED_DURING_ADMISSION"};
    // Scheduled script callers may suspend before this commit. Do not consume a
    // durable order against a different lane journal than the preflight admitted.
    if (_resumeLaneReceipt isNotEqualTo [] && {
        (_group getVariable ["CBE_Cortex_ClearLanes",[]]) isNotEqualTo _resumeLaneReceipt
    }) exitWith {_handoffFailure="RESUME_LANES_CHANGED"};
    if (_resumePhaseReceipts findIf {
        (_group getVariable [_x select 0,[]]) isNotEqualTo (_x select 1)
    } >= 0) exitWith {_handoffFailure="RESUME_PHASE_CHANGED"};
    // These arrays can change without a new common generation. Never commit a roster
    // selected before a replacement or changed visit episode arrived during planning.
    if (_useResumeRoster && {
        (_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isNotEqualTo _resumeRosterContext
        || {_useRosterJournal && {(_group getVariable ["CBE_Cortex_ClearRoster",[]]) isNotEqualTo _resumeRosterJournal}}
        || {!_useRosterJournal && {
            (_liveOperation getOrDefault ["participants",[]]) isNotEqualTo _resumeParticipants
            || {(_liveOperation getOrDefault ["pairs",[]]) isNotEqualTo _resumePairs}
            || {(_liveOperation getOrDefault ["unavailable",[]]) isNotEqualTo _resumeUnavailable}
        }}
    }) exitWith {_handoffFailure="RESUME_ROSTER_CHANGED"};
    // Repeat actor/task admission at the mutation boundary, not just before geometry.
    // Stop counting once the requested minimum is met; do not acquire a new roster.
    private _readyCount=0;
    _available findIf {
        if ([_x] call _actorAdmissible) then {_readyCount=_readyCount+1};
        _readyCount >= _minimumActors
    };
    if (_readyCount < _minimumActors || {_team findIf {!([_x] call _actorAdmissible)} >= 0}) exitWith {
        _handoffFailure="ACTORS_CHANGED_DURING_ADMISSION";
    };
    if (!_resume && {_previous isNotEqualTo []}) then {[_group] call CBE_fnc_CortexClearRelease};
    if (_preserveBrain) then {
        private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
        if (count (_state getOrDefault ["drill",createHashMap]) > 0) then {
            [_group,_state,"BUILDING_CONTACT"] call CBE_fnc_CortexFlankEnd;
        };
        [_group] call CBE_fnc_CortexGroupMoveClear;
    } else {
        [_group,false] call CBE_fnc_CortexReleaseGroup;
    };
    if ((_group getVariable ["CBE_AIPass_Garrison", []]) isNotEqualTo []) then {[_group,true,[],false] call CBE_fnc_CortexGarrisonRelease};
    if ((_group getVariable ["CBE_AIPass_Defend", []]) isNotEqualTo []) then {[_group,false,false] call CBE_fnc_CortexDefendRelease};
    // Receipt our own authorized cleanup without adopting a later scheduled mission edit.
    _nativeOrderReceipt=[_group] call CBE_fnc_NativeOrderReceipt;
    if (!_resume) then {_baseAttack=attackEnabled _leader};
    if (_previous isEqualTo []) then {_baseBehaviour=behaviour _leader};
    _group setVariable ["CBE_Cortex_ClearAdmissionFailure",nil,true];
    _group setVariable ["CBE_AIPass_ClearOrder", [_building, _cleared, _deadline, _baseBehaviour, _unreachable, _retryCounts, _failedBy, _lastProgressAt, _baseAttack, _nativeOrderReceipt, _hardDeadline, _contactBelief, _continueRoute, +_admissionTransform], true];
    _group setVariable ["CBE_AIPass_ClearApplied", true];
    _group setVariable ["CBE_Cortex_ClearResult",["RUNNING",count _cleared,count _positions],true];
    _group setVariable ["CBE_Cortex_ClearEvidence",nil,true];
    _group setVariable ["CBE_Cortex_ClearReinforcements",[],true];
    // Compact setup snapshot; later updates occur on material room/retry progress or egress.
    _group setVariable ["CBE_Cortex_ClearStatus",["ENTRY",count _cleared,count _unreachable,count _positions,0,serverTime],true];
    _generation=(_group getVariable ["CBE_AIPass_ClearGeneration",0])+1;
    _group setVariable ["CBE_AIPass_ClearGeneration",_generation];
    _operation=[_group,"CLEAR",_building,_team,_positions,"ENTRY"] call CBE_fnc_OperationStart;
    if (count _operation == 0) exitWith {
        _handoffFailure="OPERATION_REFUSED";
        if (local _group && {(_group getVariable ["CBE_AIPass_ClearGeneration",-1]) == _generation}) then {
            _group setVariable ["CBE_AIPass_ClearOrder",nil,true];
            _group setVariable ["CBE_AIPass_ClearApplied",nil];
            _group setVariable ["CBE_Cortex_ClearStatus",nil,true];
            _group setVariable ["CBE_Cortex_ClearResult",["CANCELLED",count _cleared,count _positions],true];
        };
    };
    _handoffAccepted=true;
};
if (!_handoffAccepted) exitWith {[_handoffFailure] call _refuse};
// Route preparation may yield. Every later world/operation write must still belong to
// this admission; never put the potentially quadratic room plan inside an unscheduled block.
private _operationGeneration=_operation get "generation";
private _preparationEpoch=_operation get "ownerEpoch";
private _commitPreparation={
    params ["_mutation"];
    private _committed=false;
    isNil {
        private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
        if (!local _group
            || {_generation != (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
            || {_preparationEpoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {(_liveOperation getOrDefault ["generation",-1]) != _operationGeneration}
            || {(_liveOperation getOrDefault ["ownerEpoch",-1]) != _preparationEpoch}
            || {(_liveOperation getOrDefault ["intent",""]) != "CLEAR"}
            || {(_liveOperation getOrDefault ["objective",objNull]) != _building}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {serverTime >= (_deadline min _hardDeadline)}
            || {_resume && {(_group getVariable ["CBE_Cortex_ClearVisitContext",[]]) isNotEqualTo _resumeRosterContext}}
            || {!(call _admissionStable)}
            || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _nativeOrderReceipt}
            || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {};
        [_liveOperation] call _mutation;
        _committed=true;
    };
    _committed
};
private _admissionHoldPositions=createHashMap;
// A valid new operation now owns the selected actors. Retire only its predecessor's
// matching recall so the initial building step sees STOP instead of protected JOIN.
[{
    {
        if ([_x,_generation-1] call _ownedRecall && {local _x} && {!isPlayer _x}
            && {!([_group,false,_x] call CBE_fnc_CortexExternalTakeover)}) then {
            doStop _x;
            _admissionHoldPositions set [netId _x,getPosATL _x];
            _x setVariable ["CBE_Cortex_ClearRecall",nil];
        };
    } forEach _team;
}] call _commitPreparation;
// Capture admitted native intent before entry/topology planning can delay the first reserve step.
private _reserveAdmissionRows=[];
if (!_resume) then {
    _reserveAdmissionRows=(_available select [0,64]) apply {
        [_x,toUpperANSI currentCommand _x,
            (expectedDestination _x) apply {if (_x isEqualType []) then {+_x} else {_x}},formLeader _x]
    };
};
// Acquire the shared permission receipt only inside this preparation's current authority.
// A resumed durable task retains its original baseline; repeated acquisition cannot replace it.
private _attackPolicyReady=false;
[{
    params ["_liveOperation"];
    private _originalPolicy=if (_resume) then {[_baseAttack]} else {[]};
    private _policy=[_group,_liveOperation,false,_originalPolicy] call CBE_fnc_OperationAttackPolicy;
    _attackPolicyReady=_policy in ["ACQUIRED","OWNED"];
    if (_attackPolicyReady) then {
        _baseAttack=((_liveOperation get "restore") get "groupAttack") select 0;
        // OperationStart may restore an outgoing task. Persist the actual acquired baseline,
        // not the policy observed before that predecessor was retired.
        private _ownedClearOrder=+(_group getVariable ["CBE_AIPass_ClearOrder",[]]);
        if (count _ownedClearOrder == 14 && {(_ownedClearOrder select 8) != _baseAttack}) then {
            _ownedClearOrder set [8,_baseAttack];
            _group setVariable ["CBE_AIPass_ClearOrder",_ownedClearOrder,true];
        };
        // Initial owner adoption may reset replay markers; this admitted operation owns them.
        _group setVariable ["CBE_AIPass_ClearApplied",true];
        _group setVariable ["CBE_AIPass_ClearBuilding", true, true];
    };
}] call _commitPreparation;
if (!_attackPolicyReady) exitWith {
    // A replaced preparation cannot retire its successor. The commit gate repeats its proof.
    [{[_group,false] call CBE_fnc_CortexClearRelease}] call _commitPreparation;
    ["ATTACK_POLICY_REFUSED"] call _refuse
};
private _entryRoute=if (_entries isEqualTo []) then {[]} else {
    private _centroid=[0,0,0];
    {_centroid=_centroid vectorAdd getPosATL _x} forEach _team;
    _centroid=_centroid vectorMultiply (1/(count _team));
    private _ranked=_entries apply {[_centroid distance2D _x,_x]};
    _ranked sort true;
    +((_ranked select 0) select 1)
};
// Build a stable continuous route rather than repeatedly choosing whichever marker is nearest
// to each individual. This prevents criss-crossing and gives every pair a clear-through sector.
private _routeOrder=[];
// Snapshot absolute heights once. Repeated remaining-node scans are array arithmetic,
// not repeated terrain-frame engine conversions for every route step (up to 512 nodes).
private _positionHeights=_positions apply {(AGLToASL _x) select 2};
private _beliefHeight=if (_contactBelief isEqualTo []) then {0} else {(AGLToASL (_contactBelief select 0)) select 2};
private _beliefSeeded=false;
private _retiredIndices=_cleared+_unreachable;
private _remaining=[];
for "_index" from 0 to ((count _positions)-1) do {
    if !(_index in _retiredIndices) then {_remaining pushBack _index};
};
private _routeCursor=if (_entryRoute isEqualTo []) then {getPosATL _building} else {_entryRoute};
while {_remaining isNotEqualTo []} do {
    private _lowest=1e9;
    {private _height=_positionHeights select _x; if (_height < _lowest) then {_lowest=_height}} forEach _remaining;
    private _floorCandidates=_remaining select {abs ((_positionHeights select _x)-_lowest) < 1.8};
    private _selectionOrigin=_routeCursor;
    if (!_beliefSeeded && {_contactBelief isNotEqualTo []}
        && {_floorCandidates findIf {abs ((_positionHeights select _x)-_beliefHeight) <= 1.5} >= 0}) then {
        _selectionOrigin=_contactBelief select 0;
        _beliefSeeded=true;
    };
    private _bestSlot=0;
    private _bestDistance=1e9;
    {
        private _distance=_selectionOrigin distance2D (_positions select _x);
        if (_distance < _bestDistance) then {_bestSlot=_remaining find _x; _bestDistance=_distance};
    } forEach _floorCandidates;
    private _positionIndex=_remaining deleteAt _bestSlot;
    _routeOrder pushBack _positionIndex;
    _routeCursor=_positions select _positionIndex;
};
// A lead/security pair keeps small clears from assigning the sole reachable room to one soldier while
// every other member waits outside. Larger squads still receive several independent lanes, each with
// a trailing security partner and its own claimed room route. Shared queue and failure evidence prevent
// lanes from crowding the same room.
private _pairs=[];
private _pairPreference=if (_useResumeRoster) then {_resumePairs} else {[]};
[{_pairs=[_group,_team,true,_pairPreference] call CBE_fnc_CombatPairs}] call _commitPreparation;
private _pairRoutes=_pairs apply {[]};
private _pending=+_routeOrder;
private _pairStates=[];
// Avoid turning a multi-lane clear into a queue at one doorway. Each pair initially claims a
// distinct real entrance where possible; only when there are more pairs than entrances do later
// pairs reuse the nearest entry. Retry logic below still selects another entrance after a real
// path failure, so this is dispersion rather than a permanent door reservation.
private _claimedEntryIndices=[];
{
    private _pair=_x;
    private _pairLead=_pair select 0;
    private _entryIndex=-1;
    if (_entries isNotEqualTo []) then {
        private _ranked=[];
        {_ranked pushBack [_pairLead distance2D _x,_forEachIndex]} forEach _entries;
        _ranked sort true;
        private _unclaimed=_ranked select {!((_x select 1) in _claimedEntryIndices)};
        private _choice=if (_unclaimed isEqualTo []) then {_ranked} else {_unclaimed};
        _entryIndex=(_choice select 0) select 1;
        _claimedEntryIndices pushBackUnique _entryIndex;
    };
    _pairStates pushBack [0,false,_pair apply {getPosATL _x},time,0,-1,
        time+(_forEachIndex*1.25),0,-1,_entryIndex,[],0,false];
} forEach _pairs;
[{_group setVariable ["CBE_Cortex_ClearStatus",["ENTRY",count _cleared,count _unreachable,count _positions,count _pairs,serverTime],true]}] call _commitPreparation;
private _job=createHashMapFromArray [
    ["nativeHoldPositions",_admissionHoldPositions],
    ["group", _group], ["team", _team], ["started", []], ["positions", _positions], ["navigationPositions",+_allPositions], ["transitPositions",_allPositions select {!(_x in _positions)}], ["cleared", _cleared], ["building", _building], ["assigned", _team apply {[]}], ["unreachable",_unreachable], ["retryCounts",_retryCounts],
    ["entry",_entryRoute], ["entries",_entries], ["securityEntries",_securityEntries], ["pairs",_pairs], ["pairRoutes",_pairRoutes], ["pairStates",_pairStates], ["pending",_pending],
    ["deadline", _deadline], ["hardDeadline",_hardDeadline], ["baseBehaviour", _baseBehaviour], ["baseAttack",_baseAttack], ["generation", _generation], ["operationGeneration",_operationGeneration], ["ownerEpoch",_operation get "ownerEpoch"], ["failedBy",_failedBy], ["lastProgressAt",_lastProgressAt], ["visitCursor",0],
    ["continueRoute",_continueRoute],["contactBelief",_contactBelief],["nativeOrderReceipt",_nativeOrderReceipt],["buildingTransform",+_admissionTransform],["phase","ENTRY"],["rotatedOut",[]],["egressAssignments",[]],["egressDeadline",0],["egressProgress",[]],["egressFailed",false]
];
// Historical individual visits survive owner adoption. A fresh task gets a new token,
// even if it targets the same building in the same server frame. No movement is replayed.
private _visitContext=if (_resume) then {+_resumeRosterContext} else {[]};
private _visitBase=[_building,_job get "buildingTransform",_hardDeadline];
if (!_resume) then {
    _visitContext=_visitBase+[format ["%1:%2:%3",clientOwner,diag_tickTime,_generation]];
    [{_group setVariable ["CBE_Cortex_ClearVisitContext",_visitContext,true]}] call _commitPreparation;
};
_job set ["visitContext",+_visitContext];
// Fresh visits publish an explicit zero-spent receipt. Resume retains only its
// admitted original receipt; absence is unknown, never another free yield.
private _yieldReceipt=[+_visitContext,[]];
if (_resume) then {
    private _index=_resumePhaseReceipts findIf {(_x select 0) == "CBE_Cortex_ClearYield"};
    _yieldReceipt=if (_index < 0) then {[]} else {+((_resumePhaseReceipts select _index) select 1)};
};
_job set ["yieldReceipt",_yieldReceipt];
private _reliefReceipt=[+_visitContext,[]];
if (_resume) then {
    private _index=_resumePhaseReceipts findIf {(_x select 0) == "CBE_Cortex_ClearRelief"};
    _reliefReceipt=if (_index < 0) then {[]} else {+((_resumePhaseReceipts select _index) select 1)};
};
_job set ["reliefReceipt",_reliefReceipt];
_reliefReceipt=[_job] call CBE_fnc_BuildingReliefJournal;
_job set ["reliefReceipt",_reliefReceipt];
if (!_resume) then {
    [{_group setVariable ["CBE_Cortex_ClearYield",_yieldReceipt,true]}] call _commitPreparation;
    [{_group setVariable ["CBE_Cortex_ClearRelief",_reliefReceipt,true]}] call _commitPreparation;
};
[{
    params ["_liveOperation"];
    // OperationStart pairs before the episode lane preference is applied. The common
    // lifecycle and durable roster must retain the final allocation, not that earlier guess.
    private _committedPairs=_pairs apply {+_x};
    if ((_liveOperation getOrDefault ["pairs",[]]) isNotEqualTo _committedPairs) then {
        _liveOperation set ["pairs",_committedPairs];
        _group setVariable ["CBE_Operation",_liveOperation,true];
    };
    _group setVariable ["CBE_Cortex_ClearRoster",[+_visitContext,+_team,_pairs apply {+_x},[]],true];
}] call _commitPreparation;
// Bind delayed reserve admission to this exact episode, not the first staging callback.
// Native FOLLOW position may change with its same formation leader; that identity is retained.
private _reserveAdmission=_group getVariable ["CBE_Cortex_ClearReserveAdmission",[]];
if (!_resume) then {
    _reserveAdmission=[+_visitContext,_reserveAdmissionRows];
    [{_group setVariable ["CBE_Cortex_ClearReserveAdmission",_reserveAdmission,true]}] call _commitPreparation;
};
private _reserveAdmissionCommands=createHashMap;
if (_reserveAdmission isEqualType [] && {count _reserveAdmission == 2}
    && {(_reserveAdmission select 0) isEqualTo _visitContext}
    && {(_reserveAdmission select 1) isEqualType []} && {count (_reserveAdmission select 1) <= 64}) then {
    {
        if (_x isEqualType [] && {count _x == 4} && {(_x select 0) isEqualType objNull}
            && {(_x select 1) isEqualType ""} && {(_x select 2) isEqualType []}
            && {(_x select 3) isEqualType objNull}) then {
            _reserveAdmissionCommands set [netId (_x select 0),+_x];
        };
    } forEach (_reserveAdmission select 1);
};
_job set ["reserveAdmissionCommands",_reserveAdmissionCommands];
private _actorVisits=createHashMap;
private _enteredActors=[];
private _enteredActorIdentities=[];
if (_resume) then {
    {
        private _actor=_x;
        private _receipt=_actor getVariable ["CBE_Cortex_ClearVisits",[]];
        if (_receipt isEqualType [] && {count _receipt == 3} && {(_receipt select 0) isEqualTo _group}
            && {(_receipt select 1) isEqualTo _visitContext}
            && {(_receipt select 2) isEqualType []} && {count (_receipt select 2) <= 512}) then {
            private _visited=[];
            {
                if (_x isEqualType [] && {count _x == 2}) then {
                    private _index=_x select 0;
                    if (_index isEqualType 0 && {finite _index} && {_index == floor _index}
                        && {_index >= 0} && {_index < count _positions} && {_index in _cleared}
                        && {(_x select 1) isEqualTo (_positions select _index)}) then {
                        _visited pushBackUnique _index;
                    };
                };
            } forEach (_receipt select 2);
            if (_visited isNotEqualTo []) then {
                _actorVisits set [netId _actor,_visited];
                _enteredActors pushBack _actor;
                _enteredActorIdentities pushBack [_actor,netId _actor];
            };
        };
    } forEach (_team select [0,8]);
};
_job set ["actorVisits",_actorVisits];
_job set ["enteredActors",_enteredActors];
_job set ["enteredActorIdentities",_enteredActorIdentities];
// Early exits remain part of this episode even while other workers sweep.
// Adopt bookkeeping only when the exact native leg or a physical arrival is still ours.
_job set ["earlyExits",createHashMap];
_job set ["earlyExitMotion",createHashMap];
_job set ["earlyExitViewChecks",createHashMap];
_job set ["earlyExitViewCursor",0];
// Adopt the exact receipt admitted by preflight and rechecked at operation commit,
// rather than a later, separately delivered replacement of this phase component.
private _earlyReceipt=if (_resume) then {
    private _index=_resumePhaseReceipts findIf {(_x select 0) == "CBE_Cortex_ClearEarlyExits"};
    if (_index < 0) then {[]} else {+((_resumePhaseReceipts select _index) select 1)}
} else {[]};
if (!_resume) then {[{_group setVariable ["CBE_Cortex_ClearEarlyExits",nil,true]}] call _commitPreparation};
if (_resume && {_earlyReceipt isEqualType []} && {count _earlyReceipt == 2}
    && {(_earlyReceipt select 0) isEqualTo _visitContext}
    && {(_earlyReceipt select 1) isEqualType []} && {count (_earlyReceipt select 1) <= 8}) then {
    private _early=createHashMap;
    private _moves=_job getOrDefault ["movementTargets",createHashMap];
    private _diverted=[];
    {
        if (_x isEqualType [] && {count _x == 7}) then {
            _x params ["_actor","_target","_until","_state","_retryUsed","_entry","_watch"];
            if (_actor isEqualType objNull && {!isNull _actor} && {_actor in _team}
                && {_target isEqualType []} && {count _target == 3}
                && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {_until isEqualType 0} && {finite _until}
                && {_retryUsed isEqualType true}
                && {_entry isEqualType []} && {_watch isEqualType []}
                && {(_entry isEqualTo [] && {_watch isEqualTo []}) || {
                    count _entry == 3 && {count _watch == 3}
                        && {(_entry+_watch) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                        && {_entry in _securityEntries}
                }}
                && {_state in ["MOVING","ARRIVED","FAILED","DIVERTED"]}) then {
                private _live=(expectedDestination _actor) param [0,[]];
                private _owned=currentCommand _actor == "MOVE" && {count _live == 3} && {_live vectorDistance _target <= 0.25};
                // Exterior security may use entrances beyond the four assault lanes.
                // A finished native exit MOVE can settle as WAIT; only its exact
                // same-visit motion receipt may acknowledge that state as our arrival.
                private _settledExit=currentCommand _actor == "WAIT"
                    && {["CHECK",_actor,_job] call CBE_fnc_BuildingActorMotion}
                    && {((_actor getVariable ["CBE_Cortex_ClearMotion",[]]) select 3) isEqualTo _target};
                private _held=(currentCommand _actor in ["","STOP"] || {_settledExit})
                    && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 1};
                if (_state == "DIVERTED" || {!(_owned || {_held})}) then {
                    _state="DIVERTED";
                    _diverted pushBackUnique _actor;
                    _job set ["egressFailed",true];
                } else {
                    _moves set [netId _actor,+_target];
                    if (_state == "ARRIVED" && {!_held}) then {_state="MOVING"};
                    if (_state == "FAILED") then {_job set ["egressFailed",true]};
                };
                _early set [netId _actor,[_actor,+_target,_until,_state,_retryUsed,+_entry,+_watch]];
            } else {
                // An admitted exit that cannot retain its actor remains an unfinished
                // clearance result, never an absent worker or replacement movement grant.
                _job set ["egressFailed",true];
            };
        } else {_job set ["egressFailed",true]};
    } forEach (_earlyReceipt select 1);
    _job set ["earlyExits",_early];
    _job set ["movementTargets",_moves];
    _job set ["egressDiverted",_diverted];
};
// Adopt a transform/episode-bound exit journal without issuing movement. A different
// native destination owns the actor now and must not inherit an old exit receipt.
private _egressJournal=_group getVariable ["CBE_Cortex_ClearEgress",[]];
if (!_resume) then {[{_group setVariable ["CBE_Cortex_ClearEgress",nil,true]}] call _commitPreparation};
if (_resume && {count _egressJournal == 14} && {(_egressJournal select 0) == "EGRESS"}
    && {(_egressJournal select 4) == _building}
    && {(_egressJournal select 5) isEqualTo (_job get "buildingTransform")}
    && {(_egressJournal select 6) == _hardDeadline}
    && {(_egressJournal select 7) isEqualType 0} && {finite (_egressJournal select 7)}
    && {count (_egressJournal select 3) <= 8}
    && {(_egressJournal select 13) isEqualTo _visitContext}
    && {(_egressJournal select 10) == 5}
    && {(_egressJournal select 11) isEqualType []} && {(_egressJournal select 12) isEqualType []}
    && {count (_egressJournal select 12) <= 4}
    && {count (_egressJournal select 11)+count (_egressJournal select 3) <= 8}) then {
    private _assignments=[];
    private _records=[];
    private _moves=createHashMap;
    private _failed=(_egressJournal select 8) || {_job getOrDefault ["egressFailed",false]};
    private _progressVersion=count _egressJournal == 14 && {(_egressJournal select 10) == 5};
    private _exitRowSize=[6,10] select _progressVersion;
    {
        if (_x isEqualType [] && {count _x == _exitRowSize}) then {
            // A malformed current receipt cannot acquire fresh progress clocks. The nonce-bound
            // version retains original server-time progress and motion observations.
            if (_progressVersion && {(_x select [6,3]) findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0}} >= 0
                || {(_x select 7) > serverTime+1} || {(_x select 8) > serverTime+1}
                || {(_x select 7) > (_egressJournal select 7)} || {(_x select 8) > (_egressJournal select 7)}
                || {!((_x select 9) isEqualType [])} || {count (_x select 9) != 3}
                || {(_x select 9) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) then {_failed=true;continue};
            _x params ["_actor","_target","_arrived","_leg","_retries","_checkpoint"];
            private _live=(expectedDestination _actor) param [0,[]];
            private _atTarget=count _target == 3
                && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 1}
                && {abs (((getPosASL _actor) select 2)-((AGLToASL _target) select 2)) <= 1.5};
            private _ownsLeg=(currentCommand _actor == "MOVE" && {count _leg == 3}
                && {count _live == 3} && {_live vectorDistance _leg <= 0.25})
                || {currentCommand _actor == "WAIT" && {count _leg == 3}
                    && {["CHECK",_actor,_job,_leg] call CBE_fnc_BuildingActorMotion}};
            private _holdsArrival=_arrived && {_atTarget} && {currentCommand _actor in ["","STOP"]};
            if (_actor in _available && {group _actor == _group}
                && {(_assignments apply {_x select 0}) findIf {_x == _actor} < 0}
                && {count _target == 3} && {_ownsLeg || {_holdsArrival}}) then {
                _assignments pushBack [_actor,+_target,_holdsArrival];
                _moves set [netId _actor,+_leg];
                private _routeTarget=if (_checkpoint isEqualTo []) then {_target} else {_checkpoint};
                _records pushBack [_actor,
                    if (_progressVersion) then {_x select 6} else {(getPosASL _actor) vectorDistance (AGLToASL _routeTarget)},
                    if (_progressVersion) then {_x select 7} else {serverTime},
                    (_retries max 0) min 1,+_checkpoint,
                    if (_progressVersion) then {_x select 8} else {serverTime},
                    if (_progressVersion) then {+(_x select 9)} else {getPosASL _actor}];
            } else {_failed=true};
        } else {_failed=true};
    } forEach (_egressJournal select 3);
    // Version5 binds the existing progress, pending allocations and use counts to the
    // exact visit nonce. Unbound older records defer before startup, never grant fresh clocks.
    // Adoption never issues movement.
    private _pending=[];
    private _uses=createHashMap;
    if (count _egressJournal == 14) then {
        {
            private _pendingSize=[2,4] select ((_egressJournal select 10) == 5);
            if (_x isEqualType [] && {count _x == _pendingSize}
                && {(_x select 0) isEqualType objNull} && {(_x select 1) isEqualType []}
                && {count (_x select 1) in [0,3]}
                && {(_x select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {count _x == 2 || {(_x select 2) isEqualType 0 && {finite (_x select 2)}
                    && {(_x select 2) in [0,1,2]} && {(_x select 3) isEqualType 0}
                    && {finite (_x select 3)} && {(_x select 3) >= 0}
                    && {(_x select 3) <= (_egressJournal select 7)}}}) then {
                _x params ["_actor","_leg",["_planAttempts",0],["_nextPlanAt",0]];
                private _live=(expectedDestination _actor) param [0,[]];
                private _owned=currentCommand _actor in ["","STOP"]
                    || {currentCommand _actor == "MOVE" && {_leg isEqualType []} && {count _leg == 3}
                        && {count _live == 3} && {_live vectorDistance _leg <= 0.25}}
                    || {currentCommand _actor == "WAIT" && {count _leg == 3}
                        && {["CHECK",_actor,_job,_leg] call CBE_fnc_BuildingActorMotion}};
                if (_actor in _available && {group _actor == _group} && {_leg isEqualType []}
                    && {_owned} && {!(_actor in ((_assignments+_pending) apply {_x select 0}))}) then {
                    _pending pushBack [_actor,+_leg,_planAttempts,_nextPlanAt];
                    _moves set [netId _actor,+_leg];
                } else {_failed=true};
            } else {_failed=true};
        } forEach (_egressJournal select 11);
        {
            if (_x isEqualType [] && {count _x == 2}
                && {(_x select 0) isEqualType ""} && {(_x select 1) isEqualType 0}
                && {finite (_x select 1)} && {(_x select 1) >= 0} && {(_x select 1) <= 8}) then {
                _uses set [_x select 0,_x select 1];
            } else {_failed=true};
        } forEach ((_egressJournal select 12) select [0,4]);
    };
    if (_assignments isEqualTo [] && {_pending isEqualTo []}) then {_failed=true};
    _job set ["egressPending",_pending];
    _job set ["egressExitUses",_uses];
    _job set ["phase","EGRESS"];
    _team=(_assignments+_pending) apply {_x select 0};
    _job set ["team",_team];
    _job set ["egressAssignments",_assignments];
    _job set ["egressProgress",_records];
    _job set ["movementTargets",_moves];
    _job set ["egressDeadlineServer",_egressJournal select 7];
    _job set ["egressStartedServer",_egressJournal select 2];
    _job set ["egressDeadline",time+(((_egressJournal select 7)-serverTime) max 0)];
    _job set ["egressFailed",_failed];
    _job set ["entryFailed",_egressJournal select 9];
    [{
        params ["_liveOperation"];
        _liveOperation set ["participantPlatforms",createHashMapFromArray (_team apply {[netId _x,_x]})];
        _liveOperation set ["participants",+_team];
        _liveOperation set ["participantProgress",_team apply {[_x,getPosATL _x]}];
        _liveOperation set ["phase","EGRESS"];
        _group setVariable ["CBE_Operation",_liveOperation,true];
        _group setVariable ["CBE_Cortex_ClearStatus",["EGRESS",count _cleared,count _unreachable,count _positions,count _pairs,serverTime],true];
        diag_log format ["CBE CLEAR EGRESS ADOPTED: %1",[_generation,count _assignments,_failed,_egressJournal select 7]];
    }] call _commitPreparation;
};
// Keep reserve search consumption across a true resume, independently of local handles.
// Durable failed follow-through targets are bookkeeping, never movement/entry receipts.
_job set ["followThrough",createHashMap];
_job set ["followThroughFailures",createHashMap];
_job set ["followThroughExhausted",[]];
_job set ["followThroughExhaustedKeys",[]];
private _followBudget=_group getVariable ["CBE_Cortex_ClearFollowBudget",[]];
if (!_resume) then {[{_group setVariable ["CBE_Cortex_ClearFollowBudget",nil,true]}] call _commitPreparation};
if (_resume && {count _followBudget == 5} && {(_followBudget select 0) == _building}
    && {(_followBudget select 1) == _hardDeadline}
    && {(_followBudget select 2) isEqualTo (_job get "buildingTransform")}
    && {(_followBudget select 4) isEqualTo _visitContext}) then {
    private _failures=createHashMap;
    private _exhausted=[];
    private _actors=createHashMap;
    {_actors set [netId _x,_x]} forEach ((units _group) select [0,64]);
    {
        private _row=_x;
        if (_row isEqualType [] && {count _row == 3}
            && {(_row select 0) isEqualType ""} && {(_row select 1) isEqualType []}
            && {(_row select 2) isEqualType true}) then {
            private _key=_row select 0;
            private _indices=_row select 1;
            private _actor=_actors getOrDefault [_key,objNull];
            if (!isNull _actor && {count _indices <= 3}
                && {_indices findIf {!(_x isEqualType 0) || {!finite _x}
                    || {_x < 0} || {_x >= count _positions} || {_x != floor _x}} < 0}) then {
                _failures set [_key,+_indices];
                if (_row select 2) then {_exhausted pushBackUnique _actor};
            };
        };
    } forEach ((_followBudget select 3) select [0,64]);
    _job set ["followThroughFailures",_failures];
    _job set ["followThroughExhausted",_exhausted];
    _job set ["followThroughExhaustedKeys",_exhausted apply {netId _x}];
};
private _stageBudget=_group getVariable ["CBE_Cortex_ClearStageBudget",[]];
if (!_resume) then {[{_group setVariable ["CBE_Cortex_ClearStageBudget",nil,true]}] call _commitPreparation};
if (_resume && {count _stageBudget == 5} && {(_stageBudget select 0) == _building}
    && {(_stageBudget select 1) == _hardDeadline}
    && {(_stageBudget select 2) isEqualTo (_job get "buildingTransform")}
    && {(_stageBudget select 4) isEqualTo _visitContext}) then {
    private _counts=createHashMap;
    private _tried=createHashMap;
    private _triedEntries=createHashMap;
    private _stages=createHashMap;
    private _stageViews=createHashMap;
    private _moves=_job getOrDefault ["movementTargets",createHashMap];
    // This proposal exists only during a read-only native check of this validated
    // phase journal. It is removed before any marker commit or worker admission.
    private _checkResumeReserveMotion={
        params ["_probeActor","_probeTarget"];
        if (!(_probeTarget isEqualType []) || {count _probeTarget != 3}
            || {_probeTarget findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {count (_stageBudget select 3) > 64}
            || {_stageBudget isNotEqualTo (_group getVariable ["CBE_Cortex_ClearStageBudget",[]])}) exitWith {false};
        _job set ["reserveMotionProbe",[+_visitContext,_probeActor,+_probeTarget]];
        private _matched=["CHECK",_probeActor,_job,_probeTarget] call CBE_fnc_BuildingActorMotion;
        _job deleteAt "reserveMotionProbe";
        _matched isEqualTo true
    };
    private _actors=createHashMap;
    {_actors set [netId _x,_x]} forEach ((units _group) select [0,64]);
    {
        _x params ["_key","_count","_targets",["_stage",[]],["_entryHistory",[]]];
        private _viewReceipt=_x param [5,[]];
        private _viewReceiptValid=_viewReceipt isEqualTo [];
        if (_viewReceipt isEqualType [] && {count _viewReceipt == 4}) then {
            _viewReceiptValid=count _stage == 7 && {(_stage select 2) == "ARRIVED"}
                && {[_viewReceipt select 0,_viewReceipt select 1] findIf {
                    !(_x isEqualType []) || {count _x != 3}
                        || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
                } < 0}
                && {(_viewReceipt select 0) isEqualTo (_stage select 0)}
                && {(_viewReceipt select 1) isEqualTo (_stage select 4)}
                && {[2,3] findIf {!((_viewReceipt select _x) isEqualType 0)
                    || {!finite (_viewReceipt select _x)}} < 0}
                && {(_viewReceipt select 3) >= 0} && {(_viewReceipt select 3) <= serverTime}
                && {(_viewReceipt select 2) >= (_viewReceipt select 3)}
                && {(_viewReceipt select 2) <= _hardDeadline+2};
        };
        _counts set [_key,(_count max 0) min 3];
        _tried set [_key,+(_targets select [0,6])];
        _triedEntries set [_key,+(_entryHistory select [0,3])];
        private _actor=_actors getOrDefault [_key,objNull];
        // A known casualty's established post is history, not a live observer or
        // movement lease. Retain it across adoption so proactive exit replacement
        // can still recognise the gap. Missing network lookup never proves loss.
        private _historicGuard=if (_key isEqualType "") then {objectFromNetId _key} else {objNull};
        private _historicPost=count _stage == 7 && {(_stage select 2) == "ARRIVED"}
            && {!isNull _historicGuard} && {!alive _historicGuard
                || {lifeState _historicGuard == "INCAPACITATED"}
                || {_historicGuard getVariable ["ACE_isUnconscious",false]}}
            && {[_stage select 0,_stage select 4,_stage select 5] findIf {
                !(_x isEqualType []) || {count _x != 3}
                    || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            } < 0}
            && {(_stage select 5) in (_job getOrDefault ["securityEntries",_job getOrDefault ["entries",[]]])};
        if (_historicPost) then {_stages set [_key,+_stage]};
        if (_viewReceiptValid && {count _stage in [4,7]}
            && {(_stage select 2) in ["APPROACH","ARRIVED","REJECTED","EXHAUSTED"]}
            && {!isNull _actor} && {local _actor} && {!isPlayer _actor} && {!(_actor in _team)}
            && {[_actor] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _actor}
            && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
            && {isNull remoteControlled _actor}
            && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
            && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
            && {((_stage select 2) == "APPROACH" && {currentCommand _actor == "MOVE"
                    || {toUpperANSI currentCommand _actor in ["","WAIT"]
                        && {[_actor,_stage select 0] call _checkResumeReserveMotion}}})
                || {(_stage select 2) != "APPROACH" && {currentCommand _actor == "STOP"}
                    && {count (_stage select 0) == 3}
                    && {(getPosASL _actor) vectorDistance (AGLToASL (_stage select 0)) <= 2}
                    && {abs (((getPosASL _actor) select 2)-((AGLToASL (_stage select 0)) select 2)) <= 0.75}}}) then {
            private _target=_stage select 0;
            private _live=(expectedDestination _actor) param [0,[]];
            if (count _target == 3 && {
                (_stage select 2) != "APPROACH"
                    || {count _live == 3 && {_live vectorDistance _target <= 0.25}}
            }) then {
                // Adopt bookkeeping only: an approach retains its exact engine route.
                // A stopped physical arrival has no live MOVE endpoint to compare.
                private _postCommitted=false;
                [{
                    // Native intent can change between staged receipt observation and commit.
                    private _now=(expectedDestination _actor) param [0,[]];
                    if (local _actor && {group _actor == _group} && {!isPlayer _actor}
                        && {isNull objectParent _actor} && {[_actor] call CBE_fnc_CortexCombatEffective}
                        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
                        && {isNull remoteControlled _actor}
                        && {currentCommand _actor == "MOVE" && {count _now == 3} && {_now vectorDistance _target <= 0.25}
                            || {toUpperANSI currentCommand _actor in ["","WAIT"]
                                && {[_actor,_target] call _checkResumeReserveMotion}}
                            || {currentCommand _actor == "STOP" && {(_stage select 2) != "APPROACH"}
                                && {(getPosASL _actor) vectorDistance (AGLToASL _target) <= 2}
                                && {abs (((getPosASL _actor) select 2)-((AGLToASL _target) select 2)) <= 0.75}}}) then {
                        _actor setVariable ["CBE_Cortex_ClearReserve",[_generation,_preparationEpoch,+_target]];
                        _postCommitted=true;
                    };
                }] call _commitPreparation;
                if (_postCommitted) then {
                    _stages set [_key,+_stage];
                    _moves set [_key,+_target];
                    if (count _viewReceipt == 4) then {
                        _stageViews set [_key,[_viewReceipt select 2,_viewReceipt select 3]];
                    };
                };
            };
        };
    } forEach ((_stageBudget select 3) select [0,64]);
    _job set ["reserveStageSearchCounts",_counts];
    _job set ["reserveStageTriedTargets",_tried];
    _job set ["reserveStageTriedEntries",_triedEntries];
    _job set ["reserveStages",_stages];
    _job set ["reserveStageViewChecks",_stageViews];
    _job set ["movementTargets",_moves];
    _job set ["securityActors",(units _group) select {netId _x in _stages}];
};
// Resume restores native-work bookkeeping only, never commands, visits or deadlines.
// A known inherited receipt that refuses reconciliation cannot be treated as absent
// or ignored while a fresh worker starts. Absence itself is not complete owner-ready
// proof: coherent producer delivery and the exterior roster remain separate requirements.
private _reconciledActors=0;
private _reconcileFailure="";
{
    private _motionActor=_x;
    [{
        private _settingsOutcome=[_motionActor,_job,4,if (_resume) then {"ADOPT"} else {"PREPARE"}] call CBE_fnc_CortexClearSettingsApply;
        if (_resume) then {
            private _motionReceipt=_motionActor getVariable ["CBE_Cortex_ClearMotion",[]];
            private _motionRequired=_motionReceipt isNotEqualTo [];
            private _settingsRequired=_motionReceipt isEqualType [] && {count _motionReceipt == 5}
                && {(_motionReceipt param [4,[],[[]]]) isNotEqualTo []};
            private _motionAdopted=if (_motionRequired) then {["ADOPT",_motionActor,_job] call CBE_fnc_BuildingActorMotion} else {true};
            if (!(_settingsOutcome in ["ADOPTED","ABSENT"])
                || {_settingsRequired && {_settingsOutcome != "ADOPTED"}}) then {_reconcileFailure="ACTOR_SETTINGS_UNAVAILABLE"};
            if (!(_motionAdopted isEqualTo true)) then {_reconcileFailure="ACTOR_MOTION_UNAVAILABLE"};
        } else {
            if (!(_settingsOutcome in ["ABSENT","PREPARED"])) then {_reconcileFailure="ACTOR_PREPARATION_UNAVAILABLE"};
        };
        _reconciledActors=_reconciledActors+1;
    }] call _commitPreparation;
} forEach (_team select [0,8]);
if (_reconcileFailure != "" || {_reconciledActors != (count _team min 8)}) exitWith {
    [{
        [[_reconcileFailure,"ACTOR_RECONCILIATION_INTERRUPTED"] select (_reconcileFailure == "")] call _refuse;
        [_group,false] call CBE_fnc_CortexClearRelease;
    }] call _commitPreparation;
    false
};
private _laneAdopted=!_resume;
if (_resume) then {[{_laneAdopted=["ADOPT",_job] call CBE_fnc_BuildingLaneJournal}] call _commitPreparation};
if (!_laneAdopted) exitWith {
    // A scheduled preparation may have lost its generation. Never let this refusal
    // release whichever successor happens to be current now.
    [{
        ["LANE_SNAPSHOT_UNAVAILABLE"] call _refuse;
        [_group,false] call CBE_fnc_CortexClearRelease;
    }] call _commitPreparation;
    false
};
if !([_job] call CBE_fnc_BuildingOperationStart) exitWith {
    // Never report a worker-less order as accepted. If preparation lost ownership,
    // the new owner/episode keeps its durable order; no cleanup is remoted or restamped.
    isNil {
        private _liveOperation=_group getVariable ["CBE_Operation",createHashMap];
        if (local _group
            && {(_job get "ownerEpoch") == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {_generation == (_group getVariable ["CBE_AIPass_ClearGeneration",-1])}
            && {(_liveOperation getOrDefault ["generation",-1]) == _operationGeneration}
            && {(_liveOperation getOrDefault ["ownerEpoch",-1]) == (_job get "ownerEpoch")}
            && {(_liveOperation getOrDefault ["intent",""]) == "CLEAR"}) then {
            ["WORKER_START_REFUSED"] call _refuse;
            [_group,false] call CBE_fnc_CortexClearRelease;
        };
    };
    false
};
["SAVE",_job] call CBE_fnc_BuildingLaneJournal;
diag_log format ["[CBE] %1 clearing %2 (%3 positions, %4 soldiers, %5 entrances)", _group, typeOf _building, count _positions, count _team, count _entries];
true
