/*
 * Author: WaldoTheWarfighter
 * Native crew flight vetoes new steering and route recall; exact cap-only release remains separate.
 * Purpose: Hands back an unchanged authored route after an exact owned queue-abort STOP,
 * only when the existing driving observer has fresh clear traffic/geometry and an owned cap.
 * Locality/authority: current ordinary-driving vehicle/group owner and exact original brain
 * identity. New native orders, seats, route, reservations or successor work retire authority.
 * Repeat/JIP: consume once before native issue; original queue expiry plus15s bounds cleanup.
 * Public receipt alone grants no replay authority. Migration requires the local group-edge proposal,
 * unchanged released baseline and native/crew/route proof before registering existing cleanup.
 * Adopted cleanup republishes its owner identity for a subsequent transfer only when no driving brain exists.
 * Controlled same-owner master-stop adoption requires source identity, exact next epoch,
 * unchanged generation, released baseline and current STOP/route/crew validation; it issues no movement.
 * A released-cap receipt permits original-owner cleanup through the existing bounded observer,
 * with at most one fresh traffic/geometry observation per second and no speed mutation.
 * Arguments: 0 vehicle <OBJECT,objNull>; 1 group <GROUP,grpNull>; 2 brain <HASHMAP,empty>;
 * 3 safety <ARRAY,[]> [traffic observation, gate observation, solid observation, cap m/s];
 * 4 current route/authority predicate <CODE,{false}>, synchronous caller context only;
 * 5 source owner receipt <ARRAY,[]> internal master-stop or group-edge transfer proposal.
 * Return: BOOL true when route handoff was issued, not proof of travel or queue completion.
 * Cost: fixed two-seat checks; released cleanup uses existing bounded traffic/geometry sensors
 * at most once per second per receipt. No speed write, new timer or new controller.
 * Current callers: DrivingAssistStart after its sole speed-cap transaction; DrivingRecoveryCleanup after release; CortexStop for controlled epoch adoption.
 * Example: [truck1,group driver truck1,_brain,[_traffic,_gate,_solid,_cap],{call _mayRecoverRoute}] call CBE_fnc_DrivingAbortHandback;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_brain",createHashMap,[createHashMap]],["_safety",[],[[]]],["_mayResume",{false},[{}]],["_adoptFrom",[],[[]]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _vehicle} || {!local _vehicle} || {isNull _group} || {!local _group}) exitWith {false};
private _hold=_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap];
if (!(_hold isEqualType createHashMap) || {count _hold == 0}) exitWith {false};
private _retire={
    params ["_result"];
    if ((_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap]) isEqualTo _hold) then {
        _vehicle setVariable ["CBE_DrivingAbort_Hold",nil,true];
        _vehicle setVariable ["CBE_DrivingAbort_Result",[_result,serverTime,_hold getOrDefault ["binding",[]]],true];
    };
};
// Controlled master-stop or a captured group-locality edge may propose rebinding.
// This changes no native state and grants no extra lifetime. Ordinary calls cannot
// silently accept a different owner or executor generation.
private _ownerNow=[_group] call CBE_fnc_DrivingOwnerReceipt;
private _adoption=_adoptFrom isNotEqualTo [];
private _transfer=_group getVariable ["CBE_DrivingAbort_Transfer",[]];
private _transferValid=_transfer isEqualType [] && {count _transfer == 3}
    && {(_transfer select 0) isEqualTo _adoptFrom}
    && {(_transfer select 1) isEqualTo (_group getVariable ["CBE_AIPass_Epoch",0])}
    && {(_transfer select 2) isEqualType 0} && {finite (_transfer select 2)} && {serverTime < (_transfer select 2)}
    && {count _adoptFrom == 3} && {(_adoptFrom select 0) != clientOwner}
    && {count (_group getVariable ["CBE_Driving_Brain",createHashMap]) == 0}
    && {(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isEqualTo []};
private _adoptionValid=_adoption && {count _adoptFrom == 3} && {count _ownerNow == 3}
    && {_adoptFrom findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} < 0}
    && {(_hold getOrDefault ["owner",[]]) isEqualTo _adoptFrom}
    && {(_ownerNow select 0) == clientOwner}
    && {_transferValid || {(_adoptFrom select 0) == clientOwner
        && {(_ownerNow select 1) == (_adoptFrom select 1)+1}
        && {(_ownerNow select 2) == (_adoptFrom select 2)}}}
    && {"releasedCap" in _hold}
    && {private _baseline=_hold get "releasedCap";
        _baseline isEqualType 0 && {finite _baseline} && {_baseline != 0}
            && {abs ((getForcedSpeed _vehicle)-_baseline) <= 0.1}};
if (_adoption && {!_adoptionValid}) exitWith {false};
private _deadline=_hold getOrDefault ["deadline",-1];
private _route=_hold getOrDefault ["route",[]];
private _driver=_hold getOrDefault ["driver",objNull];private _operator=_hold getOrDefault ["operator",objNull];
// Crew locality can follow group and vehicle arrival. No native observation is trusted yet.
if (_adoptionValid && {[_driver,_operator] findIf {!isNull _x && {!local _x}} >= 0}) exitWith {false};
if (!(_deadline isEqualType 0) || {!finite _deadline} || {serverTime >= _deadline}
    || {(_hold getOrDefault ["group",grpNull]) != _group}
    || {!_adoptionValid && {(_hold getOrDefault ["owner",[]]) isNotEqualTo _ownerNow}}
    || {_route isNotEqualTo ([_group] call CBE_fnc_DrivingRouteReceipt)}
    || {driver _vehicle != _driver} || {effectiveCommander _vehicle != _operator}
    || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {[_group] call CBE_fnc_CortexExternalTakeover} || {[_group] call CBE_fnc_CortexZeusHeld}
    || {[_driver,_operator] findIf {isNull _x || {!local _x} || {group _x != _group}
        || {vehicle _x != _vehicle} || {currentCommand _x != "STOP"}
        || {isPlayer _x} || {!isNull remoteControlled _x}
        || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
        || {[_x] call CBE_fnc_CompatibilityExternalControl}
        || {[_x] call CBE_fnc_CortexActorMoveReserved}} >= 0}
    || {(expectedDestination _driver) isNotEqualTo (_hold getOrDefault ["driverCommand",[]])}
    || {(expectedDestination _operator) isNotEqualTo (_hold getOrDefault ["command",[]])}
    || {formLeader _driver != (_hold getOrDefault ["driverLeader",objNull])}
    || {formLeader _operator != (_hold getOrDefault ["operatorLeader",objNull])}) exitWith {["REPLACED_OR_EXPIRED"] call _retire;false};
if (["CBE_DrivingQueue_Consent","CBE_DrivingBypass_Work","CBE_DrivingPass_Work","CBE_DrivingRecovery_Work"] findIf {
    count (_vehicle getVariable [_x,createHashMap]) > 0
} >= 0 || {(_vehicle getVariable ["CBE_DrivingCorridor_Work",[]]) isNotEqualTo []}) exitWith {["SUCCESSOR"] call _retire;false};
if (_adoptionValid) exitWith {
    isNil {
        if ((_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap]) isEqualTo _hold
            && {([_group] call CBE_fnc_DrivingOwnerReceipt) isEqualTo _ownerNow}) then {
            _hold set ["owner",+_ownerNow];
            _vehicle setVariable ["CBE_DrivingAbort_Hold",_hold,true];
            // A second transfer must observe this adopted identity, not the previous
            // owner's status. This is cleanup status only, never FSM liveness or motion.
            if (count (_group getVariable ["CBE_Driving_Brain",createHashMap]) == 0) then {
                _group setVariable ["CBE_Driving_State",["HANDBACK",_ownerNow select 2,
                    serverTime,"ABORT_ADOPTED",clientOwner,_ownerNow select 1],true];
            };
            [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
        };
    };
    false
};
private _released="releasedCap" in _hold;
private _liveBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
if (_released && {count _liveBrain > 0}
    && {(_liveBrain getOrDefault ["generation",-1]) != ((_hold get "owner") select 2)
        || {(_liveBrain getOrDefault ["ownerEpoch",-1]) != ((_hold get "owner") select 1)}}) exitWith {["SUCCESSOR_EXECUTOR"] call _retire;false};
if (_released) then {
    private _baseline=_hold get "releasedCap";
    if (!(_baseline isEqualType 0) || {!finite _baseline} || {_baseline == 0}
        || {abs ((getForcedSpeed _vehicle)-_baseline) > 0.1}) then {["CAP_REPLACED_OR_HELD"] call _retire};
};
if ((_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap]) isNotEqualTo _hold) exitWith {false};
if (!_released && {_liveBrain isNotEqualTo _brain || {_brain getOrDefault ["finished",false]}
    || {_brain getOrDefault ["cancelled",false]}}) exitWith {false};
if (_released && {_safety isEqualTo []} && {call _mayResume}) then {
    // The existing cleanup service owns cadence. Throttle expensive safety observation
    // per receipt and preserve the original deadline even when no safe lane appears.
    private _baseline=_hold get "releasedCap";
    if (alive _vehicle && {canMove _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {vectorMagnitude velocity _vehicle < 0.1} && {vectorMagnitude angularVelocity _vehicle < 0.01}
        && {[_driver,_operator] findIf {fleeing _x || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} < 0}
        && {abs ((getForcedSpeed _vehicle)-_baseline) <= 0.1}
        && {serverTime >= (_hold getOrDefault ["observeAt",-1])}) then {
        _hold set ["observeAt",serverTime+1];
        private _requested=((getNumber (configOf _vehicle >> "maxSpeed"))/3.6) max 0 min (120/3.6);
        if (_baseline > 0) then {_requested=_requested min _baseline};
        if (_requested > 0) then {
            private _traffic=[_vehicle,_requested] call CBE_fnc_DrivingFollowingCap;
            private _geometry=[_vehicle,_requested] call CBE_fnc_DrivingGeometryCap;
            _safety=[_traffic,_geometry select 0,_geometry select 1,_requested];
        };
    };
};
if (count _safety != 4) exitWith {false};
_safety params ["_traffic","_gate","_solid","_cap"];
if (!(_traffic isEqualType []) || {count _traffic < 4}
    || {!((_traffic select 1) isEqualType objNull)}
    || {!((_traffic select 3) isEqualType 0)} || {!finite (_traffic select 3)}
    || {!(_gate isEqualType [])} || {time < (_traffic select 3)} || {time-(_traffic select 3) > 1.5}
    || {!isNull (_traffic select 1)} || {_solid isNotEqualTo []}
    || {_gate isNotEqualTo [] && {count _gate < 4 || {!((_gate select 1) isEqualType objNull)}
        || {!((_gate select 3) isEqualType 0)} || {!finite (_gate select 3)} || {!isNull (_gate select 1)}
        || {time < (_gate select 3)} || {time-(_gate select 3) > 1.5}}}
    || {!(_cap isEqualType 0)} || {!finite _cap} || {_cap <= 0}) exitWith {false};
private _issued=false;
isNil {
    private _assist=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
    private _linear=vectorMagnitude velocity _vehicle;private _angular=vectorMagnitude angularVelocity _vehicle;
    private _input=vehicleMoveInfo _vehicle;
    if ((_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap]) isNotEqualTo _hold
        || {serverTime >= _deadline} || {!(call _mayResume)}
        || {(_hold get "owner") isNotEqualTo ([_group] call CBE_fnc_DrivingOwnerReceipt)}
        || {!_released && {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}}
        || {_released && {private _nowBrain=_group getVariable ["CBE_Driving_Brain",createHashMap];
            count _nowBrain > 0 && {(_nowBrain getOrDefault ["generation",-1]) != ((_hold get "owner") select 2)
                || {(_nowBrain getOrDefault ["ownerEpoch",-1]) != ((_hold get "owner") select 1)}}}}
        || {!alive _vehicle} || {!canMove _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {vehicle leader _group != _vehicle} || {!([_group] call CBE_fnc_DrivingMovementAvailable)}
        || {[_driver,_operator] findIf {fleeing _x || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} >= 0}
        || {!finite _linear} || {!finite _angular} || {_linear >= 0.1} || {_angular >= 0.01}
        || {if (_released) then {
            private _baseline=_hold get "releasedCap";
            !(_baseline isEqualType 0) || {!finite _baseline} || {_baseline == 0}
                || {abs ((getForcedSpeed _vehicle)-_baseline) > 0.1}
        } else {
            !(_assist isEqualType []) || {count _assist < 4}
                || {!((_assist select 0) isEqualType 0)} || {!finite (_assist select 0)}
                || {(_assist select 3) != _group} || {(_assist select 0) != _cap}
                || {abs ((getForcedSpeed _vehicle)-_cap) > 0.1}
        }}
        || {toUpperANSI (_input param [0,""]) in ["BACK","DIRECTBYCOMANDER"]}
        || {toUpperANSI (_input param [1,""]) in ["LEFT","RIGHT"]}
        || {currentCommand _driver != "STOP"} || {currentCommand _operator != "STOP"}
        || {(expectedDestination _driver) isNotEqualTo (_hold get "driverCommand")}
        || {(expectedDestination _operator) isNotEqualTo (_hold get "command")}) exitWith {};
    ["HANDOFF_ISSUED"] call _retire;
    if (_driver != _operator) then {_driver doFollow _operator};
    _operator doMove waypointPosition [_group,currentWaypoint _group];
    _issued=true;
};
_issued
