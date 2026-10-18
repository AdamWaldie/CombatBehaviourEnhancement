/*
 * Author: WaldoTheWarfighter
 * Purpose: Executes finite OUT, DROP_BACK, RETURN_SCAN, RETURN_READY and RETURN pass work in the driving FSM.
 * Locality/authority: Existing current ordinary-driving callback only. Exact epoch, generation,
 * route, crew, token and issued command receipts guard every fixed-path write. No speed writer:
 * the caller applies the returned cap with its unchanged traffic/pedestrian/geometry limits.
 * Observed native STOP events end work without recall. Own setup carries an exact write fence.
 * Repeated identical STOP delivery and event timing require physical interruption QA.
 * Repeat/JIP: Original consent context and finite expiry must still match; its deadline never renews. Return begins only after measured hull
 * separation. New native/controller orders retire work without recall. Each issued leg publishes
 * cleanup identity for successor owners, never the path/work. No physics or JIP replay.
 * Arguments: 0 group <GROUP>, grpNull; 1 vehicle <OBJECT>, objNull; 2 brain <HASHMAP>, empty;
 * 3 current caller movement guard <CODE>, false.
 * Return: ARRAY [active BOOL, cap m/s NUMBER, phase/reason STRING]. Terminal blocked aborts
 * retain failure evidence and may leave an owned STOP rather than merge through an occupied hull.
 * Each issue trims passed stations and validates a forward connector against current geometry
 * and traffic. Return scanning and issue run on separate callbacks: at most one 243-ray slice
 * OR a 159-ray connector plus one bounded traffic query. Native steering remains unverified.
 * Current callers: DrivingAssistStart only; admission is explicit DrivingPassBegin.
 * Example: [_group,_vehicle,_brain,_mayIssueDriving] call CBE_fnc_DrivingPassStep;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_mayIssue",{false},[{}]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2} || {isNull _vehicle} || {!local _vehicle}
    || {isNull _group} || {!local _group}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}) exitWith {[false,1e6,"NOT_CURRENT_OWNER"]};
private _work=_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap];
if (count _work == 0) exitWith {[false,1e6,""]};
if ((_work get "group") != _group) exitWith {
    [_vehicle,_work get "group","GROUP_CHANGED",false] call CBE_fnc_DrivingPassFinish;
    [false,1e6,"GROUP_CHANGED"]
};
private _driver=_work get "driver";private _operator=_work get "operator";private _peer=_work get "peer";
private _base={
    !(_work getOrDefault ["interrupted",false]) && {call _mayIssue} && {(_work get "epoch") == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_work get "generation") == (_brain getOrDefault ["generation",-1])}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
        && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo (_work get "route")}
        && {driver _vehicle == _driver} && {(effectiveCommander _vehicle) in [_operator,objNull]}
        && {[_driver,_operator] findIf {[_x] call CBE_fnc_CortexActorMoveReserved} < 0}
        && {[_driver,_operator] findIf {!(currentCommand _x in ["","MOVE","WAIT","STOP"])} < 0}
        && {(_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap]) isEqualTo _work}
};
private _current={call _base && {(expectedDestination _driver) isEqualTo (_work get "driverCommand")}
    && {(expectedDestination _operator) isEqualTo (_work get "command")}};
private _finish={params ["_reason",["_resume",false]];
    [_vehicle,_group,_reason,_resume] call CBE_fnc_DrivingPassFinish;
    [false,1e6,_reason]
};
if (_work getOrDefault ["interrupted",false]) exitWith {["NATIVE_STOP_EVENT",false] call _finish};
if !(call _current) exitWith {["OWNER_OR_ORDER_CHANGED",true] call _finish};
private _consent=_vehicle getVariable ["CBE_DrivingPass_Consent",[]];

if (isNull _peer) exitWith {["PEER_DELETED",true] call _finish};
// Use complete oriented hull intervals, not centre distance and nominal half lengths.
// Even the permitted heading difference changes longitudinal extent at the outer corners.
private _heading=getDir _peer;private _axis=[sin _heading,cos _heading,0];
private _origin=getPosWorld _peer;
private _span={
    params ["_object"];
    private _box=boundingBoxReal _object;private _low=_box select 0;private _high=_box select 1;
    private _minimum=1e9;private _maximum=-1e9;
    {private _xx=_x;{private _yy=_x;{
        private _point=(_object modelToWorldWorld [_xx,_yy,_x]) vectorDiff _origin;
        private _along=_point vectorDotProduct _axis;
        _minimum=_minimum min _along;_maximum=_maximum max _along;
    } forEach [_low select 2,_high select 2];} forEach [_low select 1,_high select 1];} forEach [_low select 0,_high select 0];
    [_minimum,_maximum]
};
private _ownSpan=[_vehicle] call _span;private _peerSpan=[_peer] call _span;
private _aligned=abs (((getDir _vehicle-getDir _peer+540) mod 360)-180) <= 25;
private _ahead=_aligned && {(_ownSpan select 0) > (_peerSpan select 1)+6};
private _behind=_aligned && {(_ownSpan select 1) < (_peerSpan select 0)-3};
if (!(_consent isEqualType []) || {count _consent != 5} || {(_consent select 0) isNotEqualTo (_work get "token")}
    || {(_consent select 4) isNotEqualTo "AGREED"}
    || {(_consent select 1) isNotEqualTo (_work get "context")}
    || {!((_consent select 3) isEqualType 0)} || {!finite (_consent select 3)}
    || {(_consent select 3) != (_work get "deadline")}) exitWith {["CONSENT_RETIRED",_ahead || {_behind}] call _finish};
if (serverTime >= (_work get "deadline")) exitWith {
    [["EXPIRED_HELD","EXPIRED_CLEAR"] select (_ahead || {_behind}),_ahead || {_behind}] call _finish
};
private _phase=_work get "phase";
private _pairContext=[[_vehicle,_peer]] call CBE_fnc_DrivingPassContext;
private _peerCurrent=_pairContext isNotEqualTo [] && {((_pairContext select 1) select 1) isEqualTo (_work get "peerRow")};
if ((!_peerCurrent || {!alive _peer} || {!_aligned}) && {_phase in ["OUT","RETURN_SCAN","RETURN_READY"]}) then {
    _phase="DROP_BACK";_work set ["phase",_phase];
};
private _issue={
    params ["_path","_newPhase"];
    private _issued=false;
    // Preparation/consent may span moving callbacks. Never steer back toward its old origin.
    private _pose=[getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle];
    private _originASL=_pose select 0;
    private _forward=+(_pose select 1);_forward set [2,0];_forward=vectorNormalized _forward;
    private _join=-1;
    if (count _path <= 128) then {
        _join=_path findIf {
            private _delta=(ATLToASL _x) vectorDiff _originASL;
            private _height=abs (_delta select 2);_delta set [2,0];
            private _distance=vectorMagnitude _delta;
            _distance >= 6 && {_distance <= 35} && {_height <= 2}
                && {(vectorNormalized _delta) vectorDotProduct _forward >= cos 20}
        };
    };
    if (_join < 0) exitWith {false};
    private _joinASL=ATLToASL (_path select _join);
    private _segments=ceil ((_originASL distance2D _joinASL)/5);
    private _connectorGuide=[];
    for "_i" from 0 to _segments do {
        _connectorGuide pushBack (_originASL vectorAdd ((_joinASL vectorDiff _originASL) vectorMultiply (_i/_segments)));
    };
    private _connector=createHashMapFromArray [["status","PROPOSAL"],["vehicles",[_vehicle,_peer]],
        ["context",_pairContext],["observedAt",serverTime],
        ["guideASL",_connectorGuide]];
    private _geometry=[_connector,0] call CBE_fnc_DrivingPassGeometry;
    if ((_geometry getOrDefault ["status",""]) != "SLICE_PROPOSAL") exitWith {false};
    private _joined=+(_geometry get "pointsATL");
    _joined append ((_path select [_join+1]) apply {+_x});
    if (count _joined > 128) exitWith {false};
    private _guide=_joined apply {ATLToASL _x};
    private _travel=0;
    for "_i" from 1 to (count _guide-1) do {
        _travel=_travel+((_guide select (_i-1)) distance (_guide select _i));
    };
    if (_travel <= 0 || {_travel > 350}) exitWith {false};
    private _proposal=createHashMapFromArray [["status","PROPOSAL"],["vehicles",[_vehicle,_peer]],
        ["context",_pairContext],["observedAt",serverTime],["guideASL",_guide],
        ["estimatedSeconds",((_work get "deadline")-serverTime) min 24],["requiredTravel",_travel]];
    private _traffic=[_proposal] call CBE_fnc_DrivingPassTraffic;
    if ((_traffic getOrDefault ["status",""]) != "TRAFFIC_OBSERVATION"
        || {_traffic getOrDefault ["blocked",true]}) exitWith {false};
    _path=_joined;
    // Keep the formation release and sole fixed-path write in one unscheduled boundary.
    isNil {
        if (count _path >= 2 && {call _current} && {serverTime < (_work get "deadline")}
            && {_pose isEqualTo [getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle]}
            && {_pairContext isEqualTo ([[_vehicle,_peer]] call CBE_fnc_DrivingPassContext)}) then {
            private _writing=[_vehicle,_work get "token",_work get "epoch",_work get "generation"];
            _group setVariable ["CBE_DrivingPass_CommandWriting",_writing];
            doStop _driver;if (_operator != _driver) then {doStop _operator};
            if (call _base) then {
                _vehicle setDriveOnPath _path;
                _work set ["driverCommand",+(expectedDestination _driver)];
                _work set ["command",+(expectedDestination _operator)];
                _work set ["issued",true];_work set ["phase",_newPhase];
                if (_newPhase == "OUT") then {_work set ["outPath",_path apply {+_x}]};
                // Cleanup identity only: successors must never replay the old fixed path.
                _vehicle setVariable ["CBE_DrivingPass_Leg",["PASS_LEG_V1",clientOwner,_group,
                    _work get "epoch",_work get "generation",_work get "token",_driver,_operator,
                    +(expectedDestination _driver),+(expectedDestination _operator),
                    _work get "route",_work get "deadline",_peer],true];
                _work set ["target",+(_path select (count _path-1))];
                _work set ["lastDistance",_vehicle distance2D (_work get "target")];
                _work set ["lastAt",serverTime];
                _issued=true;
            };
            if ((_group getVariable ["CBE_DrivingPass_CommandWriting",[]]) isEqualTo _writing) then {
                _group setVariable ["CBE_DrivingPass_CommandWriting",nil];
            };
        };
        false
    };
    _issued
};
if (!(_work get "issued") && {!_peerCurrent || {!_aligned} || {!alive _peer}}) exitWith {["ADMISSION_CONTEXT_CHANGED",false] call _finish};
if !(_work get "issued") exitWith {
    if !([_work get "outPath","OUT"] call _issue) exitWith {["PATH_NOT_ISSUED",false] call _finish};
    // Fresh connector and traffic already checked; no second query or return slice this callback.
    [true,_work get "cap","OUT"]
};
if (_phase == "OUT" && {_ahead}) then {
    _phase="RETURN_SCAN";_work set ["phase",_phase];_work set ["scanAt",serverTime];
};
if (_phase == "DROP_BACK") exitWith {
    if (_behind || {_ahead}) exitWith {["ABORT_CLEAR",true] call _finish};
    [true,(((velocityModelSpace _peer select 1) max 0)-12/3.6) max 0,"DROP_BACK"]
};
if (_phase == "RETURN_SCAN") exitWith {
    if (serverTime-(_work get "scanAt") >= 4) exitWith {["RETURN_SCAN_EXPIRED",_ahead] call _finish};
    private _proposal=createHashMapFromArray [["status","PROPOSAL"],["vehicles",[_vehicle,_peer]],
        ["context",_pairContext],["observedAt",serverTime],["guideASL",_work get "returnASL"]];
    private _slice=[_proposal,_work get "scanCursor"] call CBE_fnc_DrivingPassGeometry;
    if ((_slice getOrDefault ["status",""]) != "SLICE_PROPOSAL") exitWith {["RETURN_OBSTRUCTED",false] call _finish};
    private _points=_work get "returnValidated";
    _points append ((_slice get "pointsATL") select [[1,0] select ((_work get "scanCursor") == 0)]);
    _work set ["scanCursor",_slice get "next"];
    if (_slice get "lastSlice") then {
        _phase="RETURN_READY";_work set ["phase",_phase];
    };
    [true,[0,_work get "cap"] select (_phase == "RETURN"),_phase]
};
if (_phase == "RETURN_READY") exitWith {
    if (!_ahead || {serverTime-(_work get "scanAt") >= 4}) exitWith {["RETURN_JOIN_EXPIRED",false] call _finish};
    if !([_work get "returnValidated","RETURN"] call _issue) exitWith {["RETURN_JOIN_REFUSED",false] call _finish};
    [true,_work get "cap","RETURN"]
};
if (_phase == "RETURN") exitWith {
    private _target=_work get "target";
    if (_vehicle distance2D _target <= 4 && {abs (((getPosATL _vehicle) select 2)-(_target select 2)) <= 2}) exitWith {["RETURN_COMPLETE",true] call _finish};
    [true,_work get "cap","RETURN"]
};
// OUT retains all caller collision caps. An obstruction never grants traffic-ignore time.
private _proposal=createHashMapFromArray [["status","PROPOSAL"],["vehicles",[_vehicle,_peer]],
    ["context",_pairContext],["observedAt",serverTime],["guideASL",(_work get "outPath") apply {ATLToASL _x}],
    ["estimatedSeconds",((_work get "deadline")-serverTime) min 24],["requiredTravel",350]];
private _traffic=[_proposal] call CBE_fnc_DrivingPassTraffic;
private _distance=_vehicle distance2D (_work get "target");
if ((_work get "lastDistance")-_distance >= 1) then {_work set ["lastDistance",_distance];_work set ["lastAt",serverTime]};
if ((_traffic getOrDefault ["status",""]) != "TRAFFIC_OBSERVATION" || {_traffic getOrDefault ["blocked",true]}
    || {serverTime-(_work get "lastAt") >= 15} || {behaviour leader _group in ["COMBAT","STEALTH"]}) then {
    _work set ["phase","DROP_BACK"];
    [true,(((velocityModelSpace _peer select 1) max 0)-12/3.6) max 0,"DROP_BACK"]
} else {[true,_work get "cap","OUT"]}