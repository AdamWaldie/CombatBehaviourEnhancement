/*
 * Author: WaldoTheWarfighter
 * Purpose: Applies a short, local danger posture selected by the danger FSM without replacing an active CBE or external movement operation.
 * Locality/authority: Runs where the observed actor and its group are local. It changes only group behaviour and combat mode that it records as owned. Explicit BLUE/GREEN hold-fire discipline remains authoritative.
 * Application and its lease commit atomically after current native-task/hold-fire/owner checks.
 * STEALTH defers group posture/RED escalation; native defence and weak actor reflexes remain independent.
 * Restoration atomically rechecks the exact lease, actor/group locality, epoch and generation.
 * Cleanup may retire a dead observer's group lease using a surviving local posture anchor. New reactions require a live observer.
 * Repeat/JIP: One public lease contains prior/applied values, operation generation, locality epoch and owner. Repeated events extend the lease; restore changes only values still matching CBE's application and discards its lease on external takeover. DangerStep owns the finite response context.
 * Arguments: 0 actor <OBJECT>; 1 cause <STRING, RESTORE or RELEASE>; 2 approximate danger position <ARRAY, []>; 3 classified action <STRING, "">.
 * Return Value: STRING - RESTORED, ASSESS, POSTURE, YIELDED or IGNORED.
 * Current callers: DangerStep and CortexGroupTick cleanup.
 * Example: [leader group player,"SUPPRESSED",getPosATL player,"HIDE"] call CBE_fnc_DangerReact;
 */
params [["_actor",objNull,[objNull]],["_cause","RESTORE",[""]],["_position",[],[[]]],["_action","",[""]]];
if (isNull _actor || {!local _actor} || {!alive _actor && {!(_cause in ["RESTORE","RELEASE"])}}) exitWith {"IGNORED"};
private _group=group _actor;
if (isNull _group || {!local _group}) exitWith {"IGNORED"};
private _lease=+(_group getVariable ["CBE_Danger_ReactionLease",[]]);
private _generation=_group getVariable ["CBE_OperationGeneration",0];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _leaseOwned=count _lease == 8
    && {(_lease select 5) == _generation}
    && {(_lease select 6) == _epoch}
    && {(_lease select 7) == clientOwner};
// Use the same local surviving actor used by danger setup and cleanup when comparing CBE's
// temporary posture. A leader casualty or reassignment must not make an intact CBE lease look
// externally changed, or restore a stale posture over the new leader.
private _postureActor=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _postureActor) then {_postureActor=leader _group};
// Restore has a separate short commit boundary. Pending scheduled callbacks must not erase
// a renewed response or restore posture after actor/group locality or generation changes.
private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;
if (_cause in ["RESTORE","RELEASE"]) exitWith {
    private _restoreResult="IGNORED";
    isNil {
        _restoreResult=call {
            if (isNull _actor || {!local _actor} || {group _actor != _group} || {!local _group}
                || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
                || {_generation != (_group getVariable ["CBE_OperationGeneration",0])}
                || {(_group getVariable ["CBE_Danger_ReactionLease",[]]) isNotEqualTo _lease}) exitWith {"IGNORED"};
            _postureActor=[_group] call CBE_fnc_CortexGroupAnchor;
            if (isNull _postureActor) then {_postureActor=leader _group};
            // No surviving local posture owner remains: retire this exact metadata only.
            if (!([_postureActor] call CBE_fnc_CortexCombatEffective)) exitWith {
                _group setVariable ["CBE_Danger_ReactionLease",nil,true];
                "YIELDED"
            };
            _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;
            // Never restore over a curator/player/specialist. Discard only the captured lease.
            if (_yieldToOwner || {count _lease > 0 && {!_leaseOwned}}) exitWith {
                _group setVariable ["CBE_Danger_ReactionLease",nil,true];
                "YIELDED"
            };
            // RESTORE waits for expiry; explicit RELEASE relinquishes unchanged owned values now.
            if (_leaseOwned && {_cause == "RELEASE" || {time >= (_lease select 4)}}) then {
                _lease params ["_behaviour","_ownedBehaviour","_combatMode","_ownedCombatMode"];
                if (_behaviour != _ownedBehaviour && {behaviour _postureActor == _ownedBehaviour}) then {_group setBehaviour _behaviour};
                if (_combatMode != _ownedCombatMode && {combatMode _group == _ownedCombatMode}) then {_group setCombatMode _combatMode};
                _group setVariable ["CBE_Danger_ReactionLease",nil,true];
                "RESTORED"
            } else {"ASSESS"}
        };
    };
    _restoreResult
};
if !(_cause in ["HIT","EXPLOSION","SUPPRESSED","DETECTED","PROXIMITY","CANFIRE","GUNFIRE","CASUALTY","BODY_FOUND","SCREAM"]) exitWith {"IGNORED"};
if (_yieldToOwner) exitWith {"IGNORED"};
// The immediate FSM response is deliberately posture-only. Movement, target assignment and route
// ownership stay with native AI or the already-running CBE operation. This makes the classifier
// useful without creating a second combat controller.
if (_action == "RELEASE") exitWith {"IGNORED"};
// Vehicle crews and actors executing a native forced command are observation-only here. Their
// dedicated vehicle/native owner receives the group-brain wake, but CBE does not alter behaviour,
// ROE, posture or movement while that owner is active.
if (_action in ["FORCED","VEHICLE"]) exitWith {"ASSESS"};
// Casualty and scream causes do not identify a hostile. The per-soldier engine FSM may still use a
// short weak stance, while the group layer preserves its current behaviour and ROE. Morale and
// survivor-role logic consume actual losses independently on their normal bounded group step.
if (_cause in ["CASUALTY","BODY_FOUND","SCREAM"]) exitWith {"ASSESS"};
// BLUE and GREEN are deliberate fire-control orders rather than passive defaults. Preserve them
// exactly: the actor-local engine FSM may still take a finite weak stance, but a danger callback
// cannot silently authorise fire or launch group tactics against the mission maker's order.
if (combatMode _group in ["BLUE","GREEN"]) exitWith {"ASSESS"};
if !(_action in ["HIDE","ENGAGE","MAINTAIN",""]) then {_action=""};
// Classification may have run in scheduled code. Apply posture and its baseline lease together,
// using current authority and native-task state; never publish a lease after a newer hold-fire order.
private _postureResult="IGNORED";
isNil {
    _postureResult=call {
        if (isNull _actor || {!local _actor} || {!local _group} || {group _actor != _group}
            || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {_generation != (_group getVariable ["CBE_OperationGeneration",0])}
            || {(_group getVariable ["CBE_Danger_ReactionLease",[]]) isNotEqualTo _lease}
            || {!([_actor] call CBE_fnc_CortexCombatEffective)}
            || {[_group] call CBE_fnc_CortexExternalTakeover}
            || {[_actor] call CBE_fnc_CompatibilityExternalControl}) exitWith {"IGNORED"};
        if (combatMode _group in ["BLUE","GREEN"]) exitWith {"ASSESS"};
        if (!isNull objectParent _actor || {fleeing _actor}
            || {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}) exitWith {"ASSESS"};
        _postureActor=[_group] call CBE_fnc_CortexGroupAnchor;
        if (isNull _postureActor) then {_postureActor=leader _group};
        if (!([_postureActor] call CBE_fnc_CortexCombatEffective) || {!local _postureActor}) exitWith {"IGNORED"};
        // Retain the mission's concealment policy. Weak self-defence posture/native
        // combat still operate; observing a hostile cannot authorise RED pursuit here.
        if (behaviour _postureActor == "STEALTH") exitWith {"ASSESS"};
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if ((_operation getOrDefault ["phase",""]) == "CANCELLED") exitWith {"ASSESS"};
// MAINTAIN is valid only while a real operation still owns the committed route. A delayed danger
// callback can outlive operation cleanup, so reclassify that orphaned label instead of treating it
// as evidence of movement ownership.
if (_action == "MAINTAIN" && {count _operation == 0}) then {
    _action=["ENGAGE","HIDE"] select (_cause in ["HIT","EXPLOSION","SUPPRESSED","CASUALTY","BODY_FOUND","SCREAM"]);
};
// Expiry permits cleanup; it does not prove cleanup has run. A late renewing event must
// preserve the original baseline while the exact owned values still remain applied.
private _behaviourIntact=_leaseOwned && {behaviour _postureActor == (_lease select 1)};
private _combatIntact=_leaseOwned && {combatMode _group == (_lease select 3)};
private _leaseIntact=_leaseOwned && {_behaviourIntact} && {_combatIntact};
private _priorBehaviour=if (_behaviourIntact) then {_lease select 0} else {behaviour _postureActor};
private _priorCombat=if (_combatIntact) then {_lease select 2} else {combatMode _group};
private _appliedBehaviour=if (_behaviourIntact) then {_lease select 1} else {_priorBehaviour};
private _appliedCombat=if (_combatIntact) then {_lease select 3} else {_priorCombat};
// CARELESS is an explicit mission-maker instruction. A danger observation alone must not
// silently turn it into a CBE combat task.
if (_priorBehaviour in ["SAFE","AWARE"]) then {
    if (behaviour _postureActor != "COMBAT") then {_group setBehaviour "COMBAT"};
    _appliedBehaviour="COMBAT";
};
// MAINTAIN means keep the committed route, not ignore the threat. A manoeuvring element may adopt
// the same short combat posture as an idle element without receiving a destination, target or
// firing command. This closes the gap where an active advance/flank/CQB operation suppressed its
// own danger response merely because it already owned movement.
private _engaging=_action == "ENGAGE" || {_action == "MAINTAIN" && {_cause in ["DETECTED","PROXIMITY","CANFIRE","GUNFIRE"]}};
// Suppression renews the finite response without withdrawing an already-authorised engagement.
// Exact ownership is required; an external mode change and BLUE/GREEN orders remain authoritative.
private _keepEngagement=_combatIntact && {_appliedCombat == "RED"};
private _desiredCombat=if (_engaging || {_keepEngagement}) then {"RED"} else {"YELLOW"};
// A committed tactical drill owns its YELLOW discipline. Danger response may retain
// posture but cannot turn that exact lease into RED and falsely trigger ROE_CHANGED.
private _tacticalState=_group getVariable ["CBE_AIPass_State",createHashMap];
private _tacticalDrill=_tacticalState getOrDefault ["drill",createHashMap];
private _tacticalMode=_tacticalDrill getOrDefault ["groupCombatMode",[]];
private _tacticalModeOwned=count _operation > 0 && {count _tacticalMode == 2}
    && {(_operation getOrDefault ["generation",-2]) == _generation}
    && {(_operation getOrDefault ["ownerEpoch",-1]) == _epoch}
    && {(_tacticalDrill getOrDefault ["operationGeneration",-1]) == _generation}
    && {(_tacticalDrill getOrDefault ["stage",""]) in ["START","MOVE","PAUSE","HOLD"]}
    && {combatMode _group == (_tacticalMode select 1)};
if (!_tacticalModeOwned && {_priorCombat == "WHITE" || {_engaging && {_priorCombat == "YELLOW"}}}) then {
    if (combatMode _group != _desiredCombat) then {_group setCombatMode _desiredCombat};
    _appliedCombat=_desiredCombat;
};
// These finite durations are fixed policy, not mutable state. Avoid allocating the same
// lookup map for every danger response across a large firefight.
private _duration=switch (_cause) do {
    case "HIT": {3};
    case "EXPLOSION": {2.5};
    case "SUPPRESSED";
    case "CASUALTY": {2};
    case "BODY_FOUND";
    case "SCREAM";
    case "PROXIMITY";
    case "CANFIRE";
    case "DETECTED": {1.5};
    default {1};
};
private _until=(time + _duration) max (if (_leaseIntact) then {_lease select 4} else {-1});
_group setVariable ["CBE_Danger_ReactionLease",[_priorBehaviour,_appliedBehaviour,_priorCombat,_appliedCombat,_until,_generation,_epoch,clientOwner],true];
"POSTURE"
    };
};
_postureResult
