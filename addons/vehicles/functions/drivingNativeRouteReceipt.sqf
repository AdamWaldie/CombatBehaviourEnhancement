/*
 * Author: WaldoTheWarfighter
 * Purpose: Read one exact owner-local native MOVE intent without fabricating a waypoint.
 * Locality/authority: Local group and leader vehicle/driver/effective commander only.
 * Read-only command provenance; callers retain feature, Zeus/provider and movement authority.
 * Repeat/JIP: No state, worker or replay. Receipt binds current owner epoch/client and exact
 * seats. Existing recovery may retain its original receipt only through exact native command
 * classification without renewing parent lifetime. Cap authority remains with the caller.
 * A current brain may retain its already admitted vehicle goal through driver death
 * for the finite crew executor. Historical seat fields during this transition grant no
 * movement permission; confirmed replacement seats and original-goal ACK rebind them.
 * No crew locality adoption is inferred.
 * Arguments: 0 group GROUP grpNull.
 * Return: ARRAY [NATIVE_MOVE,group,vehicle,driver,operator,native frame,goal,epoch,clientOwner],
 * or[] when native intent/temporary leg is unknown. Same-value mission orders are indistinguishable.
 * Current callers: DrivingRouteReceipt and DrivingRouteGoal when no authored waypoint exists.
 * Example: private _intent=[group driver truck1] call CBE_fnc_DrivingNativeRouteReceipt;
 */
params [["_nativeGroup",grpNull,[grpNull]]];
if (isNull _nativeGroup || {!local _nativeGroup} || {count waypoints _nativeGroup > 1}) exitWith {[]};
private _nativeVehicle=vehicle leader _nativeGroup;
if (isNull _nativeVehicle || {_nativeVehicle == leader _nativeGroup}
    || {!local _nativeVehicle} || {!(_nativeVehicle isKindOf "LandVehicle")}
    || {_nativeVehicle isKindOf "StaticWeapon"}) exitWith {[]};
private _nativeDriver=driver _nativeVehicle;
private _nativeOperator=effectiveCommander _nativeVehicle;
if (isNull _nativeOperator) then {_nativeOperator=_nativeDriver};
// A current admitted vehicle intent can outlive its driver. This is route provenance
// for the finite crew executor, never permission for a new seat to drive. Native action
// and forward-goal acknowledgement remain in DrivingCrewStep.
private _nativeBrain=_nativeGroup getVariable ["CBE_Driving_Brain",createHashMap];
if !(_nativeBrain isEqualType createHashMap) exitWith {[]};
private _crewRoute=_nativeBrain getOrDefault ["route",[]];
private _crewWork=_nativeVehicle getVariable ["CBE_DrivingCrew_Work",createHashMap];
private _crewIntent=_crewRoute isEqualType [] && {count _crewRoute == 9}
    && {(_crewRoute param [0,"",[""]]) == "NATIVE_MOVE"}
    && {(_crewRoute select 1) isEqualTo _nativeGroup} && {(_crewRoute select 2) isEqualTo _nativeVehicle}
    && {(_crewRoute select 7) isEqualTo (_nativeGroup getVariable ["CBE_AIPass_Epoch",0])}
    && {(_crewRoute select 8) isEqualTo clientOwner}
    && {(_crewRoute select 6) isEqualType []} && {count (_crewRoute select 6) == 3}
    && {(_crewRoute select 6) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {(_nativeBrain getOrDefault ["ownerEpoch",-1]) isEqualTo (_crewRoute select 7)}
    && {!(_nativeBrain getOrDefault ["cancelled",true])} && {!(_nativeBrain getOrDefault ["finished",true])}
    && {(_crewRoute select 3) isEqualType objNull}
    && {!alive (_crewRoute select 3)};
if (_crewIntent) then {
    private _crewVacancy=isNull _nativeDriver || {_nativeDriver isEqualTo (_crewRoute select 3)};
    private _crewSwitch=_crewWork isEqualType createHashMap
        && {(_crewWork getOrDefault ["route",[]]) isEqualTo _crewRoute}
        && {(_crewWork getOrDefault ["group",grpNull]) isEqualTo _nativeGroup}
        && {(_crewWork getOrDefault ["phase",""]) in ["SWITCHING","RETURNING"]}
        && {_nativeDriver isEqualTo (_crewWork getOrDefault ["candidate",objNull])};
    _crewIntent=_crewVacancy || {_crewSwitch};
};
if (_crewIntent) exitWith {+_crewRoute};
if ([_nativeDriver,_nativeOperator] findIf {isNull _x || {!local _x}
    || {group _x != _nativeGroup} || {!alive _x}} >= 0) exitWith {[]};
private _nativeFrame=[currentCommand _nativeDriver,+(expectedDestination _nativeDriver),
    currentCommand _nativeOperator,+(expectedDestination _nativeOperator)];
private _nativeEpoch=_nativeGroup getVariable ["CBE_AIPass_Epoch",0];
private _nativeVector={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
if (!(_nativeEpoch isEqualType 0) || {!finite _nativeEpoch} || {_nativeEpoch < 0}
    || {_nativeEpoch != floor _nativeEpoch}) exitWith {[]};
private _nativeWork=_nativeVehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
if !(_nativeWork isEqualType createHashMap) exitWith {[]};
private _nativePrior=_nativeWork getOrDefault ["route",[]];
if !(_nativePrior isEqualType []) exitWith {[]};
if (count _nativeWork > 0 && {(_nativePrior param [0,"",[""]]) != "NATIVE_MOVE"}) exitWith {[]};
if (["CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work","CBE_DrivingPass_Work"]
    findIf {private _childProof=_nativeVehicle getVariable [_x,createHashMap];
        !(_childProof isEqualType createHashMap) || {count _childProof > 0}} >= 0) exitWith {[]};
if (count _nativeWork > 0 && {(_nativePrior param [0,"",[""]]) == "NATIVE_MOVE"}) exitWith {
    private _nativeBound=count _nativePrior == 9 && {(_nativePrior select 6) call _nativeVector}
        && {(_nativePrior select 1) isEqualTo _nativeGroup}
        && {(_nativePrior select 2) isEqualTo _nativeVehicle} && {(_nativePrior select 3) isEqualTo _nativeDriver}
        && {(_nativePrior select 4) isEqualTo _nativeOperator} && {(_nativePrior select 7) isEqualTo _nativeEpoch}
        && {(_nativePrior select 8) isEqualTo clientOwner}
        && {(_nativeWork getOrDefault ["group",grpNull]) == _nativeGroup}
        && {(_nativeWork getOrDefault ["driver",objNull]) == _nativeDriver}
        && {(_nativeWork getOrDefault ["operator",objNull]) == _nativeOperator}
        && {(_nativeFrame select 0) in ["","MOVE","WAIT"] || {"nativeReturn" in _nativeWork}}
        && {(_nativeFrame select 2) in ["","MOVE","WAIT"] || {"nativeReturn" in _nativeWork}};
    if (!_nativeBound) exitWith {[]};
    // The classifier is deliberately route-reader-free to prevent recursive identity queries.
    if ((_nativeWork getOrDefault ["commandMode","DESTINATION"]) == "DESTINATION"
        || {"nativeReturn" in _nativeWork}) exitWith {
        if (([_nativeVehicle,_nativeWork] call CBE_fnc_DrivingRecoveryCommandState) in ["OWNED","PENDING","EXPIRED"]) then {+_nativePrior} else {[]}
    };
    private _nativeInfo=vehicleMoveInfo _nativeVehicle;
    private _nativeSimple=_nativeDriver != _nativeOperator
        && {(_nativeInfo param [1,""]) == ((_nativeWork getOrDefault ["simpleBefore",[]]) param [1,"MISSING"])}
        && {toUpperANSI (_nativeInfo param [0,""]) == "BACK"
            || {_nativeWork getOrDefault ["simpleStopIssued",false] && {toUpperANSI (_nativeInfo param [0,""]) == "STOP"}}
            || {!(_nativeWork getOrDefault ["simpleAcknowledged",false])
                && {_nativeInfo isEqualTo (_nativeWork getOrDefault ["simpleBefore",[]])}}};
    if (_nativeSimple && {(_nativeWork getOrDefault ["commandMode",""]) == "SIMPLE_BACK"}
        && {(_nativeFrame select 1) isEqualTo (_nativeWork getOrDefault ["driverCommand",[]])}
        && {(_nativeFrame select 3) isEqualTo (_nativeWork getOrDefault ["command",[]])}) then {+_nativePrior} else {[]}
};
if ((_nativeFrame select 0) != "MOVE" || {(_nativeFrame select 2) != "MOVE"}) exitWith {[]};
private _nativeGoal=(_nativeFrame select 3) param [0,[],[[]]];
private _nativeDriverGoal=(_nativeFrame select 1) param [0,[],[[]]];

if (!(_nativeGoal call _nativeVector) || {!(_nativeDriverGoal call _nativeVector)}
    || {_nativeDriverGoal vectorDistance _nativeGoal > 3}) exitWith {[]};
// Native planning flags may change while the same goal remains in force. Keep the admitted
// original identity, including after observed handback, rather than renewing its recovery budget.
private _admitted=_nativeBrain getOrDefault ["route",[]];
if !(_admitted isEqualType []) exitWith {[]};
if (count _admitted == 9 && {(_admitted param [0,"",[""]]) == "NATIVE_MOVE"}
    && {(_admitted select 1) isEqualTo _nativeGroup} && {(_admitted select 2) isEqualTo _nativeVehicle}
    && {(_admitted select 3) isEqualTo _nativeDriver} && {(_admitted select 4) isEqualTo _nativeOperator}
    && {(_admitted select 7) isEqualTo _nativeEpoch} && {(_admitted select 8) isEqualTo clientOwner}
    && {(_admitted select 6) isEqualTo _nativeGoal}) exitWith {+_admitted};
["NATIVE_MOVE",_nativeGroup,_nativeVehicle,_nativeDriver,_nativeOperator,_nativeFrame,+_nativeGoal,_nativeEpoch,clientOwner]
