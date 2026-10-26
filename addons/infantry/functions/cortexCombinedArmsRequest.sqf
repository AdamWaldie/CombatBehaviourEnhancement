/*
 * Author: WaldoTheWarfighter
 * Publishes one fresh visual contact as a bounded combined-arms opportunity.
 * Samples at most16 reports and64 living group members. Fresh reported contacts within150m
 * of any sampled member take priority by nearest distance; otherwise retain report order.
 * Positions come from the existing knowledge receipt, never the hostile object transform.
 * Locality/authority: called on the observing group owner; the server validates and selects assets.
 * It never moves the requester, creates a rally point or waits for another arm to become ready.
 * Repeat/JIP: owner-local cooldown limits requests; opportunities expire and are not replayed to JIP.
 * Contact positions require exactly three finite numeric ATL components, each within +/-1e6m.
 * Invalid payloads reject before local cooldown or server reservation; no live-target fallback is used.
 * Arguments: 0: observing group <GROUP>; 1: group state <HASHMAP>; 2: visible contacts <ARRAY>.
 * Return Value: Boolean, true when a valid opportunity was sent to the server.
 * Current callers: CBE_fnc_CortexGroupTick.
 * Example: [_group,_state,_visible] call CBE_fnc_CortexCombinedArmsRequest;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_visible",[],[[]]]];
if (isNull _group || {!local _group} || {_visible isEqualTo []}) exitWith {false};
if (serverTime < (_state getOrDefault ["combinedArmsDue",0])) exitWith {false};
private _candidates=[];
{
    if (_x isEqualType []) then {
        private _contact=_x;
        private _target=_contact param [0,objNull,[objNull]];
        private _position=_contact param [1,[],[[]]];
        private _age=_contact param [2,1e6,[0]];
        private _confidence=_contact param [5,1,[0]];
        private _invalidPosition=count _position != 3
            || {_position findIf {!(_x isEqualType 0) || {!finite _x} || {abs _x > 1e6}} >= 0};
        if (!isNull _target && {alive _target} && {finite _age} && {_age >= 0} && {_age <= 5}
            && {finite _confidence} && {_confidence > 0} && {_confidence <= 4}
            && {!_invalidPosition}
            && {(side _group) getFriend side _target < 0.6}
            && {!captive _target} && {!(_target getVariable ["ace_captives_isSurrendering",false])}
            && {!(_target getVariable ["ace_captives_isHandcuffed",false])}) then {
            _candidates pushBack _contact;
        };
    };
} forEach (_visible select [0,16]);
if (_candidates isEqualTo []) exitWith {false};
private _memberPositions=[];
{
    if (!isNull _x && {alive _x}) then {_memberPositions pushBack getPosATL _x};
} forEach ((units _group) select [0,64]);
private _contact=_candidates select 0;
private _nearest=151;
{
    private _reportPosition=_x select 1;
    private _distance=1e9;
    {_distance=_distance min (_x distance2D _reportPosition)} forEach _memberPositions;
    if (_distance <= 150 && {_distance < _nearest}) then {
        _nearest=_distance;
        _contact=_x;
    };
} forEach _candidates;
private _target=_contact select 0;
private _position=_contact select 1;
private _age=_contact select 2;
private _confidence=_contact param [5,1,[0]];
_state set ["combinedArmsDue",serverTime+20+random 8];
[_group,_target,+_position,serverTime-_age,_confidence min 2.5] remoteExecCall ["CBE_fnc_CortexCombinedArmsServer",2];
true
