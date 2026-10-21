/*
 * Author: WaldoTheWarfighter
 * Purpose: Offers one opt-in head-on/crossing queue negotiation from an existing persistent jam.
 * Locality/authority: Existing ordinary-driving callback on the actual vehicle/group owner.
 * This helper sends consent/commit requests only; the server and every owner still validate.
 * It never writes speed or movement and creates no worker, timer or route.
 * Repeat/JIP: One attempt per original traffic-retry episode, including refusal. The public
 * jam journal keeps consumption across owner adoption; expiry/progress/order rules are unchanged.
 * Pending handshake suppresses competing route refresh. At most two COMMIT requests, two seconds
 * apart, use the original consent expiry. Disabling cancels only an uncommitted matching request;
 * already committed work retains its original finite safety and cleanup path.
 * Arguments: 0 group GROUP grpNull; 1 vehicle OBJECT objNull; 2 driving brain HASHMAP empty;
 * 3 mutable original jam journal HASHMAP empty; 4 limiting peer OBJECT objNull;
 * 5 uninterrupted eligible jam BOOL false. Caller journals mutations through its current lease.
 * Return: ARRAY [BOOL competing refresh deferred, BOOL jam journal changed]; not movement success.
 * Current callers: DrivingAssistStart inside the existing finite traffic-retry transaction.
 * Example: private _result=[_group,_vehicle,_brain,_jam,_peer,true] call CBE_fnc_DrivingQueueAutoStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_jam",createHashMap,[createHashMap]],
    ["_peer",objNull,[objNull]],["_continuous",false,[true]]];
if (isRemoteExecuted || {isNull _group} || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {count _jam == 0} || {(_jam getOrDefault ["group",grpNull]) != _group}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}
    || {(_jam getOrDefault ["route",[]]) isNotEqualTo (_brain getOrDefault ["route",[]])}) exitWith {[false,false]};
if (((_brain getOrDefault ["route",[]]) param [0,"",[""]]) == "NATIVE_MOVE") exitWith {[false,false]};
private _executor=_group getVariable ["CBE_Driving_FSM",-1];
if (!(_executor isEqualType 0) || {!finite _executor} || {_executor < 0} || {completedFSM _executor}) exitWith {[false,false]};
private _enabled=[_group,"CBE_AIPass_DrivingAssist_Queue_Enable",false,_vehicle] call CBE_fnc_CortexFeatureEnabled;
private _proposal=_jam getOrDefault ["queueAutoProposal",createHashMap];
if ((_jam getOrDefault ["queueAutoFinished",false]) isEqualTo true) exitWith {[false,false]};
private _until=_jam getOrDefault ["deadline",-1];
if (!(_until isEqualType 0) || {!finite _until}) exitWith {[false,false]};
if (count _proposal > 0) exitWith {
    private _serial=_proposal getOrDefault ["requestSerial",-1];
    private _context=_proposal getOrDefault ["context",[]];
    private _consent=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    private _ours=(_consent getOrDefault ["serial",-2]) == _serial
        && {(_consent getOrDefault ["context",[]]) isEqualTo _context};
    // A new initiation setting cannot cancel already committed native work.
    // A delayed retirement marker also cannot extend this helper's busy lifetime.
    if (_ours && {(_consent getOrDefault ["committed",false]) isEqualTo true}) exitWith {
        private _expires=_consent getOrDefault ["expires",-1];
        if (_expires isEqualType 0 && {finite _expires} && {serverTime < _expires}
            && {serverTime < _until}) exitWith {[true,false]};
        _jam set ["queueAutoFinished",true];
        [false,true]
    };
    private _abandon={
        [_proposal,true] call CBE_fnc_DrivingQueueAgreementRequest;
        _jam set ["queueAutoFinished",true];
        [false,true]
    };
    if (!_enabled || {!_continuous} || {serverTime >= _until}
        || {_jam getOrDefault ["yielded",false]}
        || {!([_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent)}) exitWith {call _abandon};
    private _request=_vehicle getVariable ["CBE_DrivingQueue_Request",[]];
    if (count _request != 4 || {(_request select 0) != _serial}
        || {(_request select 1) isNotEqualTo _context}) exitWith {call _abandon};
    if (_ours && {(_consent getOrDefault ["phase",""]) == "AGREED"}) exitWith {
        private _expires=_consent getOrDefault ["expires",-1];
        private _token=_consent getOrDefault ["token",""];
        if (!(_expires isEqualType 0) || {!finite _expires} || {_expires > _until}
            || {serverTime >= _expires} || {_token == ""}
            || {!([_proposal get "vehicles",_proposal get "roles",_proposal get "dependencies",_context,true]
                call CBE_fnc_DrivingQueueProposalCurrent)}) exitWith {call _abandon};
        private _sent=_jam getOrDefault ["queueAutoCommitSends",0];
        private _last=_jam getOrDefault ["queueAutoCommitAt",-1e9];
        if (_sent >= 2) exitWith {
            if (serverTime-_last >= 2) then {call _abandon} else {[true,false]}
        };
        if (serverTime-_last < 2) exitWith {[true,false]};
        _jam set ["queueAutoCommitSends",_sent+1];
        _jam set ["queueAutoCommitAt",serverTime];
        ["COMMIT",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
        [true,true]
    };
    if (serverTime >= (_proposal getOrDefault ["deadline",-1])) exitWith {call _abandon};
    [true,false]
};
if (!_enabled || {!_continuous} || {(_jam getOrDefault ["queueAutoAttempted",false]) isEqualTo true}
    || {_jam getOrDefault ["yielded",false]} || {isNull _peer} || {serverTime >= _until}
    || {serverTime-(_jam getOrDefault ["since",serverTime]) < 20}
    || {!([_vehicle,"QUEUE"] call CBE_fnc_DrivingPassCanConsent)}
    || {count (_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap]) > 0}
    || {(_vehicle getVariable ["CBE_DrivingQueue_Request",[]]) isNotEqualTo []}) exitWith {[false,false]};
// Consume before the bounded discovery query; refusal cannot produce a per-tick query loop.
_jam set ["queueAutoAttempted",true];
private _candidate=[_vehicle,_peer,_until] call CBE_fnc_DrivingQueueProposal;
if ((_candidate getOrDefault ["status",""]) != "PROPOSAL") exitWith {
    _jam set ["queueAutoResult",_candidate getOrDefault ["reason","REFUSED"]];[false,true]
};
if (!([_candidate] call CBE_fnc_DrivingQueueAgreementRequest)) exitWith {
    _jam set ["queueAutoResult","REQUEST_REFUSED"];[false,true]
};
_jam set ["queueAutoProposal",_candidate];
_jam set ["queueAutoResult","SUBMITTED"];
[true,true]
