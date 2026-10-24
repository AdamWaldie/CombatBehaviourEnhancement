/*
 * Author: WaldoTheWarfighter
 * Unchanged blocked danger-stance receipts transfer metadata to the successor generation
 * inside this publication transaction; original baselines and cleanup expiry never renew.
 * Purpose: Starts or replaces one finite CBE operation without allowing stale work to command the group.
 * Locality/authority: Runs on the current group owner; server forwards only through callers that already own dispatch.
 * After locality adoption, replacement, generation capture and publication run unscheduled even for
 * scheduled script callers. Normal group PFH jobs already run unscheduled; no extra job is created.
 * Actor lists (at most64 unique objects), pair elements, array objectives and routes are
 * copied before mutation, isolating later caller-array edits. Routes admit at most512 points;
 * oversized/invalid inputs refuse rather than truncate or retire the active operation.
 * Nonempty position objectives and every route point require two/three finite numeric coordinates.
 * Invalid geometry returns before locality adoption, predecessor cleanup or generation mutation;
 * empty objectives/routes and object targets remain supported.
 * Object objectives retain identity for features which deliberately track a live world object.
 * Progress domain: participant platforms are captured at commitment. Foot actors boarding another
 * vehicle and crews changing vehicle cannot supply progress to the old operation; empty-roster
 * fallback retains its original foot/vehicle domain without fixing the leader actor identity.
 * Repeat/JIP: Replacing an intent increments a public generation. The durable summary is replayable; local routes and callbacks rebuild on ownership migration.
 * Arguments: 0 group <GROUP>; 1 intent <STRING>; 2 objective <OBJECT or ARRAY>; 3 participants <ARRAY of up to64 unique OBJECTs>; 4 route <ARRAY of up to512 positions>; 5 state <STRING, PLAN>.
 * Optional argument6: pair elements <ARRAY,[]>; at most two disjoint actor arrays covering
 * the requested participants. New pair identity is formed within each element and published once.
 * Empty preserves ordinary pairing. Element membership grants no command or fitness authority.
 * Return Value: HASHMAP operation, or an empty HASHMAP when the group cannot be owned here.
 * Current callers: Cortex tactical, building, vehicle and air operation starts.
 * Example: [group player, "ADVANCE", getPosATL player, units group player, [], "PLAN"] call CBE_fnc_OperationStart;
 */
params [
    ["_group",grpNull,[grpNull]], ["_intent","",[""]], ["_objective",objNull,[objNull,[]]],
    ["_participants",[],[[]]], ["_route",[],[[]]], ["_phase","PLAN",[""]], ["_pairElements",[],[[]]]
];
if (isNull _group || {!local _group} || {_intent == ""}) exitWith {createHashMap};
// Participant validation precedes even owner adoption and outgoing cleanup. Never let
// malformed script input enter native actor commands or multiply progress accounting.
if (count _participants > 64
    || {_participants findIf {!(_x isEqualType objNull)} >= 0}
    || {count (_participants arrayIntersect _participants) != count _participants}) exitWith {createHashMap};
_participants=+_participants;
// Validate the same private geometry that will be committed. A malformed replacement
// must not adopt/retire work or consume the current generation. Empty means no position.
if (count _route > 512 || {_objective isEqualType [] && {!(count _objective in [0,2,3])}}) exitWith {createHashMap};
private _objectiveSnapshot=if (_objective isEqualType []) then {+_objective} else {_objective};
private _routeSnapshot=+_route;
private _positionValid={
    private _point=_this;
    _point isEqualType [] && {count _point in [2,3]}
        && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
if ((_objectiveSnapshot isEqualType [] && {_objectiveSnapshot isNotEqualTo []}
        && {!(_objectiveSnapshot call _positionValid)})
    || {_routeSnapshot findIf {!(_x call _positionValid)} >= 0}) exitWith {createHashMap};
// Reject a malformed optional partition before retiring any previous operation.
// Each row is bounded by the admitted actor count before membership scans/copying.
private _partitionValid=count _pairElements <= 2;
private _partitioned=[];
{
    if (!(_x isEqualType []) || {count _x > count _participants}
        || {_x findIf {!(_x isEqualType objNull) || {!(_x in _participants)}} >= 0}) exitWith {_partitionValid=false};
    _partitioned append _x;
} forEach (_pairElements select [0,2]);
if (_pairElements isNotEqualTo [] && {!_partitionValid
    || {count (_partitioned arrayIntersect _partitioned) != count _partitioned}
    || {_participants findIf {!(_x in _partitioned)} >= 0}}) exitWith {createHashMap};
_pairElements=_pairElements apply {+_x};
// The shared lifecycle is the final authority boundary for every feature. Check it before
// retiring an earlier route: a delayed job must not cancel CBE state or issue cleanup after
// Zeus, a player or a specialist controller has claimed the group.
if !([_group,false,false,true] call CBE_fnc_CortexIsEligible) exitWith {createHashMap};
// Explicit feature orders can arrive before periodic discovery adopts a fresh local group.
// Establish its owner epoch first; adopting after publication would cancel this new operation
// as if it were inherited from another machine. Locality adoption marks itself before resuming
// durable intents, so any nested operation start sees the already-established owner.
if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {
    [_group,true] call CBE_fnc_CortexLocality;
};
// Public scheduled callers share this lifecycle with unscheduled group jobs. Keep
// generation capture, outgoing cleanup and new publication in one non-suspending call.
// Locality adoption above may resume durable work; recapture only after it returns.
private _cbeStartedOperation=createHashMap;
isNil {
_cbeStartedOperation=call {
if (!local _group || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}) exitWith {createHashMap};
// Retire native attack caps before a committed operation can inherit them as mission limits.
{if (local _x) then {["RELEASE",_x] call CBE_fnc_DangerAttackPace}}
    forEach (_participants select [0,64]);
if (_participants findIf {(_x getVariable ["CBE_Danger_AttackPace",[]]) isNotEqualTo []} >= 0) exitWith {createHashMap};
// Relinquish finite weapon support before changing the original operation proof.
[_group,true] call CBE_fnc_CortexIlluminationStep;
private _previous=_group getVariable ["CBE_Operation",createHashMap];
private _generation=(_group getVariable ["CBE_OperationGeneration",0])+1;
if (count _previous > 0) then {
    // Retire a matching outgoing drill while its generation/epoch still own feature holds.
    // REPLACED suppresses return-to-formation; a new operation supplies its own movement.
    private _previousState=_group getVariable ["CBE_AIPass_State",createHashMap];
    private _previousDrill=_previousState getOrDefault ["drill",createHashMap];
    if (count _previousDrill > 0
        && {(_previousDrill getOrDefault ["operationGeneration",-1]) == (_previous getOrDefault ["generation",-2])}
        && {(_previousDrill getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
        [_group,_previousState,"REPLACED"] call CBE_fnc_CortexFlankEnd;
    };
    [_group,_previous getOrDefault ["generation",-1],"REPLACED"] call CBE_fnc_OperationCancel;
};
// A finite danger posture is meaningful only for an on-foot group. Aircraft, vehicles and boats
// use this common record too, but must not have their native flight or combat state altered merely
// because a lifecycle record starts. Retain the decision so release is equally narrow later.
private _operationAnchor=[_group] call CBE_fnc_CortexGroupAnchor;
if (isNull _operationAnchor) then {_operationAnchor=leader _group};
private _dangerPosture=(vehicle _operationAnchor) isEqualTo _operationAnchor;
private _dangerResponse=_group getVariable ["CBE_Danger_Response",[]];
private _liveDanger=if (count _dangerResponse == 5
    && {(_dangerResponse select 4) == (_group getVariable ["CBE_Danger_Generation",-1])}
    && {time < (_dangerResponse select 3)}) then {+_dangerResponse} else {[]};
private _capable=_participants select {
    [_x] call CBE_fnc_CortexCombatEffective && {local _x} && {group _x == _group}
        && {!isPlayer _x} && {isNull (remoteControlled _x)}
        && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
};
private _pairs=[];
if (toUpperANSI _intent in ["ADVANCE","FLANK","ASSAULT","WITHDRAW","CLEAR"]) then {
    if (_pairElements isEqualTo []) then {_pairs=[_group,_capable] call CBE_fnc_CombatPairs} else {
        {
            private _element=_x select {_x in _capable};
            _pairs append ([_group,_element,false] call CBE_fnc_CombatPairs);
        } forEach _pairElements;
        [_group,_pairs] call CBE_fnc_CombatPairsPublish;
    };
};
private _operation=createHashMapFromArray [
    ["intent",toUpperANSI _intent], ["generation",_generation], ["ownerEpoch",_group getVariable ["CBE_AIPass_Epoch",0]],
    ["pairs",_pairs], ["pairElements",_pairElements apply {_x select {_x in _capable}}], ["objective",_objectiveSnapshot], ["participants",_capable], ["participantsRequired",_participants isNotEqualTo []], ["route",_routeSnapshot], ["phase",toUpperANSI _phase],
    ["startedAt",time], ["lastProgressAt",time], ["lastProgressPosition",getPosATL _operationAnchor],
    ["participantProgress",_capable apply {[_x,getPosATL _x]}], ["lastProgressActor",objNull],
    ["participantPlatforms",createHashMapFromArray (_capable apply {[netId _x,vehicle _x]})],
    ["progressPlatform",vehicle _operationAnchor],["progressOnFoot",_dangerPosture],
    ["replans",0], ["recovery",createHashMap], ["recoveryAttempts",createHashMap], ["unavailable",[]], ["restore",createHashMap],
    ["dangerAtStart",_liveDanger], ["dangerPosture",_dangerPosture], ["cancelReason",""]
];
// Relinquish the old posture before changing its generation proof. Otherwise renewal captures
// CBE-applied values as a new baseline and a later release cannot restore the original posture.
if (_dangerPosture) then {
    [_operationAnchor,"RELEASE"] call CBE_fnc_DangerReact;
    // Retire weak posture while its original generation still grants restoration authority.
    // New committed movers must not inherit a temporary danger stance as an authored baseline.
    {
        if (local _x && {count (_x getVariable ["CBE_Danger_EngineStanceLease",[]]) > 0}) then {
            [_x] call CBE_fnc_DangerEngineRelease;
        };
    } forEach ((units _group) select [0,64]);
    [_group,-1,false,""] call CBE_fnc_DangerGroupHideStep;
    // Both release paths above may defer to a native task. Carry only exact unchanged
    // proof through this internal generation publication, never reapply stance here.
    {
        private _postureReceipt=_x getVariable ["CBE_Danger_EngineStanceLease",[]];
        if (local _x && {group _x == _group} && {!isPlayer _x}
            && {isNull remoteControlled _x} && {([_x] call CBE_fnc_CortexExternalOwner) == ""}
            && {!([_x] call CBE_fnc_CompatibilityExternalControl)}
            && {_postureReceipt isEqualType []} && {count _postureReceipt == 6}
            && {(_postureReceipt select 0) in ["AUTO","UP","MIDDLE","DOWN"]}
            && {(_postureReceipt select 1) in ["AUTO","UP","MIDDLE","DOWN"]}
            && {(_postureReceipt select 2) isEqualType 0} && {finite (_postureReceipt select 2)}
            && {(_postureReceipt select 3) isEqualTo (_generation-1)}
            && {(_postureReceipt select 4) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_postureReceipt select 5) isEqualTo _group}
            && {toUpperANSI unitPos _x == (_postureReceipt select 1)}) then {
            private _successorPosture=+_postureReceipt;
            _successorPosture set [3,_generation];
            _x setVariable ["CBE_Danger_EngineStanceLease",_successorPosture];
        };
    } forEach ((units _group) select [0,64]);
    // Carry unresolved group posture through the same internal publication. Confirmed
    // components are already retired; preserve the original baseline and expiry of the rest.
    private _reactionReceipt=_group getVariable ["CBE_Danger_ReactionLease",[]];
    if (_reactionReceipt isEqualType [] && {count _reactionReceipt == 8}
        && {(_reactionReceipt select 0) in ["CARELESS","SAFE","AWARE","COMBAT","STEALTH"]}
        && {(_reactionReceipt select 1) in ["CARELESS","SAFE","AWARE","COMBAT","STEALTH"]}
        && {(_reactionReceipt select 2) in ["BLUE","GREEN","WHITE","YELLOW","RED"]}
        && {(_reactionReceipt select 3) in ["BLUE","GREEN","WHITE","YELLOW","RED"]}
        && {(_reactionReceipt select 4) isEqualType 0} && {finite (_reactionReceipt select 4)}
        && {(_reactionReceipt select 5) isEqualTo (_generation-1)}
        && {(_reactionReceipt select 6) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_reactionReceipt select 7) isEqualTo clientOwner}
        && {(_reactionReceipt select 0) != (_reactionReceipt select 1)
            || {(_reactionReceipt select 2) != (_reactionReceipt select 3)}}
        && {(_reactionReceipt select 0) == (_reactionReceipt select 1)
            || {behaviour _operationAnchor == (_reactionReceipt select 1)}}
        && {(_reactionReceipt select 2) == (_reactionReceipt select 3)
            || {combatMode _group == (_reactionReceipt select 3)}}) then {
        private _successorReaction=+_reactionReceipt;
        _successorReaction set [5,_generation];
        _group setVariable ["CBE_Danger_ReactionLease",_successorReaction,true];
    };
};
_group setVariable ["CBE_OperationGeneration",_generation,true];
_group setVariable ["CBE_Operation",_operation,true];
_group setVariable ["CBE_OperationResult",[toUpperANSI _intent,"RUNNING",_generation,serverTime],true];
// The new generation is now authoritative, so a still-live danger response can adopt MAINTAIN
// without being mistaken for a stale operation. This preserves the committed route while keeping
// the bounded combat posture across CONTACT -> manoeuvre/CQB/withdrawal transitions. A stale
// posture is released rather than carried into unrelated work.
if (_dangerPosture) then {
    if (_liveDanger isNotEqualTo []) then {
        _liveDanger params ["_dangerCause","_dangerPosition"];
        private _dangerEvent=_group getVariable ["CBE_Danger_ResponseEvent",[]];
        if (!(count _dangerEvent in [4,5,6,7,8])
            || {(_dangerEvent param [0,"",[""]]) != _dangerCause}
            || {(_dangerEvent param [2,-1,[0]]) != (_liveDanger select 2)}) then {
            _dangerEvent=_liveDanger select [0,4];
        };
        private _dangerAction=[_group,_dangerEvent] call CBE_fnc_DangerActionSelect;
        private _dangerObserver=_dangerEvent param [5,_operationAnchor,[objNull]];
        [_dangerObserver,_dangerCause,_dangerPosition,_dangerAction,_liveDanger select 3] call CBE_fnc_DangerReact;
    };
};
_operation
};
};
_cbeStartedOperation
