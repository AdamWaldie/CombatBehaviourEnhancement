/*
 * Author: WaldoTheWarfighter
 * Purpose: Finite release-only restoration of an exact landing aircraft feature snapshot.
 * Locality/authority: Current aircraft owner, local or trusted server call. Exact public release,
 * snapshot and retired control revision must match. Other flight/player/Zeus/external control defers.
 * Repeat/JIP: One coalesced chain per receipt/owner/tracker epoch, at most60 retries and original
 * absolute60s deadline. Actual locality/tracker adoption may offer the same receipt, never renew it.
 * Expiry retains UNRESOLVED provenance. No old flight, waypoint, velocity or height command is replayed.
 * Arguments:0 aircraft <OBJECT,objNull>;1 release <ARRAY,[]> [snapshot ARRAY,deadline NUMBER];
 * 2 internal attempt <NUMBER,0>;3 internal tracker epoch <NUMBER,-1 captures current>.
 * Return: BOOL, true only when this exact aircraft feature receipt was consumed now.
 * Current callers: ImprovedHelicopterLandingRestoreLocal/Step/Init and finite CBA callback.
 * Example: [_heli,_heli getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]] call CBE_fnc_ImprovedHelicopterLandingFeatureReleaseLocal;
 */
params [["_helicopter",objNull,[objNull]],["_release",[],[[]]],
    ["_attempt",0,[0]],["_epoch",-1,[0]]];
if (isNull _helicopter || {!local _helicopter} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {count _release != 2} || {!finite _attempt} || {_attempt < 0} || {_attempt > 60}
    || {_attempt != floor _attempt}) exitWith {false};
_release params ["_snapshot","_until"];
if (!(_snapshot isEqualType []) || {count _snapshot != 6}
    || {!(_until isEqualType 0)} || {!finite _until} || {_until < 0}
    || {[0,1] findIf {!((_snapshot select _x) isEqualType 0) || {!finite (_snapshot select _x)}} >= 0}
    || {(_snapshot select 0) < 0} || {!((_snapshot select 2) isEqualType objNull)}
    || {[3,4,5] findIf {!((_snapshot select _x) isEqualType true)} >= 0}) exitWith {false};
private _liveEpoch=_helicopter getVariable ["CBE_ImprovedHelicopterLanding_TrackerGenerationLocal",0];
if (_epoch < 0) then {_epoch=_liveEpoch};
private _current={
    local _helicopter && {_epoch == (_helicopter getVariable ["CBE_ImprovedHelicopterLanding_TrackerGenerationLocal",0])}
        && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",[]]) isEqualTo _release}
        && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",[]]) isEqualTo _snapshot}
        && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_ControlRevision",-1]) == (_snapshot select 0)+1}
        && {!(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_Active",false])}
};
if !(call _current) exitWith {false};
private _unresolved={
    if !(call _current) exitWith {false};

    private _result=["UNRESOLVED",_snapshot select 0,_snapshot select 1,_until];
    if (((_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseResult",[]]) select [0,4]) isNotEqualTo _result) then {
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseResult",_result+[serverTime],true];
        diag_log format ["[CBE AI LANDING] Feature release unresolved helicopter=%1 revision=%2 issuer=%3 deadline=%4",
            netId _helicopter,_snapshot select 0,_snapshot select 1,_until];
    };
    // Keep the exact work key too: repeated lookup cannot restart a spent chain.
    false
};
// A receipt/worker marker is not proof that its old delayed callback will still arrive.
// Any actual observation of the original expired deadline retires status before coalescing.
if (serverTime >= _until || {!alive _helicopter}) exitWith {call _unresolved};
private _key=[+_release,clientOwner,_epoch];
if (_attempt == 0 && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseWork",[]]) isEqualTo _key}) exitWith {false};
if (_attempt > 0 && {(_helicopter getVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseWork",[]]) isNotEqualTo _key}) exitWith {false};
_helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseWork",_key];
private _restored=false;
isNil {
    private _lease=_helicopter getVariable ["CBE_FlightLease",createHashMap];
    private _pilot=currentPilot _helicopter;
    private _controllerFree=isNull _pilot || {!isPlayer _pilot && {isNull remoteControlled _pilot}
        && {!([group _pilot] call CBE_fnc_CortexExternalTakeover)}};
    if (call _current && {serverTime < _until} && {alive _helicopter}
        && {_lease isEqualType createHashMap} && {count _lease == 0} && {_controllerFree}) then {
        if (!(_helicopter checkAIFeature "MOVE") && {_snapshot select 3}) then {_helicopter enableAI "MOVE"};
        if ((_helicopter checkAIFeature "PATH") isEqualTo (_snapshot select 5) && {_snapshot select 4}) then {
            _helicopter enableAI "PATH";
        };
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureSnapshot",nil,true];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureRelease",nil,true];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseWork",nil];
        _helicopter setVariable ["CBE_ImprovedHelicopterLanding_FeatureReleaseResult",
            ["RELEASED",_snapshot select 0,_snapshot select 1,_until,serverTime],true];
        _restored=true;
    };
};
if (_restored) exitWith {true};
if (!(call _current)) exitWith {false};
if (_attempt >= 60) exitWith {call _unresolved};
[{_this call CBE_fnc_ImprovedHelicopterLandingFeatureReleaseLocal},
    [_helicopter,+_release,_attempt+1,_epoch],1] call CBA_fnc_waitAndExecute;
false
