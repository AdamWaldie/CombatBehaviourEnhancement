/*
 * Author: WaldoTheWarfighter
 * Allows explicitly assigned observers in the requesting group to ask the server for cross-owner fire support.
 * Locality/authority: requesting group owner dispatches; the server validates and reserves batteries.
 * Repeat/JIP: mission tokens reject stale work; server state survives HC migration, not restart.
 * Arguments: 0: group <GROUP>; 1: state <HASHMAP>; 2: known enemies <ARRAY>, default [].
 * Return Value: Boolean, server accepted or an HC forwarded a request; no firing claim.
 * A synchronous server rejection uses the short retry cooldown; HC forwarding is not server acceptance.
 * Current callers: GroupTick.
 * Example: [_group, _state, _enemies] call CBE_fnc_CortexArtilleryRequest;
 */
params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]]];
if (!local _group || {[_state, "artillery"] call CBE_fnc_CortexCooldown}) exitWith {false};
private _spotters = (units _group) select {alive _x && {local _x} && {_x getVariable ["CBE_AIPass_Spotter", false]}};
private _sent = false;
{
    private _spotter = _x;
    {
        private _enemy = _x select 0;
        private _fix = [_spotter, _enemy] call CBE_fnc_CortexSpotterFix;
        if (_fix isNotEqualTo [] && {(_fix select 1) <= (missionNamespace getVariable ["CBE_AIPass_Artillery_MaxError", 50])}) exitWith {
            _sent = [objNull, _fix select 0, _fix select 1, "HE", -1, -1, "SUPPORT", _spotter, _enemy,grpNull,serverTime-((time-((_spotter targetKnowledge _enemy) select 2)) max 0)] call CBE_fnc_CortexArtilleryFire;
        };
    } forEach _enemies;
    if (_sent) exitWith {};
} forEach _spotters;
[_state, "artillery", [20, missionNamespace getVariable ["CBE_AIPass_Artillery_Cooldown", 120]] select _sent] call CBE_fnc_CortexCooldown;
_sent
