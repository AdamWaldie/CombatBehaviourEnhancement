/*
 * Author: WaldoTheWarfighter
 * Purpose: Brokers bounded queue-role consent, explicit root commit and measured hold readiness.
 * Consent/READY never authorizes a reverse leg; dependency execution remains separate.
 * All-ready observation sends one metadata-only PREPARE to all participant owners at original expiry; each acknowledges its own applied holds.
 * Locality/authority: Authenticated server remote calls only; BEGIN requires current initiator vehicle/crew/group owner, ACK its expected actual owner.
 * Repeat/JIP: Private32episode registry, fixed2s handshake/30s maximum consent; idempotent replies and exact-token release.
 * A private64-entry vehicle admission journal allows one accepted BEGIN per30seconds,
 * bounding retired timer accumulation as well as the32live episodes.
 * A negative ACK from an expected owner withdraws an existing agreement immediately.
 * One timer per admitted phase retires exact-token/phase/deadline state without waiting for
 * another request. Late callbacks preserve newer phases. No recurring scan or JIP command.
 * Arguments: 0 mode STRING empty BEGIN/ACK/RELEASE/COMMIT/READY/PREPARED/ARMED;1 payload ARRAY []. BEGIN=[serial,vehicles,roles,dependencies,context,deadline,expires]; ACK=[token,BOOL]; RELEASE/COMMIT=[token]; READY=[token,vehicle]; PREPARED/ARMED=[token].
 * Return: BOOL processed, never native execution or queue success.
 * Current callers: DrivingQueueAgreementRequest and actual-owner DrivingQueueAgreementOwner replies.
 * Example: ["ACK",[_token,true]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
 */
params [["_mode","",[""]],["_payload",[],[[]]]];
if (!isServer || {remoteExecutedOwner <= 0} || {!(_mode in ["BEGIN","ACK","RELEASE","COMMIT","READY","PREPARED","ARMED"])}) exitWith {false};
private _sender=remoteExecutedOwner;
private _registry=localNamespace getVariable ["CBE_DrivingQueue_Agreements",createHashMap];
localNamespace setVariable ["CBE_DrivingQueue_Agreements",_registry];
private _current={params ["_record"];
    if ("motionBinding" in _record) exitWith {[_record,false] call CBE_fnc_DrivingQueueReverseCurrent};
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
if (count _payload != ([1,2] select (_mode in ["ACK","READY"])) || {!((_payload select 0) isEqualType "")}) exitWith {false};
private _token=_payload select 0;private _record=_registry getOrDefault [_token,createHashMap];
if (count _record == 0 || {!(_sender in (_record get "owners"))}) exitWith {false};
if (_mode == "RELEASE") exitWith {
    _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;true
};
if (_mode == "PREPARED" && {_sender in (_record getOrDefault ["preparedOwners",[]])}) exitWith {true};
if (_mode == "ARMED" && {_sender in (_record getOrDefault ["armedOwners",[]])}) exitWith {true};
// Every actual participant owner must preserve the prepared hold before a later
// execution grant can exist. This acknowledgement is metadata, never movement authority.
if (_mode == "PREPARED") exitWith {
    if ((_record get "phase") != "AGREED" || {serverTime >= (_record get "expires")}
        || {!(_record getOrDefault ["committed",false])}
        || {!(_record getOrDefault ["holdReady",false])}
        || {!(_record getOrDefault ["executionPrepared",false])}
        || {(_record get "vehicles") findIf {
            private _linear=vectorMagnitude velocity _x;private _angular=vectorMagnitude angularVelocity _x;
            !finite _linear || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
        } >= 0}
        || {!([_record] call _current)}) exitWith {
        _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;false
    };
    private _prepared=_record getOrDefault ["preparedOwners",[]];
    _prepared pushBackUnique _sender;
    _record set ["preparedOwners",_prepared];
    _record set ["executionReady",count _prepared == count (_record get "owners")];
    if (_record get "executionReady" && {!(_record getOrDefault ["armSent",false])}) then {
        private _vehicles=_record get "vehicles";
        _record set ["motionBinding",[_vehicles select (count _vehicles-1),_token,_record get "expires",8]];
        _record set ["motionStage","ARMED"];_record set ["armSent",true];
        private _message=[_token,_record get "serial",_vehicles,_record get "roles",
            _record get "dependencies",_record get "context",_record get "deadline",_record get "expires","AGREED"];
        {["ARM",_message] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_x]} forEach (_record get "owners");
    };
    true
};
if (_mode == "ARMED") exitWith {
    if ((_record get "phase") != "AGREED" || {serverTime >= (_record get "expires")}
        || {!(_record getOrDefault ["executionReady",false])}
        || {!(_record getOrDefault ["armSent",false])} || {!([_record] call _current)}) exitWith {
        _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;false
    };
    private _armed=_record getOrDefault ["armedOwners",[]];_armed pushBackUnique _sender;
    _record set ["armedOwners",_armed];
    if (count _armed == count (_record get "owners") && {!(_record getOrDefault ["executeSent",false])}) then {
        private _vehicles=_record get "vehicles";private _leaf=_vehicles select (count _vehicles-1);
        _record set ["executeSent",true];
        private _message=[_token,_record get "serial",_vehicles,_record get "roles",
            _record get "dependencies",_record get "context",_record get "deadline",_record get "expires","AGREED"];
        ["EXECUTE",_message] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",owner _leaf];
    };
    true
};
// COMMIT is separate from consent and can originate only from the actual root owner.
// READY is an actual participant-owner report, never a public variable or a motion grant.
if (_mode in ["COMMIT","READY"]) exitWith {
    if ((_record get "phase") != "AGREED" || {serverTime >= (_record get "expires")}
        || {!([_record] call _current)}) exitWith {
        _record set ["phase","RELEASED"];[_record] call _send;_registry deleteAt _token;false
    };
    if (_mode == "COMMIT") exitWith {
        private _root=(_record get "vehicles") select 0;
        private _operator=effectiveCommander _root;if (isNull _operator) then {_operator=driver _root};
        if (_sender != owner _root || {_sender != owner driver _root}
            || {_sender != owner _operator} || {_sender != groupOwner group driver _root}) exitWith {false};
        private _deliveries=_record getOrDefault ["commitDeliveries",0];
        if (_deliveries >= 2) exitWith {true};
        _record set ["commitDeliveries",_deliveries+1];
        _record set ["committed",true];
        private _message=[_token,_record get "serial",_record get "vehicles",_record get "roles",
            _record get "dependencies",_record get "context",_record get "deadline",_record get "expires","AGREED"];
        {["COMMIT",_message] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_x]} forEach (_record get "owners");
        true
    };
    private _vehicle=_payload select 1;
    if (!(_vehicle isEqualType objNull) || {isNull _vehicle}
        || {!(_record getOrDefault ["committed",false])}
        || {!(_vehicle in (_record get "vehicles"))} || {owner _vehicle != _sender}
        || {owner driver _vehicle != _sender} || {groupOwner group driver _vehicle != _sender}) exitWith {false};
    private _operator=effectiveCommander _vehicle;if (isNull _operator) then {_operator=driver _vehicle};
    private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
    if (owner _operator != _sender || {!finite _linear} || {!finite _angular}
        || {_linear >= 0.1} || {_angular >= 0.01}) exitWith {false};
    private _ready=_record getOrDefault ["holdReadyVehicles",[]];_ready pushBackUnique _vehicle;
    _record set ["holdReadyVehicles",_ready];
    // Collected reports alone do not prove simultaneous stillness at this observation.
    private _allSettled=(_record get "vehicles") findIf {
        private _linear=vectorMagnitude velocity _x;private _angular=vectorMagnitude angularVelocity _x;
        !finite _linear || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
    } < 0;
    _record set ["holdReady",count _ready == count (_record get "vehicles") && {_allSettled}];
    // Preparation selects one dependency leaf under the original agreement. It is
    // metadata only: no owner may infer native motion authority from this message.
    if (_record get "holdReady" && {!(_record getOrDefault ["executionPrepared",false])}) then {
        private _vehicles=_record get "vehicles";
        _record set ["executionPrepared",true];
        private _message=[_token,_record get "serial",_vehicles,_record get "roles",
            _record get "dependencies",_record get "context",_record get "deadline",_record get "expires","AGREED"];
        {["PREPARE",_message] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_x]} forEach (_record get "owners");
    };
    true
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
