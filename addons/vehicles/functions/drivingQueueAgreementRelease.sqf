/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires queue consent or an unacknowledged root request for one driving brain, without native commands.
 * Locality/authority: Machine holding the original private consent; local or trusted server call.
 * The captured vehicle-owner row must name this machine and both crew receipts must match the
 * retiring group, owner epoch and generation. Metadata cancellation remains valid after vehicle
 * locality is lost. The server authenticates this original participant; no native command follows.
 * Exact root request metadata retires with its consent, including on the old owner.
 * A request awaiting its first receipt also retires by its original participant context.
 * Silent broker refusal or stopping before VERIFY cannot strand initiation metadata.
 * No token is invented and no server release is sent for an unacknowledged request.
 * A successor private receipt or request is never overwritten.
 * Repeat/JIP: Missing, malformed or replaced receipts do nothing. No handlers, timer renewal,
 * movement, speed restoration, peer state writes or JIP replay. Old expiry timers remain harmless.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 expected group <GROUP, grpNull>;
 * 2 expected owner epoch <NUMBER, -1>; 3 expected driving generation <NUMBER, -1>.
 * Return: BOOL, exact local request/consent retired; existing tokens request server release. Not queue execution.
 * Current callers: DrivingOperationFinish before its current-brain native cleanup guard.
 * Example: [truck1,_group,_brain get "ownerEpoch",_brain get "generation"] call CBE_fnc_DrivingQueueAgreementRelease;
 */
params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]],
    ["_expectedEpoch",-1,[0]],["_expectedGeneration",-1,[0]]];
if (isNull _vehicle || {isNull _expectedGroup}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {!finite _expectedEpoch} || {_expectedEpoch < 0}
    || {!finite _expectedGeneration} || {_expectedGeneration < 0}) exitWith {false};
private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
if (!(_consent isEqualType createHashMap)) exitWith {false};
private _hasConsent=count _consent > 0;
private _request=_vehicle getVariable ["CBE_DrivingQueue_Request",[]];
if (!_hasConsent && {!(_request isEqualType []) || {count _request != 4}}) exitWith {false};
private _token=_consent getOrDefault ["token",""];
private _context=if (_hasConsent) then {_consent getOrDefault ["context",[]]} else {_request select 1};
if (_hasConsent && {!(_token isEqualType "") || {_token == ""}
    || {!((_consent getOrDefault ["phase",""]) in ["PENDING","AGREED"])}}) exitWith {false};
if (!(_context isEqualType []) || {count _context < 2} || {count _context > 4}) exitWith {false};
private _index=_context findIf {_x isEqualType [] && {count _x == 6} && {(_x select 0) isEqualTo _vehicle}};
if (_index < 0) exitWith {false};
private _row=_context select _index;
if ((_row select 1) != clientOwner) exitWith {false};
private _matches=true;
{
    private _actorReceipt=_row select _x;
    if (!(_actorReceipt isEqualType []) || {count _actorReceipt != 11}
        || {(_actorReceipt select 2) isNotEqualTo _expectedGroup}
        || {(_actorReceipt select 4) isNotEqualTo _expectedEpoch}
        || {(_actorReceipt select 5) isNotEqualTo _expectedGeneration}) exitWith {_matches=false};
} forEach [2,3];
if (!_matches) exitWith {false};
private _retired=false;
isNil {
    // This is a machine-private receipt, not a command on the migrated vehicle.
    // Original participant identity above, not current locality, owns cancellation.
    if (_hasConsent && {!isNull _vehicle} && {(_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isEqualTo _consent}) then {
        [_token,_consent getOrDefault ["expires",-1]] call CBE_fnc_DrivingQueueTokenClosed;
        _vehicle setVariable ["CBE_DrivingQueue_Consent",nil];
        if (_index == 0 && {
            (_vehicle getVariable ["CBE_DrivingQueue_Request",[]]) isEqualTo [
                _consent getOrDefault ["serial",-1],_context,
                _consent getOrDefault ["deadline",-1],_consent getOrDefault ["expires",-1]]
        }) then {_vehicle setVariable ["CBE_DrivingQueue_Request",nil]};
        _retired=true;
    };
    // A root may stop before VERIFY installs consent, including a BEGIN silently
    // refused by broker admission limits. Retire only its original private request.
    // Do not touch a receipt installed since capture or a successor request.
    if (!_hasConsent && {_index == 0} && {!isNull _vehicle}
        && {(_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) isEqualTo _consent}
        && {(_vehicle getVariable ["CBE_DrivingQueue_Request",[]]) isEqualTo _request}) then {
        _vehicle setVariable ["CBE_DrivingQueue_Request",nil];_retired=true;
    };
};
if (!_retired) exitWith {false};
if (_hasConsent) then {["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
true
