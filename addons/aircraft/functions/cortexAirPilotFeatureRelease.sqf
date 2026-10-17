/*
 * Author: WaldoTheWarfighter
 * Purpose: Make one finite release attempt for an unresolved lateral pilot feature snapshot.
 * Locality/authority: Original actor owner or explicit actor-local adoption; no live flight/task override.
 * Repeat/JIP: Schema2 stores its absolute release deadline in the same public receipt. The first
 * authorised release starts it once; owner adoption preserves it. No world scan or movement replay.
 * Unresolved records remain public; adoption never changes immutable issuer provenance.
 * Arguments: 0 actor <OBJECT, objNull>; 1 exact receipt <ARRAY, []>; 2 attempt <NUMBER, 0>;
 * 3 internal actor-local epoch <NUMBER, -1 captures current epoch>.
 * Return: BOOL, true only when restored now; refused or delayed attempts return false.
 * Current callers: CortexAirAttack cleanup, aircraft FSM Finished, and bounded CBA delayed callback.
 * Example: [pilot1,pilot1 getVariable ["WAIT_AirPilotFeatureReceipt",[]]] call WAIT_fnc_CortexAirPilotFeatureRelease;
 */
params [["_actor",objNull,[objNull]],["_receipt",[],[[]]],["_attempt",0,[0]],["_epoch",-1,[0]]];
if (isNull _actor || {!local _actor} || {count _receipt != 8}
    || {!finite _attempt} || {_attempt < 0} || {_attempt > 60} || {_attempt != floor _attempt}
    || {(_actor getVariable ["WAIT_AirPilotFeatureReceipt",[]]) isNotEqualTo _receipt}) exitWith {false};
private _liveEpoch=_actor getVariable ["WAIT_AirPilotFeatureLocalEpoch",0];
if (_epoch < 0) then {_epoch=_liveEpoch};
if (_epoch != _liveEpoch) exitWith {false};
_receipt params ["_schema","_originalActor","_aircraft","_group","_token","_issuer","_features","_releaseUntil"];
if (_schema isNotEqualTo 2 || {_originalActor isNotEqualTo _actor}
    || {!(_aircraft isEqualType objNull)} || {!(_group isEqualType grpNull)}
    || {!(_token isEqualType "")} || {_token == ""}
    || {_issuer isNotEqualTo clientOwner && {(_actor getVariable ["WAIT_AirPilotFeatureAdoption",[]]) isNotEqualTo _receipt}}
    || {!(_releaseUntil isEqualType 0)} || {!finite _releaseUntil}
    || {_releaseUntil != -1 && {_releaseUntil < 0}}
    || {!(_features isEqualType [])} || {count _features == 0} || {count _features > 3}
    || {_features findIf {!(_x in ["AUTOCOMBAT","TARGET","AUTOTARGET"])} >= 0}) exitWith {false};
// Release authority was established above from actual actor locality and exact issuer/adoption.
// Publish the clock with the snapshot itself; a successor cannot receive one without the other.
if (_releaseUntil == -1) then {
    private _previousReceipt=+_receipt;
    _releaseUntil=serverTime+60;
    _receipt=+_receipt;
    _receipt set [7,_releaseUntil];
    if ((_actor getVariable ["WAIT_AirPilotFeatureAdoption",[]]) isEqualTo _previousReceipt) then {
        _actor setVariable ["WAIT_AirPilotFeatureAdoption",+_receipt];
    };
    _actor setVariable ["WAIT_AirPilotFeatureReceipt",_receipt,true];
};
if (_attempt == 0 && {(_actor getVariable ["WAIT_AirPilotFeatureReleaseStarted",[]]) isEqualTo _receipt}) exitWith {false};
if (_attempt == 0) then {_actor setVariable ["WAIT_AirPilotFeatureReleaseStarted",+_receipt]};
if (serverTime >= _releaseUntil) exitWith {
    _actor setVariable ["WAIT_AirPilotFeatureReleaseResult",["UNRESOLVED",_token,serverTime],true];
    false
};
private _lease=if (isNull _aircraft) then {createHashMap} else {_aircraft getVariable ["WAIT_FlightLease",createHashMap]};
private _safe=alive _actor && {!isPlayer _actor} && {isNull remoteControlled _actor}
    && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {!isNull _aircraft} && {!isNull _group} && {group _actor == _group} && {vehicle _actor == _aircraft}
    && {([_actor] call WAIT_fnc_CortexExternalOwner) == ""}
    && {!([_actor] call WAIT_fnc_CompatibilityExternalControl)}
    && {!([_group,false,_actor] call WAIT_fnc_CortexExternalTakeover)}
    && {[_actor] call WAIT_fnc_CortexActorFireTaskAvailable};
if (count _lease == 0 && {_safe}) exitWith {
    {if !(_actor checkAIFeature _x) then {_actor enableAI _x}} forEach _features;
    _actor setVariable ["WAIT_AirPilotFeatureReceipt",nil,true];
    _actor setVariable ["WAIT_AirPilotFeatureReleaseResult",["RESTORED",_token,serverTime],true];
    _actor setVariable ["WAIT_AirPilotFeatureReleaseStarted",nil];
    _actor setVariable ["WAIT_AirPilotFeatureAdoption",nil];
    true
};
if (_attempt >= 60 || {!alive _actor}) exitWith {
    _actor setVariable ["WAIT_AirPilotFeatureReleaseResult",["UNRESOLVED",_token,serverTime],true];
    false
};
[{_this call WAIT_fnc_CortexAirPilotFeatureRelease},[_actor,+_receipt,_attempt+1,_epoch],1] call CBA_fnc_waitAndExecute;
false
