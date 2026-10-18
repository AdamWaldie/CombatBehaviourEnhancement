/*
 * Author: WaldoTheWarfighter
 * Purpose: Brokers distinct bounded queue-role owner consent without movement or priority.
 * Locality/authority: Authenticated server remote calls only; BEGIN requires current initiator vehicle/crew/group owner, ACK its expected actual owner.
 * Repeat/JIP: Private32episode registry, fixed2s handshake/30s maximum consent; idempotent replies and exact-token release.
 * A private64-entry vehicle admission journal allows one accepted BEGIN per30seconds,
 * bounding retired timer accumulation as well as the32live episodes.
 * A negative ACK from an expected owner withdraws an existing agreement immediately.
 * One timer per admitted phase retires exact-token/phase/deadline state without waiting for
 * another request. Late callbacks preserve newer phases. No recurring scan or JIP command.
 * Arguments: 0 mode STRING empty BEGIN/ACK/RELEASE;1 payload ARRAY []. BEGIN=[serial,vehicles,roles,dependencies,context,deadline,expires]; ACK=[token,BOOL]; RELEASE=[token].
 * Return: BOOL processed, never native execution or queue success.
 * Current callers: DrivingQueueAgreementRequest and actual-owner DrivingQueueAgreementOwner replies.
 * Example: ["ACK",[_token,true]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
 */
params [["_mode","",[""]],["_payload",[],[[]]]];
if (!isServer || {remoteExecutedOwner <= 0} || {!(_mode in ["BEGIN","ACK","RELEASE"])}) exitWith {false};
private _sender=remoteExecutedOwner;
private _registry=localNamespace getVariable ["CBE_DrivingQueue_Agreements",createHashMap];
localNamespace setVariable ["CBE_DrivingQueue_Agreements",_registry];
private _current={params ["_record"];
    [_record get "vehicles",_record get "roles",_record get "dependencies",_record get "context",false]
        call CBE_fnc_DrivingQueueProposalCurrent
};
private _send={params ["_record"];
    private _message=[_record get "token",_record get "serial",_record get "vehicles",_record get "roles",
        _record get "dependencies",_record get "context",_record get "deadline",_record get "expires",_record get "phase"];
    {["RESULT",_message] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_x]} forEach (_record get "owners");
};
// Fixed one-shot retirement remains independent of tactical scheduling/owner disconnect.
// A delayed callback may revoke only its original phase, never renew or restore consent.
private _scheduleExpiry={
    params ["_record"];
    private _phase=_record get "phase";
    private _until=[_record get "deadline",_record get "expires"] select (_phase == "AGREED");
    [{
        params ["_token","_phase","_until","_send"];
        isNil {
            private _registry=localNamespace getVariable ["CBE_DrivingQueue_Agreements",createHashMap];
            private _live=_registry getOrDefault [_token,createHashMap];
            if (count _live == 0 || {(_live get "phase") != _phase}
                || {([_live get "deadline",_live get "expires"] select (_phase == "AGREED")) != _until}) exitWith {false};
            _live set ["phase","RELEASED"];
            [_live] call _send;
            _registry deleteAt _token;
            false
        };
    },[_record get "token",_phase,_until,_send],(_until-serverTime) max 0] call CBA_fnc_waitAndExecute;
};
if (_mode == "BEGIN") exitWith {
    if (count _payload != 7) exitWith {false};
    _payload params ["_serial","_vehicles","_roles","_dependencies","_context","_deadline","_expires"];
    if (!(_serial isEqualType 0) || {!finite _serial} || {_serial < 1} || {_serial != floor _serial}
        || {!(_vehicles isEqualType [])} || {count _vehicles < 2} || {count _vehicles > 4}
        || {!(_roles isEqualType [])} || {!(_dependencies isEqualType [])} || {!(_context isEqualType [])}
        || {!(_deadline isEqualType 0)} || {!finite _deadline} || {_deadline <= serverTime} || {_deadline > serverTime+2}
        || {!(_expires isEqualType 0)} || {!finite _expires} || {_expires <= _deadline} || {_expires > serverTime+30}) exitWith {false};
    private _vehicle=_vehicles select 0;
    if (!(_vehicle isEqualType objNull) || {isNull _vehicle} || {owner _vehicle != _sender}
        || {isNull driver _vehicle} || {owner driver _vehicle != _sender}
        || {groupOwner group driver _vehicle != _sender}) exitWith {false};
    // Caller deduplication is not server authority. Bound timer admission even if a
    // participant sends fresh serials and immediately releases every accepted episode.
    private _admissions=localNamespace getVariable ["CBE_DrivingQueue_Admissions",createHashMap];
    private _admissionKey=netId _vehicle;
    if (_admissionKey == "" || {serverTime < (_admissions getOrDefault [_admissionKey,-1])}) exitWith {false};
    if (!([_vehicles,_roles,_dependencies,_context,false] call CBE_fnc_DrivingQueueProposalCurrent)) exitWith {false};
    {if (serverTime >= (_admissions get _x)) then {_admissions deleteAt _x}} forEach keys _admissions;
    if (count _admissions >= 64) exitWith {false};
    // Only authenticated BEGIN performs the bounded registry sweep.
    {
        private _record=_registry get _x;
        private _until=[_record get "deadline",_record get "expires"] select ((_record get "phase") == "AGREED");
        if (serverTime >= _until || {!([_record] call _current)}) then {
            _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _x;
        };
    } forEach keys _registry;
    if (count _registry >= 32 || {keys _registry findIf {
        private _old=_registry get _x;
        (_old get "vehicles") findIf {_x in _vehicles} >= 0
    } >= 0}) exitWith {false};
    private _owners=_vehicles apply {owner _x};_owners=_owners arrayIntersect _owners;
    if (_owners findIf {_x <= 0} >= 0) exitWith {false};
    private _sequence=(localNamespace getVariable ["CBE_DrivingQueue_Sequence",0])+1;
    localNamespace setVariable ["CBE_DrivingQueue_Sequence",_sequence];
    private _token=format ["QUEUE:%1:%2:%3",_sender,netId _vehicle,_sequence];
    private _record=createHashMapFromArray [["token",_token],["serial",_serial],["vehicles",_vehicles],
        ["roles",_roles],["dependencies",_dependencies],["context",_context],["deadline",_deadline],
        ["expires",_expires],["owners",_owners],["acks",[]],["phase","PENDING"]];
    _registry set [_token,_record];
    _admissions set [_admissionKey,serverTime+30];
    localNamespace setVariable ["CBE_DrivingQueue_Admissions",_admissions];
    [_record] call _scheduleExpiry;
    private _message=[_token,_serial,_vehicles,_roles,_dependencies,_context,_deadline,_expires];
    {["VERIFY",_message] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_x]} forEach _owners;
    true
};
if (count _payload != ([1,2] select (_mode == "ACK")) || {!((_payload select 0) isEqualType "")}) exitWith {false};
private _token=_payload select 0;private _record=_registry getOrDefault [_token,createHashMap];
if (count _record == 0 || {!(_sender in (_record get "owners"))}) exitWith {false};
if (_mode == "RELEASE") exitWith {
    _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;true
};
if (!((_payload select 1) isEqualType true)) exitWith {false};
private _until=[_record get "deadline",_record get "expires"] select ((_record get "phase") == "AGREED");
if (serverTime >= _until || {!([_record] call _current)}) exitWith {
    _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;false
};
// An expected owner can withdraw agreement after its native context changes.
// A late refusal is terminal; duplicate positive ACKs retain the original expiry.
if ((_record get "phase") == "AGREED" && {!(_payload select 1)}) exitWith {
    _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;true
};
if ((_record get "phase") != "PENDING") exitWith {[_record] call _send;true};
if !(_payload select 1) then {_record set ["phase","REFUSED"]} else {
    private _acks=_record get "acks";_acks pushBackUnique _sender;
    if (count _acks == count (_record get "owners")) then {_record set ["phase","AGREED"]};
};
if ((_record get "phase") != "PENDING") then {
    if ((_record get "phase") == "AGREED") then {[_record] call _scheduleExpiry};
    [_record] call _send;
    if ((_record get "phase") == "REFUSED") then {_registry deleteAt _token};
};
true
