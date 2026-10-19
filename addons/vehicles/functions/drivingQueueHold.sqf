/*
 * Author: WaldoTheWarfighter
 * Purpose: Consumes an explicitly committed queue agreement through the sole driving cap writer.
 * Locality/authority: Existing ordinary-driving callback, actual group/vehicle/crew owner only.
 * OBSERVE requests zero cap; APPLIED journals that the existing writer actually holds its cap.
 * READY requires the exact applied token/brain plus sampled linear/angular stillness for1s.
 * One retry after2s tolerates stale server motion replication; the existing callback services it.
 * Both reports retain the original expiry and all owner/cap/stillness checks.
 * No native movement/speed commands, reverse leg, worker or ownership transfer occur here.
 * Repeat/JIP: Private exact consent/commit and original expiry only. Duplicate application does
 * not reset dwell. Changed order/context/locality or expired consent grants no hold/replay.
 * Existing consent timers retire requests; existing driving release restores only its own cap.
 * Arguments: mode STRING OBSERVE/APPLIED, group GROUP grpNull, vehicle OBJECT objNull,
 * current driving brain HASHMAP empty.
 * Return: BOOL - valid committed hold requested/applied, never reverse or queue success.
 * Cost: OBSERVE revalidates at most4 participants through existing canonical context; APPLIED
 * uses the current cap receipt. No world query/ray, new timer, handler or movement scheduler.
 * Current callers: DrivingAssistStart before observation/commit and immediately after cap write.
 * Example: ["OBSERVE",_group,_vehicle,_brain] call CBE_fnc_DrivingQueueHold;
 */
params [["_mode","OBSERVE",[""]],["_group",grpNull,[grpNull]],
    ["_vehicle",objNull,[objNull]],["_brain",createHashMap,[createHashMap]]];
private _holding=false;
isNil {
    _holding=call {
if (!(_mode in ["OBSERVE","APPLIED"]) || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {isNull _group} || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
if (!(_consent isEqualType createHashMap) || {count _consent == 0}
    || {(_consent getOrDefault ["phase",""]) != "AGREED"}
    || {!((_consent getOrDefault ["committed",false]) isEqualTo true)}) exitWith {false};
private _token=_consent getOrDefault ["token",""];private _expires=_consent getOrDefault ["expires",-1];
if (!(_token isEqualType "") || {_token == ""} || {!(_expires isEqualType 0)} || {!finite _expires}
    || {serverTime >= _expires} || {[_token] call CBE_fnc_DrivingQueueTokenClosed}) exitWith {false};
private _epoch=_brain get "ownerEpoch";private _generation=_brain get "generation";
private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
private _capOwned=_state isEqualType [] && {(_state param [3,grpNull]) == _group} && {(_state param [0,-1]) == 0}
    && {abs getForcedSpeed _vehicle <= 0.001};
private _applied=[_token,_epoch,_generation];
if (_mode == "APPLIED") exitWith {
    if (!_capOwned) exitWith {false};
    if ((_consent getOrDefault ["holdApplied",[]]) isNotEqualTo _applied) then {
        private _updated=createHashMapFromArray (keys _consent apply {[_x,_consent get _x]});
        _updated set ["holdApplied",_applied];_updated set ["holdStillSince",-1];
        _updated set ["holdReadySent",false];
        _updated set ["holdReadyReports",0];_updated set ["holdReadyReportedAt",-1];
        _vehicle setVariable ["CBE_DrivingQueue_Consent",_updated];
    };
    true
};
if (!([_consent getOrDefault ["vehicles",[]],_consent getOrDefault ["roles",[]],
    _consent getOrDefault ["dependencies",[]],_consent getOrDefault ["context",[]],true]
    call CBE_fnc_DrivingQueueProposalCurrent)) exitWith {
    [_vehicle,_group,_epoch,_generation] call CBE_fnc_DrivingQueueAgreementRelease;false
};
// Once applied, a changed cap/lease is a takeover, not permission to reacquire it.
if ((_consent getOrDefault ["holdApplied",[]]) isEqualTo _applied && {!_capOwned}) exitWith {
    [_vehicle,_group,_epoch,_generation] call CBE_fnc_DrivingQueueAgreementRelease;false
};
private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
private _settled=_capOwned && {(_consent getOrDefault ["holdApplied",[]]) isEqualTo _applied}
    && {finite _linear} && {finite _angular} && {_linear < 0.1} && {_angular < 0.01};
private _since=_consent getOrDefault ["holdStillSince",-1];
private _ready=_consent getOrDefault ["holdReadySent",false];
if (!_settled && {_ready}) exitWith {
    [_vehicle,_group,_epoch,_generation] call CBE_fnc_DrivingQueueAgreementRelease;false
};
private _updated=createHashMapFromArray (keys _consent apply {[_x,_consent get _x]});
private _reportReady=false;
if (_settled) then {
    if (_since < 0) then {_since=serverTime;_updated set ["holdStillSince",_since]};
    private _reports=_consent getOrDefault ["holdReadyReports",[0,1] select _ready];
    private _reportedAt=_consent getOrDefault ["holdReadyReportedAt",_since+1];
    if (serverTime-_since >= 1 && {_reports < 2}
        && {!_ready || {serverTime-_reportedAt >= 2}}) then {
        _updated set ["holdReadySent",true];
        _updated set ["holdReadyReports",_reports+1];
        _updated set ["holdReadyReportedAt",serverTime];
        _reportReady=true;
    };
} else {_updated set ["holdStillSince",-1]};
if (_updated isNotEqualTo _consent) then {_vehicle setVariable ["CBE_DrivingQueue_Consent",_updated]};
// Publish before delivery; synchronous local delivery cannot resurrect a retired receipt.
if (_reportReady) then {["READY",[_token,_vehicle]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
true
    };
};
_holding
