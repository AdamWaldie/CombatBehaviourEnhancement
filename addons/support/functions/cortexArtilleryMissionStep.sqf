/*
 * Author: WaldoTheWarfighter
 * Server-owned fire sequence. One observer query per burst; lethal HE bursts receive four red warning smoke shells.
 * Warning smoke surrounds the reported target, ten seconds before the first shot; later shots do not repeat it.
 * Smoke is globally created by the server and deleted after sixty seconds; no per-unit polling is added.
 * Locality/authority: documented guards enforce server coordination and owner-local execution.
 * Repeat/JIP: mission tokens reject stale work; server state survives HC migration, not restart.
 * An unconfirmed native shot reaches the original deadline without renewal, then parks its
 * registry/token reservation with no recurring scheduler work or duplicate fire request.
 * Qualified event/rejection callbacks restart settlement only; parking is not completion.
 * Executor failure parks an uncertain native shot without replay or deadline renewal; otherwise it retires the registry.
 * Counter-generation cancellation blocks future shots while uncertain native shots retain
 * their token/quarantine; re-enabling cannot revive queued counter missions.
 * Each dispatched native shot has a monotonic per-mission serial, independent of fired counts.
 * Arguments: 0: mission <HASHMAP>, created by ArtilleryFire.
 * Return Value: Number next delay, or -1 to finish.
 * Current caller: CBE_fnc_ArtilleryMissionStep as one bounded action under the artillery mission FSM.
 * Example: [_mission] call CBE_fnc_CortexArtilleryMissionStep;
 */
params ["_mission"];
if (!isServer) exitWith {-1};
private _battery = _mission get "battery";
private _retirePosition={
    private _session=_mission getOrDefault ["positionSession",[]];
    if (_session isNotEqualTo [] && {(_battery getVariable ["CBE_ArtilleryPosition_Session",[]]) isEqualTo _session}) then {
        _battery setVariable ["CBE_ArtilleryPosition_Session",nil,true];
        if ((_battery getVariable ["CBE_ArtilleryPosition_Attempt",[]]) isEqualTo _session) then {
            _battery setVariable ["CBE_ArtilleryPosition_Attempt",nil,true];
        };
        private _issued=_battery getVariable ["CBE_ArtilleryPosition_Issued",[]];
        if (count _issued == 7 && {(_issued select 0) == (_mission get "token")} && {(_issued select 1) isEqualTo _session}) then {
            _battery setVariable ["CBE_ArtilleryPosition_Issued",nil,true];
        };
        [_battery,_mission get "token",_session,true] remoteExecCall ["CBE_fnc_CortexArtilleryPosition",owner _battery];
    };
};
private _finish = {
    call _retirePosition;
    private _counter = (_mission get "purpose") == "COUNTER";
    private _cooldown = time + (missionNamespace getVariable [["CBE_AIPass_Artillery_Cooldown", "CBE_AIPass_CounterBattery_Interval"] select _counter, 120]);
    private _spotter = _mission get "spotter";
    if (!isNull _spotter) then {_spotter setVariable ["CBE_AIPass_NextFireRequest_" + (_mission get "purpose"), _cooldown]};
    if (_counter && {!isNull (_mission get "enemy")}) then {(_mission get "enemy") setVariable ["CBE_AIPass_CounterUntil_" + str (_mission get "side"), _cooldown]};
    if ((_mission get "purpose") == "DANGER") then {_battery setVariable ["CBE_AIPass_NextDangerFire",time+120,true]};
    (missionNamespace getVariable ["CBE_AIPass_FireMissions", createHashMap]) deleteAt (_mission get "key");
    _battery setVariable ["CBE_AIPass_FireToken", nil, true];
    _battery setVariable ["CBE_AIPass_BusyUntil", nil, true];
    -1
};
// Executor loss is not proof that an owner-issued round failed. Keep uncertain
// native work reserved and parked; qualified callbacks may only settle it later.
if ((_mission getOrDefault ["executorFailure",""]) != "") exitWith {
    _mission set ["remaining",0];_mission set ["burstsLeft",0];_mission set ["scoot",false];
    if (alive _battery && {(_mission get "phase") in ["PENDING","UNCERTAIN"]}) then {
        _mission set ["phase","UNCERTAIN"];_mission set ["parked",true];
        -1
    } else {call _finish}
};
if ((_mission get "phase") in ["PENDING", "UNCERTAIN"] && {alive _battery}
    && {time > (_mission get "deadline")}) exitWith {
    // Retire polling, not the unresolved native command. Keep registry/token
    // reservation until a qualified firing event or owner rejection settles it.
    _mission set ["phase","UNCERTAIN"];
    _mission set ["remaining",0];
    _mission set ["burstsLeft",0];
    _mission set ["scoot",false];
    _mission set ["parked",true];
    diag_log format ["[CBE] Artillery uncertainty parked token=%1; battery remains reserved",_mission get "token"];
    -1
};
private _requester=_mission getOrDefault ["requester",grpNull];
private _danger=(_mission get "purpose") == "DANGER";
private _crewGroup=if (isNull gunner _battery) then {grpNull} else {group gunner _battery};
private _requesterBlocked=!isNull _requester && {!([_requester,"CBE_AIPass_Artillery_Enable",false] call CBE_fnc_CortexFeatureEnabled) || {!([_requester,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)}};
private _smokeBlocked=(_mission get "mode") == "SMOKE"
    && {!([_crewGroup,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)};
private _counterExpired=(_mission get "purpose") == "COUNTER"
    && {(_mission getOrDefault ["counterGeneration",-1]) != (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])};
private _fireGenerationName=switch (_mission get "purpose") do {
    case "SUPPORT": {"CBE_Artillery_SupportFireGeneration"};
    case "DANGER": {"CBE_Artillery_DangerFireGeneration"};
    default {"CBE_AIPass_CounterGeneration"};
};
private _fireExpired=(_mission getOrDefault ["fireGeneration",-1]) != (missionNamespace getVariable [_fireGenerationName,0]);
private _smokeExpired=(_mission get "mode") == "SMOKE"
    && {(_mission getOrDefault ["smokeGeneration",-1]) != (missionNamespace getVariable ["CBE_Artillery_SmokeFireGeneration",0])};
// Keep the exact positioning HOLD until retirement; a newer route stops future shots.
private _positionLost=false;
if ((_mission getOrDefault ["positionSession",[]]) isNotEqualTo [] && {(_mission get "phase") != "POSITIONING"}) then {
    private _session=_mission get "positionSession";
    private _group=_session select 3;
    private _issued=_battery getVariable ["CBE_ArtilleryPosition_Issued",[]];
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
    _positionLost=count _issued != 7;
    if (!_positionLost) then {
        _positionLost=(_issued select 0) != (_mission get "token") || {(_issued select 1) isNotEqualTo _session}
            || {(_issued select 6) != owner _battery}
            || {(_issued select 4) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
            || {(_operation getOrDefault ["generation",-2]) != (_issued select 3)}
            || {(_operation getOrDefault ["intent",""]) != "ARTILLERY_POSITION"}
            || {(_intent getOrDefault ["operationGeneration",-2]) != (_issued select 3)}
            || {(_intent getOrDefault ["waypoint",[]]) isNotEqualTo [_group,currentWaypoint _group]}
            || {waypointType [_group,currentWaypoint _group] != "HOLD"}
            || {serverTime >= (_session select 9)};
    };
};
private _blocked = _counterExpired || {_fireExpired} || {_smokeExpired} || {_smokeBlocked} || {_positionLost} || {_requesterBlocked} || {!alive _battery} || {!alive gunner _battery}
    || {combatMode group gunner _battery == "BLUE"} || {unitCombatMode gunner _battery == "BLUE"} || {time > (_mission get "deadline")}
    || {side group gunner _battery != (_mission get "side")}
    || {!([group gunner _battery] call CBE_fnc_CortexIsEligible)}
    || {!_danger && {!([_battery, _mission get "purpose"] call CBE_fnc_CortexArtilleryRole)}}
    || {if (_danger) then {
        !([_crewGroup,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)
        || {!([_crewGroup,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_crewGroup,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {[_crewGroup] call CBE_fnc_CortexExternalTakeover}
    } else {
        !([_crewGroup, ["CBE_AIPass_Artillery_Enable", "CBE_AIPass_CounterBattery_Enable"] select ((_mission get "purpose") == "COUNTER"), false] call CBE_fnc_CortexFeatureEnabled)
    }};
if (_blocked) exitWith {
    if (alive _battery && {(_mission get "phase") in ["PENDING", "UNCERTAIN"]}) then {
        _mission set ["remaining", 0];
    _mission set ["burstsLeft", 0];
        _mission set ["phase", "UNCERTAIN"];
        10
    } else {call _finish}
};
private _phase = _mission get "phase";
if (_phase == "POSITIONING") exitWith {
    private _session=_mission get "positionSession";
    private _result=_mission getOrDefault ["positionResult",""];
    if (serverTime >= (_session select 2) || {_result != "" && {_result != "READY"}}) exitWith {call _finish};
    if (_result == "READY") exitWith {
        _mission set ["phase","WAIT"];_mission set ["due",time];1
    };
    _mission set ["positionOwner",owner _battery];
    [_battery,_mission get "token",_session] remoteExecCall ["CBE_fnc_CortexArtilleryPosition",owner _battery];
    2
};
if (time < (_mission get "due")) exitWith {1};
// A missing firing event is uncertain. Never reissue it, including after an HC disconnect.
if (_phase in ["PENDING", "UNCERTAIN"]) exitWith {
    if (_phase == "PENDING") then {diag_log "[CBE] Unconfirmed artillery shot quarantined; no retry."};
    _mission set ["phase", "UNCERTAIN"];
    _mission set ["remaining", 0];
    _mission set ["burstsLeft", 0];
    _mission set ["due", time + 10];
    10
};
if ((_mission get "burstsLeft") <= 0) exitWith {
    if (_mission get "scoot" && {(_mission get "fired") > 0} && {!(_battery isKindOf "StaticWeapon")}) then {
        private _scootToken = _mission get "token";
        private _scootPurpose=_mission get "purpose";
        private _scootGenerationName=["CBE_ArtilleryScoot_SupportGeneration","CBE_ArtilleryScoot_CounterGeneration"] select (_scootPurpose == "COUNTER");
        private _scootSession=[_scootToken,missionNamespace getVariable [_scootGenerationName,0],
            _mission getOrDefault ["counterGeneration",-1],serverTime+120,_scootPurpose,
            +(_mission getOrDefault ["movementOrder",[]])];
        // Retain the original observation identity after the fire registry retires.
        // Pending admission is at most120s and a started native move at most another120s.
        _mission set ["scootSession",+_scootSession];
        _mission set ["scootGroup",group driver _battery];
        _mission set ["scootObserveUntil",(_scootSession select 3)+120];
        _battery setVariable ["CBE_Cortex_ArtilleryScootSession",_scootSession,true];
        _battery setVariable ["CBE_Cortex_ArtilleryScootToken",_scootToken,true];
        _battery setVariable ["CBE_Cortex_ArtilleryScootDeadline",_scootSession select 3,true];
        _battery setVariable ["CBE_Cortex_ArtilleryScootPurpose",_mission get "purpose",true];
        [_battery,_scootToken,_scootSession] remoteExecCall ["CBE_fnc_CortexArtilleryScoot", owner _battery];
    };
    call _finish
};
if (_phase == "WAIT") then {
    _mission set ["remaining", _mission get "burstSize"];
    private _spotter = _mission get "spotter";
    if (alive _spotter && {_spotter getVariable ["CBE_AIPass_Spotter", false]}) then {
        _mission set ["phase", "OBSERVE"];
        _mission set ["observerOwner", owner _spotter];
        _mission set ["due", time + 3];
        [_battery, _mission get "token", _spotter, _mission get "enemy", _mission getOrDefault ["aim", []]] remoteExecCall ["CBE_fnc_CortexArtilleryObserve", owner _spotter];
    } else {
        if ((_mission get "purpose") == "COUNTER") then {
            // Relocation needs this side's qualified radar receipt, never a global emission or live transform.
            private _emission = (_mission get "enemy") getVariable ["CBE_AIPass_DetectedEmission_" + str (_mission get "side"), []];
            if (count _emission == 4 && {(_emission select 3) == "RADAR"}
                && {serverTime >= (_emission select 0)} && {serverTime-(_emission select 0) <= 120}
                && {(_emission select 1) distance2D (_mission get "location") >= (missionNamespace getVariable ["CBE_AIPass_Artillery_LocationResetDistance", 150])}) then {
                _mission set ["fix", [+(_emission select 1), 30]];
                _mission set ["location", +(_emission select 1)];
                _mission set ["offset", 300];
                _mission set ["opening", true];
                _mission set ["bearing", random 360];
            } else {
                if ((_mission get "burstsCompleted") > 0) then {
                    _mission set ["offset", ((_mission get "offset") * 0.55) max 40];
                    _mission set ["opening", false];
                };
            };
        };
        _mission set ["phase", "READY"];
    };
};
if ((_mission get "phase") == "OBSERVE" && {time >= (_mission get "due")}) then {_mission set ["phase", "READY"]};
if (!((_mission get "phase") in ["READY", "WARNED", "FIRING"])) exitWith {1};
private _aim = if ((_mission get "phase") in ["WARNED", "FIRING"]) then {_mission get "aim"} else {[_mission] call CBE_fnc_CortexArtilleryAim};
if (_aim isEqualTo []) exitWith {diag_log "[CBE] No safe in-range ranging point; fire mission cancelled."; call _finish};
_mission set ["aim", _aim];
// Server-owned phase guarantees one spread per burst, including across gun-owner migration.
// Warn around the reported target, not the deliberately offset opening ranging point.
if ((_mission get "phase") == "READY" && {(_mission get "mode") == "HE"}) exitWith {
    private _target=(_mission get "fix") select 0;
    private _smokes=[];
    for "_index" from 0 to 3 do {
        private _position=_target getPos [25,90*_index];
        _position set [2,0.2];
        private _smoke=createVehicle ["SmokeShellRed",_position,[],0,"CAN_COLLIDE"];
        _smokes pushBack _smoke;
    };
    [{params ["_smokes"]; {if (!isNull _x) then {deleteVehicle _x}} forEach _smokes},[_smokes],60] call CBA_fnc_waitAndExecute;
    _mission set ["phase","WARNED"];
    _mission set ["due",time+10];
    diag_log format ["[CBE] Artillery warning token=%1 burst=%2 target=%3 smoke=%4",_mission get "token",(_mission get "burstsCompleted")+1,_target,count _smokes];
    10
};
_mission set ["shotSerial",(_mission getOrDefault ["shotSerial",0])+1];
_mission set ["phase", "PENDING"];
_mission set ["due", time + 60];
_mission set ["gunOwner", owner _battery];
[_battery, _aim, _mission get "magazine", _mission get "purpose", _mission get "mode", _mission get "token",_mission getOrDefault ["counterGeneration",-1],_mission get "shotSerial",_mission getOrDefault ["fireGeneration",-1],_mission getOrDefault ["smokeGeneration",-1]] remoteExecCall ["CBE_fnc_CortexArtilleryShot", owner _battery];
1
