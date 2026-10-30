/*
 * Author: WaldoTheWarfighter
 * Purpose: Share native AA warnings and allocate finite point-defence responders in one group.
 * Locality/authority: Group/crew owner only. Native observer NOTICE contributes exact warning
 * provenance; STEP may invoke existing current-owner interceptor admission, never direct fire.
 * Repeat/JIP: Eight tracks retain first warning expiry<=8s. One coalesced finite3s planner/group,
 * <=64 roster actors/16 unique AA platforms/one start attempt per callback. Coverage ownership
 * is sampled once across those platforms per callback, then compared for at most8 warnings.
 * One platform per scheduler visit with zero added delay; lower-FPS/budget deferral still applies.
 * Three-second pass limit and native warning expiry both stop admission. Cached transmitter
 * reads expire after one second; longer allocation never grants a longer communication permission.
 * The ephemeral sample grants no fire permission and is never retained. No world scan/replay.
 * Existing active responses are never retargeted or renewed. Overflow refuses new tracks.
 * Urgent approach ranks first; equal-urgency warnings prefer this responder as victim,
 * then fewer existing responders and shorter approach time. Coverage counts only unfinished
 * responses retaining their original local gunner and exact fire lease. Only native warnings contribute.
 * Arguments: 0 mode STRING,NOTICE; 1 input OBJECT or HASHMAP,objNull (vehicle or planner state).
 * Return: NOTICE BOOL; STEP NUMBER next delay or -1, not assignment/fire/interception proof.
 * Current caller: CortexAAObserve IncomingMissile and its existing scheduler adapter.
 * Example: ["NOTICE",_vehicle] call CBE_fnc_CortexAAAllocate;
 */
params [["_mode","NOTICE",[""]],["_input",objNull,[objNull,createHashMap]]];
private _group=if (_input isEqualType objNull) then {group gunner _input} else {_input getOrDefault ["group",grpNull]};
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,"CBE_AIPass_AAIntercept_Enable",false] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group] call CBE_fnc_CortexIsEligible)}) exitWith {[-1,false] select (_mode != "STEP")};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _registry=_group getVariable ["CBE_AA_WarningTracks",[clientOwner,_epoch,[]]];
private _tracks=if ((_registry select 0) == clientOwner && {(_registry select 1) == _epoch}) then {
    (_registry select 2) select {
        !isNull (_x select 4) && {alive (_x select 4)} && {serverTime < (_x select 3)}
            && {[_x select 4,_group,_x select 5] call CBE_fnc_CortexAAThreat}
            && {!isNull (_x select 6)} && {alive (_x select 6)} && {group gunner (_x select 6) == _group}
    }
} else {[]};
if (_mode == "NOTICE") exitWith {
    if (!(_input isEqualType objNull) || {isNull _input} || {!local _input}
        || {!([_input] call CBE_fnc_CortexAirDefenceRole)}) exitWith {false};
    private _warning=_input getVariable ["CBE_AA_MissileWarning",[]];
    if (count _warning != 6 || {(_warning select 0) != clientOwner} || {(_warning select 1) != _group}
        || {(_warning select 2) != _epoch} || {serverTime >= (_warning select 3)}
        || {!([_warning select 4,_group,_warning select 5] call CBE_fnc_CortexAAThreat)}) exitWith {false};
    private _missile=_warning select 4;
    // Keep first sighting lifetime on the exact projectile, so pruning an expired
    // group track cannot let a duplicate native warning renew the same episode.
    private _lifetimes=_missile getVariable ["CBE_AA_WarningLifetimes",[]];
    private _known=_lifetimes findIf {(_x select 0) == clientOwner && {(_x select 1) == _group} && {(_x select 2) == _epoch}};
    private _firstExpiry=serverTime+8;
    if (_known >= 0) then {_firstExpiry=(_lifetimes select _known) select 3} else {
        if (count _lifetimes >= 8) exitWith {_firstExpiry=-1};
        _lifetimes pushBack [clientOwner,_group,_epoch,_firstExpiry];
        _missile setVariable ["CBE_AA_WarningLifetimes",_lifetimes];
    };
    if (serverTime >= _firstExpiry) exitWith {false};
    private _added=false;
    if (_tracks findIf {(_x select 4) == _missile} < 0) then {
        if (count _tracks < 8) then {
            private _track=+_warning;_track set [3,(_track select 3) min _firstExpiry];
            _track pushBack _input;_track pushBack [];_tracks pushBack _track;_added=true;
        };
    };
    _group setVariable ["CBE_AA_WarningTracks",[clientOwner,_epoch,_tracks]];
    if (_tracks isEqualTo []) exitWith {false};
    private _plan=_group getVariable ["CBE_AA_Allocation",createHashMap];
    private _freshPlan=count _plan == 0 || {_plan getOrDefault ["finished",false]}
        || {(_plan getOrDefault ["ownerEpoch",-1]) != _epoch};
    if (_freshPlan && {!_added}) exitWith {false};
    if (_freshPlan) then {
        private _serial=(_group getVariable ["CBE_AA_AllocationSerial",0])+1;
        _group setVariable ["CBE_AA_AllocationSerial",_serial];
        _plan=createHashMapFromArray [["group",_group],["ownerEpoch",_epoch],["generation",_serial],
            ["until",time+3],["cursor",0],["vehicles",[]],["linkCache",[]],["linkCacheUntil",time+1],["initialised",false],["replan",false]];
        _group setVariable ["CBE_AA_Allocation",_plan];
    } else {
        if (_added) then {_plan set ["replan",true]};
    };
    [{params ["_job"];["STEP",_job] call CBE_fnc_CortexAAAllocate},_plan,0,
        format ["AA_ALLOCATE:%1",netId _group]] call CBE_fnc_CortexQueueJob;
    true
};
if (_mode != "STEP" || {!(_input isEqualType createHashMap)}) exitWith {-1};
private _plan=_input;
private _finish={
    // An expired but unobserved planner keeps its queued identity. Only a NEW
    // canonical warning may request a subsequent pass, after this one retires.
    if ((_plan get "ownerEpoch") == _epoch && {_plan getOrDefault ["replan",false]}
        && {_tracks isNotEqualTo []}) exitWith {
        _plan set ["replan",false];_plan set ["until",time+3];_plan set ["cursor",0];
        _plan set ["vehicles",[]];_plan set ["linkCache",[]];_plan set ["linkCacheUntil",time+1];
        _plan set ["initialised",false];
        0
    };
    _plan set ["finished",true];-1
};
if ((_plan getOrDefault ["ownerEpoch",-1]) != _epoch || {time >= (_plan get "until")}
    || {_tracks isEqualTo []}) exitWith {call _finish};
// A longer finite pass must not stretch the old one-second radio-hook cache.
// Admission and active interception still recheck the live link without this cache.
if (time >= (_plan getOrDefault ["linkCacheUntil",0])) then {
    _plan set ["linkCache",[]];_plan set ["linkCacheUntil",time+1];
};
if !(_plan get "initialised") then {
    private _vehicles=[];
    {
        private _vehicle=vehicle _x;private _gunner=gunner _vehicle;
        if (_vehicle isKindOf "LandVehicle" && {local _vehicle} && {!isNull _gunner}
            && {local _gunner} && {group _gunner == _group}
            && {[_vehicle] call CBE_fnc_CortexAirDefenceRole}) then {
            _vehicles pushBackUnique _vehicle;
        };
        if (count _vehicles >= 16) exitWith {};
    } forEach ((units _group) select [0,64]);
    _plan set ["vehicles",_vehicles];_plan set ["initialised",true];
};
private _vehicles=_plan get "vehicles";private _cursor=_plan get "cursor";
if (_cursor >= count _vehicles) exitWith {call _finish};
private _vehicle=_vehicles select _cursor;_plan set ["cursor",_cursor+1];
// One callback-local coverage sample avoids repeating crew/lease checks for each
// warning. It is a ranking hint only; START retains fresh executor admission.
private _coverageMissiles=[];
{
            private _active=_x getVariable ["CBE_AA_Intercept",createHashMap];
            if (_x != _vehicle && {_active isEqualType createHashMap} && {count _active > 0}
                && {!(_active getOrDefault ["finished",false])}
                && {time < (_active get "until")}
                && {(_active get "ownerEpoch") == _epoch}
                && {alive _x} && {local _x}
                && {[_x] call CBE_fnc_CortexAirDefenceRole}
                && {private _coverageGunner=_active getOrDefault ["gunner",objNull];
                    !isNull _coverageGunner && {alive _coverageGunner} && {local _coverageGunner}
                        && {gunner _x == _coverageGunner} && {group _coverageGunner == _group}
                        && {(_coverageGunner getVariable ["CBE_AA_InterceptOwner",[]])
                            isEqualTo [_active get "token",_active get "until"]}
                }) then {
                _coverageMissiles pushBack (_active getOrDefault ["missile",objNull]);
            };
} forEach _vehicles;
private _ranked=[];
{
    private _trackIndex=_forEachIndex;
    private _missile=_x select 4;private _victim=_x select 6;
    if (_vehicle distance _missile <= 1500 && {!(_vehicle in (_x select 7))}
        && {[_vehicle,gunner _vehicle,_group,_victim,_plan get "linkCache"] call CBE_fnc_CortexAAWarningLink}
        && {[_missile,_group,_x select 5] call CBE_fnc_CortexAAThreat}) then {
        private _position=(getPosASL _missile) vectorDiff (getPosASL _victim);
        private _velocity=(velocity _missile) vectorDiff (velocity _victim);
        private _squared=_velocity vectorDotProduct _velocity;
        private _time=if (_squared > 0.01) then {-(_position vectorDotProduct _velocity)/_squared} else {-1};
        private _miss=if (_time > 0) then {vectorMagnitude (_position vectorAdd (_velocity vectorMultiply _time))} else {1e9};
        // Relative 3D approach, never altitude-only crossing. Native warning still
        // permits a bounded response when its present trajectory is uncertain.
        private _urgent=_time > 0 && {_time <= 2} && {_miss <= 30};
        private _coverage={_x isEqualTo _missile} count _coverageMissiles;
        // Urgency remains first; within that class protect this responder before
        // another asset, then spread remaining coverage. Never retarget active episodes.
        _ranked pushBack [[1,0] select _urgent,[1,0] select (_victim == _vehicle),
            _coverage,if (_time > 0) then {_time min 9} else {10},_trackIndex];
    };
} forEach _tracks;
_ranked sort true;
if (_ranked isNotEqualTo []) then {
    private _warning=_tracks select ((_ranked select 0) select 4);
    if ([_vehicle,"START",[_warning]] call CBE_fnc_CortexAAIntercept) then {
        // One automatic start/platform/native warning. New planner wakes cannot reset
        // that platform's original shot/step budgets after a terminal response.
        (_warning select 7) pushBackUnique _vehicle;
    };
};
if ((_plan get "cursor") >= count _vehicles) exitWith {call _finish};
// No artificial wait between responders: the shared scheduler already invokes this
// bounded callback at most once per visit and rotates it behind other due work.
0
