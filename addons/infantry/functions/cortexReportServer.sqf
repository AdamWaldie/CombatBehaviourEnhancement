/*
 * Author: WaldoTheWarfighter
 * Relays up to three expiring sighting reports to eligible mutually allied group owners, preserving reported positions.
 * Both mission friendship directions must be at least0.6; the receiver repeats this live check.
 * Spatial discovery includes mounted crews. Radio range requires a communicating member at
 * both ends; voice uses3D ASL separation and is rechecked by the receiver. Radio radius
 * remains horizontal; a receiver high above the sender cannot substitute voice for a missing radio.
 * Locality/authority: server validates shared assignments; commands run only on the current AI owner.
 * Repeat/JIP: original finite observation times survive relay; invalid payloads spend no cooldown.
 * Server-time deadlines reject stale work; no historical JIP commands are replayed.
 * Arguments: 0 sender GROUP grpNull; 1 reports ARRAY []: at most3
 * [ATL position ARRAY of3 finite NUMBERs, confidence NUMBER0..4,
 * original observed server time NUMBER>=0, reported contact SIDE west/east/resistance]; 2 sent server time NUMBER -1 (invalid default).
 * Return Value: Nothing.
 * Current callers: CBE_fnc_CortexContactReport.
 * Example: [_group, _reports, serverTime] remoteExecCall ["CBE_fnc_CortexReportServer", 2];
 */
params [["_sender", grpNull, [grpNull]], ["_reports", [], [[]]], ["_sent", -1, [0]]];
if (!isServer || {isNull _sender} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != groupOwner _sender}}
    || {!(missionNamespace getVariable ["CBE_AIPass_Enable", false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!([_sender, "CBE_AIPass_ContactReports_Enable", true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_sender] call CBE_fnc_CortexIsEligible)} || {!finite _sent} || {_sent < 0} || {serverTime - _sent > 10} || {_sent > serverTime + 1}) exitWith {};
if (serverTime < (_sender getVariable ["CBE_AIPass_ReportServerDue", -1])) exitWith {};
private _valid = (_reports select [0,3]) select {
    _x isEqualType [] && {count _x == 4} && {(_x select 0) isEqualType []} && {count (_x select 0) == 3}
    && {(_x select 0) findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} < 0}
    && {(_x select 3) isEqualType west} && {(_x select 3) in [west,east,resistance]}
        && {(side _sender) getFriend (_x select 3) < 0.6}
        && {(_x select 1) isEqualType 0} && {finite (_x select 1)} && {(_x select 1) >= 0} && {(_x select 1) <= 4}
    && {(_x select 2) isEqualType 0} && {finite (_x select 2)} && {(_x select 2) >= 0}
    && {serverTime - (_x select 2) <= 10} && {(_x select 2) <= serverTime} && {(_x select 2) <= _sent+1}
};
if (_valid isEqualTo []) exitWith {};
_sender setVariable ["CBE_AIPass_ReportServerDue", serverTime + 15];
private _transmitter = [_sender] call CBE_fnc_CortexGroupTransmitter;
private _voiceRange=missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35];
private _range = if (!isNull _transmitter) then {missionNamespace getVariable ["CBE_AIPass_ContactReports_Radius",500]} else {missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35]};
private _senderPosition = getPosATL ([_transmitter, leader _sender] select isNull _transmitter);
private _senderASL=getPosASL ([_transmitter, leader _sender] select isNull _transmitter);
// A receiver is eligible only when its transmitter or local command anchor is inside this report's
// delivery envelope. Derive distinct groups from nearby actors rather than scanning every group.
private _receiverGroups=[];
private _receiverSeen=createHashMap;
private _receiverArea=[_senderPosition,_range,_range,0,false,_range];
{
    private _receiverGroup=group _x;
    if (!isNull _receiverGroup) then {
        private _groupKey=netId _receiverGroup;
        if (_groupKey == "") then {
            // Preserve identity/order if a transient local group has no network key.
            _receiverGroups pushBackUnique _receiverGroup;
        } else {
            if !(_groupKey in _receiverSeen) then {
                _receiverSeen set [_groupKey,true];
                _receiverGroups pushBack _receiverGroup;
            };
        };
    };
} forEach (_receiverArea nearEntities [["Man"],false,true,true]);
private _receivers = [];
{
    private _receiver = _x;
    private _receiverTransmitter = [_receiver] call CBE_fnc_CortexGroupTransmitter;
    private _receiverAnchor = if (isNull _receiverTransmitter) then {leader _receiver} else {_receiverTransmitter};
    if (_receiver != _sender && {(side _receiver) getFriend (side _sender) >= 0.6}
        && {(side _sender) getFriend (side _receiver) >= 0.6}
        && {!isNull _receiverAnchor} && {alive _receiverAnchor}
        && {_receiverAnchor distance2D _senderPosition <= _range}
        && {(_receiverAnchor distance2D _senderPosition <= _voiceRange
                && {(getPosASL _receiverAnchor) vectorDistance _senderASL <= _voiceRange})
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
