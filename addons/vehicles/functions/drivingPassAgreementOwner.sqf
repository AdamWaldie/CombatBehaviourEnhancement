/*
 * Author: WaldoTheWarfighter
 * Purpose: Checks server-requested road-pass consent on each actual vehicle owner and receives result.
 * Locality/authority: Only authenticated server remote calls. Each owned participant checks its
 * exact current crew/order row and local eligibility. A peer's public label is never an ACK.
 * Repeat/JIP: Matching-token private receipts expire at original deadlines; no deadline renewal,
 * One exact-receipt expiry callback per accepted phase also retires old-machine metadata.
 * No movement, priority, controller transfer or JIP replay. Passing-owner verification requires
 * its still-current request serial/context; a cancelled request cannot acquire late consent. AGREED still requires live execution guards.
 * Arguments: 0 mode <STRING>, empty, VERIFY or RESULT; 1 server payload <ARRAY>, empty.
 * VERIFY: [token, vehicles, context, handshakeDeadline, consentExpiry, serial]; RESULT adds phase.
 * Return: BOOL - reply/result handled, not physical passing or authority to disable safety.
 * Current callers: DrivingPassAgreementServer only.
 * Example: ["VERIFY",_payload] remoteExecCall ["CBE_fnc_DrivingPassAgreementOwner",_owner];
 */
params [["_mode","",[""]],["_payload",[],[[]]]];
if (remoteExecutedOwner != 2 || {!(_mode in ["VERIFY","RESULT"])}
    || {count _payload != ([6,7] select (_mode == "RESULT"))}) exitWith {false};
_payload params ["_token","_vehicles","_context","_deadline","_expires","_serial"];
// Terminal metadata belongs to the original consenting machine, not today's topology.
if (_mode == "RESULT" && {(_payload select 6) in ["REFUSED","RELEASED"]}) exitWith {
    [_token,_expires] call CBE_fnc_DrivingPassTokenClosed;
    {if (!isNull _x) then {[_x,grpNull,_token] call CBE_fnc_DrivingPassAgreementRelease}} forEach _vehicles;
    true
};
// Retired tokens cannot be readmitted by delayed VERIFY or AGREED delivery.
if ([_token] call CBE_fnc_DrivingPassTokenClosed) exitWith {
    ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingPassAgreementServer",2];
    false
};
private _scheduleExpiry={
    params ["_targets","_receipt"];
    private _until=[_receipt select 2,_receipt select 3] select ((_receipt select 4) == "AGREED");
    [{
        params ["_targets","_receipt"];
        isNil {
            {
                if (!isNull _x && {(_x getVariable ["CBE_DrivingPass_Consent",[]]) isEqualTo _receipt}) then {
                    [_x,grpNull,_receipt select 0] call CBE_fnc_DrivingPassAgreementRelease;
                };
            } forEach _targets;
            false
        };
    },[+_targets,+_receipt],(_until-serverTime) max 0] call CBA_fnc_waitAndExecute;
};
private _live=[_vehicles] call CBE_fnc_DrivingPassContext;
if (_live isEqualTo [] || {count _context != 2} || {count (_context select 1) != 2}) exitWith {false};
// An already-installed result is not a new request to reinterpret native commands.
// In particular, our own later fixed-path command must not make duplicate delivery revoke consent.
if (_mode == "RESULT" && {(_payload select 6) == "AGREED"}) then {
    private _local=_vehicles select {local _x};
    private _installed=_local isNotEqualTo [] && {_local findIf {
        private _old=_x getVariable ["CBE_DrivingPass_Consent",[]];
        !(_old isEqualType []) || {count _old != 5} || {(_old select 0) isNotEqualTo _token}
            || {(_old select 4) isNotEqualTo "AGREED"}
    } < 0};
    if (_installed) exitWith {_mode="DUPLICATE"};
};
if (_mode == "DUPLICATE") exitWith {true};
private _owned=[];private _accepted=serverTime < ([_deadline,_expires] select (_mode == "RESULT"))
    && {group driver (_vehicles select 0) != group driver (_vehicles select 1)};
for "_i" from 0 to 1 do {
    private _vehicle=_vehicles select _i;
    if (local _vehicle) then {
        _owned pushBack _vehicle;
        if (_vehicle == (_vehicles select 0)) then {
            private _request=_vehicle getVariable ["CBE_DrivingPass_Request",[]];
            if (count _request != 3 || {(_request select 2) != _serial}
                || {(_request select 0) isNotEqualTo _context}) then {_accepted=false};
        };
        if (((_live select 1) select _i) isNotEqualTo ((_context select 1) select _i)
            || {!([_vehicle] call CBE_fnc_DrivingPassCanConsent)}) then {_accepted=false};
        private _old=_vehicle getVariable ["CBE_DrivingPass_Consent",[]];
        if (_old isNotEqualTo []) then {
            private _valid=_old isEqualType [] && {count _old == 5}
                && {(_old select 0) isEqualType ""} && {(_old select 1) isEqualType []}
                && {count (_old select 1) == 2}
                && {(_old select 2) isEqualType 0} && {finite (_old select 2)}
                && {(_old select 3) isEqualType 0} && {finite (_old select 3)}
                && {(_old select 4) in ["PENDING","AGREED"]};
            if (!_valid) then {_accepted=false} else {
                private _until=[_old select 2,_old select 3] select ((_old select 4) == "AGREED");
                private _oldContext=_old select 1;
                if ((_old select 0) != _token && {serverTime < _until}
                    && {(_oldContext select 1) isEqualTo (_live select 1)}) then {_accepted=false};
            };
        };
    };
};
if (_owned isEqualTo []) exitWith {false};
if (_mode == "VERIFY") exitWith {
    if (_accepted) then {
        private _pending=[_token,_context,_deadline,_expires,"PENDING"];
        private _agreed=[_token,_context,_deadline,_expires,"AGREED"];
        private _install=_owned select {
            private _old=_x getVariable ["CBE_DrivingPass_Consent",[]];
            !(_old isEqualTo _pending || {_old isEqualTo _agreed})
        };
        // Duplicate verification neither adds an expiry callback nor downgrades AGREED.
        {_x setVariable ["CBE_DrivingPass_Consent",+_pending]} forEach _install;
        if (_install isNotEqualTo []) then {[_install,_pending] call _scheduleExpiry};
    };
    ["ACK",[_token,_accepted]] remoteExecCall ["CBE_fnc_DrivingPassAgreementServer",2];
    true
};
private _phase=_payload select 6;
{
    private _old=_x getVariable ["CBE_DrivingPass_Consent",[]];
    if (count _old == 5 && {(_old select 0) == _token}) then {
        if (_accepted && {_phase == "AGREED"}) then {
            _x setVariable ["CBE_DrivingPass_Consent",[_token,_context,_deadline,_expires,"AGREED"]];
            if (_x == (_vehicles select 0)) then {
                private _request=_x getVariable ["CBE_DrivingPass_Request",[]];
                if (count _request == 3 && {(_request select 2) == _serial} && {(_request select 0) isEqualTo _context}) then {
                    _x setVariable ["CBE_DrivingPass_Agreement",[_token,_vehicles,_context,_expires,"AGREED"]];
                };
            };
        } else {
            [_token,_expires] call CBE_fnc_DrivingPassTokenClosed;
            _x setVariable ["CBE_DrivingPass_Consent",nil];
            private _agreement=_x getVariable ["CBE_DrivingPass_Agreement",[]];
            if (count _agreement == 5 && {(_agreement select 0) == _token}) then {_x setVariable ["CBE_DrivingPass_Agreement",nil]};
        };
    };
} forEach _owned;
if (_phase == "AGREED" && {_accepted}) then {
    [_owned,[_token,_context,_deadline,_expires,"AGREED"]] call _scheduleExpiry;
};
if (_phase == "AGREED" && {!_accepted}) then {
    ["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingPassAgreementServer",2];
};
true