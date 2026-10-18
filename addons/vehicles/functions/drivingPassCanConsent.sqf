/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads whether this owner may consent to one vehicle's proposed road-pass role.
 * Locality/authority: Current vehicle, driver, commander and group owner only. False for a
 * remote participant; observing its public receipt cannot substitute for its owner's consent.
 * Repeat/JIP: No commands, state, claims, handlers or cached permission. Recheck at negotiation
 * and every future command boundary. True is eligibility only, not an acknowledgement or priority.
 * Arguments: 0 vehicle <OBJECT>, objNull; 1 protocol <STRING, PASS>, PASS or internal QUEUE.
 * PASS refuses live/malformed queue consent; QUEUE reuses ordinary eligibility without rejecting
 * its own agreement. QueueProposalCurrent independently refuses passing consent.
 * Return: BOOL - local ordinary-route eligibility, never authority to execute a pass.
 * Current callers: DrivingPassPrepare and authenticated DrivingPassAgreementOwner verification.
 * Example: private _eligible=[truck1] call CBE_fnc_DrivingPassCanConsent;
 */
params [["_vehicle",objNull,[objNull]],["_protocol","PASS",[""]]];
if !(_protocol in ["PASS","QUEUE"]) exitWith {false};
if (_protocol == "PASS" && {!isNull _vehicle}) then {
    private _queue=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    private _busy=false;
    if !(_queue isEqualType createHashMap) then {_busy=true} else {
        if (count _queue > 0) then {
            private _phase=_queue getOrDefault ["phase",""];
            private _until=_queue getOrDefault [["deadline","expires"] select (_phase == "AGREED"),-1];
            private _token=_queue getOrDefault ["token",""];
            _busy=!(_phase in ["PENDING","AGREED"]) || {!(_until isEqualType 0)}
                || {!finite _until} || {_until < 0} || {!(_token isEqualType "")} || {_token == ""}
                || {serverTime < _until};
        };
    };
    if (_busy) then {_protocol="BUSY"};
};
if (_protocol == "BUSY") exitWith {false};
if (isNull _vehicle || {!local _vehicle} || {!alive _vehicle}
    || {!canMove _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!isNil {_vehicle getVariable "CBE_DrivingPass_Leg"}}
    || {_vehicle getVariable ["CBE_Convoy_Active",false]}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}) exitWith {false};
private _driver=driver _vehicle;private _operator=effectiveCommander _vehicle;
if (isNull _operator) then {_operator=_driver};
if (isNull _driver || {isNull _operator}) exitWith {false};
private _group=group _driver;
if (isNull _group || {!local _group} || {group _operator != _group}
    || {behaviour leader _group in ["COMBAT","STEALTH"]}
    || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {[_group] call CBE_fnc_CortexExternalTakeover}
    || {!([_group] call CBE_fnc_DrivingMovementAvailable)}
    || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true] call CBE_fnc_CortexFeatureEnabled)}) exitWith {false};
if ([_driver,_operator] findIf {!local _x || {isPlayer _x} || {!isNull remoteControlled _x}
    || {!simulationEnabled _x} || {isObjectHidden _x}
    || {!([_x] call CBE_fnc_CortexCombatEffective)}
    || {[_x] call CBE_fnc_CortexActorMoveReserved}
    || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
    || {!(currentCommand _x in ["","MOVE","WAIT"])}} >= 0) exitWith {false};
if (["CBE_DrivingRecovery_Work","CBE_DrivingBypass_Work","CBE_DrivingCorridor_Work"] findIf {
    count (_vehicle getVariable [_x,createHashMap]) > 0
} >= 0) exitWith {false};
// Consent cannot displace a newer direct driver/commander destination or native CBE.
private _route=[_group] call CBE_fnc_DrivingRouteReceipt;
if !([_group,_vehicle,_route] call CBE_fnc_DrivingGateIntent) exitWith {false};
private _index=currentWaypoint _group;
if (_index <= 0 || {_index >= count waypoints _group}) exitWith {false};
private _waypoint=[_group,_index];private _statements=waypointStatements _waypoint;
private _condition=toLowerANSI ((_statements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
waypointType _waypoint == "MOVE" && {_condition == "true"}
    && {((_statements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
    && {waypointScript _waypoint == ""} && {(waypointTimeout _waypoint param [2,0]) <= 0}
    && {isNull waypointAttachedVehicle _waypoint} && {isNull waypointAttachedObject _waypoint}
    && {(synchronizedWaypoints _waypoint) isEqualTo []} && {(synchronizedTriggers _waypoint) isEqualTo []}