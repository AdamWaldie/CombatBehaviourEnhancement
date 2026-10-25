/*
 * Author: WaldoTheWarfighter
 * Purpose: Request selected-gun retirement through the shared finite crew retirement executor.
 * Locality/authority: Trusted local maintenance or server cancellation; vehicle and original
 * group must both be local. A live exact worker receives release without a second executor.
 * A locality change or failed worker can resume STOPPING/RETURNING observation, never outward
 * movement. Crew, original native route and external-control gates remain in the worker.
 * Repeat/JIP: Exact token/serial/public reference, private owner/epoch/handle and original
 * deadlines. One exact retirement-FSM creation refusal may retry inside its original cleanup
 * window, retaining the saved phase/native observations. No other unresolved reason reopens.
 * Unresolved work stays reserved while any original crew member survives or the gun
 * is moving, unless its ended original worker has a positively observed recorded native return.
 * Once every original actor is dead/deleted and the gun is at rest, maintenance can
 * retire that exact reference without commands, replacement crew adoption or deadline renewal.
 * Arguments: 0 battery OBJECT,objNull; 1 token STRING,""; 2 serial NUMBER,-1.
 * Return: BOOL retirement worker active, not native stop, physical rest or returned authority.
 * Current callers: Position cancellation, CortexDiscover/CortexLocality maintenance and CortexStop.
 * Generic worker/reference/deadline retirement is delegated; artillery scoot-session cleanup stays here.
 * Example: [_battery,_token,_serial] call CBE_fnc_ArtilleryCrewMoveRetire;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_serial",-1,[0]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2})
    || {isNull _battery} || {!local _battery} || {_token == ""}) exitWith {false};
private _pending=false;
isNil {
    private _before=_battery getVariable ["CBE_ArtilleryCrew_Work",createHashMap];
    private _wasRetiring=(_before getOrDefault ["phase",""]) in ["RETURNING","UNRESOLVED"];
    _pending=[_battery,_token,_serial,["CBE_ArtilleryCrew_Work","CBE_ArtilleryCrew_Reference",
        "CBE_ArtilleryCrew_FSM","CBE_ArtilleryCrew_ExecutorSerial","ARTILLERY_CREW",
        "\z\cbe\addons\main\fsm\artilleryCrewMove.fsm"]] call CBE_fnc_VehicleCrewMoveRetire;
    private _work=_battery getVariable ["CBE_ArtilleryCrew_Work",createHashMap];
    if (_wasRetiring && {(_work getOrDefault ["token",""]) == _token}
        && {(_work getOrDefault ["serial",-2]) == _serial}
        && {(_work getOrDefault ["phase",""]) == "RETIRED"}
        && {(_work getOrDefault ["result",""]) in ["ORIGINAL_CREW_LOST_AT_REST","NATIVE_RETURN_OBSERVED_AFTER_WORKER","NATIVE_STOP_OBSERVED_AFTER_WORKER"]}) then {
            if ((_work getOrDefault ["kind","POSITION"]) == "SCOOT"
                && {(_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token}
                && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo (_work get "session")}) then {
                {_battery setVariable [_x,nil,true]} forEach ["CBE_Cortex_ArtilleryScootToken",
                    "CBE_Cortex_ArtilleryScootSession","CBE_Cortex_ArtilleryScootDeadline","CBE_Cortex_ArtilleryScootPurpose"];
            };
    };
};
_pending
