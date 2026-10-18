/*
 * Author: WaldoTheWarfighter
 * Relays up to three expiring sighting reports to eligible group owners, preserving reported positions.
 * Spatial discovery includes mounted crews. Radio range requires a communicating member at
 * both ends; voice range remains available without radio and is rechecked by the receiver.
 * Locality/authority: server validates shared assignments; commands run only on the current AI owner.
 * Repeat/JIP: tokens and server-time deadlines reject stale work; no historical JIP commands are replayed.
 * Arguments: 0: sender <GROUP>, grpNull; 1: reports <ARRAY>, []; 2: sent server time <NUMBER>, -1.
 * Return Value: Nothing.
 * Current callers: ContactReport.
 * Example: [_group, _reports, serverTime] remoteExecCall ["CBE_fnc_CortexReportServer", 2];
 */
params [["_sender", grpNull, [grpNull]], ["_reports", [], [[]]], ["_sent", -1, [0]]];
if (!isServer || {isNull _sender} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != groupOwner _sender}}
    || {!(missionNamespace getVariable ["CBE_AIPass_Enable", false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!([_sender, "CBE_AIPass_ContactReports_Enable", true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_sender] call CBE_fnc_CortexIsEligible)} || {serverTime - _sent > 10} || {_sent > serverTime + 1}) exitWith {};
if (serverTime < (_sender getVariable ["CBE_AIPass_ReportServerDue", -1])) exitWith {};
_sender setVariable ["CBE_AIPass_ReportServerDue", serverTime + 15];
private _valid = (_reports select [0,3]) select {
    _x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualType []} && {count (_x select 0) == 3}
    && {(_x select 0) findIf {!(_x isEqualType 0)} < 0} && {(_x select 1) isEqualType 0}
    && {(_x select 2) isEqualType 0} && {serverTime - (_x select 2) <= 10} && {(_x select 2) <= serverTime}
};
if (_valid isEqualTo []) exitWith {};
private _transmitter = [_sender] call CBE_fnc_CortexGroupTransmitter;
private _voiceRange=missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35];
private _range = if (!isNull _transmitter) then {missionNamespace getVariable ["CBE_AIPass_ContactReports_Radius",500]} else {missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35]};
private _senderPosition = getPosATL ([_transmitter, leader _sender] select isNull _transmitter);
// A receiver is eligible only when its transmitter or local command anchor is inside this report's
// delivery envelope. Derive distinct groups from nearby actors rather than scanning every group.
private _receiverGroups=[];
private _receiverArea=[_senderPosition,_range,_range,0,false,_range];
{
    private _receiverGroup=group _x;
    if (!isNull _receiverGroup && {!(_receiverGroup in _receiverGroups)}) then {
        _receiverGroups pushBack _receiverGroup;
    };
} forEach (_receiverArea nearEntities [["Man"],false,true,true]);
private _receivers = [];
{
    private _receiver = _x;
    private _receiverTransmitter = [_receiver] call CBE_fnc_CortexGroupTransmitter;
    private _receiverAnchor = if (isNull _receiverTransmitter) then {leader _receiver} else {_receiverTransmitter};
    if (_receiver != _sender && {side _receiver == side _sender} && {!isNull _receiverAnchor} && {alive _receiverAnchor}
        && {_receiverAnchor distance2D _senderPosition <= _range}
        && {_receiverAnchor distance2D _senderPosition <= _voiceRange
            || {!isNull _transmitter && {!isNull _receiverTransmitter}}}
        && {[_receiver] call CBE_fnc_CortexIsEligible}) then {
        _receivers pushBack _receiver;
    };
} forEach _receiverGroups;
// One bounded delivery job; do not fan out an unbounded remote-call burst.
[{
    params ["_job"];
    private _sender = _job get "sender";
    private _receivers = _job get "receivers";
    private _cursor = _job getOrDefault ["cursor",0];
    for "_i" from 1 to 8 do {
        if (_cursor >= count _receivers) exitWith {};
        private _receiver = _receivers select _cursor;
        _cursor = _cursor + 1;
        if (!isNull _receiver && {serverTime < (_job get "expiry")}) then {
            [_receiver, _sender, _job get "reports", _job get "sent"] remoteExecCall ["CBE_fnc_CortexReportLocal", groupOwner _receiver];
        };
    };
    _job set ["cursor",_cursor];
    if (_cursor >= count _receivers || {serverTime >= (_job get "expiry")}) then {-1} else {0.5}
}, createHashMapFromArray [["sender",_sender],["receivers",_receivers],["reports",_valid],["sent",_sent],["expiry",_sent+15]],1.5] call CBE_fnc_CortexQueueJob;
