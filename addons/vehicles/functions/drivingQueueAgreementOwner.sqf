/*
 * Author: WaldoTheWarfighter
 * Purpose: Validates actual-owner queue-role consent and receives matching server results.
 * Locality/authority: Only authenticated server remote calls. Each owner validates its own crew/native orders/current brain plus canonical topology; public markers never count as ACK.
 * Repeat/JIP: Exact token/serial/context/roles/original expiry; duplicate agreed delivery does not renew or replay.
 * One timer per accepted phase retires matching local receipts even after movement scheduling
 * stops. Old-machine private metadata can retire after locality loss; no command is issued.
 * Duplicate VERIFY cannot downgrade AGREED. No movement, reservation or JIP commands.
 * Arguments: 0 mode STRING empty VERIFY/RESULT;1 payload ARRAY [],[token,serial,vehicles,roles,dependencies,context,deadline,expires,optional phase].
 * Return: BOOL reply/result handled, not queue movement authority.
 * Current callers: DrivingQueueAgreementServer only.
 * Example: ["VERIFY",_payload] remoteExecCall ["CBE_fnc_DrivingQueueAgreementOwner",_owner];
 */
params [["_mode","",[""]],["_payload",[],[[]]]];
if (remoteExecutedOwner != 2 || {!(_mode in ["VERIFY","RESULT"])}
    || {count _payload != ([8,9] select (_mode == "RESULT"))}) exitWith {false};
_payload params ["_token","_serial","_vehicles","_roles","_dependencies","_context","_deadline","_expires"];
if (!(_token isEqualType "") || {!(_serial isEqualType 0)} || {!finite _serial}
    || {!(_vehicles isEqualType [])} || {count _vehicles < 2} || {count _vehicles > 4}
    || {_vehicles findIf {!(_x isEqualType objNull)} >= 0}
    || {!(_roles isEqualType [])} || {!(_dependencies isEqualType [])} || {!(_context isEqualType [])}
    || {!(_deadline isEqualType 0)} || {!finite _deadline}
    || {!(_expires isEqualType 0)} || {!finite _expires}) exitWith {false};
private _owned=_vehicles select {!isNull _x && {local _x}};
if (_owned isEqualTo []) exitWith {false};
private _phase=["PENDING",_payload param [8,""]] select (_mode == "RESULT");
if (_mode == "RESULT" && {!(_phase in ["AGREED","REFUSED","RELEASED"])}) exitWith {false};
private _receiptKey={
    params ["_receipt"];
    ["token","serial","vehicles","roles","dependencies","context","deadline","expires","phase"] apply {
        _receipt getOrDefault [_x,""]
    }
};
private _scheduleExpiry={
    params ["_key"];
    private _until=[_key select 6,_key select 7] select ((_key select 8) == "AGREED");
    [{
        params ["_vehicles","_key","_receiptKey"];
        isNil {
            private _retired=false;
            {
                if (!isNull _x) then {
                    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
                    if (([_old] call _receiptKey) isEqualTo _key) then {
                        _x setVariable ["CBE_DrivingQueue_Consent",nil];_retired=true;
                    };
                };
            } forEach _vehicles;
            if (_retired) then {["RELEASE",[_key select 0]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
            false
        };
    },[+_owned,+_key,_receiptKey],(_until-serverTime) max 0] call CBA_fnc_waitAndExecute;
};
// Terminal token cleanup must work even if another participant was deleted or changed owner.
if (_mode == "RESULT" && {_phase in ["REFUSED","RELEASED"]}) exitWith {
    {private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
        if ((_old getOrDefault ["token",""]) == _token) then {_x setVariable ["CBE_DrivingQueue_Consent",nil]};
    } forEach _owned;
    true
};
private _duplicate=_owned findIf {
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    (_old getOrDefault ["token",""]) != _token || {(_old getOrDefault ["phase",""]) != "AGREED"}
        || {(_old getOrDefault ["serial",-1]) != _serial}
        || {(_old getOrDefault ["vehicles",[]]) isNotEqualTo _vehicles}
        || {(_old getOrDefault ["deadline",-1]) != _deadline}
        || {(_old getOrDefault ["context",[]]) isNotEqualTo _context}
        || {(_old getOrDefault ["roles",[]]) isNotEqualTo _roles}
        || {(_old getOrDefault ["dependencies",[]]) isNotEqualTo _dependencies}
        || {(_old getOrDefault ["expires",-1]) != _expires} || {serverTime >= _expires}
} < 0;
if (_duplicate) exitWith {
    if (_mode == "VERIFY") then {["ACK",[_token,true]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2]};
    true
};
private _accepted=serverTime < ([_deadline,_expires] select (_mode == "RESULT"))
    && {[_vehicles,_roles,_dependencies,_context,true] call CBE_fnc_DrivingQueueProposalCurrent};
{
    if (_x == (_vehicles select 0)) then {
        private _request=_x getVariable ["CBE_DrivingQueue_Request",[]];
        if (count _request != 4 || {(_request select 0) != _serial}
            || {(_request select 1) isNotEqualTo _context} || {(_request select 2) != _deadline}
            || {(_request select 3) != _expires}) then {_accepted=false};
    };
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    if (_mode == "RESULT" && {_phase == "AGREED"} && {
        (_old getOrDefault ["token",""]) != _token || {(_old getOrDefault ["serial",-1]) != _serial}
        || {(_old getOrDefault ["context",[]]) isNotEqualTo _context}
        || {(_old getOrDefault ["roles",[]]) isNotEqualTo _roles}
        || {(_old getOrDefault ["dependencies",[]]) isNotEqualTo _dependencies}
        || {(_old getOrDefault ["deadline",-1]) != _deadline}
        || {(_old getOrDefault ["expires",-1]) != _expires}
    }) then {_accepted=false};
    if (count _old > 0 && {(_old getOrDefault ["token",""]) != _token}
        && {serverTime < (_old getOrDefault ["expires",-1])}) then {_accepted=false};
} forEach _owned;
if (_mode == "VERIFY") exitWith {
    if (_accepted) then {
        private _pendingKey=[_token,_serial,_vehicles,_roles,_dependencies,_context,_deadline,_expires,"PENDING"];
        private _pendingDuplicate=_owned findIf {
            ([_x getVariable ["CBE_DrivingQueue_Consent",createHashMap]] call _receiptKey) isNotEqualTo _pendingKey
        } < 0;
        {_x setVariable ["CBE_DrivingQueue_Consent",createHashMapFromArray [["token",_token],
            ["serial",_serial],["vehicles",_vehicles],["roles",_roles],["dependencies",_dependencies],
            ["context",_context],["deadline",_deadline],["expires",_expires],["phase","PENDING"]]]} forEach _owned;
        if (!_pendingDuplicate) then {[_pendingKey] call _scheduleExpiry};
    };
    ["ACK",[_token,_accepted]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];true
};
{
    private _old=_x getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    if ((_old getOrDefault ["token",""]) == _token) then {
        if (_accepted && {_phase == "AGREED"}) then {
            private _new=createHashMapFromArray ((keys _old) apply {[_x,_old get _x]});
            _new set ["phase","AGREED"];_x setVariable ["CBE_DrivingQueue_Consent",_new];
        } else {_x setVariable ["CBE_DrivingQueue_Consent",nil]};
    };
} forEach _owned;
if (_phase == "AGREED" && {_accepted}) then {
    [[_token,_serial,_vehicles,_roles,_dependencies,_context,_deadline,_expires,"AGREED"]] call _scheduleExpiry;
};
if (_phase == "AGREED" && {!_accepted}) then {
    ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingQueueAgreementServer",2];
};
true
