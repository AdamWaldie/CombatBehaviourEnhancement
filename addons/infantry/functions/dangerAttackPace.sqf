/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply a finite native ATTACK speed cap without owning destinations or fire.
 * Locality/authority: Actual actor/group owner. START uses current native knowledge and the
 * exact local engine-danger response; RELEASE may retire unchanged public proof after migration.
 * Repeat/JIP: No deadline renewal or replay. Pending release uses the existing group posture
 * cleanup queue for at most 30 seconds after original expiry. Changed native values survive.
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
        if (leader _group == _actor) then {_pace=_pace-1};
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
if (!(_proof isEqualType []) || {count _proof != 3}) exitWith {false};
private _context=_proof select 0;
if (!(_context isEqualType []) || {count _context != 5}
    || {_mode != "RELEASE" && {(_context select 0) != _group}} || {!((_context select 4) isEqualType 0)}
    || {!finite (_context select 4)}) exitWith {false};
if (_mode == "CHECK") exitWith {
    private _native=_proof select 2;
    if (!(_native isEqualType []) || {count _native != 3}) exitWith {false};
    serverTime < (_context select 4)
        && {(_context select 2) isEqualTo (_group getVariable ["CBE_OperationGeneration",0])}
        && {(_context select 3) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_actor getVariable ["CBE_Danger_EngineResponse",[]]) isEqualTo (_proof select 1)}
        && {currentCommand _actor == "ATTACK"}
        && {(getAttackTarget _actor) isEqualTo (_native select 0)}
        && {(expectedDestination _actor) isEqualTo (_native select 2)}
};
if (_mode != "RELEASE" || {serverTime >= (_context select 4)+30}) exitWith {false};
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
