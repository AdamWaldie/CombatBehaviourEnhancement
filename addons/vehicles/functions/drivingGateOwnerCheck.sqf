/*
 * Author: WaldoTheWarfighter
 * Purpose: Read current gate-related native intent on the actual operating crew owner.
 * Locality/authority: Owner-local read only; never opens gates or commands vehicles.
 * Repeat/JIP: Stateless snapshot, no timer, cache, replay or movement authority.
 * Arguments: 0 group GROUP grpNull; 1 vehicle OBJECT objNull; 2 route ARRAY [];
 * 3 convoy revision NUMBER -1; 4 prior native destinations ARRAY []; 5 prior tasks ARRAY []; 6 opening direction NUMBER1, +1/-1 (ordinary only).
 * Return: ARRAY [native destinations,tasks], or[] when intent cannot be proved.
 * Current callers: DrivingGateOwnerEvidence owner probe and local server gate checks.
 * Example: private _proof=[group driver truck1,truck1,_route,-1] call CBE_fnc_DrivingGateOwnerCheck;
 */
params [["_gateGroup",grpNull,[grpNull]],["_gateVehicle",objNull,[objNull]],
    ["_gateRoute",[],[[]]],["_gateRevision",-1,[0]],["_gateBefore",[],[[]]],["_gateTasksBefore",[],[[]]],["_gateDirection",1,[0]]];
if (isNull _gateGroup || {isNull _gateVehicle} || {!local _gateGroup} || {!local _gateVehicle}
    || {!alive _gateVehicle} || {!simulationEnabled _gateVehicle} || {isObjectHidden _gateVehicle}
    || {[_gateGroup] call CBE_fnc_CortexZeusHeld} || {[_gateGroup] call CBE_fnc_CortexExternalTakeover}
    || {!isNil {_gateVehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[] call CBE_fnc_CortexIsPaused}
    || {([_gateGroup] call CBE_fnc_DrivingRouteReceipt) isNotEqualTo _gateRoute}) exitWith {[]};
private _gateDriver=driver _gateVehicle;private _gateCommander=effectiveCommander _gateVehicle;
if (isNull _gateCommander) then {_gateCommander=_gateDriver};
if ([_gateDriver,_gateCommander] findIf {isNull _x || {!local _x} || {!alive _x}
    || {group _x != _gateGroup} || {isPlayer _x} || {!isNull remoteControlled _x}
    || {!simulationEnabled _x} || {isObjectHidden _x}
    || {!([_x] call CBE_fnc_CortexCombatEffective)}
    || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} >= 0) exitWith {[]};
// Rear opening needs current owner-local observation, not a caller direction flag.
// Exact cap/brain/task/route identity survives only this ordinary native leg.
if (!(_gateDirection in [-1,1]) || {_gateDirection == -1 && {_gateRevision >= 0}}) exitWith {[]};
if (_gateDirection == -1) then {
    private _directionBrain=_gateGroup getVariable ["CBE_Driving_Brain",createHashMap];
    private _directionContext=[_gateGroup,clientOwner,_directionBrain getOrDefault ["ownerEpoch",-1],
        _directionBrain getOrDefault ["generation",-1],_gateRoute,_gateDriver,_gateCommander];
    private _directionFrame=[_gateDriver,_gateCommander] apply {
        private _command=toUpperANSI currentCommand _x;
        if (_command in ["","MOVE","WAIT"]) then {_command="TRAVEL"};
        [_command,+((expectedDestination _x) param [0,[],[[]]]),formLeader _x]
    };
    private _directionObservation=_gateVehicle getVariable ["CBE_DrivingDirection_Observation",[]];
    private _directionCap=_gateVehicle getVariable ["CBE_DrivingAssist_State",[]];
    private _directionVelocity=(velocity _gateVehicle) vectorDotProduct (vectorNormalized vectorDir _gateVehicle);
    private _directionPathAt=(_gateVehicle getVariable ["CBE_DrivingNativePath_Segment",[]]) param [1,-1,[0]];
    private _directionMode=toUpperANSI ((vehicleMoveInfo _gateVehicle) param [0,"",[""]]);
    private _reverseCurrent=count _directionBrain > 0
        && {!(_directionBrain getOrDefault ["cancelled",false])} && {!(_directionBrain getOrDefault ["finished",false])}
        && {(_directionBrain getOrDefault ["ownerEpoch",-1]) == (_gateGroup getVariable ["CBE_AIPass_Epoch",0])}
        && {count _directionObservation == 4}
        && {(_directionObservation select 0) isEqualTo _directionContext}
        && {(_directionObservation select 1) isEqualTo _directionFrame}
        && {(_directionObservation select 2) isEqualTo -1}
        && {(_directionObservation select 3) isEqualType 0} && {finite (_directionObservation select 3)}
        && {count _directionCap == 12} && {(_directionCap select 3) == _gateGroup}
        && {(_directionCap select 9) isEqualTo _gateRoute}
        && {(_directionCap select 10) isEqualTo false}
        && {time >= (_directionCap select 2)} && {time-(_directionCap select 2) <= 6}
        && {abs ((getForcedSpeed _gateVehicle)-(_directionCap select 0)) <= 0.1}
        && {finite _directionVelocity} && {_directionVelocity <= 0.15}
        && {!(_directionMode in ["FORWARD","FAST","SLOW"])}
        && {_directionVelocity < -0.15 || {finite _directionPathAt
            && {_directionPathAt <= (_directionObservation select 3)}}}
        && {["CBE_DrivingPass_Work","CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work"]
            findIf {!isNil {_gateVehicle getVariable _x}} < 0};
    if (!_reverseCurrent) then {_gateDirection=0};
};
if (_gateDirection == 0) exitWith {[]};
private _gateNative=[+(expectedDestination _gateDriver),+(expectedDestination _gateCommander)];
private _gateTasks=[currentCommand _gateDriver,currentCommand _gateCommander];
if (_gateTasks findIf {!(_x in ["","MOVE","FOLLOW","WAIT","STOP"])} >= 0) exitWith {[]};
if (_gateTasksBefore isNotEqualTo [] && {count _gateTasksBefore != 2
    || {[0,1] findIf {(_gateTasks select _x) == "STOP" && {(_gateTasksBefore select _x) != "STOP"}} >= 0}}) exitWith {[]};
if (_gateRevision < 0) exitWith {
    if (missionNamespace getVariable ["CBE_AIPass_Active",false]
        && {[_gateGroup] call CBE_fnc_DrivingMovementAvailable}
        && {[_gateGroup,"CBE_AIPass_DrivingAssist_Enable",true,_gateVehicle] call CBE_fnc_CortexFeatureEnabled}
        && {[_gateGroup,_gateVehicle,_gateRoute] call CBE_fnc_DrivingGateIntent}) then {[_gateNative,_gateTasks]} else {[]}
};
private _gateRegistry=missionNamespace getVariable [["CBE_Convoy_LocalRegistry","CBE_Convoy_Registry"] select isServer,[]];
private _gateIndex=_gateRegistry findIf {(_x select 0) == _gateGroup};
if (_gateIndex < 0) exitWith {[]};
private _gateConfig=(_gateRegistry select _gateIndex) select 1;
if ((_gateConfig select 0) != _gateRevision || {(_gateConfig select 5) != "TRAVEL"}
    || {!(_gateVehicle in (_gateConfig select 4))}
    || {!([_gateGroup,"CBE_Convoy_DrivingAssist_Enable",true,_gateVehicle] call CBE_fnc_CortexFeatureEnabled)}
    || {((_gateGroup getVariable ["CBE_Convoy_CommandYield",[]]) param [0,-2]) == _gateRevision}) exitWith {[]};
private _gateCurrent=_gateBefore isEqualTo [] || {_gateNative isEqualTo _gateBefore};
if (!_gateCurrent) then {
    private _gateReceipt=_gateVehicle getVariable ["CBE_Convoy_MovementReceipt",[]];
    if (count _gateReceipt == 8 && {(_gateReceipt select 0) == _gateGroup} && {(_gateReceipt select 1) == _gateRevision}
        && {(_gateReceipt select 2) == _gateDriver} && {(_gateReceipt select 3) == _gateCommander}
        && {(_gateReceipt select 6) isEqualTo []} && {(_gateReceipt select 4) isEqualTo (_gateNative select 1)}) then {
        private _gateDriverProof=_gateReceipt select 7;
        _gateCurrent=count _gateDriverProof == 2 && {_gateDriver == _gateCommander
            || {(_gateDriverProof select 1) isEqualTo (_gateNative select 0)}};
    };
};
if (_gateCurrent) then {[_gateNative,_gateTasks]} else {[]}
