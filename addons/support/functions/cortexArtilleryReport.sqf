/*
 * Author: WaldoTheWarfighter
 * Accepts the pending observer result only from its expected and current owner.
 * Locality/authority: documented guards enforce server coordination and owner-local execution.
 * A TARGET_IGNORED refusal from that exact pending observer marks this mission for
 * normal finite retirement before another burst. It neither fabricates a fix nor cancels
 * already-fired shells; invalid/stale/refused-owner replies cannot set the veto.
 * Repeat/JIP: mission tokens reject stale work; server state survives HC migration, not restart.
 * Arguments: 0: battery <OBJECT>; 1: token <STRING>; 2: spotter <OBJECT>; 3: fix <ARRAY>.
 * 4: reply owner <NUMBER>, default -1; HC callers supply clientOwner.
 * 5: native observation server time <NUMBER>, default -1; missing/stale time cannot update the fix.
 * 6: refusal STRING, default empty; only TARGET_IGNORED with empty fix is supported.
 * 7: observation serial NUMBER, required; matches only this pending ranging exchange.
 * Return Value: Nothing.
 * Current callers: ArtilleryObserve.
 * Example: [_gun, _token, _spotter, [], clientOwner, -1, "", 1] remoteExecCall ["CBE_fnc_CortexArtilleryReport", 2];
 */
params ["_battery", "_token", "_spotter", "_fix", ["_replyOwner",-1,[0]], ["_observedAt",-1,[0]], ["_refusal","",[""]], ["_observationSerial",-1,[0]]];
if (!isServer || {isNull _battery}) exitWith {};
private _sender = [_replyOwner,owner _spotter] call CBE_fnc_HeadlessResolveSender;
private _mission = (missionNamespace getVariable ["CBE_AIPass_FireMissions", createHashMap]) getOrDefault [netId _battery, createHashMap];
if (count _mission == 0 || {(_mission get "token") != _token} || {(_mission get "phase") != "OBSERVE"}
    || {_spotter != (_mission get "spotter")} || {_sender != (_mission get "observerOwner")}
    || {_sender != owner _spotter}
    || {!finite _observationSerial} || {_observationSerial < 1} || {_observationSerial != floor _observationSerial}
    || {_observationSerial != (_mission getOrDefault ["observerSerial",-1])}) exitWith {};
if ((_mission getOrDefault ["observerVeto",""]) != "") exitWith {};
if (!(_refusal in ["","TARGET_IGNORED"])) exitWith {};
if (_refusal == "TARGET_IGNORED") exitWith {
    if (_fix isEqualTo []) then {_mission set ["observerVeto","TARGET_IGNORED"]};
};
if (count _fix == 2 && {finite _observedAt} && {_observedAt >= 0}
    && {_observedAt <= serverTime+1} && {serverTime-_observedAt <= 10}
    && {[_spotter] call CBE_fnc_CortexCombatEffective}
    && {simulationEnabled _spotter} && {!isObjectHidden _spotter} && {alive _spotter} && {_spotter getVariable ["CBE_AIPass_Spotter", false]}
    && {(_fix select 0) isEqualType []} && {count (_fix select 0) == 3} && {(_fix select 1) isEqualType 0}
    && {(_fix select 0) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {finite (_fix select 1)} && {(_fix select 1) >= 0}
    && {(_fix select 1) <= (missionNamespace getVariable [["CBE_AIPass_Artillery_MaxError", "CBE_AIPass_CounterBattery_MaxError"] select ((_mission get "purpose") == "COUNTER"), 50])}) then {
    _mission set ["fix", _fix];
    private _moved = (_fix select 0) distance2D (_mission get "location") >= (missionNamespace getVariable ["CBE_AIPass_Artillery_LocationResetDistance", 150]);
    if (_moved) then {
        _mission set ["location", +(_fix select 0)];
        _mission set ["offset", 300];
        _mission set ["opening", true];
        _mission set ["bearing", random 360];
    } else {
        if ((_mission get "burstsCompleted") > 0) then {
            _mission set ["offset", ((_mission get "offset") * 0.55) max 40];
            _mission set ["opening", false];
        };
    };
};
_mission set ["phase", "READY"];
