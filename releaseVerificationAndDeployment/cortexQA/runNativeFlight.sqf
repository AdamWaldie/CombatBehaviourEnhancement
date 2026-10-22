/*
 * Author: WaldoTheWarfighter
 * Purpose: Measure native fleeing, CBE fallback attribution and physical authored-order handback.
 * Locality/authority: Scheduled dedicated server, separate normal batch; disposable local actors.
 * Repeat/JIP: Fresh groups/objects per run, cleaned on exit; observer state only is public.
 * Real casualties and native courage/fleeing policy create the stimulus. No fleeing flag,
 * danger event, flight lease, solved result or actor position is injected after spawn.
 * Arguments: 0 check CODE, 1 phase CODE, 2 bounded wait CODE from runServer.
 * Return: Nothing. Native travel and actual CBE fallback exercise are separate requirements;
 * a native-owned route cannot pass fallback coverage merely because the actor travels.
 * Current callers: runServer nativeflight focus, excluded from all and HC batches.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQANativeFlight.sqf";
 */
params ["_check","_phase","_wait"];
if (missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false]) exitWith {
    ["NATIVEFLIGHT-normal-batch",false,"No HC or migration coverage in this case"] call _check;
};
[createHashMapFromArray [["CBE_AIPass_Enable",true],["CBE_AIPass_Danger_Enable",true],
    ["CBE_AIPass_Contact_Enable",true],["CBE_AIPass_Morale_Enable",false],
    ["CBE_AIPass_Regroup_Enable",false],["CBE_AIPass_Flank_Enable",false],
    ["CBE_AIPass_Advance_Enable",false],["CBE_AIPass_Assault_Enable",false],
    ["CBE_AIPass_FireControl_Enable",false],["CBE_AIPass_CoordinatedAssault_Enable",false],
    ["CBE_AIRebalance_Enable",false]]] call CBE_fnc_CortexTuning;
private _group=createGroup [west,true];
private _enemyGroup=createGroup [east,true];
{
    _x setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_group,_enemyGroup];
_enemyGroup setVariable ["CBE_AIPass_Exclude",true,true];
_enemyGroup allowFleeing 0;
private _origin=[3600,2800,0];
private _units=[];
for "_index" from 0 to 7 do {
    private _position=_origin vectorAdd [-6*(_index mod 4),-8*floor (_index/4),0];
    private _unit=_group createUnit ["B_Soldier_F",_position,[],0,"NONE"];
    _unit setVariable ["CBE_CortexQA_Label",format ["NATIVE FLIGHT / %1",_index+1],true];
    _unit setSkill ["courage",0];
    _unit allowDamage false;
    _units pushBack _unit;
};
private _survivors=[_units select 0,_units select 7];
_group selectLeader (_survivors select 0);
_group allowFleeing 1;
private _enemy=_enemyGroup createUnit ["O_Soldier_F",_origin vectorAdd [0,110,0],[],0,"NONE"];
_enemy allowDamage false;
_enemy setDir 180;
_enemy addEventHandler ["FiredMan",{params ["_shooter"];_shooter setVariable ["CBE_CortexQA_FlightShots",1+(_shooter getVariable ["CBE_CortexQA_FlightShots",0])]}];
_enemy setSkill ["aimingAccuracy",0.05];
_enemyGroup setCombatMode "RED";
private _wall=createVehicle ["Land_CncWall4_F",_origin vectorAdd [-8,-5,0],[],0,"CAN_COLLIDE"];
_wall setDir 90;
missionNamespace setVariable ["CBE_CortexQA_Actors",_survivors+[_enemy],true];
["Native flight: casualty stimulus","Real squad casualties should trigger native fleeing. Watch actual movement and the labelled survivors. Native travel and an exercised CBE fallback are reported separately; neither is fabricated.",_origin] call _phase;
sleep 4;
{if (!(_x in _survivors)) then {_x allowDamage true;_x setDamage 1}} forEach _units;
private _nativeFled=[{_survivors findIf {fleeing _x} >= 0},25] call _wait;
["NATIVEFLIGHT-native-fleeing-prerequisite",_nativeFled,str (_survivors apply {fleeing _x})] call _check;
private _starts=_survivors apply {getPosASL _x};
private _travel=[0,0];
private _fallback=[false,false];
private _unleasedNativeRoute=[false,false];
private _physicalFallback=[false,false];
private _rejoinOrigins=[[],[]];
private _flightReceipts=[[],[]];
private _previousLeases=[[],[]];
private _deadlinesStable=true;
private _observedLeasedEscape=false;
private _observationsValid=true;
if (_nativeFled) then {
    private _sampleUntil=diag_tickTime+35;
    waitUntil {
        {
            private _actor=_x;
            private _index=_forEachIndex;
            _travel set [_index,(_travel select _index) max ((getPosASL _actor) vectorDistance (_starts select _index))];
            private _result=_actor getVariable ["CBE_Danger_FlightResult",[]];
            private _lease=_actor getVariable ["CBE_Danger_FlightLease",[]];
            if (_lease isEqualTo [] && {currentCommand _actor in ["MOVE","FOLLOW"]}) then {_unleasedNativeRoute set [_index,true]};
            private _validLease=_lease isEqualType [] && {count _lease == 7}
                    && {(_lease select 1) isEqualType 0} && {finite (_lease select 1)}
                    && {(_lease select 6) isEqualType 0} && {finite (_lease select 6)};
            if (_lease isNotEqualTo []) then {
                if (!_validLease) then {_observationsValid=false} else {
                    _observedLeasedEscape=true;
                    private _prior=_previousLeases select _index;
                    if ((_lease select 1)-(_lease select 6) > 12.01 || {time > (_lease select 1)+1}) then {_deadlinesStable=false};
                    if (count _prior == 7 && {time < (_prior select 1)} && {
                        (_prior select 1) != (_lease select 1) || {(_prior select 6) != (_lease select 6)}}) then {_deadlinesStable=false};
                };
            };
            _previousLeases set [_index,if (_validLease) then {+_lease} else {[]}];
            private _validResult=_result isEqualType [] && {count _result == 5}
                && {(_result select 0) in ["MOVE_REQUESTED","AT_COVER_POSITION","OWNERSHIP_CHANGED","NATIVE_RETURN_REQUESTED","NATIVE_REJOIN_REQUESTED"]}
                && {[_result select 1,_result select 3,_result select 4] findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {(_result select 2) isEqualType []} && {count (_result select 2) == 3}
                && {(_result select 2) findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
            if (_result isNotEqualTo [] && {!_validResult}) then {_observationsValid=false};

            if (_validResult) then {
                _fallback set [_index,true];
                if ((_flightReceipts select _index) isEqualTo []) then {
                    _flightReceipts set [_index,+_result];
                    _rejoinOrigins set [_index,[getPosASL _actor,_actor distance2D leader _group]];
                };
                private _first=_flightReceipts select _index;
                // Measure actual approach to the recorded fixed escape destination, not result text.
                if ((_first select 0) != "NATIVE_REJOIN_REQUESTED"
                    && {(getPosASL _actor) vectorDistance (AGLToASL (_first select 2)) <= 2}
                    && {time <= (_first select 4)}
                    && {(getPosASL _actor) vectorDistance ((_rejoinOrigins select _index) select 0) >= 0.6}
                    && {_validLease || {(_result select 0) == "AT_COVER_POSITION"}}) then {_physicalFallback set [_index,true]};
                if ((_first select 0) == "NATIVE_REJOIN_REQUESTED") then {
                    private _rejoinStart=_rejoinOrigins select _index;
                    if ((getPosASL _actor) vectorDistance (_rejoinStart select 0) >= 3
                        && {_actor distance2D leader _group <= 8 || {
                            _actor distance2D leader _group <= (_rejoinStart select 1)-3}}) then {
                        _physicalFallback set [_index,true];
                    };
                };
            };
        } forEach _survivors;
        sleep 0.2;
        diag_tickTime >= _sampleUntil
    };
};
["NATIVEFLIGHT-real-enemy-fire",(_enemy getVariable ["CBE_CortexQA_FlightShots",0]) > 0] call _check;
["NATIVEFLIGHT-engine-forced-observed",(((_group getVariable ["CBE_Danger_EngineStats",createHashMap]) getOrDefault ["modes",createHashMap]) getOrDefault ["FORCED",0]) > 0] call _check;
["NATIVEFLIGHT-valid-observations",_observationsValid] call _check;
["NATIVEFLIGHT-original-deadlines",_observedLeasedEscape && {_deadlinesStable}] call _check;
["NATIVEFLIGHT-physical-native-or-fallback-travel",_nativeFled && {_travel findIf {_x >= 8} >= 0},str [_travel,_unleasedNativeRoute]] call _check;
["NATIVEFLIGHT-fallback-exercised",_fallback findIf {_x} >= 0,"Unexercised fallback remains a finding even when native movement succeeds"] call _check;
["NATIVEFLIGHT-fallback-physical-outcome",_physicalFallback findIf {_x} >= 0,str [_flightReceipts,_physicalFallback]] call _check;
// Replace through genuine native mission orders. Never invoke CBE cleanup or relocate survivors.
_group allowFleeing 0;
_enemyGroup setCombatMode "BLUE";
removeAllWeapons _enemy;
private _destination=(getPosATL leader _group) vectorAdd [0,-55,0];
private _waypoint=_group addWaypoint [_destination,0];
_waypoint setWaypointType "MOVE";
_waypoint setWaypointCompletionRadius 5;
_group setCurrentWaypoint _waypoint;
["Native flight: authored replacement","Native fleeing is disabled and a fresh ordinary waypoint must physically take the survivors away. No cleanup function or movement reset is injected.",_destination] call _phase;
private _arrived=[{_survivors findIf {!alive _x || {_x distance2D _destination > 10}} < 0},60] call _wait;
["NATIVEFLIGHT-replacement-physical",_nativeFled && {_arrived},str (_survivors apply {getPosATL _x})] call _check;
["NATIVEFLIGHT-lease-drained",(_fallback findIf {_x} >= 0) && {_survivors findIf {(_x getVariable ["CBE_Danger_FlightLease",[]]) isNotEqualTo []} < 0}] call _check;
{deleteVehicle _x} forEach (_units+[_enemy,_wall]);
{deleteGroup _x} forEach [_group,_enemyGroup];
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
