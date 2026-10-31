/*
 * Author: WaldoTheWarfighter
 * Stores an expiring area report without revealing or tracking a target object.
 * Voice fallback reselects a combat-effective member at both ends after queued delivery;
 * an incapable/dead native leader supplies no voice origin. This does not qualify radio.
 * Both live mission friendship directions must be at least0.6, including after queued delivery.
 * A one-way alliance or a relationship change cannot inherit earlier sharing permission.
 * Delivery rechecks both radio endpoints; nearby voice communication remains possible
 * when either endpoint is jammed. Voice uses3D ASL separation; radio radius remains horizontal.
 * Mounted receivers use the same eligibility contract.
 * Locality/authority: server validates shared assignments; commands run only on the current AI owner.
 * Repeat/JIP: storage and expiry retain original finite observation time, not relay time;
 * older/duplicate sightings cannot replace fresher evidence. Among newer sightings, prefer
 * the first within the receiver profile investigation range; otherwise retain sender priority.
 * No historical JIP commands replay.
 * Arguments: 0 receiver GROUP grpNull; 1 sender GROUP grpNull; 2 reports ARRAY []:
 * at most3 [ATL position ARRAY of3 finite NUMBERs, confidence NUMBER0..4,
 * original observed server time NUMBER>=0, reported contact SIDE west/east/resistance]; 3 sent server time NUMBER -1 (invalid default).
 * Return Value: Nothing.
 * Current callers: CBE_fnc_CortexReportServer queued owner delivery.
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
private _senderAnchor=if (isNull _transmitter) then {[_sender,false] call CBE_fnc_CortexGroupTransmitter} else {_transmitter};
private _receiverAnchor=if (isNull _receiverTransmitter) then {[_receiver,false] call CBE_fnc_CortexGroupTransmitter} else {_receiverTransmitter};
if (isNull _senderAnchor || {isNull _receiverAnchor}) exitWith {};
private _senderPosition = getPosASL _senderAnchor;
private _receiverPosition = getPosASL _receiverAnchor;
if ((side _receiver) getFriend (side _sender) < 0.6
    || {(side _sender) getFriend (side _receiver) < 0.6}
    || {_receiverPosition distance2D _senderPosition > _range}
    || {_receiverPosition vectorDistance _senderPosition > _voiceRange
        && {isNull _transmitter || {isNull _receiverTransmitter}}}) exitWith {};
private _valid=(_reports select [0,3]) select {
    _x isEqualType [] && {count _x == 4} && {(_x select 0) isEqualType []} && {count (_x select 0) == 3}
        && {(_x select 0) findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} < 0}
        && {(_x select 3) isEqualType west} && {(_x select 3) in [west,east,resistance]}
        && {(side _receiver) getFriend (_x select 3) < 0.6}
        && {(_x select 1) isEqualType 0} && {finite (_x select 1)} && {(_x select 1) >= 0} && {(_x select 1) <= 4}
        && {(_x select 2) isEqualType 0} && {finite (_x select 2)} && {(_x select 2) >= 0}
        && {(_x select 2) <= serverTime} && {(_x select 2) <= _sent+1} && {serverTime < (_x select 2)+30}
};
private _previous = _receiver getVariable ["CBE_AIPass_AreaReport",[]];
private _previousObserved=-1;
if (_previous isEqualType [] && {count _previous == 4}
    && {(_previous select 1) isEqualType 0} && {finite (_previous select 1)}) then {
    _previousObserved=_previous select 1;
};
// Preserve sender priority among genuinely newer rows. An old first row must not
// suppress a fresh sighting later in this same bounded batch.
private _newIndex=_valid findIf {(_x select 2) > _previousObserved};
if (_newIndex < 0) exitWith {};
// Prefer a report this receiver can investigate over an unreachable first contact.
// Keep sender priority inside that set and retain the original fallback when none qualify.
// This is attention selection only; GroupTick still owns all actual task admission.
private _investigationPreference=[_receiver,"investigateChance"] call CBE_fnc_CortexProfile;
private _investigationRange=(missionNamespace getVariable ["CBE_AIPass_Investigate_Range",300])
    * (0.5+0.5*_investigationPreference);
private _actionableIndex=_valid findIf {(_x select 2) > _previousObserved
    && {_investigationPreference > 0}
    && {leader _receiver distance2D (_x select 0) <= _investigationRange}};
if (_actionableIndex >= 0) then {_newIndex=_actionableIndex};
private _best = _valid select _newIndex;
private _observed=_best select 2;
_receiver setVariable ["CBE_AIPass_AreaReport",[+(_best select 0),_observed,_observed+30,"REPORT"],true];
