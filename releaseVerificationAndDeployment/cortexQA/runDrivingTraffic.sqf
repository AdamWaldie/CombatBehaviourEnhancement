/*
 * Author: WaldoTheWarfighter
 * Purpose: Physically exercises ordinary traffic following behind a stopped tracked predecessor,
 * then departure, repeated stop/restart and a newer direct MOVE during blockage.
 * No controller callbacks or success state are injected.
 * Locality/authority: scheduled server creates separate disposable driver groups. Predecessor
 * native waypoint/speed holds are fixture inputs; the follower is discovered and driven by WAIT.
 * Repeat/JIP: fresh fixtures per call; tuning restored and all crews/vehicles/groups deleted.
 * Public actor labels support the audit observer; no historical command replay or HC transfer.
 * Arguments: 0 check <CODE>; 1 phase <CODE>; 2 wait <CODE>, required audit callbacks.
 * Return: Nothing. Physical results remain unrun until a fresh authorized vehicles batch.
 * Current callers: runServer.sqf vehicles/full focus, normal server-owner fixtures.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQADrivingTraffic.sqf";
 */
params ["_check","_phase","_wait"];
private _previous=createHashMapFromArray [
    ["WAIT_AIPass_Enable",missionNamespace getVariable ["WAIT_AIPass_Enable",true]],
    ["WAIT_AIPass_Contact_Enable",missionNamespace getVariable ["WAIT_AIPass_Contact_Enable",true]],
    ["WAIT_AIPass_DrivingAssist_Enable",missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_Enable",true]],
    ["WAIT_AIPass_DrivingAssist_MaxSpeed",missionNamespace getVariable ["WAIT_AIPass_DrivingAssist_MaxSpeed",70]]
];
[createHashMapFromArray [["WAIT_AIPass_Enable",true],["WAIT_AIPass_Contact_Enable",false],
    ["WAIT_AIPass_DrivingAssist_Enable",true],["WAIT_AIPass_DrivingAssist_MaxSpeed",70]]] call WAIT_fnc_CortexTuning;
private _front=createVehicle ["O_APC_Tracked_02_cannon_F",[4000,2150,0],[],0,"NONE"];
private _follower=createVehicle ["O_Truck_03_transport_F",[4000,2030,0],[],0,"NONE"];
_front setDir 0;_follower setDir 0;
createVehicleCrew _front;createVehicleCrew _follower;
private _frontGroup=group driver _front;private _followerGroup=group driver _follower;
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
    _x setBehaviour "SAFE";_x setCombatMode "BLUE";_x setSpeedMode "FULL";
} forEach [_frontGroup,_followerGroup];
_frontGroup setVariable ["WAIT_AIPass_Exclude",true,true];
private _destination=[4000,2520,0];
private _frontWP=_frontGroup addWaypoint [_destination,0];
private _followerWP=_followerGroup addWaypoint [_destination,0];
{_x setWaypointType "MOVE";_x setWaypointCompletionRadius 5} forEach [_frontWP,_followerWP];
_frontGroup setCurrentWaypoint _frontWP;_followerGroup setCurrentWaypoint _followerWP;
_front forceSpeed 0;
(driver _front) setVariable ["WAIT_CortexQA_Label","TRAFFIC PREDECESSOR: NATIVE HOLD",true];
(driver _follower) setVariable ["WAIT_CortexQA_Label","ORDINARY FOLLOWER: ACTUAL GAP / RESTART",true];
(driver _follower) setVariable ["WAIT_CortexQA_Target",_destination,true];
missionNamespace setVariable ["WAIT_CortexQA_Actors",[_front,_follower,driver _front,driver _follower],true];
["Ordinary driving: stopped predecessor","The truck must physically approach the tracked vehicle and wait behind it with separation. Assigned caps or roles cannot pass. The predecessor then moves on its native waypoint; the truck must resume without a reverse-recovery loop. A second stop/restart uses the same actors.",[4000,2150,0]] call _phase;
private _ready=!isNull driver _front && {!isNull driver _follower} && {local _front} && {local _follower}
    && {simulationEnabled _front} && {simulationEnabled _follower}
    && {!surfaceIsWater getPosATL _front} && {!surfaceIsWater getPosATL _follower}
    && {!(_follower getVariable ["WAIT_Convoy_Active",false])};
["DRIVING-traffic-fixture-ready",_ready] call _check;
private _initialDamage=[damage _front,damage _follower];
private _start=getPosATL _follower;
private _approached=[{_follower distance2D _start >= 45 && {_follower distance2D _front < 65}},60] call _wait;
["DRIVING-traffic-physical-approach",_ready && {_approached},str [getPosATL _follower,speed _follower]] call _check;
private _frontLength=abs (((boundingBoxReal _front select 1) select 1)-((boundingBoxReal _front select 0) select 1));
private _followLength=abs (((boundingBoxReal _follower select 1) select 1)-((boundingBoxReal _follower select 0) select 1));
private _bodyDistance=(_frontLength+_followLength)*0.5;
private _holdPosition=getPosATL _front;
private _stableSamples=0;private _queueObserved=false;private _noRecovery=true;private _clear=true;
for "_sample" from 1 to 60 do {
    sleep 0.5;
    private _relative=_front worldToModel (getPosATL _follower);
    private _behind=-(_relative select 1);
    private _state=_follower getVariable ["WAIT_DrivingAssist_State",[]];
    private _traffic=_follower getVariable ["WAIT_DrivingAssist_Traffic",[]];
    if ((_traffic param [1,objNull]) == _front) then {_queueObserved=true};
    if ((_state param [6,0]) != 0) then {_noRecovery=false};
    if (_behind < _bodyDistance+1 || {abs (_relative select 0) > 5}
        || {damage _front > (_initialDamage select 0)+0.01}
        || {damage _follower > (_initialDamage select 1)+0.01}) then {_clear=false};
    if (abs speed _follower < 2 && {_behind >= _bodyDistance+1} && {_behind <= _bodyDistance+18}
        && {abs (_relative select 0) <= 5}
        && {(_state param [3,grpNull]) == _followerGroup}
        && {(_traffic param [1,objNull]) == _front}) then {_stableSamples=_stableSamples+1};
    if (_sample mod 2 == 0) then {
        diag_log format ["WAIT DRIVING TRAFFIC SAMPLE: phase=HOLD t=%1 follower=%2 front=%3 gap=%4 speed=%5 cap=%6 state=%7 traffic=%8",
            time,getPosATL _follower,getPosATL _front,_behind-_bodyDistance,speed _follower,getForcedSpeed _follower,_state,_traffic];
    };
};
["DRIVING-traffic-physical-separated-hold",_approached && {_queueObserved} && {_clear} && {_stableSamples >= 12}
    && {_front distance2D _holdPosition <= 2},str [_stableSamples,_clear,getPosATL _follower]] call _check;
["DRIVING-traffic-no-queue-induced-recovery",_approached && {_queueObserved} && {_noRecovery}] call _check;
private _resumeStart=getPosATL _follower;
_front forceSpeed 5;
private _resumed=[{_front distance2D _holdPosition >= 60 && {_follower distance2D _resumeStart >= 45}
    && {speed _follower > 3}},70] call _wait;
["DRIVING-traffic-release-physical-resume",_queueObserved && {_clear} && {_resumed},str [getPosATL _front,getPosATL _follower]] call _check;
_front forceSpeed 0;
private _repeatStopped=[{abs speed _front < 1 && {abs speed _follower < 2}
    && {_follower distance2D _front >= _bodyDistance+1}},40] call _wait;
["DRIVING-traffic-repeat-physical-stop",_resumed && {_repeatStopped},str [speed _front,speed _follower,getPosATL _follower]] call _check;
private _repeatStart=getPosATL _follower;
_front forceSpeed 5;
private _repeatResumed=[{_follower distance2D _repeatStart >= 35 && {speed _follower > 3}},60] call _wait;
["DRIVING-traffic-repeat-physical-resume",_resumed && {_repeatStopped} && {_repeatResumed},str getPosATL _follower] call _check;
// A mission's newer direct MOVE does not replace its group waypoint. Hold the predecessor
// again so traffic retries would become due, then observe that newer native destination.
_front forceSpeed 0;
private _directBlocked=[{abs speed _front < 1 && {abs speed _follower < 2}
    && {_follower distance2D _front >= _bodyDistance+1}},40] call _wait;
private _directDestination=_destination vectorAdd [0,250,0];
(driver _follower) doMove _directDestination;
private _directAccepted=[{((expectedDestination driver _follower) param [0,[]]) distance2D _directDestination <= 3},15] call _wait;
private _attemptsBefore=(_follower getVariable ["WAIT_DrivingTrafficRetry",createHashMap]) getOrDefault ["attempts",0];
private _directPreserved=true;
["Ordinary driving: newer direct MOVE","The predecessor holds again. The truck has a new individual MOVE while its authored waypoint remains unchanged. WAIT must keep that native destination through a persistent traffic hold; it may not replace it with the old waypoint or start reverse recovery.",getPosATL _follower] call _phase;
for "_sample" from 1 to 64 do {
    sleep 0.5;
    private _native=expectedDestination driver _follower;
    private _retry=_follower getVariable ["WAIT_DrivingTrafficRetry",createHashMap];
    private _state=_follower getVariable ["WAIT_DrivingAssist_State",[]];
    if ((_native param [0,[]]) distance2D _directDestination > 3
        || {(_retry getOrDefault ["attempts",0]) > _attemptsBefore} || {(_state param [6,0]) != 0}) then {_directPreserved=false};
    if (_sample mod 2 == 0) then {
        diag_log format ["WAIT DRIVING DIRECT ORDER: t=%1 command=%2 expected=%3 retry=%4 state=%5",
            time,currentCommand driver _follower,_native,_retry,_state];
    };
};
["DRIVING-traffic-newer-direct-MOVE-preserved",_ready && {_repeatResumed} && {_directBlocked} && {_directAccepted} && {_directPreserved},
    str [_directDestination,expectedDestination driver _follower,_attemptsBefore]] call _check;
[createHashMapFromArray [["WAIT_AIPass_DrivingAssist_Enable",false]]] call WAIT_fnc_CortexTuning;
private _released=[{(_follower getVariable ["WAIT_DrivingAssist_State",[]]) isEqualTo []
    && {(_follower getVariable ["WAIT_DrivingAssist_Traffic",[]]) isEqualTo []}},15] call _wait;
["DRIVING-traffic-disabled-observation-cleanup",_queueObserved && {_released}] call _check;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{private _vehicle=_x;{deleteVehicle _x} forEach crew _vehicle;deleteVehicle _vehicle} forEach [_front,_follower];
{deleteGroup _x} forEach [_frontGroup,_followerGroup];
[_previous] call WAIT_fnc_CortexTuning;
