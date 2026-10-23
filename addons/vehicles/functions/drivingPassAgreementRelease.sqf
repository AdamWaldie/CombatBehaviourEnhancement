/*
 * Author: WaldoTheWarfighter
 * Purpose: Retires this owner's exact pass-consent token when ordinary driving is released.
 * Locality/authority: Original private-receipt machine; local or authenticated server call.
 * Captured vehicle owner must be this machine, including after locality loss. Only the
 * recorded group/token/context is cleared, atomically even for scheduled script callers.
 * Server separately authenticates the original participant; no native authority is granted.
 * Repeat/JIP: Repeated calls without a matching receipt do nothing. No movement, speed, route,
 * ownership transfer, peer state writes or JIP replay. Delayed results cannot recreate cleared consent.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 expected group <GROUP>, grpNull permits local shutdown.
 * 2 expected token <STRING>, empty permits current local receipt; supplied tokens fence stale work.
 * 3 expected owner epoch <NUMBER, -1>; 4 expected driving generation <NUMBER, -1>.
 * Supply both for exact retiring-brain cancellation, including passive peer consent. Both
 * defaulting to-1 preserves explicit group/subsystem cancellation; partial binding refuses.
 * Return: BOOL - a matching local receipt was retired and broker release requested.
 * Current callers: DrivingAssistRelease, DrivingOperationFinish, DrivingPassAdmission
 * and trusted cancellation scripts.
 * Example: [truck1,group driver truck1] call CBE_fnc_DrivingPassAgreementRelease;
 */
params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]],["_expectedToken","",[""]],
    ["_expectedEpoch",-1,[0]],["_expectedGeneration",-1,[0]]];
private _released=false;
isNil {
    _released=call {
if (isNull _vehicle || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
if (!finite _expectedEpoch || {!finite _expectedGeneration}) exitWith {false};
private _bound=_expectedEpoch >= 0 || {_expectedGeneration >= 0};
if (_bound && {_expectedEpoch < 0 || {_expectedGeneration < 0} || {isNull _expectedGroup}}) exitWith {false};
private _consent=_vehicle getVariable ["CBE_DrivingPass_Consent",[]];
private _agreement=_vehicle getVariable ["CBE_DrivingPass_Agreement",[]];
private _token="";private _context=[];
if (_consent isNotEqualTo []) then {
    if (_consent isEqualType [] && {count _consent == 5}
        && {(_consent select 0) isEqualType ""} && {(_consent select 1) isEqualType []}
        && {(_consent select 2) isEqualType 0} && {finite (_consent select 2)}
        && {(_consent select 3) isEqualType 0} && {finite (_consent select 3)}
        && {(_consent select 4) in ["PENDING","AGREED"]}) then {
        _token=_consent select 0;_context=_consent select 1;
    };
} else {
    if (_agreement isEqualType [] && {count _agreement == 5}
        && {(_agreement select 0) isEqualType ""} && {(_agreement select 2) isEqualType []}
        && {(_agreement select 3) isEqualType 0} && {finite (_agreement select 3)}
        && {(_agreement select 4) isEqualTo "AGREED"}) then {
        _token=_agreement select 0;_context=_agreement select 2;
    };
};
if (_token == "" || {_expectedToken != "" && {_token != _expectedToken}} || {count _context != 2} || {!((_context select 1) isEqualType [])}) exitWith {false};
private _rows=_context select 1;
private _index=_rows findIf {_x isEqualType [] && {count _x == 4} && {(_x select 0) isEqualTo _vehicle}};
if (_index < 0) exitWith {false};
if (((_rows select _index) select 1) != clientOwner) exitWith {false};
private _driverReceipt=(_rows select _index) select 2;
if (!(_driverReceipt isEqualType []) || {count _driverReceipt != 11}
    || {!((_driverReceipt select 2) isEqualType grpNull)}
    || {!isNull _expectedGroup && {(_driverReceipt select 2) != _expectedGroup}}) exitWith {false};
if (_bound && {[2,3] findIf {
    private _actorReceipt=(_rows select _index) select _x;
    !(_actorReceipt isEqualType []) || {count _actorReceipt != 11}
        || {(_actorReceipt select 2) isNotEqualTo _expectedGroup}
        || {(_actorReceipt select 4) isNotEqualTo _expectedEpoch}
        || {(_actorReceipt select 10) isNotEqualTo _expectedGeneration}
} >= 0}) exitWith {false};
private _closeUntil=if (_consent isNotEqualTo []) then {_consent select 3} else {_agreement select 3};
[_token,_closeUntil] call CBE_fnc_DrivingPassTokenClosed;
// Retire only matching local observations. A newer token/request must survive stale cleanup.
if (_consent isNotEqualTo [] && {(_vehicle getVariable ["CBE_DrivingPass_Consent",[]]) isEqualTo _consent}) then {
    _vehicle setVariable ["CBE_DrivingPass_Consent",nil];
};
if (_agreement isEqualType [] && {count _agreement == 5} && {(_agreement select 0) isEqualTo _token}
    && {(_vehicle getVariable ["CBE_DrivingPass_Agreement",[]]) isEqualTo _agreement}) then {
    _vehicle setVariable ["CBE_DrivingPass_Agreement",nil];
};
private _orders=_vehicle getVariable ["CBE_DrivingPass_OwnerOrders",[]];
if (_orders isEqualType [] && {count _orders == 6} && {(_orders select 0) isEqualTo _token}
    && {(_orders select 1) isEqualTo _context}) then {_vehicle setVariable ["CBE_DrivingPass_OwnerOrders",nil]};
private _request=_vehicle getVariable ["CBE_DrivingPass_Request",[]];
if (_request isEqualType [] && {count _request == 3} && {(_request select 0) isEqualTo _context}) then {
    _vehicle setVariable ["CBE_DrivingPass_Request",nil];
};
["RELEASE",[_token]] remoteExecCall ["CBE_fnc_DrivingPassAgreementServer",2];
true
    };
};
_released
