/*
 * Author: WaldoTheWarfighter
 * Purpose: Prepares real ordinary-driver casualty/replacement and protected-seat comparisons.
 * Locality / Authority: Scheduled server, normal batch only. Initial mounting, casualty,
 * unconsciousness, lock, assignment and explicit STOP are fixture inputs. No production callbacks, completion
 * state, replacement seat actions or post-casualty relocation are injected by the test.
 * Late STOP and native GETOUT/MOVE are explicit replacement-order stimuli after actual
 * production VACATING and a physically vacant driver seat. Both observe the original deadline;
 * GETOUT/MOVE also requires native dismount and measured travel toward the new destination.
 * Repeat/JIP: Fresh disposable actors per case; tuning restored, explicit corpse/crew cleanup.
 * Observer labels replicate; this fixture does not transfer groups to headless clients.
 * Arguments: 0 check <CODE, required>; 1 phase <CODE, required>; 2 wait <CODE, required>.
 * Return Value: Nothing. Every result remains unrun until a fresh authorized normal audit.
 * Current callers: runServer.sqf normal vehicles/full or focused drivercrew batch.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQADrivingCrew.sqf";
 */
params ["_check","_phase","_wait"];
if (!isServer || {missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false]}) exitWith {};
private _settings=["CBE_AIPass_Enable","CBE_AIPass_Contact_Enable","CBE_AIPass_DrivingAssist_Enable","CBE_AIPass_DrivingAssist_Recovery_Enable"];
private _previous=createHashMapFromArray (_settings apply {[_x,missionNamespace getVariable [_x,true]]});
[createHashMapFromArray [["CBE_AIPass_Enable",true],["CBE_AIPass_Contact_Enable",false],
    ["CBE_AIPass_DrivingAssist_Enable",true],["CBE_AIPass_DrivingAssist_Recovery_Enable",true]]] call CBE_fnc_CortexTuning;
{
    private _kind=_x;
    private _lateCase=_kind in ["LATE_STOP","LATE_GETOUT"];
    private _start=[4400+_forEachIndex*200,2150,0];
    private _destination=_start vectorAdd [0,350,0];
    private _vehicle=createVehicle ["O_MRAP_02_F",_start,[],0,"NONE"];
    _vehicle setDir 0;createVehicleCrew _vehicle;_vehicle forceSpeed 0;
    private _driver=driver _vehicle;private _group=group _driver;
    _group setVariable ["CBE_AIPass_Exclude",true,true];
    _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    _group setBehaviour "SAFE";_group setCombatMode "BLUE";_group setSpeedMode "FULL";
    private _replacement=_group createUnit ["O_Soldier_F",_start vectorAdd [5,0,0],[],0,"NONE"];
    // Initial mounting only, before the casualty and production admission.
    _replacement moveInCargo _vehicle;_group selectLeader _replacement;
    private _incoming=objNull;private _incomingGroup=grpNull;
    if (_kind == "ASSIGNED") then {
        _incomingGroup=createGroup [east,true];
        _incomingGroup setVariable ["CBE_AIPass_Exclude",true,true];
        _incomingGroup setVariable ["CBE_Headless_ExcludeGroup",true,true];
        _incomingGroup setVariable ["acex_headless_blacklist",true,true];
        _incoming=_incomingGroup createUnit ["O_Soldier_F",_start vectorAdd [30,0,0],[],0,"NONE"];
        _incoming assignAsDriver _vehicle;
    };
    if (_kind == "LOCKED") then {_vehicle lockDriver true};
    private _waypoint=_group addWaypoint [_destination,0];
    _waypoint setWaypointType "MOVE";_waypoint setWaypointCompletionRadius 5;
    _group setCurrentWaypoint _waypoint;
    private _ready=!isNull _driver && {vehicle _replacement == _vehicle} && {local _group} && {local _vehicle}
        && {local _replacement} && {canMove _vehicle} && {simulationEnabled _vehicle}
        && {!surfaceIsWater getPosATL _vehicle} && {vehicle leader _group == _vehicle};
    _replacement setVariable ["CBE_CortexQA_Label","DRIVER HANDOVER "+_kind+": ACTUAL SEAT / ROUTE",true];
    _replacement setVariable ["CBE_CortexQA_Target",_destination,true];
    missionNamespace setVariable ["CBE_CortexQA_Actors",[_vehicle,_driver,_replacement,_incoming],true];
    ["Ordinary driver handover: "+_kind,
        if (_kind == "REPLACE") then {"The original driver dies. CBE must remove the corpse using its own native action, move mounted crew into the confirmed free driver seat, and physically resume this route. The fixture never seats the replacement or calls the production executor."}
        else {"Protected comparison: the living unconscious driver, locked seat, incoming driver assignment or explicit STOP must prevent the mounted replacement from taking the seat. Original fixture intent must remain intact."},_start] call _phase;
    ["DRIVING-crew-"+_kind+"-fixture",_ready] call _check;
    if (_kind == "UNCONSCIOUS") then {_driver setUnconscious true} else {_driver setDamage 1};
    private _damaged=damage _vehicle;private _routeStart=getPosATL _vehicle;
    if (_kind == "STOP") then {doStop _replacement};
    _vehicle forceSpeed -1;
    _group setVariable ["CBE_AIPass_Exclude",false,true];
    if (_kind == "REPLACE") then {
        private _seated=[{driver _vehicle == _replacement && {alive _replacement} && {vehicle _driver != _vehicle}
            && {(_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]) getOrDefault ["phase",""] == "COMPLETE"}},40] call _wait;
        ["DRIVING-crew-actual-replacement",_ready && {_seated},str [driver _vehicle,_replacement,_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]]] call _check;
        _routeStart=getPosATL _vehicle;
        private _moved=if (_seated) then {
            [{driver _vehicle == _replacement && {_vehicle distance2D _routeStart >= 35} && {speed _vehicle > 3}
                && {(_vehicle distance2D _destination) < (_routeStart distance2D _destination)-30}},60] call _wait
        } else {false};
        ["DRIVING-crew-replacement-physical-route",_ready && {_seated} && {_moved}
            && {alive _vehicle} && {damage _vehicle <= _damaged+0.01},str [getPosATL _vehicle,speed _vehicle,damage _vehicle]] call _check;
    } else {if (_lateCase) then {
        private _entry=createHashMap;
        private _vacant=[{
            private _live=_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap];
            private _observed=alive _vehicle && {alive _replacement} && {canMove _vehicle}
                && {(_live getOrDefault ["phase",""]) == "VACATING"}
                && {(_live getOrDefault ["candidate",objNull]) == _replacement}
                && {(_live getOrDefault ["driver",objNull]) == _driver}
                && {serverTime < (_live getOrDefault ["deadline",-1])-2}
                && {isNull driver _vehicle} && {vehicle _driver != _vehicle}
                && {vehicle _replacement == _vehicle} && {local _replacement};
            if (_observed) then {_entry=+_live};
            _observed
        },35] call _wait;
        ["DRIVING-crew-"+_kind+"-real-vacancy-prerequisite",_ready && {_vacant},str _entry] call _check;
        private _preserved=_vacant;
        private _replacementMoved=false;
        private _replacementFoot=false;
        private _newDestination=_start vectorAdd [45,0,0];
        private _replacementOrigin=getPosATL _replacement;
        private _sampleIntent={
            private _live=_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap];
            if (driver _vehicle == _replacement
                || {(_live getOrDefault ["phase",""]) in ["SWITCHING","COMPLETE"]}
                || {(_live getOrDefault ["deadline",-1]) != (_entry get "deadline")}
                || {_kind == "LATE_STOP" && {currentCommand _replacement != "STOP"}}) then {_preserved=false};
        };
        if (_vacant) then {
            private _issued=false;
            isNil {
                if ((_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap]) isEqualTo _entry
                    && {isNull driver _vehicle} && {vehicle _replacement == _vehicle}
                    && {local _replacement} && {alive _vehicle} && {alive _replacement}
                    && {serverTime < (_entry get "deadline")}) then {
                    if (_kind == "LATE_STOP") then {doStop _replacement} else {
                        // Explicit native replacement task; no forced relocation or seat change.
                        unassignVehicle _replacement;
                        doGetOut _replacement;
                    };
                    _issued=true;
                };
            };
            ["DRIVING-crew-"+_kind+"-interruption-boundary",_ready && {_issued}] call _check;
            _preserved=_preserved && {_issued};
            if (_issued && {_kind == "LATE_GETOUT"}) then {
                _replacementFoot=[{call _sampleIntent;vehicle _replacement == _replacement && {alive _replacement}},15] call _wait;
                if (_replacementFoot) then {
                    _replacementOrigin=getPosATL _replacement;
                    _replacement doMove _newDestination;
                    _replacementMoved=[{
                        call _sampleIntent;
                        vehicle _replacement == _replacement && {alive _replacement}
                            && {_replacement distance2D _replacementOrigin >= 25}
                            && {_replacement distance2D _newDestination <= (_replacementOrigin distance2D _newDestination)-20}
                    },35] call _wait;
                };
            };
            private _observeUntil=(_entry get "deadline")+3;
            private _wallUntil=diag_tickTime+35;
            while {serverTime < _observeUntil && {diag_tickTime < _wallUntil}} do {
                call _sampleIntent;
                sleep 0.2;
            };
            private _terminal=_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap];
            _preserved=_preserved && {alive _vehicle} && {alive _replacement}
                && {damage _vehicle <= _damaged+0.01} && {serverTime >= _observeUntil}
                && {(_terminal getOrDefault ["phase",""]) == "CANCELLED"}
                && {(_terminal getOrDefault ["candidate",objNull]) == _replacement}
                && {(_terminal getOrDefault ["route",[]]) isEqualTo (_entry get "route")}
                && {(_terminal getOrDefault ["deadline",-1]) == (_entry get "deadline")}
                && {driver _vehicle != _replacement};
            diag_log format ["CBE CREW LATE ORDER: %1",[_kind,_entry,_terminal,currentCommand _replacement,
                expectedDestination _replacement,getPosATL _replacement,_replacementFoot,_replacementMoved]];
        };
        ["DRIVING-crew-"+_kind+"-deadline-intent-preserved",_ready && {_vacant} && {_preserved}] call _check;
        if (_kind == "LATE_GETOUT") then {
            ["DRIVING-crew-LATE_GETOUT-physical-new-task",_ready && {_vacant} && {_preserved}
                && {_replacementFoot} && {_replacementMoved},str [getPosATL _replacement,_newDestination]] call _check;
        };
    } else {
        private _preserved=true;
        for "_sample" from 1 to 64 do {
            sleep 0.5;
            private _work=_vehicle getVariable ["CBE_DrivingCrew_Work",createHashMap];
            if (driver _vehicle == _replacement || {(_work getOrDefault ["phase",""]) in ["VACATING","SWITCHING","COMPLETE"]}) then {_preserved=false};
            if (_kind == "UNCONSCIOUS" && {!alive _driver || {driver _vehicle != _driver}}) then {_preserved=false};
            if (_kind == "LOCKED" && {!lockedDriver _vehicle}) then {_preserved=false};
            if (_kind == "STOP" && {currentCommand _replacement != "STOP"}) then {_preserved=false};
            if (_kind == "ASSIGNED" && {assignedVehicle _incoming != _vehicle
                || {(assignedVehicleRole _incoming param [0,""]) != "driver"}}) then {_preserved=false};
            if (_sample mod 2 == 0) then {
                diag_log format ["CBE DRIVING CREW SAMPLE: case=%1 t=%2 driver=%3 replacement=%4 work=%5 incoming=%6",
                    _kind,time,driver _vehicle,_replacement,_work,assignedVehicleRole _incoming];
            };
        };
        ["DRIVING-crew-"+_kind+"-intent-preserved",_ready && {_preserved},str [_kind,driver _vehicle,assignedVehicleRole _incoming]] call _check;
    }};
    missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
    private _cleanup=(crew _vehicle)+[_driver,_replacement,_incoming];
    {if (!isNull _x) then {deleteVehicle _x}} forEach (_cleanup arrayIntersect _cleanup);
    deleteVehicle _vehicle;deleteGroup _group;
    if (!isNull _incomingGroup) then {deleteGroup _incomingGroup};
} forEach ["REPLACE","UNCONSCIOUS","LOCKED","ASSIGNED","STOP","LATE_STOP","LATE_GETOUT"];
[_previous] call CBE_fnc_CortexTuning;
