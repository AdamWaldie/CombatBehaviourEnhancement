/*
 * Author: WaldoTheWarfighter
 * Stores an expiring area report without revealing or tracking a target object.
 * Delivery rechecks both radio endpoints; nearby voice communication remains possible
 * when either endpoint is jammed. Mounted receivers use the same eligibility contract.
 * Locality/authority: server validates shared assignments; commands run only on the current AI owner.
 * Repeat/JIP: storage and expiry retain original finite observation time, not relay time;
 * older/duplicate sightings cannot replace fresher evidence. No historical JIP commands replay.
 * Arguments: 0: receiver <GROUP>, grpNull; 1: sender <GROUP>, grpNull; 2: reports <ARRAY>, []; 3: sent time <NUMBER>, -1.
 * Return Value: Nothing.
 * Current callers: ReportServer.
 * Example: [_receiver, _sender, _reports, serverTime] remoteExecCall ["CBE_fnc_CortexReportLocal", groupOwner _receiver];
 */
params [["_receiver",grpNull,[grpNull]],["_sender",grpNull,[grpNull]],["_reports",[],[[]]],["_sent",-1,[0]]];
if (remoteExecutedOwner != 2 || {!local _receiver} || {isNull _sender} || {(units _sender) findIf {alive _x} < 0}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!finite _sent} || {_sent < 0} || {_sent > serverTime+1} || {serverTime - _sent > 15} || {!([_receiver] call CBE_fnc_CortexIsEligible)}
    || {!([_receiver,"CBE_AIPass_ContactReports_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_sender,"CBE_AIPass_ContactReports_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {};
private _transmitter = [_sender] call CBE_fnc_CortexGroupTransmitter;
private _receiverTransmitter = [_receiver] call CBE_fnc_CortexGroupTransmitter;
private _voiceRange=missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35];
private _range = if (!isNull _transmitter) then {missionNamespace getVariable ["CBE_AIPass_ContactReports_Radius",500]} else {missionNamespace getVariable ["CBE_AIPass_ContactReports_VoiceRange",35]};
private _senderPosition = getPosATL ([_transmitter, leader _sender] select isNull _transmitter);
private _receiverPosition = getPosATL ([_receiverTransmitter, leader _receiver] select isNull _receiverTransmitter);
if (side _receiver != side _sender || {isNull _receiverTransmitter && {!alive leader _receiver}}
    || {_receiverPosition distance2D _senderPosition > _range}
    || {_receiverPosition distance2D _senderPosition > _voiceRange
        && {isNull _transmitter || {isNull _receiverTransmitter}}}) exitWith {};
private _valid=(_reports select [0,3]) select {
    _x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualType []} && {count (_x select 0) == 3}
        && {(_x select 0) findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} < 0}
        && {(_x select 1) isEqualType 0} && {finite (_x select 1)} && {(_x select 1) >= 0} && {(_x select 1) <= 4}
        && {(_x select 2) isEqualType 0} && {finite (_x select 2)} && {(_x select 2) >= 0}
        && {(_x select 2) <= serverTime} && {(_x select 2) <= _sent+1} && {serverTime < (_x select 2)+30}
};
private _best = _valid param [0,[]];
if (_best isEqualTo []) exitWith {};
private _observed=_best select 2;
private _previous = _receiver getVariable ["CBE_AIPass_AreaReport",[]];
if (_previous isNotEqualTo [] && {(_previous select 1) >= _observed}) exitWith {};
_receiver setVariable ["CBE_AIPass_AreaReport",[+(_best select 0),_observed,_observed+30,"REPORT"],true];
