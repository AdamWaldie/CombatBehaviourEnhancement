/*
 * Author: WaldoTheWarfighter
 * Purpose: Starts one route-scoped ordinary driving FSM; registered convoys retain their own writer.
 * Seat-only casualty handover can start for local crew in a remote vehicle. Driving still requires
 * vehicle locality; native unit seat actions never acquire its speed/path authority.
 * Locality / Authority: Owner-local group only; no ownership transfer or second scheduler.
 * Repeat/JIP: Epoch, generation and current-brain identity reject stale work. New owners start
 * their own execution; local jobs and FSM handles are never replayed to JIP. The route is
 * captured after owner adoption. A short unscheduled replacement commit rechecks route,
 * epoch, feature/movement gates, current brain and recovery-yield identity before retirement
 * and publication. Duplicate live starts reuse the same worker; exhausted routes stay terminal.
 * Arguments: 0 group <GROUP, grpNull>.
 * Return Value: BOOL - whether a current driving brain exists.
 * Current callers: CBE_fnc_DrivingAssistStart.
 * Example: [group driver truck1] call CBE_fnc_DrivingOperationStart;
 */
params [["_group",grpNull,[grpNull]]];
if (isNull _group || {!local _group} || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group] call CBE_fnc_DrivingMovementAvailable)}
    || {[_group] call CBE_fnc_CortexZeusHeld} || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
// Read-only fast refusal before adoption; no yield/worker state is changed here.
private _entryRoute=[_group] call CBE_fnc_DrivingRouteReceipt;
if (_entryRoute isEqualTo []) exitWith {false};
if ((_group getVariable ["CBE_DrivingRecovery_Yield",[]]) isEqualTo _entryRoute) exitWith {false};
// Direct script admission uses the same locality establishment as ordinary group discovery.
if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {
    if ([_group] call CBE_fnc_CortexIsEligible) then {[_group,true] call CBE_fnc_CortexLocality};
};
if (!local _group || {!(_group getVariable ["CBE_AIPass_Adopted",false])}) exitWith {false};
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _route=[_group] call CBE_fnc_DrivingRouteReceipt;
if (_route isEqualTo []) exitWith {false};
private _current=_group getVariable ["CBE_Driving_Brain",createHashMap];
private _yieldSnapshot=+(_group getVariable ["CBE_DrivingRecovery_Yield",[]]);
private _accepted=false;
isNil {
    private _available={
        local _group && {_group getVariable ["CBE_AIPass_Adopted",false]}
            && {_epoch == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
            && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
            && {[_group,"CBE_AIPass_DrivingAssist_Enable",true] call CBE_fnc_CortexFeatureEnabled}
            && {[_group] call CBE_fnc_DrivingMovementAvailable}
            && {!([_group] call CBE_fnc_CortexZeusHeld)}
            && {!([_group] call CBE_fnc_CortexExternalTakeover)}
            && {(_group getVariable ["CBE_DrivingRecovery_Yield",[]]) isEqualTo _yieldSnapshot}
            && {_yieldSnapshot isNotEqualTo _route}
    };
    if (!(call _available)
        || {(_group getVariable ["CBE_Driving_Brain",createHashMap]) isNotEqualTo _current}) exitWith {};
    if (count _current > 0 && {(_current getOrDefault ["ownerEpoch",-1]) == _epoch}
        && {(_current getOrDefault ["route",[]]) isEqualTo _route}) exitWith {
        // Exhaustion belongs to the exact order; duplicate discovery cannot restart it.
        _accepted=!(_current getOrDefault ["cancelled",false]) && {!(_current getOrDefault ["finished",false])};
    };
    private _hasVehicle=(units _group) findIf {
        private _vehicle=vehicle _x;
        _vehicle != _x && {_vehicle isKindOf "LandVehicle"} && {!(_vehicle isKindOf "StaticWeapon")}
            && {alive _vehicle} && {canMove _vehicle}
            && {(local _vehicle && {!isNull driver _vehicle} && {group driver _vehicle == _group})
                || {vehicle leader _group == _vehicle && {[_x] call CBE_fnc_CortexCombatEffective}
                    && {(isNull driver _vehicle || {!alive driver _vehicle})}
                    && {[_group,"CBE_AIPass_DrivingAssist_Recovery_Enable",true] call CBE_fnc_CortexFeatureEnabled}}}
            && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
    } >= 0;
    if (!_hasVehicle) exitWith {};
    if (count _current > 0) then {[_current,"REPLACED"] call CBE_fnc_DrivingOperationFinish};
    // Cleanup may invoke other feature handlers. Recheck their resulting authority before
    // clearing a yield or overwriting a worker, even within this unscheduled commit.
    private _after=_group getVariable ["CBE_Driving_Brain",createHashMap];
    if (!(call _available) || {count _after > 0 && {_after isNotEqualTo _current}}) exitWith {};
    _group setVariable ["CBE_DrivingRecovery_Yield",nil,true];
    private _generation=(_group getVariable ["CBE_Driving_Generation",0])+1;
    _group setVariable ["CBE_Driving_Generation",_generation];
    private _brain=createHashMapFromArray [["group",_group],["ownerEpoch",_epoch],
        ["generation",_generation],["route",_route],["phase","CRUISE"],["pending",false],
        ["completed",false],["cancelled",false],["finished",false],["cancelReason",""],
        ["nextAt",time],["queuedAt",time],["watchdogCount",0]];
    _group setVariable ["CBE_Driving_Brain",_brain];
    private _handle=[_brain] execFSM "\z\cbe\addons\main\fsm\drivingOperation.fsm";
    _group setVariable ["CBE_Driving_FSM",_handle];
    _accepted=true;
};
_accepted
