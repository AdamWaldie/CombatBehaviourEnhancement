/*
 * Author: WaldoTheWarfighter
 * Purpose: Compare native building entry and traversal with no WAIT addon loaded.
 * Locality/authority: Dedicated server owns comparison actors and physical sampling.
 * Repeat/JIP: One guarded run; joining clients do not restart fixtures. Actors and houses
 * are removed by the shared comparison before completion is published.
 * Arguments: None. Return value: Nothing.
 * Current callers: Staged nativebuildings initServer.sqf after observer Zeus assignment.
 * Example: Launch the nativebuildings focus with NativeBaseline enabled.
 */
if (!isServer || {missionNamespace getVariable ["WAIT_QA_NativeBuildingsRunning",false]}) exitWith {};
missionNamespace setVariable ["WAIT_QA_NativeBuildingsRunning",true];
private _failures=[];
private _check={
    params ["_id","_ok",["_detail",""]];
    diag_log format ["WAIT CORTEX QA|%1|%2|%3",_id,["FAIL","PASS"] select _ok,_detail];
    if (!_ok) then {_failures pushBack _id};
    private _results=missionNamespace getVariable ["WAIT_CortexQA_Results",[]];
    _results pushBack [_id,["FAIL","PASS"] select _ok];
    missionNamespace setVariable ["WAIT_CortexQA_Results",_results,true];
};
private _loaded=isClass (configFile >> "CfgPatches" >> "WAIT_AI_Tweaks_Main")
    || {isClass (configFile >> "CfgPatches" >> "WAIT_danger")};
["BUILD-NATIVE-addon-absent",!_loaded,
    getText (configFile >> "CfgVehicles" >> "O_Soldier_F" >> "fsmDanger")] call _check;
private _observerDeadline=time+10;
waitUntil {sleep 0.2; allPlayers findIf {!(_x isKindOf "HeadlessClient_F") && {!captive _x}} < 0 || {time >= _observerDeadline}};
private _observerSafe=allPlayers findIf {!(_x isKindOf "HeadlessClient_F") && {!captive _x}} < 0;
["BUILD-NATIVE-observer-noncombat",_observerSafe] call _check;
if (!_loaded && {_observerSafe}) then {
    private _phase={
        params ["_title","_expected",["_position",[],[[]]]];
        diag_log format ["WAIT NATIVE BUILDING PHASE: %1",[_title,_expected]];
        missionNamespace setVariable ["WAIT_CortexQA_Phase",[_title,_expected,_position,serverTime],true];
        sleep 8;
    };
    private _wait={false};
    [_check,_phase,_wait,true] call compile preprocessFileLineNumbers "cortexQABuildings.sqf";
};
missionNamespace setVariable ["WAIT_CortexQA_ServerDone",true,true];
diag_log format ["WAIT CORTEX QA SERVER COMPLETE: %1 finding(s) %2",count _failures,_failures];
