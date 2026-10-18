/*
 * Author: WaldoTheWarfighter
 * Purpose: Physically exercises ordinary traffic following behind a stopped tracked predecessor,
 * then departure, repeated stop/restart and a newer direct MOVE during blockage.
 * A separate fresh pair exercises sub-1km/h predecessor creep without stationary retry credit.
 * A separate opposing pair requires actual lane closing, production traffic observation,
 * measured braking and physical hull separation without damage. No cap is injected.
 * No controller callbacks or success state are injected.
 * Locality/authority: scheduled server creates separate disposable driver groups. Predecessor
 * native waypoint/speed holds are fixture inputs; the follower is discovered and driven by CBE.
 * Repeat/JIP: fresh fixtures per call; tuning restored and all crews/vehicles/groups deleted.
 * Public actor labels support the audit observer; no historical command replay or HC transfer.
 * Arguments: 0 check <CODE>; 1 phase <CODE>; 2 wait <CODE>, required audit callbacks.
 * Return: Nothing. Physical results remain unrun until a fresh authorized vehicles batch.
 * Current callers: runServer.sqf vehicles/full focus, normal server-owner fixtures.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQADrivingTraffic.sqf";
 */
params ["_check","_phase","_wait"];
private _previous=createHashMapFromArray [
    ["CBE_AIPass_Enable",missionNamespace getVariable ["CBE_AIPass_Enable",true]],
    ["CBE_AIPass_Contact_Enable",missionNamespace getVariable ["CBE_AIPass_Contact_Enable",true]],
    ["CBE_AIPass_DrivingAssist_Enable",missionNamespace getVariable ["CBE_AIPass_DrivingAssist_Enable",true]],
    ["CBE_AIPass_DrivingAssist_MaxSpeed",missionNamespace getVariable ["CBE_AIPass_DrivingAssist_MaxSpeed",70]]
];
[createHashMapFromArray [["CBE_AIPass_Enable",true],["CBE_AIPass_Contact_Enable",false],
    ["CBE_AIPass_DrivingAssist_Enable",true],["CBE_AIPass_DrivingAssist_MaxSpeed",70]]] call CBE_fnc_CortexTuning;
private _front=createVehicle ["O_APC_Tracked_02_cannon_F",[4000,2150,0],[],0,"NONE"];
private _follower=createVehicle ["O_Truck_03_transport_F",[4000,2030,0],[],0,"NONE"];
_front setDir 0;_follower setDir 0;
createVehicleCrew _front;createVehicleCrew _follower;
private _frontGroup=group driver _front;private _followerGroup=group driver _follower;
{
    _x setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
    _x setBehaviour "SAFE";_x setCombatMode "BLUE";_x setSpeedMode "FULL";
} forEach [_frontGroup,_followerGroup];
_frontGroup setVariable ["CBE_AIPass_Exclude",true,true];
private _destination=[4000,2520,0];
private _frontWP=_frontGroup addWaypoint [_destination,0];
private _followerWP=_followerGroup addWaypoint [_destination,0];
{_x setWaypointType "MOVE";_x setWaypointCompletionRadius 5} forEach [_frontWP,_followerWP];
_frontGroup setCurrentWaypoint _frontWP;_followerGroup setCurrentWaypoint _followerWP;
_front forceSpeed 0;
(driver _front) setVariable ["CBE_CortexQA_Label","TRAFFIC PREDECESSOR: NATIVE HOLD",true];
(driver _follower) setVariable ["CBE_CortexQA_Label","ORDINARY FOLLOWER: ACTUAL GAP / RESTART",true];
(driver _follower) setVariable ["CBE_CortexQA_Target",_destination,true];
missionNamespace setVariable ["CBE_CortexQA_Actors",[_front,_follower,driver _front,driver _follower],true];
["Ordinary driving: stopped predecessor","The truck must physically approach the tracked vehicle and wait behind it with separation. Assigned caps or roles cannot pass. The predecessor then moves on its native waypoint; the truck must resume without a reverse-recovery loop. A second stop/restart uses the same actors.",[4000,2150,0]] call _phase;
private _ready=!isNull driver _front && {!isNull driver _follower} && {local _front} && {local _follower}
    && {simulationEnabled _front} && {simulationEnabled _follower}
    && {!surfaceIsWater getPosATL _front} && {!surfaceIsWater getPosATL _follower}
    && {!(_follower getVariable ["CBE_Convoy_Active",false])};
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
    private _state=_follower getVariable ["CBE_DrivingAssist_State",[]];
    private _traffic=_follower getVariable ["CBE_DrivingAssist_Traffic",[]];
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
        diag_log format ["CBE DRIVING TRAFFIC SAMPLE: phase=HOLD t=%1 follower=%2 front=%3 gap=%4 speed=%5 cap=%6 state=%7 traffic=%8",
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
private _attemptsBefore=(_follower getVariable ["CBE_DrivingTrafficRetry",createHashMap]) getOrDefault ["attempts",0];
private _directPreserved=true;
["Ordinary driving: newer direct MOVE","The predecessor holds again. The truck has a new individual MOVE while its authored waypoint remains unchanged. CBE must keep that native destination through a persistent traffic hold; it may not replace it with the old waypoint or start reverse recovery.",getPosATL _follower] call _phase;
for "_sample" from 1 to 64 do {
    sleep 0.5;
    private _native=expectedDestination driver _follower;
    private _retry=_follower getVariable ["CBE_DrivingTrafficRetry",createHashMap];
    private _state=_follower getVariable ["CBE_DrivingAssist_State",[]];
    if ((_native param [0,[]]) distance2D _directDestination > 3
        || {(_retry getOrDefault ["attempts",0]) > _attemptsBefore} || {(_state param [6,0]) != 0}) then {_directPreserved=false};
    if (_sample mod 2 == 0) then {
        diag_log format ["CBE DRIVING DIRECT ORDER: t=%1 command=%2 expected=%3 retry=%4 state=%5",
            time,currentCommand driver _follower,_native,_retry,_state];
    };
};
["DRIVING-traffic-newer-direct-MOVE-preserved",_ready && {_repeatResumed} && {_directBlocked} && {_directAccepted} && {_directPreserved},
    str [_directDestination,expectedDestination driver _follower,_attemptsBefore]] call _check;
[createHashMapFromArray [["CBE_AIPass_DrivingAssist_Enable",false]]] call CBE_fnc_CortexTuning;
private _released=[{(_follower getVariable ["CBE_DrivingAssist_State",[]]) isEqualTo []
    && {(_follower getVariable ["CBE_DrivingAssist_Traffic",[]]) isEqualTo []}},15] call _wait;
["DRIVING-traffic-disabled-observation-cleanup",_queueObserved && {_released}] call _check;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
{private _vehicle=_x;{deleteVehicle _x} forEach crew _vehicle;deleteVehicle _vehicle} forEach [_front,_follower];
{deleteGroup _x} forEach [_frontGroup,_followerGroup];
// Fresh actors are required: the preceding episode may already have exhausted its
// original retry deadline. Never reset production state to manufacture this prerequisite.
[createHashMapFromArray [["CBE_AIPass_DrivingAssist_Enable",true]]] call CBE_fnc_CortexTuning;
private _creepFront=createVehicle ["O_APC_Tracked_02_cannon_F",[4200,2150,0],[],0,"NONE"];
private _creepFollower=createVehicle ["O_Truck_03_transport_F",[4200,2090,0],[],0,"NONE"];
_creepFront setDir 0;_creepFollower setDir 0;
createVehicleCrew _creepFront;createVehicleCrew _creepFollower;
private _creepFrontGroup=group driver _creepFront;
private _creepFollowerGroup=group driver _creepFollower;
{
    _x setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
    _x setBehaviour "SAFE";_x setCombatMode "BLUE";_x setSpeedMode "FULL";
    private _wp=_x addWaypoint [[4200,2500,0],0];
    _wp setWaypointType "MOVE";_wp setWaypointCompletionRadius 5;
    _x setCurrentWaypoint _wp;
} forEach [_creepFrontGroup,_creepFollowerGroup];
_creepFrontGroup setVariable ["CBE_AIPass_Exclude",true,true];
_creepFront forceSpeed 0;
(driver _creepFront) setVariable ["CBE_CortexQA_Label","CREEPING PREDECESSOR: ACTUAL MOTION REQUIRED",true];
(driver _creepFollower) setVariable ["CBE_CortexQA_Label","CREEP FOLLOWER: NO STATIONARY RETRY",true];
missionNamespace setVariable ["CBE_CortexQA_Actors",[_creepFront,_creepFollower,driver _creepFront,driver _creepFollower],true];
["Ordinary driving: creeping queue","A fresh tracked predecessor moves using its native waypoint at a requested0.2m/s. Actual sustained motion below1km/h and an active traffic-limited follower are prerequisites. Requested speed alone cannot pass. Neither vehicle may collide, and stationary retry attempts must not increase during the qualifying motion.",[4200,2150,0]] call _phase;
private _creepReady=[{
    private _retry=_creepFollower getVariable ["CBE_DrivingTrafficRetry",createHashMap];
    private _traffic=_creepFollower getVariable ["CBE_DrivingAssist_Traffic",[]];
    count _retry > 0 && {(_retry getOrDefault ["attempts",-1]) == 0}
        && {(_retry getOrDefault ["deadline",0])-serverTime > 45}
        && {(_traffic param [1,objNull]) == _creepFront}
        && {abs speed _creepFront < 1} && {abs speed _creepFollower < 1}
        && {local _creepFront} && {local _creepFollower}
},45] call _wait;
["DRIVING-creep-fresh-live-episode",_creepReady] call _check;
_creepFront forceSpeed 0.2;
private _creepQualified=false;private _creepNoRetry=true;private _creepNoCollision=true;
private _creepWindow=-1;private _creepWindowPosition=getPosASL _creepFront;
private _creepDamage=[damage _creepFront,damage _creepFollower];
private _creepUntil=time+40;
while {time < _creepUntil} do {
    sleep 0.5;
    private _frontSpeed=abs speed _creepFront;
    private _followerSpeed=abs speed _creepFollower;
    private _traffic=_creepFollower getVariable ["CBE_DrivingAssist_Traffic",[]];
    private _retry=_creepFollower getVariable ["CBE_DrivingTrafficRetry",createHashMap];
    private _qualifying=_frontSpeed > 0.35 && {_frontSpeed < 1} && {_followerSpeed < 1}
        && {(_traffic param [1,objNull]) == _creepFront}
        && {count _retry > 0} && {(_retry getOrDefault ["deadline",0]) > serverTime};
    if (_qualifying) then {
        if (_creepWindow < 0) then {_creepWindow=time;_creepWindowPosition=getPosASL _creepFront};
        if (time-_creepWindow >= 24 && {(getPosASL _creepFront) vectorDistance _creepWindowPosition >= 3}) then {_creepQualified=true};
        if ((_retry getOrDefault ["attempts",0]) > 0) then {_creepNoRetry=false};
    } else {_creepWindow=-1};
    private _relative=_creepFront worldToModel (getPosATL _creepFollower);
    private _room=-(_relative select 1)-_bodyDistance;
    if (_room < 1 || {damage _creepFront > (_creepDamage select 0)+0.01}
        || {damage _creepFollower > (_creepDamage select 1)+0.01}) then {_creepNoCollision=false};
    diag_log format ["CBE DRIVING CREEP: t=%1 frontASL=%2 followerASL=%3 speeds=%4 room=%5 qualifying=%6 window=%7 retry=%8",
        time,getPosASL _creepFront,getPosASL _creepFollower,[_frontSpeed,_followerSpeed],_room,_qualifying,_creepWindow,_retry];
};
["DRIVING-creep-actual-low-speed-motion",_creepReady && {_creepQualified}] call _check;
["DRIVING-creep-no-stationary-retry",_creepReady && {_creepQualified} && {_creepNoRetry}] call _check;
["DRIVING-creep-separated-no-damage",_creepReady && {_creepQualified} && {_creepNoCollision}] call _check;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
{private _vehicle=_x;{deleteVehicle _x} forEach crew _vehicle;deleteVehicle _vehicle} forEach [_creepFront,_creepFollower];
{deleteGroup _x} forEach [_creepFrontGroup,_creepFollowerGroup];
// Opposing native MOVE orders are the only stimulus. Observe actual closing/braking;
// a stored cap alone cannot pass, and native avoidance without an encounter is not a pass.
private _opposing=[];private _opposingGroups=[];
{
    _x params ["_position","_heading","_destination"];
    private _vehicle=createVehicle ["O_Truck_03_transport_F",_position,[],0,"NONE"];
    _vehicle setDir _heading;createVehicleCrew _vehicle;
    private _group=group driver _vehicle;
    _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setBehaviour "SAFE";_group setCombatMode "BLUE";_group setSpeedMode "FULL";
    private _wp=_group addWaypoint [_destination,0];_wp setWaypointType "MOVE";_wp setWaypointCompletionRadius 5;
    _group setCurrentWaypoint _wp;
    (driver _vehicle) setVariable ["CBE_CortexQA_Label",format ["ONCOMING ORDINARY %1",_forEachIndex+1],true];
    _opposing pushBack _vehicle;_opposingGroups pushBack _group;
} forEach [[[4200,2030,0],0,[4200,2520,0]],[[4200,2250,0],180,[4200,1760,0]]];
missionNamespace setVariable ["CBE_CortexQA_Actors",_opposing+( _opposing apply {driver _x}),true];
["Ordinary driving: approaching lane hulls","Two ordinary trucks receive opposing native MOVE orders. Require real overlapping-lane closing, live production traffic observation, measurable braking and physical hull separation without damage. No forced speed, callback or artificial result is applied.",getPosATL (_opposing select 0)] call _phase;
private _opposingReady=_opposing findIf {!alive _x || {!simulationEnabled _x} || {!local _x}
    || {isNull driver _x} || {!alive driver _x} || {!canMove _x} || {surfaceIsWater getPosATL _x}} < 0;
private _opposingDamage=_opposing apply {damage _x};
private _closingObserved=false;private _brakingObserved=false;private _opposingSeparated=true;
private _opposingPeaks=[0,0];private _peerObserved=[false,false];private _opposingMinGap=1e9;
private _opposingUntil=time+80;
while {time < _opposingUntil} do {
    sleep 0.5;
    private _own=_opposing select 0;private _peer=_opposing select 1;
    private _ownBox=boundingBoxReal _own;private _low=_ownBox select 0;private _high=_ownBox select 1;
    private _peerBox=boundingBoxReal _peer;private _otherLow=_peerBox select 0;private _otherHigh=_peerBox select 1;
    private _minimum=[1e9,1e9,1e9];private _maximum=[-1e9,-1e9,-1e9];
    {private _xx=_x;{private _yy=_x;{
        private _point=_own worldToModel (_peer modelToWorld [_xx,_yy,_x]);
        for "_axis" from 0 to 2 do {
            _minimum set [_axis,(_minimum select _axis) min (_point select _axis)];
            _maximum set [_axis,(_maximum select _axis) max (_point select _axis)];
        };
    } forEach [_otherLow select 2,_otherHigh select 2];} forEach [_otherLow select 1,_otherHigh select 1];} forEach [_otherLow select 0,_otherHigh select 0];
    private _lane=(_maximum select 0) >= (_low select 0)-0.25 && {(_minimum select 0) <= (_high select 0)+0.25}
        && {(_maximum select 2) >= (_low select 2)} && {(_minimum select 2) <= (_high select 2)};
    private _gap=(_minimum select 1)-(_high select 1);
    private _closing=((velocity _own) vectorDiff (velocity _peer)) vectorDotProduct (vectorDir _own);
    private _peerApproach=-((velocity _peer) vectorDotProduct (vectorDir _own));
    if (_lane && {_gap > 0} && {_gap < 150} && {_closing > 5} && {_peerApproach > 1}
        && {((vectorDir _own) vectorDotProduct (vectorDir _peer)) < -0.7}
        && {abs speed _own > 5} && {abs speed _peer > 5}) then {_closingObserved=true};
    if (_lane && {(_maximum select 1) >= (_low select 1)-1}) then {
        _opposingMinGap=_opposingMinGap min _gap;
        if (_gap < 1 && {(_maximum select 1) > (_low select 1)-1}) then {_opposingSeparated=false};
    };
    {
        private _vehicle=_x;private _other=_opposing select (1-_forEachIndex);
        private _actual=abs speed _vehicle;
        _opposingPeaks set [_forEachIndex,(_opposingPeaks select _forEachIndex) max _actual];
        private _observation=_vehicle getVariable ["CBE_DrivingAssist_Traffic",[]];
        if ((_observation param [1,objNull]) == _other) then {_peerObserved set [_forEachIndex,true]};
        if (_closingObserved && {_peerObserved select _forEachIndex}
            && {_actual <= (_opposingPeaks select _forEachIndex)-3}) then {_brakingObserved=true};
        if (!alive _vehicle || {!canMove _vehicle} || {damage _vehicle > (_opposingDamage select _forEachIndex)+0.01}) then {_opposingSeparated=false};
    } forEach _opposing;
    diag_log format ["CBE ONCOMING PHYSICAL: %1",[time,_closingObserved,_brakingObserved,_gap,_closing,
        _opposing apply {getPosASL _x},_opposing apply {speed _x},_peerObserved,_opposingSeparated]];
};
["DRIVING-oncoming-actual-lane-approach",_opposingReady && {_closingObserved}] call _check;
["DRIVING-oncoming-production-observed-braking",_opposingReady && {_closingObserved} && {_brakingObserved},str [_peerObserved,_opposingPeaks]] call _check;
["DRIVING-oncoming-separated-no-damage",_opposingReady && {_closingObserved} && {_brakingObserved} && {_opposingSeparated},str _opposingMinGap] call _check;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
{private _vehicle=_x;{deleteVehicle _x} forEach crew _vehicle;deleteVehicle _vehicle} forEach _opposing;
{deleteGroup _x} forEach _opposingGroups;
[_previous] call CBE_fnc_CortexTuning;
