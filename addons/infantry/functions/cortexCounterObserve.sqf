/*
 * Author: WaldoTheWarfighter
 * Checks the cached assigned observers for an actual counter-battery sighting.
 * Locality/authority: accepts only a server request on server/headless machines; observers must be local.
 * Repeat/JIP: finite 15-second owner-local scan; execution rechecks pause/activation and per-observer gates. Server per-target/side cooldown deduplicates replies; no JIP replay.
 * Arguments: 0: firing vehicle <OBJECT>, objNull.
 * Return Value: Nothing.
 * Current callers: CortexCounterBattery after emission acquisition delay and explicit server-script observation requests.
 * Example: [_enemyGun] remoteExecCall ["WAIT_fnc_CortexCounterObserve", 0];
 */
params [["_enemy", objNull, [objNull]]];
if (remoteExecutedOwner != 2 || {hasInterface && {!isServer}}
    || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])} || {[] call WAIT_fnc_CortexIsPaused}) exitWith {};
[{
    params ["_job"];
    private _enemy = _job get "enemy";
    if (!alive _enemy || {serverTime > (_job get "deadline")}
        || {!(missionNamespace getVariable ["WAIT_AIPass_Active", false])}
        || {[] call WAIT_fnc_CortexIsPaused}
        || {!(missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Enable", false])}) exitWith {-1};
    private _spotters = _job get "spotters";
    private _cursor = _job get "cursor";
{
    private _fix = if ([group _x, "WAIT_AIPass_CounterBattery_Enable", false] call WAIT_fnc_CortexFeatureEnabled) then {
        [_x, _enemy] call WAIT_fnc_CortexSpotterFix
    } else {[]};
    if (_fix isNotEqualTo [] && {(_fix select 1) <= (missionNamespace getVariable ["WAIT_AIPass_CounterBattery_MaxError", 100])}) then {
        private _knowledge=_x targetKnowledge _enemy;
        private _observedAt=serverTime-((time-(_knowledge select 2)) max 0);
        [objNull, _fix select 0, _fix select 1, "HE", missionNamespace getVariable ["WAIT_AIPass_CounterBattery_Rounds", 4],
            missionNamespace getVariable ["WAIT_AIPass_CounterBattery_ShootAndScoot", true], "COUNTER", _x, _enemy, grpNull, _observedAt] call WAIT_fnc_CortexArtilleryFire;
    };
} forEach (_spotters select [_cursor, 4]);
    _cursor = _cursor + 4;
    _job set ["cursor", _cursor];
    [1, -1] select (_cursor >= count _spotters)
}, createHashMapFromArray [["enemy", _enemy], ["deadline", serverTime + 15], ["spotters", +(missionNamespace getVariable ["WAIT_AIPass_LocalSpotters", []])], ["cursor", 0]], 0] call WAIT_fnc_CortexQueueJob;
