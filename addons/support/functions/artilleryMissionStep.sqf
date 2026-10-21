/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes one bounded artillery implementation step and reports its semantic phase to the finite mission FSM.
 * Locality / Authority: Server only through CBE's shared scheduler. Battery and observer owners still execute checked physical commands through existing callbacks.
 * Execution: Ended/invalid FSM handles retire the callback only, without cleanup,
 * replay, phase changes or new deadlines. Existing bounded executor recovery remains owner.
 * Repeat/JIP: One-shot callback. Exact token, generation, brain identity and mission registry identity reject stale work; no fire command is retried after an uncertain result.
 * Relocation observes only the original group/session within its original finite observation window.
 * Retirement reports observation ended/expired, not physical arrival; no movement is reissued.
 * Arguments: 0 artillery brain <HASHMAP>.
 * Return Value: Number - always -1 because the FSM owns later scheduling.
 * Current caller: CBE_fnc_ArtilleryMissionQueue through CBE_fnc_CortexQueueJob.
 * Example: [_brain] call CBE_fnc_ArtilleryMissionStep;
 */
params [["_brain",createHashMap,[createHashMap]]];
private _battery=_brain getOrDefault ["battery",objNull];
private _generation=_brain getOrDefault ["generation",-1];
private _mission=_brain getOrDefault ["mission",createHashMap];
private _token=_brain getOrDefault ["token",""];
private _cancel={
    params ["_reason"];
    _brain set ["pending",false];
    _brain set ["completed",true];
    _brain set ["finished",true];
    _brain set ["cancelled",true];
    _brain set ["cancelReason",_reason];
    -1
};
if (_brain getOrDefault ["cancelled",false] || {_brain getOrDefault ["finished",false]}) exitWith {[_brain getOrDefault ["cancelReason","CANCELLED"]] call _cancel};
if (!isServer || {isNull _battery} || {count _mission == 0}) exitWith {["INVALID_MISSION"] call _cancel};
if (_generation != (_battery getVariable ["CBE_Artillery_BrainGeneration",-2])
    || {(_battery getVariable ["CBE_Artillery_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {["REPLACED"] call _cancel};
// Only a live FSM may consume this queued execution callback. The existing
// discovery/restart path retains the original job, leases and phase deadlines.
private _executor=_battery getVariable ["CBE_Artillery_Brain_FSM",-1];
if (!(_executor isEqualType 0) || {!finite _executor} || {_executor < 0} || {completedFSM _executor}) exitWith {
    _brain set ["pending",false];_brain set ["completed",true];-1
};
private _semantic=toUpperANSI (_brain getOrDefault ["phase","REQUESTED"]);
private _registered=createHashMap;
if (_semantic != "RELOCATING") then {
    private _key=_mission getOrDefault ["key",""];
    _registered=(missionNamespace getVariable ["CBE_AIPass_FireMissions",createHashMap]) getOrDefault [_key,createHashMap];
};
if (_semantic != "RELOCATING" && {_registered isNotEqualTo _mission || {(_mission getOrDefault ["token",""]) != _token}}) exitWith {["MISSION_RELEASED"] call _cancel};
// Observation may outlive the fire registry, never its original scoot identity.
// It neither commands movement nor treats executor/metadata retirement as arrival.
private _observeRelocation={
    private _session=_mission getOrDefault ["scootSession",[]];
    private _observeUntil=_mission getOrDefault ["scootObserveUntil",-1];
    if (!(_session isEqualType []) || {count _session != 7} || {(_session param [0,""]) != _token}
        || {!(_observeUntil isEqualType 0)} || {!finite _observeUntil}
        || {serverTime >= _observeUntil}) exitWith {[false,"RELOCATION_OBSERVER_EXPIRED"]};
    private _seats=[driver _battery,effectiveCommander _battery];
    if (isNull (_seats select 1)) then {_seats set [1,_seats select 0]};
    if ((_session select 6) isNotEqualTo _seats) exitWith {[false,"RELOCATION_CREW_CHANGED"]};
    private _crewGroup=_mission getOrDefault ["scootGroup",grpNull];
    if (isNull _crewGroup || {group driver _battery != _crewGroup}) exitWith {[false,"RELOCATION_CREW_CHANGED"]};
    private _pending=(_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token
        && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo _session}
        && {serverTime < (_session param [3,-1])};
    private _operation=_crewGroup getVariable ["CBE_Operation",createHashMap];
    private _moving=count _operation > 0 && {(_operation getOrDefault ["intent",""]) == "ARTILLERY_SCOOT"}
        && {(_operation getOrDefault ["artilleryScootSession",[]]) isEqualTo [_battery,_session]};
    [_pending || {_moving},"RELOCATION_ENDED"]
};
private _delay=-1;
if (_semantic == "RELOCATING") then {
    private _observation=call _observeRelocation;
    if (_observation select 0) then {_delay=2} else {_brain set ["finished",true];_brain set ["cancelReason",_observation select 1]};
} else {
    _delay=[_mission] call CBE_fnc_CortexArtilleryMissionStep;
    private _nativePhase=toUpperANSI (_mission getOrDefault ["phase","WAIT"]);
    _semantic=switch true do {
        case (_nativePhase == "POSITIONING"): {"POSITIONING"};
        case (_nativePhase in ["READY","WARNED"]): {"WARNING"};
        case (_nativePhase in ["PENDING","FIRING","UNCERTAIN"]): {"FIRING"};
        default {"REQUESTED"};
    };
    if (_delay < 0) then {
        private _observation=call _observeRelocation;
        if (_observation select 0) then {
            _semantic="RELOCATING";
            _delay=1;
        } else {
            _brain set ["finished",true];
            _brain set ["cancelReason",["COMPLETE","UNCERTAINTY_PARKED"] select (_mission getOrDefault ["parked",false])];
            if (_mission getOrDefault ["parked",false]) then {_semantic="QUARANTINED"};
        };
    };
};
_brain set ["phase",_semantic];
_brain set ["lastStepAt",time];
_brain set ["lastDelay",_delay];
_brain set ["pending",false];
_brain set ["completed",true];
if (_delay >= 0) then {_brain set ["nextAt",time+_delay]};
_battery setVariable ["CBE_Artillery_Brain_State",[
    _semantic,_generation,serverTime,_brain getOrDefault ["cancelReason",""],_delay,_mission getOrDefault ["phase","RELEASED"]
],true];
-1
