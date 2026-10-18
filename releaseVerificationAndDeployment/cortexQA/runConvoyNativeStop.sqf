/*
 * Author: WaldoTheWarfighter
 * Purpose: Exercise real native convoy MOVE-to-STOP yield and later ordinary native travel.
 * Locality/authority: Scheduled server, normal batch only; observes actual group/crew owners.
 * Repeat/JIP: Fresh tracked fixtures on the matrix-validated route; public observer labels.
 * Public convoy release and fixture deletion occur only after assertions. No state completion,
 * direct cleanup, forced relocation, velocity assignment or controller reset supplies an outcome.
 * Arguments: 0 check <CODE>; 1 phase <CODE>; 2 wait <CODE>; 3 route <ARRAY> [start ATL,end ATL];
 * 4 heading <NUMBER>, 0. Route must be the matrix's validated first straight leg.
 * Return: Nothing; records missing prerequisites as failures. No HC/provider acceptance.
 * Current caller: runConvoyMatrix.sqf, before its own fixtures; focus convoynativestop runs only this.
 * Example: [_check,_phase,_wait,[_origin,_routeEnd],_heading] call compile preprocessFileLineNumbers "cortexQAConvoyNativeStop.sqf";
 */
params ["_check","_phase","_wait",["_route",[],[[]]],["_heading",0,[0]]];
private _id="CNVM-NATIVE-STOP";
private _normal=isServer && {canSuspend} && {!(missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false])};
[_id+"-normal-batch",_normal] call _check;
if (!_normal) exitWith {};
private _routeValid=count _route == 2 && {_route findIf {
    !(_x isEqualType []) || {count _x != 3} || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
} < 0} && {finite _heading};
[_id+"-validated-route-input",_routeValid] call _check;
if (!_routeValid) exitWith {};
private _origin=_route select 0;
private _group=createGroup [east,true];
_group setGroupIdGlobal [_id];
_group setVariable ["CBE_Headless_ExcludeGroup",true,true];
_group setVariable ["acex_headless_blacklist",true,true];
_group setVariable ["CBE_Convoy_CaptureControl",true];
private _vehicles=[];
private _crew=[];
for "_index" from 0 to 2 do {
    private _vehicle=createVehicle ["O_APC_Tracked_02_cannon_F",_origin getPos [30*_index,_heading+180],[],0,"NONE"];
    _vehicle setDir _heading;
    createVehicleCrew _vehicle;
    private _old=group driver _vehicle;
    (crew _vehicle) joinSilent _group;
    deleteGroup _old;
    {
        _crew pushBack [_x,_vehicle];
        _x setVariable ["acex_headless_blacklist",true,true];
        _x setVariable ["CBE_CortexQA_Label",format ["%1 / vehicle %2",_id,_index+1],true];
    } forEach crew _vehicle;
    _vehicles pushBack _vehicle;
};
missionNamespace setVariable ["CBE_CortexQA_Actors",_crew apply {_x select 0},true];
missionNamespace setVariable ["CBE_CortexQA_ConvoyVehicles",_vehicles,true];
_group selectLeader driver (_vehicles select 0);
_group setBehaviour "SAFE";
_group setCombatMode "BLUE";
private _waypoint=_group addWaypoint [_route select 1,0];
_waypoint setWaypointType "MOVE";
_waypoint setWaypointCompletionRadius 15;
private _vehicle=_vehicles select 1;
private _operator=effectiveCommander _vehicle;
private _driver=driver _vehicle;
private _nativeTravelOrigin=getPosASL _vehicle;
private _observedNativeReceipt=[];
private _ownersCurrent={
    local _group && {local _vehicle} && {local _driver} && {local _operator}
        && {driver _vehicle == _driver} && {effectiveCommander _vehicle == _operator}
        && {group _driver == _group} && {group _operator == _group}
        && {alive _driver} && {alive _operator} && {canMove _vehicle}
};
[_id+"-actual-local-owners",call _ownersCurrent,str [groupOwner _group,owner _vehicle,owner _driver,owner _operator]] call _check;
[_id,"A tracked follower must first acquire an actual native convoy MOVE and travel. The test then issues a real operator STOP; CBE must yield without a cleanup or feature reset.",getPosATL _vehicle] call _phase;
private _accepted=[_group,15,30,true] call CBE_fnc_SimpleAiConvoy;
[_id+"-public-start",_accepted] call _check;
private _revision=_group getVariable ["CBE_Convoy_Revision",-1];
private _moving=_accepted && {[{
    private _receipt=_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]];
    private _nativeOwned=call _ownersCurrent && {count _receipt == 6} && {(_receipt select 0) == _group}
        && {(_receipt select 1) == _revision} && {(_receipt select 2) == _driver}
        && {(_receipt select 3) == _operator} && {(_receipt select 5) == "NATIVE"}
        && {((expectedDestination _operator) param [0,[]]) vectorDistance ((_receipt select 4) param [0,[]]) <= 0.25}
        && {currentCommand _operator == "MOVE"};
    if (!_nativeOwned) exitWith {false};
    if (_observedNativeReceipt isNotEqualTo _receipt) then {
        _observedNativeReceipt=+_receipt;
        _nativeTravelOrigin=getPosASL _vehicle;
    };
    (getPosASL _vehicle) vectorDistance _nativeTravelOrigin >= 15
        && {(vectorMagnitude velocity _vehicle)*3.6 > 2}
},60] call _wait};
[_id+"-real-native-travel-prerequisite",_moving,str [getPosASL _vehicle,_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]]]] call _check;
private _stopIssued=false;
isNil {
    if (_moving && {call _ownersCurrent} && {currentCommand _operator == "MOVE"}
        && {(_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]]) isEqualTo _observedNativeReceipt}
        && {((expectedDestination _operator) param [0,[]]) vectorDistance ((_observedNativeReceipt select 4) param [0,[]]) <= 0.25}) then {
        doStop _operator;
        _stopIssued=true;
    };
};
private _yielded=_stopIssued && {[{
    private _yield=_group getVariable ["CBE_Convoy_CommandYield",[]];
    call _ownersCurrent && {count _yield >= 4} && {(_yield select 0) == _revision}
        && {(_yield select 1) == _vehicle} && {currentCommand _operator == "STOP"}
},12] call _wait};
[_id+"-replacement-stop-yielded",_yielded,str (_group getVariable ["CBE_Convoy_CommandYield",[]])] call _check;
private _rested=_yielded && {[{
    private _linear=vectorMagnitude velocity _vehicle;
    private _angular=vectorMagnitude angularVelocity _vehicle;
    call _ownersCurrent && {finite _linear} && {finite _angular}
        && {_linear*3.6 < 1} && {_angular < 0.01} && {currentCommand _operator == "STOP"}
},20] call _wait};
[_id+"-physical-stop",_rested,str [velocity _vehicle,angularVelocity _vehicle]] call _check;
private _stopNative=+(expectedDestination _operator);
private _stable=_rested;
if (_rested) then {
    private _stopIntentUntilServerTime=serverTime+5;
    private _observed=[{
        _stable=_stable && {call _ownersCurrent} && {currentCommand _operator == "STOP"}
            && {((expectedDestination _operator) param [0,[]]) isEqualTo (_stopNative param [0,[]])}
            && {(_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]]) isEqualTo []}
            && {((_group getVariable ["CBE_Convoy_CommandYield",[]]) param [0,-1]) == _revision}
            && {(vectorMagnitude velocity _vehicle)*3.6 < 1}
            && {vectorMagnitude angularVelocity _vehicle < 0.01};
        serverTime >= _stopIntentUntilServerTime
    },8] call _wait;
    _stable=_stable && {_observed};
};
[_id+"-sampled-stop-intent-stable",_stable,str [_stopNative,expectedDestination _operator]] call _check;
private _resumeOrigin=getPosASL _vehicle;
private _target=_origin getPos [400,_heading];
private _resumeReceipt=[];
private _freshMoveIssued=false;
if (_stable && {call _ownersCurrent}) then {
    [_id+" ordinary handover","A fresh ordinary MOVE must physically take the follower forward while the old convoy revision stays yielded. No public resume, cleanup, speed reset or owner transfer is injected.",_target] call _phase;
    isNil {
        if (call _ownersCurrent && {currentCommand _operator == "STOP"}
            && {((expectedDestination _operator) param [0,[]]) isEqualTo (_stopNative param [0,[]])}
            && {((_group getVariable ["CBE_Convoy_CommandYield",[]]) param [0,-1]) == _revision}
            && {(_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]]) isEqualTo []}) then {
            _operator doMove _target;
            _freshMoveIssued=true;
        };
    };
};
// Observe the requested native point before measuring its travel. Do not assume a
// post-command read is an acknowledgement; planner mode changes are not new destinations.
private _resumeObserved=_freshMoveIssued && {[{
    private _native=expectedDestination _operator;
    private _point=_native param [0,[]];
    private _validPoint=count _point == 3 && {_point findIf {!(_x isEqualType 0) || {!finite _x}} < 0};
    private _observed=call _ownersCurrent && {_validPoint} && {currentCommand _operator == "MOVE"}
        && {(AGLToASL _point) vectorDistance (ATLToASL _target) <= 3};
    if (_observed) then {_resumeReceipt=+_native; _resumeOrigin=getPosASL _vehicle};
    _observed
},10] call _wait};
[_id+"-fresh-native-command-observed",_resumeObserved,str _resumeReceipt] call _check;
private _travelled=_resumeObserved && {[{
    call _ownersCurrent && {(getPosASL _vehicle) vectorDistance _resumeOrigin >= 25}
        && {_vehicle distance2D _target < (_resumeOrigin distance2D (ATLToASL _target))-20}
        && {((expectedDestination _operator) param [0,[]]) isEqualTo (_resumeReceipt param [0,[]])}
        && {currentCommand _operator == "MOVE"}
        && {((_group getVariable ["CBE_Convoy_CommandYield",[]]) param [0,-1]) == _revision}
        && {(_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]]) isEqualTo []}
},60] call _wait};
[_id+"-fresh-native-move-physical",_travelled,str [getPosASL _vehicle,expectedDestination _operator]] call _check;
[_id+"-crew-retained",_crew findIf {!alive (_x select 0) || {vehicle (_x select 0) != (_x select 1)}} < 0] call _check;
// Assertions are finished. Only now retire the public convoy and delete this isolated fixture.
[_group,0,30,true,true] call CBE_fnc_SimpleAiConvoy;
{deleteVehicle (_x select 0)} forEach _crew;
{deleteVehicle _x} forEach _vehicles;
deleteGroup _group;
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
missionNamespace setVariable ["CBE_CortexQA_ConvoyVehicles",[],true];
