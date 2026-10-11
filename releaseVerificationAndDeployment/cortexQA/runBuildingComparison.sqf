/*
 * Author: WaldoTheWarfighter
 * Compares physical building entry using independent engine commands across small and large,
 * single- and multi-storey house models, then exercises production garrison and clearance.
 * Locality/authority: scheduled dedicated-server audit; all actors are pinned to this owner.
 * Clearance acceptance requires covered interior navigation positions; exposed positions remain
 * separately recorded as exterior evidence, rather than being counted as uncleared rooms.
 * Repeat/JIP: disposable actors and houses are removed; observer state is public for joining clients.
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>; all required audit callbacks.
 * Optional fourth argument: nativeOnly <BOOL>, false; stop after independent comparisons.
 * Return: Nothing. Current callers: cortexQA/runServer.sqf.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQABuildings.sqf";
 */
params ["_check","_phase","_wait",["_nativeOnly",false,[true]]];
private _recordFixture={
    params ["_house","_label"];
    private _positions=_house buildingPos -1;
    private _detail=[worldName,["TERRAIN","CREATE_VEHICLE"] select (worldName == "VR"),typeOf _house,getModelInfo _house,
        isSimpleObject _house,simulationEnabled _house,count _positions,getPosATL _house];
    diag_log format ["WAIT BUILDING FIXTURE: %1",[_label,_detail]];
    // Access points are model path entrances, not authored clearance destinations.
    // Record terrain clearance without moving either terrain or curator-created houses.
    private _accessProfile=[];
    for "_access" from 0 to 15 do {
        private _point=_house buildingExit _access;
        if (_point isEqualTo [0,0,0]) exitWith {};
        private _asl=AGLToASL _point;
        _accessProfile pushBack [_access,_point,(_asl select 2)-getTerrainHeightASL _point];
    };
    diag_log format ["WAIT BUILDING PLACEMENT: %1",[_label,getPosWorld _house,
        vectorDir _house,vectorUp _house,_accessProfile]];

    private _doorProfile=[];
    private _doorCount=(getNumber (configOf _house >> "numberOfDoors")) min 16;
    for "_door" from 1 to _doorCount do {
        private _source=format ["Door_%1_sound_source",_door];
        _doorProfile pushBack [_door,_source,
            isClass (configOf _house >> "AnimationSources" >> _source),
            _house selectionPosition [format ["Door_%1_trigger",_door],"Memory"]];
    };
    _house setVariable ["WAIT_CortexQA_DoorProfile",_doorProfile];
    diag_log format ["WAIT BUILDING DOOR CONFIG: %1",[_label,_doorProfile]];
    ["BUILD-fixture-"+_label,!isNull _house && {!isSimpleObject _house}
        && {_positions isNotEqualTo []},str _detail] call _check;
};

private _validateNewFixturePlacement={
    params ["_house","_label"];
    // Correct only a newly created production audit fixture, before any actor exists.
    // Derive a small bounded lift from model access clearance, never a classname map.
    private _highestAccess=-1e12;
    for "_access" from 0 to 15 do {
        private _point=_house buildingExit _access;
        if (_point isEqualTo [0,0,0]) exitWith {};
        _highestAccess=_highestAccess max (((AGLToASL _point) select 2)-getTerrainHeightASL _point);
    };
    private _fixtureLift=0;
    if (_highestAccess < -0.05 && {_highestAccess >= -0.35}) then {
        _fixtureLift=(ceil ((0.15-_highestAccess)/0.05))*0.05;
        _house setPosATL ((getPosATL _house) vectorAdd [0,0,_fixtureLift]);
    };
    ["CLEAR-"+_label+"-placement-access",_highestAccess+_fixtureLift >= -0.05,
        str [_highestAccess,_fixtureLift,getPosATL _house]] call _check;
};

private _cases = [];
private _actors = [];
private _terrainHouses=if (_nativeOnly && {worldName == "Altis"}) then {
    nearestTerrainObjects [[16600,12800,0],["House"],5000,false,true]
} else {[]};
private _usedTerrainHouses=[];
{
    private _class = _x;
    private _row = _forEachIndex;
    {
        private _method = _x;
        private _house=if (worldName == "Altis") then {
            (_terrainHouses select {typeOf _x == _class && {!(_x in _usedTerrainHouses)}}) param [0,objNull]
        } else {createVehicle [_class,[6250+_forEachIndex*60,5800+_row*60,0],[],0,"NONE"]};
        if (isNull _house) exitWith {[format ["BUILD-%1-model-%2-terrain-fixture",_method,_row+1],false,_class] call _check};
        if (worldName == "VR") then {_house enableSimulationGlobal true} else {_usedTerrainHouses pushBack _house};
        [_house,format ["%1-model-%2",_method,_row+1]] call _recordFixture;
        private _group = createGroup [east,true];
        _group setVariable ["WAIT_AIPass_Exclude",true,true];
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _group setVariable ["acex_headless_blacklist",true,true];
        private _unit = _group createUnit ["O_Soldier_F",_house getPos [25,180],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit allowDamage false;
        private _target = (_house buildingPos -1) param [0,[]];
        private _label = format ["%1 / model %2",_method,_row+1];
        _unit setVariable ["WAIT_CortexQA_Label",_label,true];
        _unit setVariable ["WAIT_CortexQA_Target",_target,true];
        _actors pushBack _unit;
        _cases pushBack [_group,_unit,_house,_target,_method,_label,false];
    } forEach ["DIRECT","HOUSE-WAYPOINT","REPLAN"];
} forEach ["Land_i_House_Small_03_V1_F","Land_i_House_Small_01_V1_F","Land_i_House_Big_01_V1_F","Land_i_House_Big_02_V1_F"];
missionNamespace setVariable ["WAIT_CortexQA_Actors",_actors,true];
private _comparisonPosition=if (_cases isNotEqualTo []) then {getPosATL ((_cases select 0) select 2)} else {[16600,12800,0]};
["Building entry: independent comparisons","Excluded soldiers compare direct movement, a building-attached waypoint and forced path replanning across small and large, single- and multi-storey houses. Cyan trails show actual movement; targets show remaining distance. Each model reports independently and does not replace the production clearance cases.",_comparisonPosition] call _phase;
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    private _valid = simulationEnabled _house && {simulationEnabled _unit} && {local _unit} && {_target isNotEqualTo []};
    [format ["BUILD-%1-ready",_label],_valid] call _check;
    if (_valid) then {
        if (_method in ["DIRECT","REPLAN"]) then {doStop _unit; _unit doMove _target; if (_method == "REPLAN") then {_unit setDestination [_target,"LEADER PLANNED",true]}} else {
            private _wp = _group addWaypoint [getPosATL _house,0];
            _wp setWaypointType "MOVE";
            _wp waypointAttachObject _house;
            _wp setWaypointHousePosition 0;
            _group setCurrentWaypoint _wp;
        };
    };
} forEach _cases;
private _deadline = time + 90;
waitUntil {
    sleep 2;
    {
        _x params ["_group","_unit","_house","_target","_method","_label"];
        if (_target isNotEqualTo [] && {alive _unit} && {_unit distance _target <= 2}) then {_x set [6,true]};
    } forEach _cases;
    time >= _deadline || {_cases findIf {!(_x select 6)} < 0}
};
{
    _x params ["_group","_unit","_house","_target","_method","_label","_arrived"];
    [format ["BUILD-%1-arrival",_label],_arrived,format ["class=%1 owner=%2 simulation=%3 position=%4 target=%5 command=%6 expected=%7",typeOf _house,groupOwner _group,simulationEnabled _unit,getPosATL _unit,_target,currentCommand _unit,expectedDestination _unit]] call _check;
} forEach _cases;
// Entry at position zero does not prove that later model nodes are reachable.
// Reuse the isolated native comparison actors to test successive 3D nodes without
// WAIT route ownership, partner assignments or room selection. Skipped nodes remain failures.
private _walkCases=[];
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    if (_method in ["DIRECT","REPLAN"]) then {
        private _nodes=(_house buildingPos -1) select [0,16];
        _walkCases pushBack [_unit,_nodes,0,_nodes apply {false},time,_method,_label];
    };
} forEach _cases;
["Building traversal: independent comparisons","The same excluded actors now attempt successive model positions. Physical 3D arrival is required for each node. A bounded timeout skips a node only to inspect the next; it never marks that node visited or validates WAIT clearance.",_comparisonPosition] call _phase;
private _walkDeadline=time+180;
waitUntil {
    sleep 2;
    {
        _x params ["_unit","_nodes","_cursor","_seen","_issued","_method","_label"];
        if (_cursor < count _nodes) then {
            private _node=_nodes select _cursor;
            private _arrived=(getPosASL _unit) vectorDistance (AGLToASL _node) <= 1.5;
            if (_arrived || {time-_issued >= 20}) then {
                if (_arrived) then {_seen set [_cursor,true]};
                _cursor=_cursor+1;
                _x set [2,_cursor];
                _x set [4,time];
                if (_cursor < count _nodes) then {
                    private _next=_nodes select _cursor;
                    _unit doMove _next;
                    _unit setVariable ["WAIT_CortexQA_Target",_next,true];
                    _unit setVariable ["WAIT_CortexQA_Label",format ["%1 / node %2",_label,_cursor],true];
                    if (_method == "REPLAN") then {_unit setDestination [_next,"LEADER PLANNED",true]};
                };
            };
        };
    } forEach _walkCases;
    time >= _walkDeadline || {_walkCases findIf {(_x select 2) < count (_x select 1)} < 0}
};
{
    _x params ["_unit","_nodes","_cursor","_seen","_issued","_method","_label"];
    ["BUILD-TRAVERSE-"+_label,_nodes isNotEqualTo [] && {_seen findIf {!_x} < 0},
        str [_nodes,_seen,getPosATL _unit,currentCommand _unit,expectedDestination _unit,getUnitState _unit]] call _check;
} forEach _walkCases;
// Isolate door state after preserving every original traversal failure. This is
// an explicit native diagnostic, never assistance to the production clearance cases.
private _doorControls=[];
{
    _x params ["_group","_unit","_house","_target","_method","_label"];
    if (typeOf _house == "Land_i_House_Small_01_V1_F" && {_method in ["DIRECT","REPLAN"]}) then {
        private _node=(_house buildingPos -1) param [1,[]];
        private _doorCount=(getNumber (configOf _house >> "numberOfDoors")) min 16;
        for "_door" from 1 to _doorCount do {
            if ((_house getVariable [format ["bis_disabled_Door_%1",_door],0]) isEqualTo 0) then {
                [_house,_door,1] call BIS_fnc_door;
            };
        };
        if (_node isNotEqualTo []) then {
            _unit doMove _node;
            _unit setVariable ["WAIT_CortexQA_Target",_node,true];
            if (_method == "REPLAN") then {_unit setDestination [_node,"LEADER PLANNED",true]};
            _doorControls pushBack [_unit,_node,_label,false,_doorCount,_house];
        };
    };
} forEach _cases;
["Building traversal: native open-door control","Diagnostic only: unlocked doors are explicitly opened on the native comparison houses, then actors retry the previously failed room index 1. Original failures remain. Production clearance receives no test-side door assistance.",_comparisonPosition] call _phase;
private _doorDeadline=time+60;
waitUntil {
    sleep 2;
    {
        if ((getPosASL (_x select 0)) vectorDistance (AGLToASL (_x select 1)) <= 1.5) then {_x set [3,true]};
    } forEach _doorControls;
    time >= _doorDeadline || {_doorControls findIf {!(_x select 3)} < 0}
};
{
    _x params ["_unit","_node","_label","_arrived","_doorCount","_house"];
    private _doorPhases=[];
    for "_door" from 1 to _doorCount do {
        _doorPhases pushBack [_door,
            _house animationSourcePhase format ["Door_%1_sound_source",_door],
            _house animationPhase format ["Door_%1_rot",_door],
            _house getVariable [format ["bis_disabled_Door_%1",_door],0]];
    };
    private _doorsOpen=_doorPhases isNotEqualTo []
        && {_doorPhases findIf {((_x select 1) max (_x select 2)) < 0.9} < 0};
    ["BUILD-OPEN-DOORS-FIXTURE-"+_label,_doorsOpen,str _doorPhases] call _check;
    ["BUILD-OPEN-DOORS-"+_label,_arrived && {_doorsOpen},str [_doorPhases,getPosATL _unit,_node,expectedDestination _unit]] call _check;
} forEach _doorControls;
sleep 15;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{_x params ["_group","_unit","_house"]; deleteVehicle _unit; deleteGroup _group; if (worldName == "VR") then {deleteVehicle _house}} forEach _cases;
if (_nativeOnly && {worldName == "VR"}) then {
    // Controlled diagnostic: same model, direction, flat ground and open doors.
    // Height is the only placement difference; no production object is repositioned.
    private _heightCases=[];
    {
        private _fixtureClass=_x;
        private _modelRow=_forEachIndex;
        {
        private _height=_x;
        private _row=_modelRow*3+_forEachIndex;
        {
            private _method=_x;
            private _house=createVehicle [_fixtureClass,[6250+_forEachIndex*60,6120+_row*60,0],[],0,"NONE"];
            _house setDir 0;
            _house setPosATL [6250+_forEachIndex*60,6120+_row*60,_height];
            private _label=format ["HEIGHT-%1-%2-%3",_fixtureClass,_height,_method];
            [_house,_label] call _recordFixture;
            for "_door" from 1 to 4 do {
                _house animateSource [format ["Door_%1_sound_source",_door],1,true];
            };
            private _group=createGroup [east,true];
            private _unit=_group createUnit ["O_Soldier_F",_house getPos [25,180],[],0,"NONE"];
            _unit allowDamage false;
            _unit setVariable ["WAIT_CortexQA_Label",_label,true];
            private _nodes=(_house buildingPos -1) select [0,16];
            private _target=_nodes param [0,[]];
            _unit setVariable ["WAIT_CortexQA_Target",_target,true];
            _unit doMove _target;
            if (_method == "REPLAN") then {_unit setDestination [_target,"LEADER PLANNED",true]};
            _heightCases pushBack [_group,_unit,_house,_nodes,0,_nodes apply {false},time,_method,_label];
        } forEach ["DIRECT","REPLAN"];
        } forEach [0,0.3,0.6];
    } forEach ["Land_i_House_Small_01_V1_F","Land_i_House_Big_01_V1_F","Land_i_House_Big_02_V1_F"];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_heightCases apply {_x select 1},true];
    ["Building entry: controlled placement height","Diagnostic only: identical houses at 0, 0.3 and 0.6 metres, all doors open. Each actor attempts every model node. Failed nodes remain unvisited when the bounded diagnostic advances. Raised houses test access clearance; they are not a production remedy.",[6250,6120,0]] call _phase;
    private _heightDeadline=time+240;
    waitUntil {
        sleep 2;
        {
            _x params ["_group","_unit","_house","_nodes","_cursor","_seen","_issued","_method","_label"];
            if (_cursor < count _nodes) then {
                private _target=_nodes select _cursor;
                private _arrived=(getPosASL _unit) vectorDistance (AGLToASL _target) <= 1.5;
                if (_arrived || {time-_issued >= 20}) then {
                    if (_arrived) then {_seen set [_cursor,true]};
                    _x set [6,time];
                    _cursor=_cursor+1;
                    _x set [4,_cursor];
                    if (_cursor < count _nodes) then {
                        _target=_nodes select _cursor;
                        _unit doMove _target;
                        _unit setVariable ["WAIT_CortexQA_Target",_target,true];
                        if (_method == "REPLAN") then {_unit setDestination [_target,"LEADER PLANNED",true]};
                    };
                };
            };
        } forEach _heightCases;
        time >= _heightDeadline || {_heightCases findIf {(_x select 4) < count (_x select 3)} < 0}
    };
    {
        _x params ["_group","_unit","_house","_nodes","_cursor","_seen","_issued","_method","_label"];
        ["BUILD-PLACEMENT-"+_label,_seen isNotEqualTo [] && {_seen findIf {!_x} < 0},str [_nodes,_seen,getPosATL _unit,expectedDestination _unit]] call _check;
    } forEach _heightCases;
    sleep 10;
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {_x params ["_group","_unit","_house"]; deleteVehicle _unit; deleteGroup _group; deleteVehicle _house} forEach _heightCases;
};
if (_nativeOnly) exitWith {};

// Fresh groups distinguish clearance defects from state left by a previous garrison.
// Keep all original comparisons above, including their failures.
{
    _x params ["_size","_class"];
    private _site=[6550+_forEachIndex*200,5800,0];
    private _house=createVehicle [_class,_site,[],0,"NONE"];
    _house enableSimulationGlobal true;
    [_house,format ["fresh-%1",_size]] call _validateNewFixturePlacement;
    [_house,format ["fresh-%1",_size]] call _recordFixture;
    private _otherBuildings=(nearestObjects [_site,["House"],50,true])-[_house];
    [format ["CLEAR-fresh-%1-site-isolated",_size],_otherBuildings isEqualTo [],str [_site,_otherBuildings]] call _check;
    private _group=createGroup [east,true];
    _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    private _members=[];
    for "_i" from 0 to (_size-1) do {
        private _unit=_group createUnit ["O_Soldier_F",_site vectorAdd [-15+(_i mod 4)*4,-40-floor(_i/4)*4,0],[],0,"NONE"];
        _unit setVariable ["acex_headless_blacklist",true,true];
        _unit setVariable ["WAIT_CortexQA_Label",format ["FRESH CLEAR %1 / soldier %2",_size,_i+1],true];
        _members pushBack _unit;
    };
    missionNamespace setVariable ["WAIT_CortexQA_Actors",_members,true];
    [format ["Fresh clearance: %1 soldiers / %2",_size,_class],"This new audit house has bounded placement validation before actors spawn. This fresh group has never garrisoned. Watch clearing pairs physically enter and continue through their assigned sector. The 2/6/12-person cases use progressively larger building models. Markers are navigation positions, not proof that a hostile room is safe. No test-side teleport, door opening or forced completion is applied.",getPosATL _house] call _phase;
    private _allRooms=_house buildingPos -1;
    private _rooms=_allRooms select {
        private _origin=AGLToASL _x;
        (lineIntersectsSurfaces [_origin vectorAdd [0,0,0.5],_origin vectorAdd [0,0,10],objNull,objNull,true,1]) isNotEqualTo []
    };
    // Preserve all-position evidence independently of the production operation's claimed visits.
    private _exteriorRooms=_allRooms select {!(_x in _rooms)};
    private _exteriorVisits=_exteriorRooms apply {false};
    private _visits=_rooms apply {false};
    [format ["CLEAR-fresh-%1-interior-fixture",_size],_rooms isNotEqualTo [],
        str [typeOf _house,count _rooms,count _exteriorRooms]] call _check;
    // Every committed soldier, including the leader, owns a production clearance lane.
    // Audit exactly that set rather than preserving the superseded exterior-leader assumption.
    private _clearingMembers=+_members;
    private _memberVisits=_clearingMembers apply {[]};
    private _originalAttack=attackEnabled leader _group;
    private _accepted=[_group,_house] call WAIT_fnc_CortexClearBuilding;
    [format ["CLEAR-fresh-%1-accepted",_size],_accepted] call _check;
    [format ["CLEAR-fresh-%1-owned-attack-delegation",_size],_accepted && {!attackEnabled leader _group},
        str [_originalAttack,attackEnabled leader _group]] call _check;
    private _entryEpoch=_group getVariable ["WAIT_AIPass_Epoch",0];
    private _entryGeneration=(_group getVariable ["WAIT_Operation",createHashMap]) getOrDefault ["generation",-1];
    private _entryOwnerStable=true;
    private _egressSeen=false;
    private _egressAssignments=[];
    private _egressVisits=[];
    private _nextRouteTrace=diag_tickTime;
    private _routeTraceCount=0;
    [format ["CLEAR-fresh-%1-owner-established",_size],_accepted && {_entryEpoch > 0}
        && {_group getVariable ["WAIT_AIPass_Adopted",false]} && {_entryGeneration >= 0},
        str [_entryEpoch,_entryGeneration]] call _check;
    private _settled=[{
        // Observe the live controller without injecting destinations or changing acceptance.
        // Ten-second samples and bounded actor/state slices keep diagnostics finite.
        if (diag_tickTime >= _nextRouteTrace && {_routeTraceCount < 26}) then {
            _nextRouteTrace=diag_tickTime+10;
            _routeTraceCount=_routeTraceCount+1;
            private _brain=_group getVariable ["WAIT_BuildingBrain",createHashMap];
            private _job=_brain getOrDefault ["job",createHashMap];
            private _operation=_group getVariable ["WAIT_Operation",createHashMap];
            private _traceHouse=_job getOrDefault ["building",objNull];
            diag_log format ["WAIT CLEAR LIVE DOORS: %1",[_size,_routeTraceCount,
                _traceHouse getVariable ["WAIT_Cortex_DoorDefinitions",[]],
                (_traceHouse getVariable ["WAIT_CortexQA_DoorProfile",[]]) apply {
                    [_x select 0,_traceHouse animationSourcePhase (_x select 1),
                        _traceHouse getVariable [format ["bis_disabled_Door_%1",_x select 0],0]]
                }]];
            diag_log format ["WAIT CLEAR LIVE ROUTE: %1",[
                _size,_routeTraceCount,diag_tickTime,
                _group getVariable ["WAIT_AIPass_Epoch",0],
                _brain getOrDefault ["generation",-1],_brain getOrDefault ["ownerEpoch",-1],
                _brain getOrDefault ["pending",false],_brain getOrDefault ["lastStepAt",-1],
                _operation getOrDefault ["generation",-1],_operation getOrDefault ["intent",""],
                _job getOrDefault ["phase",""],
                (_job getOrDefault ["pairStates",[]]) select [0,8],
                (_job getOrDefault ["pairRoutes",[]]) select [0,8],
                (_job getOrDefault ["assigned",[]]) select [0,16],
                (_clearingMembers select [0,16]) apply {
                    [str _x,local _x,getPosATL _x,currentCommand _x,expectedDestination _x,
                        _x checkAIFeature "MOVE",_x checkAIFeature "PATH",getForcedSpeed _x,
                        _x == leader _group,getUnitState _x,unitReady _x,simulationEnabled _x]
                }
            ]];
        };
        private _exit=_group getVariable ["WAIT_Cortex_ClearEgress",[]];
        if (!_egressSeen && {count _exit == 4} && {(_exit select 0) == "EGRESS"}) then {
            _egressAssignments=+(_exit select 3);
            _egressVisits=_egressAssignments apply {false};
            _egressSeen=_egressAssignments isNotEqualTo [];
        };
        {
            _x params ["_actor","_exitTarget"];
            if (alive _actor && {_actor distance2D _exitTarget <= 5}
                && {abs (((getPosATL _actor) select 2)-(_exitTarget param [2,0])) <= 1.5}) then {
                _egressVisits set [_forEachIndex,true];
            };
        } forEach _egressAssignments;
        private _currentOperation=_group getVariable ["WAIT_Operation",createHashMap];
        if ((_group getVariable ["WAIT_AIPass_Epoch",0]) != _entryEpoch
            || {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "CANCELLED"}
            || {count _currentOperation > 0 && {(_currentOperation getOrDefault ["generation",-1]) != _entryGeneration}}) then {
            _entryOwnerStable=false;
        };
        {private _room=_x; private _roomIndex=_forEachIndex; if (_clearingMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _room) <= 1.5}} >= 0) then {_visits set [_roomIndex,true]}} forEach _rooms;
        {
            private _worker=_x;
            private _seen=_memberVisits select _forEachIndex;
            {if (alive _worker && {(getPosASL _worker) vectorDistance (AGLToASL _x) <= 1.5}) then {_seen pushBackUnique _forEachIndex}} forEach _rooms;
        } forEach _clearingMembers;
        {
            private _position=_x;
            if (_clearingMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _position) <= 1.5}} >= 0) then {
                _exteriorVisits set [_forEachIndex,true];
            };
        } forEach _exteriorRooms;
        missionNamespace setVariable ["WAIT_CortexQA_Rooms",[_rooms,_visits],true];
        ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
    },245] call _wait;
    // Cancellation is terminal, not a successful clearance. Stop sampling promptly; physical
    // visits and completion assertions below still fail rather than waiting four idle minutes.
    // Preserve the physical sampling budget. Allow only finite controller settlement afterward:
    // a queued owner-local finish may follow the audit deadline by one scheduler interval.
    // This does not count extra visits or force cleanup, and a missing terminal result still fails.
    if (!_settled) then {
        _settled=[{
            ((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE","CANCELLED"]
        },15] call _wait;
    };
    [format ["CLEAR-fresh-%1-terminal-settlement",_size],_settled,
        str (_group getVariable ["WAIT_Cortex_ClearResult",[]])] call _check;
    [format ["CLEAR-fresh-%1-owner-continuity",_size],_accepted && {_entryOwnerStable},
        str [_entryEpoch,_group getVariable ["WAIT_AIPass_Epoch",0],
            _entryGeneration,_group getVariable ["WAIT_OperationResult",[]]]] call _check;
    diag_log format ["WAIT CLEAR EXTERIOR EVIDENCE: %1 %2",_size,[_exteriorRooms,_exteriorVisits]];
    private _localResult=(_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""];
    private _sharedResult=_group getVariable ["WAIT_OperationResult",[]];
    private _expectedReason=["CLEAR_INCOMPLETE","CLEAR_COMPLETE"] select (_localResult == "COMPLETE");
    [format ["CLEAR-fresh-%1-shared-outcome-agrees",_size],
        _localResult in ["COMPLETE","INCOMPLETE"] && {count _sharedResult == 5}
            && {(_sharedResult select 0) == "CLEAR"} && {(_sharedResult select 1) == _localResult}
            && {(_sharedResult select 2) == _entryGeneration} && {(_sharedResult select 4) == _expectedReason},
        str [_localResult,_sharedResult]] call _check;
    [format ["CLEAR-fresh-%1-attack-delegation-restored",_size],
        _localResult in ["COMPLETE","INCOMPLETE"] && {attackEnabled leader _group == _originalAttack},
        str [_localResult,_originalAttack,attackEnabled leader _group]] call _check;
    private _physical=_rooms isNotEqualTo [] && {_visits findIf {!_x} < 0};
    [format ["CLEAR-fresh-%1-physical-room-visits",_size],_physical,format ["visits=%1 units=%2",_visits,_members apply {[getPosATL _x,currentCommand _x,expectedDestination _x,_x checkAIFeature "PATH",_x checkAIFeature "MOVE",behaviour _x]}]] call _check;
    [format ["CLEAR-fresh-%1-physical-egress",_size],_egressSeen && {_egressVisits findIf {!_x} < 0},str [_egressAssignments,_egressVisits]] call _check;
    private _egressRetries=_group getVariable ["WAIT_Cortex_ClearEgressRetries",[]];
    [format ["CLEAR-fresh-%1-egress-retry-budget",_size],_egressSeen && {_egressRetries findIf {(_x select 2) > 1} < 0},str _egressRetries] call _check;
    [format ["CLEAR-fresh-%1-result-agrees",_size],_physical && {((_group getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) == "COMPLETE"}] call _check;
    [format ["CLEAR-fresh-%1-successive-positions",_size],_memberVisits findIf {count _x >= 2} >= 0,str _memberVisits] call _check;
    if (_size == 2) then {
        ["CLEAR-fresh-2-both-participate",_memberVisits findIf {_x isEqualTo []} < 0,str _memberVisits] call _check;
        if (count _rooms >= 4) then {
            ["CLEAR-fresh-2-both-progress-through-interior",_memberVisits findIf {count _x < 2} < 0,str _memberVisits] call _check;
        };
    };
    // Exercise natural completion/failure cleanup before invoking any explicit release.
    // A fresh ordinary waypoint must take control even when some rooms were unreachable.
    private _destination=_site vectorAdd [75,-30,0];
    private _beforeMove=_members apply {getPosATL _x};
    private _waypoint=_group addWaypoint [_destination,0];
    _waypoint setWaypointType "MOVE";
    _group setCurrentWaypoint _waypoint;
    [format ["Clearance handover: %1 soldiers",_size],"After the recorded clearance result, the same soldiers must follow an ordinary waypoint away from the building. No cleanup function or movement reset is injected before this check.",_destination] call _phase;
    private _moved=[{
        private _allMoved=true;
        {
            if (!alive _x || {_x distance2D (_beforeMove select _forEachIndex) < 25} || {_x distance2D _destination > 18}) then {_allMoved=false};
        } forEach _members;
        _allMoved
    },90] call _wait;
    [format ["CLEAR-fresh-%1-handover-physical",_size],_moved,str (_members apply {getPosATL _x})] call _check;
    sleep 8;
    [_group] call WAIT_fnc_CortexClearRelease;
    missionNamespace setVariable ["WAIT_CortexQA_Rooms",[],true];
    missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    {deleteVehicle _x} forEach _members;
    deleteGroup _group;
    deleteVehicle _house;
} forEach [[2,"Land_i_House_Small_01_V1_F"],[6,"Land_i_House_Big_01_V1_F"],[12,"Land_i_House_Big_02_V1_F"]];

// A casualty inside the clearing element must not strand the shared room queue. Use ten soldiers
// so the production room-limited entry element leaves genuine reserves available as replacements.
private _casualtySite=[7150,5800,0];
private _casualtyHouse=createVehicle ["Land_i_House_Big_01_V1_F",_casualtySite,[],0,"NONE"];
_casualtyHouse enableSimulationGlobal true;
[_casualtyHouse,"casualty"] call _validateNewFixturePlacement;
private _casualtyGroup=createGroup [east,true];
_casualtyGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_casualtyGroup setVariable ["acex_headless_blacklist",true,true];
private _casualtyMembers=[];
for "_i" from 0 to 9 do {
    private _unit=_casualtyGroup createUnit ["O_Soldier_F",_casualtySite vectorAdd [-20+(_i mod 5)*4,-40-floor(_i/5)*4,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["CQB CASUALTY / soldier %1",_i+1],true];
    _casualtyMembers pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_casualtyMembers,true];
["CQB casualty reinforcement","The ten-person squad starts with a room-limited clearing element and remaining reserves. One clearing soldier becomes a real casualty. A surviving reserve must join the clear and physically move toward the building; the remaining room queue must stay active.",getPosATL _casualtyHouse] call _phase;
private _casualtyAccepted=[_casualtyGroup,_casualtyHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-casualty-order-accepted",_casualtyAccepted] call _check;
private _jobStarted=[{_casualtyGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},15] call _wait;
["CLEAR-casualty-job-started",_jobStarted] call _check;
private _initialOperation=_casualtyGroup getVariable ["WAIT_Operation",createHashMap];
private _initialParticipants=+(_initialOperation getOrDefault ["participants",[]]);
private _casualty=_initialParticipants param [0,objNull];
private _reservePool=_casualtyMembers select {!(_x in _initialParticipants)};
private _reserveStarts=_reservePool apply {getPosATL _x};
private _reserve=objNull;
private _reserveStart=[];
["CLEAR-casualty-entry-and-reserve-fixture",!isNull _casualty && {_reservePool isNotEqualTo []},
    str [_initialParticipants,_reservePool]] call _check;
private _evidenceBefore=count (_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]]);
_casualty setDamage 1;
private _reinforced=[{
    private _evidence=_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]];
    private _replacementIndex=_evidence findIf {(_x param [1,""]) == netId _casualty};
    if (count _evidence > _evidenceBefore && {_replacementIndex >= 0}) then {
        private _replacementId=(_evidence select _replacementIndex) param [2,""];
        private _poolIndex=_reservePool findIf {netId _x == _replacementId};
        if (_poolIndex >= 0) then {
            _reserve=_reservePool select _poolIndex;
            _reserveStart=_reserveStarts select _poolIndex;
        };
    };
    !isNull _reserve
},30] call _wait;
["CLEAR-casualty-reserve-assigned",_reinforced,str (_casualtyGroup getVariable ["WAIT_Cortex_ClearReinforcements",[]])] call _check;
private _reserveOperation=_casualtyGroup getVariable ["WAIT_Operation",createHashMap];
["CLEAR-casualty-shared-progress-roster",_reinforced
    && {_reserve in (_reserveOperation getOrDefault ["participants",[]])}
    && {!(_casualty in (_reserveOperation getOrDefault ["participants",[]]))}
    && {(_reserveOperation getOrDefault ["participantProgress",[]]) findIf {(_x select 0) == _reserve} >= 0},
    str [_reserveOperation getOrDefault ["participants",[]],_reserveOperation getOrDefault ["participantProgress",[]]]] call _check;
private _replacementMoved=[{
    !isNull _reserve && {alive _reserve}
        && {(_reserve distance2D _reserveStart >= 8
                && {_reserve distance2D _casualtyHouse <= (_reserveStart distance2D _casualtyHouse)-5})
            || {(_casualtyHouse buildingPos -1) findIf {(getPosASL _reserve) vectorDistance (AGLToASL _x) <= 1.5} >= 0}}
},60] call _wait;
["CLEAR-casualty-reserve-physical-movement",_replacementMoved,format ["start=%1 actual=%2 command=%3 expected=%4",_reserveStart,getPosATL _reserve,currentCommand _reserve,expectedDestination _reserve]] call _check;
private _continuing=(_casualtyGroup getVariable ["WAIT_AIPass_ClearBuilding",false])
    || {((_casualtyGroup getVariable ["WAIT_Cortex_ClearResult",[]]) param [0,""]) in ["COMPLETE","INCOMPLETE"]};
["CLEAR-casualty-controller-continues",_continuing] call _check;
[_casualtyGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _casualtyMembers;
deleteGroup _casualtyGroup;
deleteVehicle _casualtyHouse;

// Exercise door handling through the real clearance job, never by calling its helper directly.
private _doorSite=[7350,5800,0];
private _doorHouse=createVehicle ["Land_i_House_Small_01_V1_F",_doorSite,[],0,"NONE"];
_doorHouse enableSimulationGlobal true;
[_doorHouse,"door"] call _validateNewFixturePlacement;
private _doorGroup=createGroup [east,true];
_doorGroup setVariable ["WAIT_Headless_ExcludeGroup",true,true];
_doorGroup setVariable ["acex_headless_blacklist",true,true];
private _doorMembers=[];
for "_i" from 0 to 1 do {
    private _unit=_doorGroup createUnit ["O_Soldier_F",_doorSite vectorAdd [_i*3,-30,0],[],0,"NONE"];
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["DOOR ORDER %1",_i+1],true];
    _doorMembers pushBack _unit;
};
missionNamespace setVariable ["WAIT_CortexQA_Actors",_doorMembers,true];
private _doorSource="Door_1_sound_source";
private _doorReady=isClass (configOf _doorHouse >> "AnimationSources" >> _doorSource)
    && {_doorHouse animationSourcePhase _doorSource < 0.1}
    && {(_doorHouse selectionPosition ["Door_1_trigger","Memory"]) isNotEqualTo [0,0,0]};
["CLEAR-door-fixture-closed-recognised",_doorReady] call _check;
_doorHouse setVariable ["bis_disabled_Door_1",1,true];
["Clearance: locked entry","The real clearance order must not unlock the front door. This phase checks the actual door phase and lock variable; it does not count an accepted order as entry.",getPosATL _doorHouse] call _phase;
private _doorAccepted=[_doorGroup,_doorHouse] call WAIT_fnc_CortexClearBuilding;
["CLEAR-door-order-accepted",_doorAccepted] call _check;
private _lockHeld=true;
private _lockedUntil=time+35;
waitUntil {
    sleep 1;
    if (_doorHouse animationSourcePhase _doorSource > 0.1 || {(_doorHouse getVariable ["bis_disabled_Door_1",0]) != 1}) then {_lockHeld=false};
    time >= _lockedUntil
};
["CLEAR-door-lock-preserved",_doorReady && {_doorAccepted} && {_lockHeld}] call _check;
// Changing the lock is the test stimulus; opening and entry must be performed by production.
_doorHouse setVariable ["bis_disabled_Door_1",0,true];
["Clearance: entry unlocked","The lock is now removed. Watch the same soldiers open the door and physically enter. The audit does not animate the door, teleport actors or reset their movement.",getPosATL _doorHouse] call _phase;
private _doorOpened=[{_doorHouse animationSourcePhase _doorSource >= 0.8},45] call _wait;
["CLEAR-door-unlocked-opens",_doorReady && {_doorOpened}] call _check;
private _doorPositions=_doorHouse buildingPos -1;
private _entered=[{_doorPositions findIf {
    private _position=_x;
    _doorMembers findIf {(getPosASL _x) vectorDistance (AGLToASL _position) <= 1.5} >= 0
} >= 0},45] call _wait;
["CLEAR-door-unlocked-physical-entry",_doorReady && {_doorOpened} && {_entered}] call _check;
[_doorGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach _doorMembers;
deleteGroup _doorGroup;
deleteVehicle _doorHouse;

// Natural building contact acceptance. This fixture supplies only live opposing actors and geometry:
// no reveal, direct clear call, target assignment or movement command is injected after spawning.
// The production contact brain must first acquire the hostile through the engine, identify that the
// fresh contact is physically inside the house, and hand the same squad to the building operation.
private _contactSite=[7550,5800,0];
private _contactHouse=createVehicle ["Land_i_House_Small_01_V1_F",_contactSite,[],0,"NONE"];
_contactHouse enableSimulationGlobal true;
[_contactHouse,"contact"] call _validateNewFixturePlacement;
private _contactRooms=_contactHouse buildingPos -1;
// Find an exterior approach with a genuine view through an opening before creating actors.
// A hidden room plus an arbitrary rear approach tests absent detection, not contact-to-clear.
private _contactRoom=[];
private _contactApproach=[];
{
    private _room=_x;
    for "_bearing" from 0 to 337.5 step 22.5 do {
        private _approach=_contactSite getPos [38,_bearing];
        private _from=AGLToASL (_approach vectorAdd [0,0,1.5]);
        private _to=AGLToASL (_room vectorAdd [0,0,1.5]);
        if ((lineIntersectsSurfaces [_from,_to,objNull,objNull,true,1,"VIEW","NONE"]) isEqualTo []) exitWith {
            _contactRoom=+_room; _contactApproach=+_approach;
        };
    };
    if (_contactRoom isNotEqualTo []) exitWith {};
} forEach (_contactRooms select [0,16]);
private _contactGeometryReady=_contactRoom isNotEqualTo [];
if (!_contactGeometryReady) then {_contactRoom=_contactRooms param [0,getPosATL _contactHouse]; _contactApproach=_contactSite vectorAdd [-12,-38,0]};
private _contactGroup=createGroup [east,true];
private _contactOpposition=createGroup [west,true];
{
    _x setVariable ["WAIT_Headless_ExcludeGroup",true,true];
    _x setVariable ["acex_headless_blacklist",true,true];
} forEach [_contactGroup,_contactOpposition];
_contactOpposition setVariable ["WAIT_AIPass_Exclude",true,true];
private _contactMembers=[];
for "_i" from 0 to 5 do {
    private _rowOrigin=_contactApproach getPos [floor (_i/3)*3,(_contactApproach getDir _contactHouse)+180];
    private _unit=_contactGroup createUnit ["O_Soldier_F",_rowOrigin getPos [(_i mod 3)*3,(_contactApproach getDir _contactHouse)+90],[],0,"NONE"];
    _unit allowDamage false;
    _unit setDir (_unit getDir _contactHouse);
    _unit setVariable ["acex_headless_blacklist",true,true];
    _unit setVariable ["WAIT_CortexQA_Label",format ["NATURAL CQB %1",_i+1],true];
    _contactMembers pushBack _unit;
};
private _contactEnemy=_contactOpposition createUnit ["B_Soldier_F",_contactRoom,[],0,"NONE"];
_contactEnemy allowDamage false;
// This contact-to-clear fixture requires a posted interior defender, not a pursuer that
// leaves the building before the squad acquires it. Native sensing, aiming and fire remain.
_contactEnemy disableAI "PATH";
_contactEnemy setDir (_contactEnemy getDir leader _contactGroup);
_contactEnemy setVariable ["acex_headless_blacklist",true,true];
_contactEnemy setVariable ["WAIT_CortexQA_Label","INDOOR LIVE HOSTILE",true];
_contactGroup setCombatMode "RED";
_contactOpposition setCombatMode "RED";
[createHashMapFromArray [
    ["WAIT_AIPass_BuildingCombat_Enable",true],
    ["WAIT_AIPass_BuildingCombat_Range",100],
    ["WAIT_AIPass_Contact_Enable",true]
]] call WAIT_fnc_CortexTuning;
private _contactSightline=_contactGeometryReady && {_contactMembers findIf {
    (lineIntersectsSurfaces [eyePos _x,eyePos _contactEnemy,_x,_contactEnemy,true,1,"VIEW","NONE"]) isEqualTo []
} >= 0};
["BUILD-CONTACT-visible-fixture",_contactSightline,str [_contactRoom,_contactApproach,_contactGeometryReady]] call _check;
missionNamespace setVariable ["WAIT_CortexQA_Actors",_contactMembers+[_contactEnemy],true];
["Natural building contact","The six-person squad faces a live hostile physically inside the house. Native knowledge must form first; WAIT should then transition directly from contact into its single building-clear operation and physically enter. The hostile is a posted interior defender with pathfinding disabled; native sensing and fire remain. The audit injects no reveal, clear order or route.",getPosATL _contactHouse] call _phase;
private _nativeContact=[{(units _contactGroup) findIf {_x knowsAbout _contactEnemy >= 1} >= 0},30] call _wait;
["BUILD-CONTACT-native-knowledge",_nativeContact,str (_contactMembers apply {_x knowsAbout _contactEnemy})] call _check;
private _interiorDefenderHeld=(getPosASL _contactEnemy) vectorDistance (AGLToASL _contactRoom) <= 1.5;
["BUILD-CONTACT-interior-defender-retained",_interiorDefenderHeld,
    str [getPosATL _contactEnemy,_contactRoom,currentCommand _contactEnemy]] call _check;
private _naturalClear=[{_contactGroup getVariable ["WAIT_AIPass_ClearBuilding",false]},20] call _wait;
["BUILD-CONTACT-natural-clear-started",_nativeContact && {_naturalClear},str [_contactGroup getVariable ["WAIT_Cortex_ClearStatus",[]],_contactGroup getVariable ["WAIT_OperationResult",[]]]] call _check;
private _naturalEntry=[{_contactRooms findIf {
    private _room=_x;
    _contactMembers findIf {alive _x && {(getPosASL _x) vectorDistance (AGLToASL _room) <= 1.5}} >= 0
} >= 0},90] call _wait;
["BUILD-CONTACT-physical-entry",_naturalClear && {_naturalEntry},str (_contactMembers apply {[getPosATL _x,currentCommand _x,expectedDestination _x]})] call _check;
[_contactGroup] call WAIT_fnc_CortexClearRelease;
missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
{deleteVehicle _x} forEach (_contactMembers+[_contactEnemy]);
deleteGroup _contactGroup;
deleteGroup _contactOpposition;
deleteVehicle _contactHouse;
