/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe passage and close only the gate leaves opened by one admitted driving request.
 * Locality/authority: Server, unscheduled shared scheduler only; original route, crew, owners,
 * gate pose, lock and private opening receipt remain authoritative. No vehicle commands.
 * Repeat/JIP: One attempt, original120s lifetime, <=8 active server jobs, <=8 leaves and
 * <=16 nearby entities/sample. No deadline renewal, remote replay, takeover or close retry.
 * Jobs have no group key: server observes a remote group's gate without adopting its AI.
 * Arguments: 0 job HASHMAP, empty; created only by DrivingGateOpenServer after actual opening.
 * Return: NUMBER,2 while observing passage,1 while observing requested closure,-1 retired.
 * Current callers: CortexQueueJob callback registered by DrivingGateOpenServer.
 * Example: private _delay=[_job] call CBE_fnc_DrivingGateCloseServer;
 * Passage requires an observed bounded segment through the gate aperture and current whole-hull
 * clearance. Sampled traffic clearance is not continuous collision proof. CLOSE_REQUESTED is
 * separate from CLOSED_OBSERVED. An indistinguishable intervening same-value gate edit is unknown.
 */
params [["_job",createHashMap,[createHashMap]]];
if (!isServer || {canSuspend} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {-1};
private _gate=_job getOrDefault ["gate",objNull];
private _vehicle=_job getOrDefault ["vehicle",objNull];
private _taskGroup=_job getOrDefault ["taskGroup",grpNull];
private _retire={
    params ["_reason"];
    _job set ["done",true];
    if (!isNull _gate && {(_gate getVariable ["CBE_DrivingGate_CloseWork",createHashMap]) isEqualTo _job}) then {
        if (_reason == "CLOSED_OBSERVED") then {
            private _proof=[+(_job get "transform"),_job get "generation",serverTime];
            // The server consumes its private proof. Owners receive a separate hint only.
            _gate setVariable ["CBE_DrivingGate_ClosedProof",_proof];
            _gate setVariable ["CBE_DrivingGate_ClosedCycle",+_proof,true];
        };
        _gate setVariable ["CBE_DrivingGate_CloseWork",nil];
        _gate setVariable ["CBE_DrivingGate_CloseResult",[_reason,serverTime,_vehicle,_job get "until"],true];
    };
    private _jobs=missionNamespace getVariable ["CBE_DrivingGate_CloseJobs",[]];
    missionNamespace setVariable ["CBE_DrivingGate_CloseJobs",_jobs select {_x isNotEqualTo _job}];
    -1
};
if (isNull _gate || {!alive _gate}
    || {(_gate getVariable ["CBE_DrivingGate_CloseWork",createHashMap]) isNotEqualTo _job}
    || {serverTime >= (_job get "until")}) exitWith {["EXPIRED_OR_LOST"] call _retire};
// Issued animation needs observation only: a departing vehicle/changed route cannot
// create another gate command, but must not erase observed completion of the old one.
if ((_job get "phase") == "CLOSING") exitWith {
    if ((_job get "transform") isNotEqualTo [getPosWorld _gate,vectorDir _gate,vectorUp _gate]
        || {(_gate getVariable ["CBE_DrivingGate_ServerOpening",[]]) isNotEqualTo (_job get "opening")}) exitWith {["CLOSURE_CONTEXT_CHANGED"] call _retire};
    private _closed=true;
    {if (abs ((_gate animationSourcePhase (_x select 1))-(_x select 2)) > 0.02) then {_closed=false}} forEach (_job get "leaves");
    if (_closed) then {["CLOSED_OBSERVED"] call _retire} else {1}
};
if (isNull _vehicle || {isNull _taskGroup} || {!alive _vehicle}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}) exitWith {["VEHICLE_LOST"] call _retire};
private _driver=_job get "driver";private _commander=_job get "commander";
private _currentCommander=effectiveCommander _vehicle;
if (isNull _currentCommander) then {_currentCommander=driver _vehicle};
if (driver _vehicle != _driver || {_currentCommander != _commander}
    || {owner _driver != (_job get "driverOwner")} || {owner _commander != (_job get "commanderOwner")}
    || {groupOwner _taskGroup != (_job get "groupOwner")} || {owner _vehicle != (_job get "vehicleOwner")}
    || {[_driver,_commander] findIf {isNull _x || {!alive _x} || {isPlayer _x}
        || {!isNull remoteControlled _x} || {group _x != _taskGroup}} >= 0}
    || {([_taskGroup] call CBE_fnc_DrivingRouteReceipt) isNotEqualTo (_job get "route")}
    || {[_taskGroup] call CBE_fnc_CortexExternalTakeover}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[] call CBE_fnc_CortexIsPaused}
    || {!([_taskGroup,"CBE_AIPass_DrivingAssist_CloseGates_Enable",false,_vehicle] call CBE_fnc_CortexFeatureEnabled)}
    || {(_job get "transform") isNotEqualTo [getPosWorld _gate,vectorDir _gate,vectorUp _gate]}
    || {(_gate getVariable ["CBE_DrivingGate_ServerOpening",[]]) isNotEqualTo (_job get "opening")}
    || {(_gate getVariable ["bis_disabled_Door",0]) isNotEqualTo 0}) exitWith {["AUTHORITY_CHANGED"] call _retire};
if ((_taskGroup getVariable ["CBE_AIPass_Epoch",0]) != (_job get "epoch")
    || {(_taskGroup getVariable ["CBE_OperationGeneration",0]) != (_job get "operation")}) exitWith {["OPERATION_CHANGED"] call _retire};
private _revision=_job get "revision";
private _enabled=if (_revision < 0) then {
    missionNamespace getVariable ["CBE_AIPass_Active",false]
        && {[_taskGroup,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
} else {
    private _registry=missionNamespace getVariable ["CBE_Convoy_Registry",[]];
    private _index=_registry findIf {(_x select 0) == _taskGroup};
    if (_index < 0) then {false} else {
        private _config=(_registry select _index) select 1;
        (_config select 0) == _revision && {(_config select 5) == "TRAVEL"}
            && {_vehicle in (_config select 4)}
            && {[_taskGroup,"CBE_Convoy_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
    }
};
if (!_enabled) exitWith {["DRIVING_ENDED"] call _retire};
private _native=[+(expectedDestination _driver),+(expectedDestination _commander)];
private _tasks=[currentCommand _driver,currentCommand _commander];
private _nativeCurrent=_native isEqualTo (_job get "native");
if (_revision >= 0 && {!_nativeCurrent}) then {
    private _receipt=_vehicle getVariable ["CBE_Convoy_MovementReceipt",[]];
    if (count _receipt == 8 && {(_receipt select 0) == _taskGroup} && {(_receipt select 1) == _revision}
        && {(_receipt select 2) == _driver} && {(_receipt select 3) == _commander}
        && {(_receipt select 6) isEqualTo []} && {(_receipt select 4) isEqualTo (_native select 1)}) then {
        private _driverProof=_receipt select 7;
        _nativeCurrent=count _driverProof == 2
            && {_driver == _commander || {(_driverProof select 1) isEqualTo (_native select 0)}};
    };
};
if (_revision < 0) then {_nativeCurrent=[_taskGroup,_vehicle,_job get "route"] call CBE_fnc_DrivingGateIntent};
private _taskConflict=false;
{
    if (!(_x in ["","MOVE","FOLLOW","WAIT","STOP"])
        || {_x == "STOP" && {((_job get "nativeTasks") select _forEachIndex) != "STOP"}}) exitWith {_taskConflict=true};
} forEach _tasks;
if (!_nativeCurrent || {_taskConflict}
    || {_revision >= 0 && {((_taskGroup getVariable ["CBE_Convoy_CommandYield",[]]) param [0,-2]) == _revision}}) exitWith {["NATIVE_ORDER_CHANGED"] call _retire};
_job set ["native",_native];_job set ["nativeTasks",_tasks];

if ((_job get "otherLeaves") findIf {abs ((_gate animationSourcePhase (_x select 1))-(_x select 2)) > 0.02} >= 0) exitWith {["OTHER_LEAF_CHANGED"] call _retire};
private _leaves=_job get "leaves";
if (_leaves findIf {(_gate getVariable [format ["bis_disabled_Door_%1",_x select 0],0]) isNotEqualTo 0} >= 0) exitWith {["LOCKED"] call _retire};
private _phases=_leaves apply {_gate animationSourcePhase (_x select 1)};

private _lastPhases=_job get "lastPhases";
private _animationChanged=false;
{
    if (_x < (_lastPhases select _forEachIndex)-0.02 || {_x < -0.02} || {_x > 1.02}) exitWith {_animationChanged=true};
} forEach _phases;
if (_animationChanged) exitWith {["ANIMATION_CHANGED"] call _retire};
_job set ["lastPhases",_phases];
private _open=_phases findIf {_x < 0.98} < 0;
if (!_open && {serverTime-(_job get "started") > 12}) exitWith {["OPEN_NOT_OBSERVED"] call _retire};
private _origin=_job get "origin";private _axis=_job get "axis";private _side=_job get "side";
private _position=getPosWorld _vehicle;private _sample=_job get "sample";
private _elapsed=serverTime-(_sample select 0);
if (_elapsed <= 0 || {_elapsed > 6} || {_position distance (_sample select 1) > 25}) exitWith {["PASSAGE_SAMPLE_LOST"] call _retire};
private _before=((_sample select 1) vectorDiff _origin) vectorDotProduct _axis;
private _after=(_position vectorDiff _origin) vectorDotProduct _axis;
if (!(_job get "crossed") && {_before < 0} && {_after >= 0}) then {
    private _fraction=(-_before)/(_after-_before);
    private _cross=(_sample select 1) vectorAdd ((_position vectorDiff (_sample select 1)) vectorMultiply _fraction);
    private _crossSide=(_cross vectorDiff _origin) vectorDotProduct _side;
    private _lateral=[_vehicle,_position,_side] call CBE_fnc_DrivingHullInterval;
    private _aperture=_job get "aperture";
    if (count _lateral == 2 && {_crossSide+(_lateral select 0) > (_aperture select 0)}
        && {_crossSide+(_lateral select 1) < (_aperture select 1)}) then {_job set ["crossed",true]};
};
_job set ["sample",[serverTime,_position]];
if (!_open || {!(_job get "crossed")} || {serverTime-(_job get "started") < 5}) exitWith {2};
private _span=[_vehicle,_origin,_axis] call CBE_fnc_DrivingHullInterval;
if (count _span != 2 || {(_span select 0) <= ((_job get "gateSpan") select 1)+3}) exitWith {2};
// Area syntax includes dead vehicles/bodies; the basic radius form omits them.
private _near=[ASLToAGL _origin,25,25,0,false,8] nearEntities [["CAManBase","LandVehicle","Air"],false,false,false];
if (count _near > 16) exitWith {2};
private _clear=true;private _aperture=_job get "aperture";private _gateSpan=_job get "gateSpan";
{
    if (_x == _vehicle || {objectParent _x == _vehicle}) then {continue};
    if (_x isKindOf "CAManBase") then {
        private _delta=(getPosWorld _x) vectorDiff _origin;
        if (abs (_delta vectorDotProduct _axis) <= 4
            && {(_delta vectorDotProduct _side) >= (_aperture select 0)-2}
            && {(_delta vectorDotProduct _side) <= (_aperture select 1)+2}) exitWith {_clear=false};
    } else {
        // Active traffic in this small approach area keeps the gate open. Parked bodies
        // still block when their full hull occupies the gate's closure envelope.
        if (abs speed _x > 1 || {!unitReady _x && {crew _x isNotEqualTo []}}) exitWith {_clear=false};
        private _hull=[_x,_origin,_axis,_side] call CBE_fnc_DrivingHullInterval;
        if (count _hull != 4
            || {(_hull select 0) < (_gateSpan select 1)+3 && {(_hull select 1) > (_gateSpan select 0)-3}
                && {(_hull select 2) < (_aperture select 1)+2} && {(_hull select 3) > (_aperture select 0)-2}}) exitWith {_clear=false};
    };
} forEach _near;
if (!_clear) exitWith {2};
// This callback is unscheduled. No wait separates the exact phase/ownership checks,
// the sampled clearance above and this single native closure request.
{_gate animateSource [_x select 1,_x select 2]} forEach _leaves;
_job set ["phase","CLOSING"];
_gate setVariable ["CBE_DrivingGate_CloseResult",["CLOSE_REQUESTED",serverTime,_vehicle,_job get "until"],true];
1
