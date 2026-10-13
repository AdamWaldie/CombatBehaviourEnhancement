/*
 * Author: WaldoTheWarfighter
 * Releases a pending round when its addressed owner confirms no firing command was issued.
 * Locality/authority: server only; the response must match the recorded owner and mission token.
 * Repeat/JIP: stale/repeated replies do nothing; no JIP replay.
 * Arguments: 0: battery <OBJECT>; 1: token <STRING>.
 * 2: reply owner <NUMBER>, default -1; HC callers supply clientOwner.
 * Return Value: Nothing.
 * Qualified replies wake a parked exact mission for finite settlement; no new shot is issued.
 * Current callers: ArtilleryShot rejection paths.
 * Example: [_gun, _token, clientOwner] remoteExecCall ["WAIT_fnc_CortexArtilleryRejected", 2];
 */
params ["_battery", "_token", ["_replyOwner",-1,[0]]];
if (!isServer) exitWith {};
private _mission = (missionNamespace getVariable ["WAIT_AIPass_FireMissions", createHashMap]) getOrDefault [netId _battery, createHashMap];
if (count _mission == 0 || {(_mission get "token") != _token}
    || {([_replyOwner,_mission getOrDefault ["gunOwner", -1]] call WAIT_fnc_HeadlessResolveSender) < 0}
    || {!((_mission get "phase") in ["PENDING", "UNCERTAIN"])}) exitWith {};
_mission set ["remaining", 0];
_mission set ["burstsLeft", 0];
_mission set ["phase", "WAIT"];
_mission set ["due", time];
_mission set ["scoot", false];

// A parked unresolved request has no active scheduler. Its qualified reply
// wakes the exact registered mission for finite settlement, never another shot.
if (_mission getOrDefault ["parked",false]) then {
    _mission set ["parked",false];
    _mission set ["deadline",(_mission get "due")+30];
    [_mission,0] call WAIT_fnc_ArtilleryMissionStart;
};
