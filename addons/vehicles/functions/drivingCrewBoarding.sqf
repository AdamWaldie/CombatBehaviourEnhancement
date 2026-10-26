/*
 * Author: WaldoTheWarfighter
 * Native water-damaged engines refuse new movement/crew admission; cleanup remains available.
 * Native planner data waits and delayed search preserve existing intent and original budgets.
 * Native fleeing ends cooperation without cancelling the boarding order.
 * Pending ACE care ends native-boarding cooperation without clearing its queue or renewing seat deadlines.
 * Purpose: Offers a finite vehicle wait for an already-ordered operating crew member.
 * Locality/authority: Existing ordinary-driving callback, current group/vehicle owner only.
 * Default behaviour reads native GET IN and the exact assigned operating seat. Optional recall
 * requests ordinary reboarding once after20 seconds idle outside an observed seat; it never
 * changes assignments, force-seats actors or changes speed. DrivingAssistStart remains the sole speed writer.
 * Repeat/JIP: Public per-seat deadlines survive owner/brain replacement on the same authored
 * route. Expired attempts cannot renew until physical boarding or assignment removal/change.
 * Twelve seconds without measured two-metre actor motion ends the wait unless native
 * INIT/INITFAILED/PLANNING/REPLAN/DELAY is pending. That search may use only the original60-second limit;
 * it does not update motion evidence or renew any clock. Native boarding is never cancelled.
 * Progress anchors/clocks survive migration; no lifetime renews.
 * Changed route starts distinct work. No native command, handler or movement job is replayed.
 * Arguments: group GROUP grpNull; vehicle OBJECT objNull; current brain HASHMAP empty;
 * current plain-route/crew admission CODE {false}, evaluated synchronously in caller context.
 * Return: BOOL - current native boarding requests a zero cap, not successful re-entry.
 * Cost: one fullCrew observation (engine cost), at most20 seat rows/20 retained attempts;
 * no world query, geometry rays, worker or event handler. Oversized/unknown journals refuse.
 * Optional recall history is brain-local, max20 rows, expires60 seconds after dismount.
 * Route/driver replacement or disabling clears history; no JIP command replay.
 * Intentional dismount scripts must unassign operators to prevent recall.
 * Current caller: DrivingAssistStart at its existing vehicle sample cadence.
 * Example: private _wait=[_group,_vehicle,_brain,{call _mayIssueDriving
 *     && {call _recoveryOrderFree} && {call _nativeRouteIntent}}] call CBE_fnc_DrivingCrewBoarding;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_brain",createHashMap,[createHashMap]],["_mayWait",{false},[{}]]];
private _result=false;
isNil {
    _result=call {
if (remoteExecutedOwner > 0 || {isNull _group} || {!local _group}
    || {isNull _vehicle} || {!local _vehicle}
    || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _brain}
    || {(_brain getOrDefault ["ownerEpoch",-1]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
    || {_brain getOrDefault ["cancelled",false]} || {_brain getOrDefault ["finished",false]}) exitWith {false};
private _route=_brain getOrDefault ["route",[]];
if (_route isEqualTo [] || {([_group] call CBE_fnc_DrivingRouteReceipt) isNotEqualTo _route}) exitWith {false};
private _entry=_vehicle getVariable ["CBE_DrivingCrewBoarding",[]];
private _valid=_entry isEqualType [] && {_entry isEqualTo [] || {count _entry == 3
    && {(_entry select 0) isEqualType grpNull} && {(_entry select 1) isEqualType []}
    && {(_entry select 2) isEqualType []} && {count (_entry select 2) <= 20}
    && {(_entry select 2) findIf {
        !(_x isEqualType []) || {count _x != 7} || {!((_x select 0) isEqualType objNull)}
            || {!((_x select 1) isEqualType "")} || {!((_x select 2) isEqualType [])}
            || {!((_x select 3) isEqualType 0)} || {!finite (_x select 3)}
            || {!((_x select 4) isEqualType true)}
            || {!((_x select 5) isEqualType [])} || {count (_x select 5) != 3}
            || {(_x select 5) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {!((_x select 6) isEqualType 0)} || {!finite (_x select 6)}
    } < 0}}};
if (!_valid) exitWith {false};
private _rows=if (_entry isNotEqualTo [] && {(_entry select 0) == _group}
    && {(_entry select 1) isEqualTo _route}) then {(_entry select 2) apply {+_x}} else {[]};
private _seats=fullCrew [_vehicle,"",true];
if (count _seats > 20) exitWith {false};
// Boarding permissions are not observable from assignedVehicle alone: orderGetIn false
// preserves that assignment. Default cooperation requires an actual native GET IN.
// Optional recall is explicit operator policy, not inferred mission permission.
private _available=call _mayWait && {alive _vehicle} && {canMove _vehicle} && {!waterDamaged _vehicle} && {simulationEnabled _vehicle}
    && {!isObjectHidden _vehicle} && {vehicle leader _group == _vehicle}
    && {behaviour leader _group in ["SAFE","AWARE"]}
    && {[_group] call CBE_fnc_DrivingMovementAvailable}
    && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {[_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_VehicleRemount_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {["CBE_DrivingRecovery_Work","CBE_DrivingPass_Work","CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work"]
        findIf {!isNil {_vehicle getVariable _x}} < 0};
// Brain-local history cannot replay commands across route, driver or owner replacement.
// Each row is [observed operator, role, turret path, first outside time, retired].
private _recallEnabled=[_group,"CBE_AIPass_DrivingAssist_CrewRecall_Enable",false,_vehicle]
    call CBE_fnc_CortexFeatureEnabled;
private _recallReceipt=[_vehicle,+_route,driver _vehicle];
if (!_recallEnabled || {(_brain getOrDefault ["crewRecallReceipt",[]]) isNotEqualTo _recallReceipt}) then {
    _brain set ["crewRecallRows",[]];
    _brain set ["crewRecallReceipt",_recallReceipt];
};
if (_recallEnabled) then {
    private _recallRows=_brain getOrDefault ["crewRecallRows",[]];
    private _recallNext=[];
    {
        private _seat=_x;
        if (count _seat < 6) then {continue};
        private _role=toLowerANSI (_seat select 1);
        private _actor=_seat select 5;
        private _path=_seat select 3;
        if (_role == "cargo" || {_seat select 4} || {isNull _actor}
            || {!alive _actor} || {group _actor != _group}
            || {assignedVehicle _actor != _vehicle}) then {continue};
        private _index=_recallRows findIf {(_x select 0) == _actor
            && {(_x select 1) == _role} && {(_x select 2) isEqualTo _path}};
        private _recall=if (_index < 0) then {[]} else {+(_recallRows select _index)};
        if ((_seat select 0) == _actor) then {
            // Only a physical occupation rearms this seat episode.
            _recall=[_actor,_role,+_path,-1,false];
        } else {
            if (_recall isNotEqualTo [] && {!(_recall select 4)}) then {
                if ((_recall select 3) < 0) then {_recall set [3,serverTime]};
                private _idle=local _actor && {isNull objectParent _actor}
                    && {isNull (_seat select 0)} && {!isPlayer _actor}
                    && {toUpperANSI currentCommand _actor in ["","NONE"]}
                    && {!fleeing _actor} && {simulationEnabled _actor}
                    && {!isObjectHidden _actor} && {isNull remoteControlled _actor}
                    && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                    && {[_actor] call CBE_fnc_CortexCombatEffective}
                    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
                    && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
                    && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
                    && {_actor distance2D _vehicle <= 100};
                // New commands, care or tactical ownership retire rather than postpone recall.
                if (!_available || {!_idle} || {serverTime-(_recall select 3) >= 60}) then {_recall set [4,true]} else {
                    if (serverTime-(_recall select 3) >= 20) then {
                        _recall set [4,true];
                        // Publish retirement before the native request. No assignment mutation.
                        _brain set ["crewRecallRows",[]];
                        [_actor] orderGetIn true;
                    };
                };
            };
        };
        if (_recall isNotEqualTo []) then {_recallNext pushBack _recall};
    } forEach _seats;
    _brain set ["crewRecallRows",_recallNext];
};
private _wait=false;
private _next=[];
{
    private _seat=_x;
    if (count _seat < 6) then {continue};
    private _role=toLowerANSI (_seat select 1);
    private _actor=_seat select 5;
    if (_role == "cargo" || {_seat select 4} || {isNull _actor} || {!alive _actor}
        || {group _actor != _group} || {assignedVehicle _actor != _vehicle}
        || {!isNull objectParent _actor} || {!isNull (_seat select 0)}) then {continue};
    private _path=_seat select 3;
    private _index=_rows findIf {(_x select 0) == _actor && {(_x select 1) == _role}
        && {(_x select 2) isEqualTo _path}};
    private _row=if (_index < 0) then {[]} else {+(_rows select _index)};
    private _boarding=local _actor && {!fleeing _actor} && {toUpperANSI currentCommand _actor == "GET IN"}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
        && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
        && {_actor distance2D _vehicle <= 100};
    if (_row isEqualTo [] && {_available} && {_boarding}) then {
        _row=[_actor,_role,+_path,serverTime+60,false,getPosASL _actor,serverTime];
    };
    if (_row isNotEqualTo []) then {
        // A newer task or tactical owner ends cooperation; original expiry stays immutable.
        // Split actor locality suspends observation without creating another lifetime.
        if (!_available || {local _actor && {!_boarding}}) then {_row set [4,true]};
        if (!(_row select 4) && {_available} && {_boarding} && {serverTime < (_row select 3)}) then {
            private _position=getPosASL _actor;
            if (_position vectorDistance (_row select 5) >= 2) then {
                _row set [5,_position];_row set [6,serverTime];
            };
            private _stalled=serverTime-(_row select 6) >= 12;
            // Native search can be stationary while still preparing its GET IN route.
            // Preserve that plan only inside the existing original seat deadline.
            // Data preparation and delayed search are not failed routes. None counts as
            // measured movement or restarts the original seat deadline.
            private _planning=_stalled && {toUpperANSI getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]};
            if (_stalled && {!_planning}) then {_row set [4,true]} else {_wait=true};
        };
        _next pushBack _row;
    };
} forEach _seats;
private _updated=[_group,_route,_next];
if (_updated isNotEqualTo _entry) then {_vehicle setVariable ["CBE_DrivingCrewBoarding",_updated,true]};
_wait
    };
};
_result
