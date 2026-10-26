/*
 * Author: WaldoTheWarfighter
 * Target identity respects native ignoreTarget policy; no ignore setting is changed.
 * Native EnemyDetected selects personal knownByUnit witnesses within its rotating twelve-member
 * sample; group-only knowledge is an approximate fallback, never personal sight proof.
 * Purpose: Maintain the bounded group contact observer that complements the engine danger FSM.
 * Locality / Authority: Group-owner local. The engine FSM supplies immediate causes; this observer
 * retains only engine-confirmed target identity without revealing targets or issuing movement.
 * Repeat/JIP: Repeat-safe. Machine-local handler identifiers are removed on disable or locality
 * handover, and the new owner rebuilds the observer from fresh native contact events.
 * Existing bounded discovery also reconciles pending owner-local flight requests without reissuing them.
 * Arguments: 0: group <GROUP>, grpNull; 1: cleanup <BOOL>, false.
 * Return Value: Nothing.
 * Current callers: CBE discovery, locality reconciliation and shutdown.
 * Example: [_group] call CBE_fnc_DangerSetup;
 */

params [["_group",grpNull,[grpNull]],["_cleanup",false,[true]]];
if (isNull _group) exitWith {};
private _yieldToOwner=[_group] call CBE_fnc_CortexExternalTakeover;
private _enabled=!_cleanup && {local _group} && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {[_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,false,true] call CBE_fnc_CortexIsEligible}
    && {!_yieldToOwner};

// Retire handlers from pre-FSM packaged candidates. New builds never install these per-unit event
// handlers, but repeat-safe cleanup prevents a live development reload from keeping two intakes.
private _legacy=_group getVariable ["CBE_Danger_Handlers",[]];
if (_legacy isNotEqualTo []) then {
    {
        _x params ["_unit","_event","_handler"];
        if (!isNull _unit) then {_unit removeEventHandler [_event,_handler]};
    } forEach (_legacy param [1,[]]);
    _group setVariable ["CBE_Danger_Handlers",nil];
};

private _groupHandlers=_group getVariable ["CBE_Danger_GroupHandlers",[]];
if (!_enabled && {_groupHandlers isNotEqualTo []}) then {
    {_group removeEventHandler _x} forEach _groupHandlers;
    _group setVariable ["CBE_Danger_GroupHandlers",nil];
    _groupHandlers=[];
};
if (!_enabled) exitWith {
    [_group,-1,false,""] call CBE_fnc_DangerGroupHideStep;
    // Retire the finite cover lease before invalidating its generation. The helper removes only
    // CBE's exact actor move; on Zeus or specialist takeover it deliberately does not issue a
    // follow command or restore movement over the new owner.
    private _dangerCoverLease=_group getVariable ["CBE_Danger_CoverLease",[]];
    if (local _group && {count _dangerCoverLease >= 2}) then {
        [_group,_dangerCoverLease select 0,[],_dangerCoverLease select 1] call CBE_fnc_DangerCoverStep;
    } else {
        _group setVariable ["CBE_Danger_CoverLease",nil];
    };
    if (local _group && {!_yieldToOwner}) then {
        private _dangerActor=[_group] call CBE_fnc_CortexGroupAnchor;
        if (isNull _dangerActor) then {_dangerActor=leader _group};
        [_dangerActor,"RELEASE"] call CBE_fnc_DangerReact;
    } else {
        // A new owner has authority over posture. Discard the old proof of ownership without
        // writing behaviour or combat mode on this machine.
        _group setVariable ["CBE_Danger_ReactionLease",nil,true];
    };
    _group setVariable ["CBE_Danger_Generation",(_group getVariable ["CBE_Danger_Generation",0])+1];
    // The invalidated FSM will observe its generation mismatch and finish. Unpublish its handle
    // immediately so a fresh owner-local observation can start the replacement generation rather
    // than coalescing into a brain that has already lost authority.
    _group setVariable ["CBE_Danger_FSM",nil];
    _group setVariable ["CBE_Danger_FSMFailure",nil];
    _group setVariable ["CBE_Danger_Events",nil];
    _group setVariable ["CBE_Danger_EventCadence",nil];
    _group setVariable ["CBE_Danger_EngineStats",nil];
    _group setVariable ["CBE_Danger_ObservedContacts",nil];
    _group setVariable ["CBE_Danger_SpotterCursor",nil];
    _group setVariable ["CBE_Danger_LastAssessment",nil];
    _group setVariable ["CBE_Danger_WakeAfter",nil];
    _group setVariable ["CBE_Danger_SmokeLease",nil,true];
    _group setVariable ["CBE_Danger_SmokeAfter",nil];
    _group setVariable ["CBE_Danger_Response",nil,true];
    _group setVariable ["CBE_Danger_ResponseEvent",nil];
    _group setVariable ["CBE_Danger_Action",nil,true];
    _group setVariable ["CBE_Danger_Contact",nil,true];
    _group setVariable ["CBE_Danger_VehicleContext",nil,true];
    // Engine danger reactions are actor-local leases, not group posture. Release every local
    // actor through the exact-ownership helper before setup state is discarded. Merely erasing
    // EngineResponse left CBE's weak crouch/prone in place after a live setting disable because
    // the interrupted engine FSM no longer had enough published state to restore it reliably.
    // On Zeus/specialist takeover DangerEngineRelease clears proof without writing the stance.
    {
        if (local _x) then {[_x] call CBE_fnc_DangerEngineRelease; _x setVariable ["CBE_Danger_EventCadence",nil]};
    } forEach units _group;
};
// Use the same typed lifetime gate as the engine waiter. Discovery cannot bless an old
// epoch/operation merely because a returning owner still has the old local response variable.
// Joined actors carry their own old-group receipt; no separate public actor index is needed.
// Discovery already owns this bounded group footprint; no world scan or new worker is added.
private _paceActors=(units _group) select [0,64];
if (_paceActors isNotEqualTo []) then {
    {
        if (local _x && {(_x getVariable ["CBE_Danger_AttackPace",[]]) isNotEqualTo []}
            && {!( ["CHECK",_x] call CBE_fnc_DangerAttackPace)}) then {
            ["RELEASE",_x] call CBE_fnc_DangerAttackPace;
        };
        if (local _x && {(_x getVariable ["CBE_Cortex_NavalEgressMove",[]]) isNotEqualTo []}) then {
            ["REAP",_x] call CBE_fnc_CortexNavalEgressActor;
        };
        private _flightProof=_x getVariable ["CBE_Danger_FlightLease",[]];
        if (local _x && {_flightProof isEqualType []} && {count _flightProof == 8}
            && {(_flightProof select 1) isEqualType 0} && {finite (_flightProof select 1)}
            && {time >= (_flightProof select 1)
                || {(_x getVariable ["CBE_Danger_EngineResponse",[]]) isEqualTo []}}) then {
            ["RELEASE",_x] call CBE_fnc_DangerFlight;
        };
    } forEach (_paceActors select [0,64]);
};
if (_groupHandlers isNotEqualTo []) exitWith {};

private _handler=_group addEventHandler ["EnemyDetected",{
    params ["_observingGroup","_target"];
    if (isNull _observingGroup || {!local _observingGroup} || {isNull _target} || {!alive _target}
        || {_target isKindOf "Logic"} || {_target isKindOf "HeadlessClient_F"} || {captive _target} || {_target getVariable ["ace_captives_isSurrendering",false]}
        || {_target getVariable ["ace_captives_isHandcuffed",false]}) exitWith {};
    // EnemyDetected can report a man or a vehicle. A vehicle object has no useful direct `group`,
    // so compare the target object's actual side or armoured/air contacts lose their identity here.
    private _friendly=(side _observingGroup) getFriend (side _target) >= 0.6;
    if (_friendly) exitWith {};
    // Bound qualification itself, rather than filtering the entire group before truncation.
    // Rotate only on real native observations; no timer or retry is created for missed witnesses.
    private _members=units _observingGroup;
    private _memberCount=count _members;
    if (_memberCount == 0) exitWith {};
    private _sampleStart=(_observingGroup getVariable ["CBE_Danger_SpotterCursor",0]) mod _memberCount;
    private _sampleCount=_memberCount min 12;
    private _spotters=[];
    for "_sampleIndex" from 0 to (_sampleCount-1) do {
        private _member=_members select ((_sampleStart+_sampleIndex) mod _memberCount);
        if (local _member && {!isPlayer _member} && {[_member] call CBE_fnc_CortexCombatEffective}) then {
            _spotters pushBack _member;
        };
    };
    _observingGroup setVariable ["CBE_Danger_SpotterCursor",(_sampleStart+_sampleCount) mod _memberCount];
    // knowsAbout can be shared group knowledge. Prefer a real personal native witness,
    // sampled within the same twelve-member bound, rather than an unseeing leader.
    if (_observingGroup knowsAbout _target < 1) exitWith {};
    private _observer=objNull;
    private _fallback=objNull;
    private _personalSeen=-1;
    private _ignored=false;
    private _leader=leader _observingGroup;
    {
        private _knowledge=_x targetKnowledge _target;
        if (_knowledge param [7,false,[true]]) then {_ignored=true};
        if (_knowledge param [0,false,[true]]) then {
            if (isNull _fallback || {_x == _leader}) then {_fallback=_x};
            private _seenAt=(_knowledge param [2,-1,[0]]) max (_knowledge param [3,-1,[0]]);
            if (_knowledge param [1,false,[true]] && {finite _seenAt} && {_seenAt > _personalSeen}) then {
                _observer=_x;_personalSeen=_seenAt;
            };
        };
    } forEach _spotters;
    if (_ignored) exitWith {};
    // Shared native belief remains a valid approximate alert when no sampled personal
    // witness is available; it is not promoted into a new visual observation.
    if (isNull _observer) then {_observer=_fallback};
    if (isNull _observer) exitWith {};
    private _contacts=_observingGroup getVariable ["CBE_Danger_ObservedContacts",[]];
    _contacts=(_contacts select [((count _contacts)-8) max 0,8]) select {
        _x isEqualType [] && {count _x in [2,3]} && {(_x select 0) isEqualType objNull} && {(_x select 1) isEqualType 0}
            && {alive (_x select 0)} && {(_x select 1) > time}
    };
    private _contactIndex=_contacts findIf {(_x select 0) == _target};
    private _contact=[_target,time+10,_observer];
    if (_contactIndex >= 0) then {_contacts set [_contactIndex,_contact]} else {_contacts pushBack _contact};
    if (count _contacts > 8) then {_contacts=_contacts select ((count _contacts)-8)};
    _observingGroup setVariable ["CBE_Danger_ObservedContacts",_contacts];
    // EnemyDetected confirms identity but does not justify exact object coordinates. Use the same
    // native believed position consumed by CortexKnowledge. Submitting the observer position made
    // the tactical handoff treat the threat as co-located with the squad and produced sideways,
    // reversing or zero-length approaches even though the contact cache contained the right actor.
    private _dangerPosition=_observer getHideFrom _target;
    if (_dangerPosition isNotEqualTo [0,0,0]) then {
        [_observer,"DETECTED",_dangerPosition,_target] call CBE_fnc_DangerRequest;
    };
}];
_group setVariable ["CBE_Danger_GroupHandlers",[["EnemyDetected",_handler]]];
