/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one server-owned finite brain for an accepted CBE artillery or counter-battery mission.
 * Locality / Authority: Server only. The FSM owns mission persistence; battery-owner callbacks retain bounded observation and physical fire execution.
 * Repeat/JIP: The exact mission token reuses its brain. A newer token increments the generation and invalidates older queued work; missions are not replayed after restart.
 * Arguments: 0 fire mission <HASHMAP>; 1 initial delay <NUMBER>, default 0.
 * Return Value: Boolean - true when the exact mission has an active brain.
 * Current callers: CBE_fnc_CortexArtilleryFire and qualified parked-mission firing/rejection callbacks.
 * A repeat-safe server deletion handler releases only the deleted battery registry entry.
 * Example: [_mission,0] call CBE_fnc_ArtilleryMissionStart;
 */
params [["_mission",createHashMap,[createHashMap]],["_delay",0,[0]]];
if (!isServer || {count _mission == 0}) exitWith {false};
private _battery=_mission getOrDefault ["battery",objNull];
private _token=_mission getOrDefault ["token",""];
private _key=_mission getOrDefault ["key",""];
if (isNull _battery || {_token == ""} || {_key == ""}) exitWith {false};
private _registered=(missionNamespace getVariable ["CBE_AIPass_FireMissions",createHashMap]) getOrDefault [_key,createHashMap];
if (_registered isNotEqualTo _mission) exitWith {false};
// A parked request has no polling job. Deletion must still release its registry
// through one server event, with no world scan and no retained deleted-object key.
_battery setVariable ["CBE_Artillery_RegistryKey",_key];
if (isNil {missionNamespace getVariable "CBE_Artillery_DeletedEH"}) then {
    private _handler=addMissionEventHandler ["EntityDeleted",{
        params ["_entity"];
        private _key=_entity getVariable ["CBE_Artillery_RegistryKey",""];
        if (_key != "") then {
            private _missions=missionNamespace getVariable ["CBE_AIPass_FireMissions",createHashMap];
            private _record=_missions getOrDefault [_key,createHashMap];
            if (count _record > 0 && {(_record getOrDefault ["battery",objNull]) isEqualTo _entity}) then {
                _missions deleteAt _key;
            };
        };
    }];
    missionNamespace setVariable ["CBE_Artillery_DeletedEH",_handler];
};
private _current=_battery getVariable ["CBE_Artillery_Brain",createHashMap];
if (count _current > 0 && {(_current getOrDefault ["token",""]) == _token}
    && {!(_current getOrDefault ["cancelled",false])} && {!(_current getOrDefault ["finished",false])}) exitWith {true};
if (count _current > 0) then {_current set ["cancelled",true];_current set ["cancelReason","REPLACED"]};
private _generation=(_battery getVariable ["CBE_Artillery_BrainGeneration",0])+1;
private _brain=createHashMapFromArray [
    ["battery",_battery],["mission",_mission],["token",_token],["generation",_generation],
    ["phase","REQUESTED"],["pending",false],["completed",false],["finished",false],
    ["cancelled",false],["cancelReason",""],["nextAt",time+(_delay max 0)],
    ["lastStepAt",-1],["lastDelay",_delay max 0],["queuedAt",-1],["watchdogCount",0]
];
_battery setVariable ["CBE_Artillery_BrainGeneration",_generation];
_battery setVariable ["CBE_Artillery_Brain",_brain];
_battery setVariable ["CBE_Artillery_Brain_State",["REQUESTED",_generation,serverTime,"STARTED"],true];
private _handle=[_mission,_generation,_brain] execFSM "\z\cbe\addons\main\fsm\artilleryMission.fsm";
_battery setVariable ["CBE_Artillery_Brain_FSM",_handle];
true
