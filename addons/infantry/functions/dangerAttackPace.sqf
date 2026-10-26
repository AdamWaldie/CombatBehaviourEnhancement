/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply a finite native ATTACK speed cap without owning destinations or fire.
 * Locality/authority: Actual actor/group owner. START uses current native knowledge and the
 * exact local engine-danger response; RELEASE may retire unchanged public proof after migration.
 * Personal native morale below zero shares the leader pace reduction; the two never stack.
 * CHECK requires the exact canonical speed-only settings lease and actual native speed,
 * not only matching response metadata. Unconfirmed/replaced/pending settings refuse.
 * The engine-condition path adds no squad scan, full settings eligibility pass or mutation.
 * Repeat/JIP: No deadline renewal or replay. Pending release uses the existing group posture
 * cleanup queue for at most 30 seconds after original expiry. Changed native values survive.
 * After that window, only exact old speed-only metadata with an actual changed native value
 * can retire without a command. Missing/foreign/still-applied settings remain unresolved.
 * Arguments: 0 mode STRING START/CHECK/RELEASE; 1 actor OBJECT objNull;
 * 2 cleanupRunning BOOL false, true only inside the shared retirement callback.
 * Return: BOOL, admission/current proof for START/CHECK, fully retired proof for RELEASE.
 * Current callers: DangerEngineAct/CanContinue/Release, DangerPostureStep, DangerSetup, OperationStart.
 * Example: ["RELEASE",soldier1] call CBE_fnc_DangerAttackPace;
 */
params [["_mode","CHECK",[""]],["_actor",objNull,[objNull]],["_cleanupRunning",false,[true]]];
if (isNull _actor || {!local _actor}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}) exitWith {false};
private _proof=_actor getVariable ["CBE_Danger_AttackPace",[]];
if (_mode == "START" && {_proof isEqualTo []}) exitWith {
    private _response=_actor getVariable ["CBE_Danger_EngineResponse",[]];
    if (count _response != 7 || {!((_response select 0) in ["ENGAGE","IMMEDIATE"])}
        || {time >= (_response select 3)} || {currentCommand _actor != "ATTACK"}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
        || {(_actor getVariable ["CBE_ActorSettings",[]]) isNotEqualTo []}
        || {!([_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible)}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
    private _target=getAttackTarget _actor;
    if (isNull _target || {!alive _target} || {captive _target}
        || {_target isKindOf "SuppressTarget"}
        || {(side _group) getFriend (side _target) >= 0.6}) exitWith {false};
    private _knowledge=_actor targetKnowledge _target;
    if (!(_knowledge param [0,false,[true]]) || {_knowledge param [7,false,[true]]}) exitWith {false};
    private _belief=_actor getHideFrom _target;
    if (_belief isEqualTo [0,0,0]) exitWith {false};
    private _wanted=if (behaviour _actor == "STEALTH") then {1} else {
        private _pace=[4,3] select (getSuppression _actor > 0);
        if (leader _group == _actor || {morale _actor < 0}) then {_pace=_pace-1};
        if (_actor distance2D _belief < 5) then {_pace=_pace-1};
        _pace max 1
    };
    private _context=[_group,format ["DANGER_ATTACK:%1:%2:%3",clientOwner,netId _actor,_response select 2],
        _response select 4,_response select 5,serverTime+((_response select 3)-time)];
    _actor setVariable ["CBE_Danger_AttackPace",[_context,+_response,[_target,currentCommand _actor,expectedDestination _actor]],true];
    private _result=["APPLY",_actor,_context,createHashMapFromArray [["SPEED",_wanted]],"DANGER_ATTACK"] call CBE_fnc_ActorSettings;
    if (!(_result in ["APPLIED","PENDING"])) exitWith {_actor setVariable ["CBE_Danger_AttackPace",nil,true];false};
    true
};
if (_proof isEqualTo []) exitWith {_mode == "RELEASE"};
if (!(_proof isEqualType []) || {count _proof != 3}
    || {[0,1,2] findIf {isNil {_proof select _x}} >= 0}) exitWith {false};
private _context=_proof select 0;
if (!(_context isEqualType []) || {count _context != 5}
    || {[0,1,2,3,4] findIf {isNil {_context select _x}} >= 0}
    || {!((_context select 0) isEqualType grpNull)}
    || {!((_context select 1) isEqualType "")} || {(_context select 1) == ""} || {count (_context select 1) > 256}
    || {[2,3,4] findIf {!((_context select _x) isEqualType 0) || {!finite (_context select _x)} || {(_context select _x) < 0}} >= 0}
    || {_mode != "RELEASE" && {(_context select 0) != _group}}) exitWith {false};
if (_mode == "CHECK") exitWith {
    private _native=_proof select 2;
    if (!(_native isEqualType []) || {count _native != 3}
        || {[0,1,2] findIf {isNil {_native select _x}} >= 0}) exitWith {false};
    if (serverTime >= (_context select 4)
        || {(_context select 2) isNotEqualTo (_group getVariable ["CBE_OperationGeneration",0])}
        || {(_context select 3) isNotEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {(_actor getVariable ["CBE_Danger_EngineResponse",[]]) isNotEqualTo (_proof select 1)}
        || {currentCommand _actor != "ATTACK"}) exitWith {false};
    // This path is evaluated by the engine FSM condition. Confirm the single SPEED
    // property directly; ActorSettings CHECK would repeat broad eligibility work here.
    private _lease=_actor getVariable ["CBE_ActorSettings",[]];
    if (!(_lease isEqualType []) || {count _lease != 3}
        || {[0,1,2] findIf {isNil {_lease select _x}} >= 0}
        || {(_lease select 0) isNotEqualTo _context} || {(_lease select 2) isNotEqualTo 0}) exitWith {false};
    private _owned=_lease select 1;
    if (!(_owned isEqualType createHashMap) || {count _owned != 1} || {!("SPEED" in _owned)}) exitWith {false};
    private _speedPair=_owned get "SPEED";
    if (!(_speedPair isEqualType []) || {count _speedPair != 2}
        || {_speedPair findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} >= 0}
        || {!((_speedPair select 0) == -1 || {(_speedPair select 0) >= 0})}
        || {(_speedPair select 1) < 0}) exitWith {false};
    private _nativeSpeed=getForcedSpeed _actor;
    finite _nativeSpeed && {abs (_nativeSpeed-(_speedPair select 1)) <= 0.00001}
        && {(getAttackTarget _actor) isEqualTo (_native select 0)}
        && {(expectedDestination _actor) isEqualTo (_native select 2)}
};
if (_mode == "RELEASE" && {serverTime >= (_context select 4)+30}) exitWith {
    // The native restoration window is closed. An actual changed value can retire
    // only this exact old speed-only bookkeeping; never issue a late native restore.
    private _retired=false;
    isNil {
        if (!local _actor || {!local _group} || {group _actor != _group}
            || {(_actor getVariable ["CBE_Danger_AttackPace",[]]) isNotEqualTo _proof}) exitWith {};
        private _lease=_actor getVariable ["CBE_ActorSettings",[]];
        if (!(_lease isEqualType []) || {count _lease != 3}
            || {[0,1,2] findIf {isNil {_lease select _x}} >= 0}
            || {(_lease select 0) isNotEqualTo _context}
            || {!((_lease select 2) isEqualType 0)} || {!finite (_lease select 2)} || {(_lease select 2) < 0}) exitWith {};
        private _owned=_lease select 1;
        if (!(_owned isEqualType createHashMap) || {count _owned != 1} || {!("SPEED" in _owned)}) exitWith {};
        private _pair=_owned get "SPEED";
        if (!(_pair isEqualType []) || {count _pair != 2}
            || {_pair findIf {isNil "_x" || {!(_x isEqualType 0)} || {!finite _x}} >= 0}
            || {!((_pair select 0) == -1 || {(_pair select 0) >= 0})} || {(_pair select 1) < 0}) exitWith {};
        private _nativeSpeed=getForcedSpeed _actor;
        if (!finite _nativeSpeed || {abs (_nativeSpeed-(_pair select 1)) <= 0.00001}) exitWith {};
        _actor setVariable ["CBE_ActorSettings",nil,true];
        _actor setVariable ["CBE_Danger_AttackPace",nil,true];
        _retired=true;
    };
    _retired
};
if (_mode != "RELEASE") exitWith {false};
// RELEASE does not adopt/replay speed. The actual new owner may remove only the old exact cap.
private _releaseContext=+_context;
if ((_context select 0) == _group) then {
    _releaseContext set [3,_group getVariable ["CBE_AIPass_Epoch",0]];
};
private _result=["RELEASE",_actor,_releaseContext,createHashMap,"DANGER_ATTACK"] call CBE_fnc_ActorSettings;
if (_result in ["RELEASED","ABSENT"]) exitWith {
    _actor setVariable ["CBE_Danger_AttackPace",nil,true];
    true
};
private _pending=_group getVariable ["CBE_Danger_StancePendingActors",[]];
if (count _pending < 64 || {_actor in _pending}) then {
    _pending pushBackUnique _actor;_group setVariable ["CBE_Danger_StancePendingActors",_pending];
    if (!_cleanupRunning) then {
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    [CBE_fnc_DangerPostureStep,createHashMapFromArray [["group",_group],["ownerEpoch",_epoch],
        ["generation",_epoch],["subsystem","POSTURE_CLEANUP"]],0.25,"DANGER_POSTURE"] call CBE_fnc_CortexQueueJob;
    [] call CBE_fnc_SchedulerReconcile;
    };
};
false
