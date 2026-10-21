/*
 * Author: WaldoTheWarfighter
 * Purpose: Cheaply decide whether a running finite engine danger response still belongs to CBE.
 * This gate intentionally avoids squad scans, terrain work and config inspection because the engine
 * may evaluate it repeatedly during the response's sub-two-second observation window.
 * Locality / Authority: Runs where the affected AI soldier is local and reads only live gates and
 * explicit actor/group and occupied-platform ownership markers. It issues no command and changes no state.
 * Repeat/JIP: Stateless and repeat-safe. A new locality starts a fresh engine danger FSM.
 * Arguments: 0: affected soldier <OBJECT>, objNull; 1: initial observation <BOOL>, false.
 * Initial observation permits native task classification only. A current FORCED response may wait
 * for its original deadline without issuing commands; a new native task interrupts other modes immediately.
 * Return Value: Boolean - true while the current short CBE response may continue.
 * Current callers: Engine-loaded infantry danger FSM Waiting state.
 * Example: if !([cursorObject] call CBE_fnc_DangerEngineCanContinue) exitWith {};
 */

params [["_actor",objNull,[objNull]],["_initial",false,[true]]];
if (isNull _actor || {!local _actor} || {!simulationEnabled _actor} || {isObjectHidden _actor}
    || {!([_actor] call CBE_fnc_CortexCombatEffective)}
    || {isPlayer _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!(missionNamespace getVariable ["CBE_AIPass_Danger_Enable",true])}
    || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};

private _disabled=_group getVariable ["CBE_AIPass_DisabledFeatures",[]];
if ("ALL" in _disabled || {"CBE_AIPass_Danger_Enable" in _disabled}
    || {_group getVariable ["CBE_AI_Exclude",false]}
    || {_group getVariable ["CBE_AIPass_Exclude",false]}
    || {_actor getVariable ["CBE_AI_Exclude",false]}
    || {_actor getVariable ["CBE_AIPass_Exclude",false]}
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {!isNull (remoteControlled _actor)}
    || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}) exitWith {false};

// A mounted provider can claim the platform without marking each occupant. Recheck
// only this actor's current parent so an already waiting crew response drains immediately.
// The neutral marker helper reads live declarations/runtime state; no crew/config scan.
private _parent=objectParent _actor;
if (!isNull _parent && {[_parent] call CBE_fnc_CompatibilityExternalControl}) exitWith {false};

private _response=_actor getVariable ["CBE_Danger_EngineResponse",[]];
// Waiting belongs to the operation and locality which classified this response. A new operation
// or owner must drain the old engine bridge before another recycle, without a squad scan.
if (!_initial && {count _response != 7
    || {(_response param [4,-1,[0]]) != (_group getVariable ["CBE_OperationGeneration",0])}
    || {(_response param [5,-1,[0]]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {(_response param [6,grpNull,[grpNull]]) != _group}}) exitWith {false};

// Native task ownership can change after the event was classified and while this finite response
// is waiting. Keep an already classified FORCED response bounded by its original deadline.
// Recheck only the affected actor here so a fresh boarding, action, treatment, rearm,
// join or fleeing task interrupts before another CBE stance or recycle. ATTACK deliberately remains
// eligible because the engine also uses it for ordinary autonomous combat.
if ((_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []) exitWith {false};
if (behaviour _actor == "CARELESS" || {!_initial && {fleeing _actor
    || {toUpperANSI (currentCommand _actor) in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}} && {(_response param [0,"",[""]]) != "FORCED"}}) exitWith {false};

// A carrier reservation can begin after this response was classified. Interrupt that old
// response, but let an already classified FORCED state keep its bounded wait instead of
// rapidly recycling the same event while the assistant walks to the assembly position.
private _carrierTask=_actor getVariable ["CBE_Cortex_ActorMove",[]];
if (!_initial && {isNull objectParent _actor} && {count _carrierTask == 3}
    && {(_carrierTask select 0) in ["STATIC_DEPLOY","STATIC_PACK","STATIC_SUPPORT"]}
    && {time < (_carrierTask select 2)}
    && {(_response param [0,"",[""]]) != "FORCED"}) exitWith {false};

// The full Zeus helper may inspect waypoints and update a timing cache. The danger FSM only needs
// the cheap interruption edge: a new curator token, a known live hold, or curator-owned waypoints.
private _token=_group getVariable ["CBE_AIPass_ZeusHold",[]];
private _newToken=_token isNotEqualTo []
    && {(_group getVariable ["CBE_AIPass_ZeusSeenToken",-1]) != (_token param [0,-1,[0]])};
!_newToken
    && {time >= (_group getVariable ["CBE_AIPass_ZeusLocalUntil",-1])}
    && {!(_group getVariable ["CBE_AIPass_ZeusWaypoints",false])}
