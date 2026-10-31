/*
 * Author: WaldoTheWarfighter
 * Requests one owner-local observation per ranging step and returns it to the server.
 * Locality/authority: documented guards enforce server coordination and owner-local execution.
 * An explicitly native-ignored enemy reports TARGET_IGNORED separately from a missing fix.
 * The authenticated pending mission can then stop future bursts; ordinary lost sight retains
 * its previous ranging policy. Already-fired shells are never recalled.
 * Repeat/JIP: mission tokens reject stale work; server state survives HC migration, not restart.
 * Arguments: 0: battery <OBJECT>; 1: token <STRING>; 2: spotter <OBJECT>; 3: enemy <OBJECT>; 4: last impact ATL <ARRAY>.
 * 5: observation serial NUMBER, required positive integer; binds one ranging exchange.
 * Return Value: Nothing.
 * Current callers: ArtilleryMissionStep.
 * Example: [_gun, _token, _spotter, _enemy, [], 1] remoteExecCall ["CBE_fnc_CortexArtilleryObserve", owner _spotter];
 */
params ["_battery", "_token", "_spotter", "_enemy", "_impact",["_observationSerial",-1,[0]]];
if (remoteExecutedOwner != 2 || {!local _spotter}
    || {!finite _observationSerial} || {_observationSerial < 1} || {_observationSerial != floor _observationSerial}) exitWith {};
private _refusal=if (!isNull _enemy && {(_spotter targetKnowledge _enemy) param [7,false,[true]]}) then {"TARGET_IGNORED"} else {""};
private _fix=if (_refusal == "") then {[_spotter, _enemy, _impact] call CBE_fnc_CortexSpotterFix} else {[]};
private _observedAt=-1;
if (_fix isNotEqualTo []) then {
    private _knowledge=_spotter targetKnowledge _enemy;
    _observedAt=serverTime-((time-(_knowledge select 2)) max 0);
};
[_battery, _token, _spotter, _fix, clientOwner, _observedAt, _refusal, _observationSerial] remoteExecCall ["CBE_fnc_CortexArtilleryReport", 2];
