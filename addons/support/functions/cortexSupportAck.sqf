/*
 * Author: WaldoTheWarfighter
 * Records only the current helper owner response for the current reservation token.
 * Locality/authority: server owns reservations; current group owners validate and execute orders.
 * Repeat/JIP: unique tokens, shared deadlines and owner acknowledgements retire stale assignments.
 * Arguments: 0: helper <GROUP>, grpNull; 1: token <STRING>, empty; 2: accepted <BOOL>, false; 3: exact lease snapshot <ARRAY>, [].
 * 4: reply owner <NUMBER>, default -1; HC callers supply clientOwner.
 * Return Value: Nothing.
 * Current callers: SupportApply.
 * Example: [_group, _token, true, _lease, clientOwner] remoteExecCall ["WAIT_fnc_CortexSupportAck", 2];
 */
params [["_group",grpNull,[grpNull]],["_token","",[""]],["_accepted",false,[true]],["_snapshot",[],[[]]],["_replyOwner",-1,[0]]];
if (!isServer || {isNull _group} || {([_replyOwner,groupOwner _group] call WAIT_fnc_HeadlessResolveSender) < 0}) exitWith {};
private _lease = _group getVariable ["WAIT_AIPass_SupportLease",[]];
if (_lease isEqualTo [] || {(_lease select 0) != _token} || {_lease isNotEqualTo _snapshot}) exitWith {};
private _requests = missionNamespace getVariable ["WAIT_AIPass_SupportRequests",createHashMap];
private _job = _requests getOrDefault [netId (_lease select 1),createHashMap];
if (count _job == 0) exitWith {};
private _leases = _job get "leases";
private _index = _leases findIf {(_x select 0) == _group && {(_x select 1) == _token}};
if (_index >= 0) then {
    (_leases select _index) set [4,["REJECTED","ACCEPTED"] select _accepted];
    // Prepared contact peers own no movement yet. Publish authenticated eligibility separately
    // from SupportStatus, which describes an operation that has actually started on its owner.
    private _prepared=_accepted && {(_lease select 5) isEqualTo []}
        && {[_group,"WAIT_AIPass_CoordinatedAssault_Enable",true] call WAIT_fnc_CortexFeatureEnabled}
        && {[_lease select 1,"WAIT_AIPass_CoordinatedAssault_Enable",true] call WAIT_fnc_CortexFeatureEnabled};
    private _eligibility=if (_prepared) then {[_token,groupOwner _group,_lease select 2]} else {[]};
    if (_prepared && {_eligibility isNotEqualTo (_group getVariable ["WAIT_Cortex_SupportEligibility",[]])}) then {
        // Evidence only: the receipt remains after execution consumes eligibility, allowing
        // a slower audit/JIP observer to see the genuine authenticated preparation transition.
        _group setVariable ["WAIT_Cortex_SupportPreparedReceipt",[_token,groupOwner _group,serverTime,_lease select 2],true];
    };
    _group setVariable ["WAIT_Cortex_SupportEligibility",if (_prepared) then {_eligibility} else {nil},true];
};
