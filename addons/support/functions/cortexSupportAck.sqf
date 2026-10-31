/*
 * Author: WaldoTheWarfighter
 * Records only the current helper owner response for the current reservation token.
 * The exact seven-field snapshot includes the request original response radius; altered
 * policy cannot be acknowledged against the server request.
 * Locality/authority: server owns reservations; current group owners validate and execute orders.
 * Repeat/JIP: unique tokens, shared deadlines and owner acknowledgements retire stale assignments.
 * Arguments: 0: helper <GROUP>, grpNull; 1: token <STRING>, empty; 2: accepted <BOOL>, false; 3: exact lease snapshot <ARRAY>, [].
 * 4: reply owner <NUMBER>, default -1; HC callers supply clientOwner.
 * 5: optional capacity <ARRAY,[]> [2,exact COVER role,owner epoch,observed server time,
 * expiry,fit count,main-ammunition count,parent generation]. Stored only in the server job; cannot renew a lease.
 * Capacity replies authenticate through the same sender and exact lease checks, then require
 * the current role and published parent identity, accepted token and at most six seconds of freshness.
 * The owner epoch is private on each machine: only local groups compare it directly. Remote
 * reports bind to the published operation epoch/generation/owner/token/original expiry instead.
 * Return Value: Nothing.
 * Current callers: SupportApply and SupportMaintain owner capacity observation.
 * Example: [_group, _token, true, _lease, clientOwner] remoteExecCall ["CBE_fnc_CortexSupportAck", 2];
 */
params [["_group",grpNull,[grpNull]],["_token","",[""]],["_accepted",false,[true]],["_snapshot",[],[[]]],["_replyOwner",-1,[0]],["_capacity",[],[[]]]];
if (!isServer || {isNull _group} || {([_replyOwner,groupOwner _group] call CBE_fnc_HeadlessResolveSender) < 0}) exitWith {};
private _lease = _group getVariable ["CBE_AIPass_SupportLease",[]];
if (count _lease != 7 || {(_lease select 0) != _token} || {_lease isNotEqualTo _snapshot}) exitWith {};
private _requests = missionNamespace getVariable ["CBE_AIPass_SupportRequests",createHashMap];
private _job = _requests getOrDefault [netId (_lease select 1),createHashMap];
if (count _job == 0 || {(_lease select 6) isNotEqualTo (_job get "discoveryRadius")}) exitWith {};
// Capacity is an authenticated owner observation, not another reservation acceptance.
if (_capacity isNotEqualTo []) exitWith {
    if (!_accepted || {count _capacity != 8} || {(_capacity select 0) isNotEqualTo 2}
        || {!((_capacity select 1) isEqualType [])}
        || {[2,3,4,5,6,7] findIf {!((_capacity select _x) isEqualType 0) || {!finite (_capacity select _x)}} >= 0}) exitWith {};
    _capacity params ["","_role","_epoch","_observed","_until","_fit","_armed","_generation"];
    private _parent=_group getVariable ["CBE_Operation",createHashMap];
    if !(_parent isEqualType createHashMap) exitWith {};
    private _leases=_job get "leases";
    if (count _role != 5 || {(_role select 0) isNotEqualTo _token} || {(_role select 2) != "COVER"}
        || {(_group getVariable ["CBE_Cortex_SupportRole",[]]) isNotEqualTo _role}
        || {_epoch < 1} || {_epoch != floor _epoch} || {local _group && {_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])}}
        || {_generation < 0} || {_generation != floor _generation}
        || {_generation != (_group getVariable ["CBE_OperationGeneration",-1])}
        || {_generation != (_parent getOrDefault ["generation",-1])}
        || {_epoch != (_parent getOrDefault ["ownerEpoch",-1])}
        || {(_parent getOrDefault ["supportOwner",-1]) != groupOwner _group}
        || {(_parent getOrDefault ["supportToken",""]) != _token}
        || {(_parent getOrDefault ["supportExpiry",-1]) != (_lease select 2)}
        || {(_parent getOrDefault ["intent",""]) != "COORDINATED_ASSAULT"}
        || {(_parent getOrDefault ["phase",""]) == "CANCELLED"}
        || {_observed > serverTime+0.25} || {_observed < serverTime-6}
        || {_until <= serverTime} || {_until <= _observed} || {_until > _observed+6}
        || {serverTime >= (_lease select 2)} || {serverTime >= (_job get "expiry")}
        || {_fit < 0} || {_fit > 64} || {_fit != floor _fit}
        || {_armed < 0} || {_armed > _fit} || {_armed != floor _armed}
        || {_leases findIf {(_x select 0) == _group && {(_x select 1) == _token} && {(_x select 4) == "ACCEPTED"}} < 0}) exitWith {};
    private _capacities=_job getOrDefault ["capacityByToken",createHashMap];
    private _old=_capacities getOrDefault [_token,[]];
    if (count _old == 3 && {(_old select 1) == groupOwner _group}
        && {((_old select 2) select 3) > _observed}) exitWith {};
    private _receipt=+_capacity;
    _receipt set [4,_until min (serverTime+6) min (_lease select 2) min (_job get "expiry")];
    _capacities set [_token,[_group,groupOwner _group,_receipt]];
    _job set ["capacityByToken",_capacities];
};
// A delayed owner reply may arrive after either finite deadline. Keep a matching
// rejection valid for cleanup, but never publish fresh eligibility for expired work.
_accepted=_accepted && {serverTime < (_lease select 2)}
    && {serverTime < (_job get "expiry")};
private _leases = _job get "leases";
private _index = _leases findIf {(_x select 0) == _group && {(_x select 1) == _token}};
if (_index >= 0) then {
    if (!_accepted) then {
        private _capacities=_job getOrDefault ["capacityByToken",createHashMap];
        _capacities deleteAt _token;
    };
    (_leases select _index) set [4,["REJECTED","ACCEPTED"] select _accepted];
    // Prepared contact peers own no movement yet. Publish authenticated eligibility separately
    // from SupportStatus, which describes an operation that has actually started on its owner.
    private _prepared=_accepted && {(_lease select 5) isEqualTo []}
        && {[_group,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled}
        && {[_lease select 1,"CBE_AIPass_CoordinatedAssault_Enable",true] call CBE_fnc_CortexFeatureEnabled};
    private _eligibility=if (_prepared) then {[_token,groupOwner _group,_lease select 2]} else {[]};
    if (_prepared && {_eligibility isNotEqualTo (_group getVariable ["CBE_Cortex_SupportEligibility",[]])}) then {
        // Evidence only: the receipt remains after execution consumes eligibility, allowing
        // a slower audit/JIP observer to see the genuine authenticated preparation transition.
        _group setVariable ["CBE_Cortex_SupportPreparedReceipt",[_token,groupOwner _group,serverTime,_lease select 2],true];
    };
    _group setVariable ["CBE_Cortex_SupportEligibility",if (_prepared) then {_eligibility} else {nil},true];
};
