/*
 * Author: WaldoTheWarfighter
 * Purpose: Submits or cancels distinct finite queue-role consent; does not acquire movement.
 * Locality/authority: Local initiating vehicle/group owner only; server and every actual participant owner independently verify. Never remote.
 * Local request checks/publication/send share one bounded unscheduled section with no world query.
 * Repeat/JIP: One attempt per canonical roster/roles/native topology and original retry deadline; no renewal, movement or JIP replay.
 * Arguments: 0 proposal HASHMAP empty;1 cancel BOOL false. Proposal from DrivingQueueProposal.
 * Return: BOOL submitted/cancelled, not agreed or physically cleared.
 * Current callers: DrivingQueueAutoStep (default-off initiation), explicit local protocol callers
 * and trusted local cancellation. Physical execution remains unverified.
 * Example: [_proposal] call CBE_fnc_DrivingQueueAgreementRequest;
 */
params [["_proposal",createHashMap,[createHashMap]],["_cancel",false,[true]]];
private _submitted=false;
isNil {
    _submitted=call {
if (isRemoteExecuted) exitWith {false};
private _vehicles=_proposal getOrDefault ["vehicles",[]];
if (!(_vehicles isEqualType []) || {count _vehicles < 2} || {count _vehicles > 4}) exitWith {false};
private _vehicle=_vehicles select 0;
if (!(_vehicle isEqualType objNull) || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
if (_cancel) exitWith {
    private _request=_vehicle getVariable ["CBE_DrivingQueue_Request",[]];
    private _context=_proposal getOrDefault ["context",[]];
    private _serial=_proposal getOrDefault ["requestSerial",-1];
    if (count _request != 4 || {(_request select 0) != _serial}
        || {(_request select 1) isNotEqualTo _context}) exitWith {false};
    private _receipt=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    _vehicle setVariable ["CBE_DrivingQueue_Request",nil];
    if ((_receipt getOrDefault ["serial",-2]) == _serial
        && {(_receipt getOrDefault ["context",[]]) isEqualTo _context}) then {
        [_receipt get "token",_receipt getOrDefault ["expires",-1]] call CBE_fnc_DrivingQueueTokenClosed;
        _vehicle setVariable ["CBE_DrivingQueue_Consent",nil];
        ["RELEASE",[_receipt get "token"]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
    };
    true
};
private _roles=_proposal getOrDefault ["roles",[]];private _dependencies=_proposal getOrDefault ["dependencies",[]];
private _context=_proposal getOrDefault ["context",[]];private _deadline=_proposal getOrDefault ["deadline",-1];
private _retryDeadline=_proposal getOrDefault ["retryDeadline",-1];
private _at=_proposal getOrDefault ["observedAt",-1];
if ((_proposal getOrDefault ["status",""]) != "PROPOSAL"
    || {!(_roles isEqualType [])} || {!(_dependencies isEqualType [])} || {!(_context isEqualType [])}
    || {!(_at isEqualType 0)} || {!finite _at} || {_at > serverTime} || {serverTime-_at > 2}
    || {!(_deadline isEqualType 0)} || {!finite _deadline} || {serverTime >= _deadline} || {_deadline > serverTime+2}
    || {!(_retryDeadline isEqualType 0)} || {!finite _retryDeadline} || {_retryDeadline <= _deadline}
    || {!([_vehicles,_roles,_dependencies,_context,true] call CBE_fnc_DrivingQueueProposalCurrent)}) exitWith {false};
private _key=[_vehicles,_roles,_dependencies,_context apply {
    [_x select 0,_x select 1,(_x select 2) select [0,8],(_x select 3) select [0,8],
        (_x select 2) select 10,(_x select 3) select 10]
},_retryDeadline];
private _old=_vehicle getVariable ["CBE_DrivingQueue_Attempt",[]];
if (_old isEqualTo _key) exitWith {false};
private _serial=(_vehicle getVariable ["CBE_DrivingQueue_Serial",0])+1;
private _expires=(_at+90) min _retryDeadline;
if (_expires <= _deadline) exitWith {false};
_vehicle setVariable ["CBE_DrivingQueue_Attempt",_key];
_vehicle setVariable ["CBE_DrivingQueue_Serial",_serial];
_vehicle setVariable ["CBE_DrivingQueue_Request",[_serial,_context,_deadline,_expires]];
_proposal set ["requestSerial",_serial];
["BEGIN",[_serial,_vehicles,_roles,_dependencies,_context,_deadline,_expires]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
true
    };
    false
};
_submitted
