/*
 * Author: WaldoTheWarfighter
 * Checks the cached assigned observers for an actual counter-battery sighting.
 * Locality/authority: accepts only a server request on server/headless machines; observers must be local.
 * Repeat/JIP: finite 15-second owner-local scan; execution rechecks pause/activation and per-observer gates. Original server generation/deadline survive delivery and scanning; per-target/side cooldown deduplicates replies; no JIP replay.
 * Arguments: 0: firing vehicle <OBJECT>, objNull; 1: server counter generation <NUMBER>, -1;
 * 2: original server scan deadline <NUMBER>, -1. Missing/stale envelopes refuse.
 * Return Value: Nothing.
 * Current callers: CortexCounterBattery after emission acquisition delay and explicit server-script observation requests.
 * Example: [_enemyGun, missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0], serverTime+15] remoteExecCall ["CBE_fnc_CortexCounterObserve", 0];
 */
params [["_enemy", objNull, [objNull]], ["_generation",-1,[0]], ["_deadline",-1,[0]]];
if (remoteExecutedOwner != 2 || {hasInterface && {!isServer}}
    || {!finite _generation} || {_generation < 0} || {_generation != floor _generation}
    || {_generation != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])}
    || {!finite _deadline} || {_deadline <= serverTime} || {_deadline > serverTime+15}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])} || {[] call CBE_fnc_CortexIsPaused}) exitWith {};
[{
    params ["_job"];
    private _enemy = _job get "enemy";
    if (!alive _enemy || {serverTime >= (_job get "deadline")}
        || {(_job get "generation") != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])}
        || {[] call CBE_fnc_CortexIsPaused}
        || {!(missionNamespace getVariable ["CBE_AIPass_CounterBattery_Enable", false])}) exitWith {-1};
    private _spotters = _job get "spotters";
    private _cursor = _job get "cursor";
{
    private _fix = if ([group _x, "CBE_AIPass_CounterBattery_Enable", false] call CBE_fnc_CortexFeatureEnabled) then {
        [_x, _enemy] call CBE_fnc_CortexSpotterFix
    } else {[]};
    if (_fix isNotEqualTo [] && {(_fix select 1) <= (missionNamespace getVariable ["CBE_AIPass_CounterBattery_MaxError", 100])}) then {
        private _knowledge=_x targetKnowledge _enemy;
        private _observedAt=serverTime-((time-(_knowledge select 2)) max 0);
        [objNull, _fix select 0, _fix select 1, "HE", missionNamespace getVariable ["CBE_AIPass_CounterBattery_Rounds", 4],
            missionNamespace getVariable ["CBE_AIPass_CounterBattery_ShootAndScoot", true], "COUNTER", _x, _enemy, grpNull, _observedAt, _job get "generation"] call CBE_fnc_CortexArtilleryFire;
    };
} forEach (_spotters select [_cursor, 4]);
    _cursor = _cursor + 4;
    _job set ["cursor", _cursor];
    [1, -1] select (_cursor >= count _spotters)
}, createHashMapFromArray [["enemy", _enemy], ["deadline", _deadline], ["generation", _generation], ["spotters", +(missionNamespace getVariable ["CBE_AIPass_LocalSpotters", []])], ["cursor", 0]], 0] call CBE_fnc_CortexQueueJob;
