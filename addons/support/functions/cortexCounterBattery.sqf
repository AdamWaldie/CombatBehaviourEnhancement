/*
 * Author: WaldoTheWarfighter
 * Acquires finite counter-battery fixes through registered radar coverage or fresh owner-local observers.
 * Locality/authority: server consumes the global firing event; guns execute on their owners.
 * Repeat/JIP: server event cooldown and per-side request cooldown prevent duplicate responses across HCs.
 * Pending cooldowns and delayed fixes/wakes retain the original server counter-battery
 * generation and original server observation time; disabling/re-enabling cannot revive old observations or renew their delay.
 * Arguments: 0: firing vehicle <OBJECT>, objNull; 1: gunner <OBJECT>, objNull.
 * Return Value: Boolean, detection processed.
 * Current callers: ArtilleryShellFired handler.
 * Example: [_vehicle, gunner _vehicle] call CBE_fnc_CortexCounterBattery;
 */
params [["_vehicle", objNull, [objNull]], ["_gunner", objNull, [objNull]]];
if (!isServer || {isNull _vehicle} || {!(missionNamespace getVariable ["CBE_AIPass_CounterBattery_Enable", false])}
    || {[] call CBE_fnc_CortexIsPaused}) exitWith {false};
private _observedAt=serverTime;
private _counterGeneration=missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0];
private _position = getPosATL _vehicle;
// Private raw event evidence is not actionable relocation knowledge; qualified side receipts below are.
_vehicle setVariable ["CBE_AIPass_LastEmission", [time, +_position]];
private _eventDue=time >= (_vehicle getVariable ["CBE_AIPass_CounterEventAt", -1]);
if (_eventDue) then {
    _vehicle setVariable ["CBE_AIPass_CounterEventAt", time + ((missionNamespace getVariable ["CBE_AIPass_CounterBattery_Interval", 60]) max 10)];
};
private _enemySide = side group _gunner;
private _sides = [];
{
    private _side = side group gunner _x;
    if (alive gunner _x && {_side getFriend _enemySide < 0.6} && {[_x, "COUNTER"] call CBE_fnc_CortexArtilleryRole}) then {_sides pushBackUnique _side};
} forEach (missionNamespace getVariable ["CBE_AIPass_AllArtillery", []]);
{
    private _side = _x;
    private _pendingKey = "CBE_AIPass_CounterPending_" + str _side;
        private _sideKey = switch (_side) do {case west: {"WEST"}; case east: {"EAST"}; case independent: {"GUER"}; default {"CIV"}};
        private _radar = (missionNamespace getVariable ["CBE_AIPass_CounterBatteryRadars", []]) findIf {
            _x params ["_object", "_radarSide"];
            alive _object && {_radarSide == _sideKey} && {_object distance2D _position <= (missionNamespace getVariable ["CBE_AIPass_CounterBattery_RadarRange", 8000])}
        } >= 0;
        if (_radar) then {
            _vehicle setVariable ["CBE_AIPass_DetectedEmission_" + str _side,[serverTime,+_position,30,"RADAR"]];
        };
    // Pending responses are bound to the original counter-battery session. A disabled
    // generation cannot block a fresh emission after re-enable or revive its old callback.
    private _pending=_vehicle getVariable [_pendingKey,[]];
    private _pendingReady=_pending isEqualTo [] || {_pending isEqualType [] && {count _pending == 2}
        && {(_pending select 0) isEqualType 0} && {finite (_pending select 0)}
        && {(_pending select 1) isEqualType 0} && {finite (_pending select 1)}
        && {(_pending select 0) != _counterGeneration || {time >= (_pending select 1)}}};
    // Observation remains available while a response is active; only admission is cooled down.
    if (_eventDue && {_radar} && {_pendingReady}
        && {time >= (_vehicle getVariable ["CBE_AIPass_CounterUntil_" + str _side, -1])}) then {
        private _normalDelay = (missionNamespace getVariable ["CBE_AIPass_CounterBattery_Delay", 60]) max 1;
        private _delay = if (_radar) then {((missionNamespace getVariable ["CBE_AIPass_CounterBattery_RadarDelay", 20]) max 1) min _normalDelay} else {_normalDelay};
        _vehicle setVariable [_pendingKey,[_counterGeneration,time+_delay+1]];
        [{
            params ["_vehicle", "_side", "_position", "_generation", "_observedAt"];
            if (_generation != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration", 0])) exitWith {};
            if (isNull _vehicle || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])}
                || {!(missionNamespace getVariable ["CBE_AIPass_CounterBattery_Enable", false])}
                || {[] call CBE_fnc_CortexIsPaused}) exitWith {};
            {
                if (side group gunner _x == _side && {
                    [_x, _position, 30, "HE", missionNamespace getVariable ["CBE_AIPass_CounterBattery_Rounds", 4],
                        missionNamespace getVariable ["CBE_AIPass_CounterBattery_ShootAndScoot", true], "COUNTER", objNull, _vehicle,grpNull,_observedAt] call CBE_fnc_CortexArtilleryFire
                }) exitWith {};
            } forEach (missionNamespace getVariable ["CBE_AIPass_AllArtillery", []]);
        }, [_vehicle, _side, +_position, _counterGeneration, _observedAt], _delay] call CBA_fnc_waitAndExecute;
    };
} forEach _sides;
// An uncovered emission wakes observers; it never grants them the hidden gun position.
// Their cached local roster and native knowledge/visibility/transmission gates establish the fix.
if (_eventDue && {_sides isNotEqualTo []}) then {
    [{
        params ["_vehicle","_generation"];
        if (_generation != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])
            || {isNull _vehicle} || {!alive _vehicle}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
            || {!(missionNamespace getVariable ["CBE_AIPass_CounterBattery_Enable",false])}
            || {[] call CBE_fnc_CortexIsPaused}) exitWith {};
        [_vehicle] remoteExecCall ["CBE_fnc_CortexCounterObserve",0];
    },[_vehicle,_counterGeneration],
        (missionNamespace getVariable ["CBE_AIPass_CounterBattery_Delay",60]) max 1] call CBA_fnc_waitAndExecute;
};
true
