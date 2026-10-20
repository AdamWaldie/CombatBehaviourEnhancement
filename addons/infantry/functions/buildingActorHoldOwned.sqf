/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe whether a stopped clearance actor remains at this job's recorded hold.
 * Locality/authority: Read-only actor/group owner. Callers retain generation, task and native
 * command authority; settings ownership alone is never proof of a movement hold.
 * Repeat/JIP: No writes, requests or replay. Resume may use the exact portable HOLD context.
 * Arguments: 0 actor <OBJECT, objNull>; 1 clearance job <HASHMAP, empty>.
 * Return: BOOL - current STOP at a recorded same-floor hold, never general movement permission.
 * Cost: At most four recorded positions, one current pose, no geometry query/timer/worker.
 * Current callers: BuildingOperationStep, CortexClearRelease, GroupBrainStep and CortexReleaseGroup.
 * Example: private _held=[soldier1,_job] call CBE_fnc_BuildingActorHoldOwned;
 */
params [["_actor",objNull,[objNull]],["_job",createHashMap,[createHashMap]]];
private _group=_job getOrDefault ["group",grpNull];
if (isNull _actor || {!local _actor} || {isNull _group} || {!local _group}
    || {group _actor != _group} || {!isNull objectParent _actor}
    || {toUpperANSI currentCommand _actor != "STOP"}) exitWith {false};
private _key=netId _actor;
private _posts=[
    (_job getOrDefault ["nativeHoldPositions",createHashMap]) getOrDefault [_key,[]],
    (_job getOrDefault ["roomHolds",createHashMap]) getOrDefault [_key,[]],
    (_job getOrDefault ["formationFallbackHolds",createHashMap]) getOrDefault [_key,[]]
];
private _receipt=_actor getVariable ["CBE_Cortex_ClearMotion",[]];
private _context=_job getOrDefault ["visitContext",[]];
if (_receipt isEqualType [] && {count _receipt == 5} && {count _context == 4}
    && {(_receipt select 0) isEqualTo _group} && {(_receipt select 1) isEqualTo _context}
    && {(_receipt select 2) == "HOLD"}) then {_posts pushBack (_receipt select 3)};
private _pose=getPosASL _actor;
_posts findIf {
    _x isEqualType [] && {count _x == 3} && {_x findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {_pose vectorDistance (AGLToASL _x) <= 1.5}
        && {abs ((_pose select 2)-((AGLToASL _x) select 2)) <= 0.75}
} >= 0
