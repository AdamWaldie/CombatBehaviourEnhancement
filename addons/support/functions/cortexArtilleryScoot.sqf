/*
 * Author: WaldoTheWarfighter
 * The fire request's original movement-group and authored-order receipt remain authoritative
 * through delayed admission; owner migration cannot rebase onto a newer mission route.
 * Both actual AI movement seats must remain local, available and free of treatment,
 * protected tasks, direct native STOP and non-route MOVE commands before planning and issue.
 * Geometry cannot grant authority over changed crew or authored route metadata.
 * Moves a mobile battery after the last shell flight and warning interval have elapsed. If another
 * Cortex movement owner is active, the relocation waits in five-second steps for at most two minutes
 * instead of replacing that route. Once acquired, the shared movement lease prevents contact,
 * investigation, vehicle standoff or infantry manoeuvre from replacing the scoot waypoint.
 * Locality/authority: the server publishes the mission token; the current vehicle owner executes.
 * Repeat/JIP: the public token and deadline reject stale work and locality gain resumes a pending
 * request. Six bounded candidate positions are scored once for usable vehicle slopes, dry ground,
 * screening and roads; Arma remains responsible for the actual route. The public purpose selects the
 * owning support/counter-battery feature and live scoot switch; closing either cancels the delayed
 * relocation. The physical move is not replayed after completion.
 * The pending session retains its original per-purpose generation and deadline through retries;
 * stale cleanup cannot clear a successor. Geometry precedes atomic session/lease/move admission.
 * Arguments: 0: battery <OBJECT>, default objNull; 1: mission token <STRING>, default "";
 * 2 session <ARRAY, [] reads public receipt> [token, purpose generation, counter generation,
 * original server deadline, purpose, [original movement group, authored route]]. Server dispatch and delayed retries carry the exact session.
 * Return Value: Boolean - true when relocation started or remains pending.
 * Current callers: ArtilleryMissionStep and CortexLocality.
 * Example: [_gun,_token] remoteExecCall ["CBE_fnc_CortexArtilleryScoot", owner _gun];
 */
params [["_battery", objNull, [objNull]],["_token","",[""]],["_session",[],[[]]]];
if (isNull _battery || {_token == ""} || {_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""] != _token}
    || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
if (!local _battery) exitWith {false};
if (_session isEqualTo []) then {_session=+(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]])};
if (count _session != 6 || {(_session select 0) != _token}
    || {!((_session select 4) in ["SUPPORT","COUNTER"])}
    || {[1,2,3] findIf {!((_session select _x) isEqualType 0) || {!finite (_session select _x)}} >= 0}) exitWith {false};
private _clear = {
    // Old retries may observe a successor while planning. Retire only this exact receipt.
    isNil {
        if ((_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token
            && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo _session}) then {
            _battery setVariable ["CBE_Cortex_ArtilleryScootToken",nil,true];
            _battery setVariable ["CBE_Cortex_ArtilleryScootDeadline",nil,true];
            _battery setVariable ["CBE_Cortex_ArtilleryScootPurpose",nil,true];
            _battery setVariable ["CBE_Cortex_ArtilleryScootSession",nil,true];
        };
    };
};
// Both server messages may arrive before remote HOLD cleanup. Retire this exact
// preceding positioning operation locally before inspecting the original authored route.
// Never rebase the request onto the HOLD or another mission's movement.
private _positionWork=_battery getVariable ["CBE_ArtilleryPosition_Work",createHashMap];
if ((_positionWork getOrDefault ["token",""]) == _token) then {
    [_battery,_token,_positionWork get "session",true] call CBE_fnc_CortexArtilleryPosition;
};
private _movementOrder=_session select 5;
if (!(_movementOrder isEqualType []) || {count _movementOrder != 2}
    || {!((_movementOrder select 0) isEqualType grpNull)} || {isNull (_movementOrder select 0)}
    || {!((_movementOrder select 1) isEqualType [])} || {(_movementOrder select 1) isEqualTo []}) exitWith {call _clear;false};
private _purpose=_session select 4;
private _counter=_purpose == "COUNTER";
private _feature=["CBE_AIPass_Artillery_Enable","CBE_AIPass_CounterBattery_Enable"] select _counter;
private _scootSetting=["CBE_AIPass_Artillery_ShootAndScoot","CBE_AIPass_CounterBattery_ShootAndScoot"] select _counter;
private _scootGenerationName=["CBE_ArtilleryScoot_SupportGeneration","CBE_ArtilleryScoot_CounterGeneration"] select _counter;
private _sessionCurrent={
    local _battery && {(_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token}
        && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo _session}
        && {serverTime < (_session select 3)}
        && {group driver _battery == (_movementOrder select 0)}
        && {([_movementOrder select 0] call CBE_fnc_NativeOrderReceipt) isEqualTo (_movementOrder select 1)}
        && {(_session select 1) == (missionNamespace getVariable [_scootGenerationName,0])}
        && {!_counter || {(_session select 2) == (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])}}
        && {missionNamespace getVariable [_scootSetting,true]}
        && {[group driver _battery,_feature,false] call CBE_fnc_CortexFeatureEnabled}
        && {missionNamespace getVariable ["CBE_AIPass_Active",false]} && {!([] call CBE_fnc_CortexIsPaused)}
};
if !(call _sessionCurrent) exitWith {call _clear;false};
if (!canMove _battery || {isNull driver _battery} || {!([group driver _battery] call CBE_fnc_CortexIsEligible)}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])} || {[] call CBE_fnc_CortexIsPaused}) exitWith {call _clear; false};
if !(_purpose in ["SUPPORT","COUNTER"]
    && {missionNamespace getVariable [_scootSetting,true]}
    && {[group driver _battery,_feature,false] call CBE_fnc_CortexFeatureEnabled}) exitWith {call _clear; false};
private _group = group driver _battery;
private _state = [_group] call CBE_fnc_CortexGroupState;
private _driver=driver _battery;
private _operator=effectiveCommander _battery;
if (isNull _operator) then {_operator=_driver};
private _crewReady={
    local _group && {local _battery} && {simulationEnabled _battery} && {!isObjectHidden _battery}
        && {driver _battery == _driver} && {(effectiveCommander _battery) in [_operator,objNull]}
        && {[_driver,_operator] findIf {
            isNull _x || {!local _x} || {group _x != _group} || {vehicle _x != _battery}
            || {!([_x] call CBE_fnc_CortexCombatEffective)} || {isPlayer _x}
            || {!simulationEnabled _x} || {isObjectHidden _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
            || {[_x] call CBE_fnc_CompatibilityExternalControl}
            || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {!(currentCommand _x in ["","MOVE","WAIT"])}
        } < 0}
        && {[_group] call CBE_fnc_NativeOrderReceipt isEqualTo _nativeOrder}
        && {[_driver,_operator] findIf {
            currentCommand _x == "MOVE" && {
                private _index=currentWaypoint _group;
                private _destination=(expectedDestination _x) param [0,[]];
                _index <= 0 || {_index >= count waypoints _group} || {count _destination != 3}
                    || {_destination vectorDistance (waypointPosition [_group,_index]) > 3}
            }
        } < 0}
};
private _nativeOrder=+(_movementOrder select 1);
if !(call _crewReady) exitWith {call _clear;false};
private _activeWaypoint = (waypoints _group) findIf {
    (_x select 1) >= currentWaypoint _group && {waypointDescription _x == "CBE AI PASS"}
} >= 0;
private _busy = _activeWaypoint || {count (_state getOrDefault ["drill",createHashMap]) > 0}
    || {_state getOrDefault ["responding",false]} || {_state getOrDefault ["assaulting",false]}
    || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}
    || {_group getVariable ["CBE_AIPass_ClearBuilding",false]};
if (_busy) exitWith {
    if (serverTime < (_session select 3)) then {
        [{_this call CBE_fnc_CortexArtilleryScoot},[_battery,_token,+_session],5] call CBA_fnc_waitAndExecute;
        true
    } else {call _clear; false}
};
private _origin=getPosATL _battery;
private _candidates=[];
for "_attempt" from 0 to 5 do {
    _candidates pushBack [_origin getPos [200+random 150,random 360]];
};
private _selected=[_origin,_candidates,_origin,[],objNull,"VEHICLE"] call CBE_fnc_CortexSelectAvenue;
private _spot=if (_selected isEqualTo []) then {[]} else {_selected select ((count _selected)-1)};
if (_spot isEqualTo []) exitWith {call _clear; false};
private _started=false;
isNil {
    _started=call {
        if (!(call _sessionCurrent) || {!(call _crewReady)} || {group driver _battery != _group}
            || {!([_group] call CBE_fnc_CortexIsEligible)}) exitWith {call _clear;false};
if !([_group,"ARTILLERY_SCOOT",true,serverTime+120] call CBE_fnc_CortexOwnershipLease) exitWith {
    if (serverTime < (_session select 3)) then {
        [{_this call CBE_fnc_CortexArtilleryScoot},[_battery,_token,+_session],5] call CBA_fnc_waitAndExecute;
        true
    } else {call _clear; false}
};
private _operation=[_group,"ARTILLERY_SCOOT",_spot,[],[_spot],"MOVING"] call CBE_fnc_OperationStart;
if (count _operation == 0) exitWith {
    [_group,"ARTILLERY_SCOOT",false] call CBE_fnc_CortexOwnershipLease;
    call _clear;
    false
};
private _generation=_operation get "generation";
// Active relocation keeps the session after its pending token is retired. The ordinary
// group callback can cancel only this generation when a live feature/session closes.
_operation set ["artilleryScootSession",[_battery,+_session]];
_group setVariable ["CBE_Operation",_operation,true];
private _waypoint=[_group,_spot,30,"MOVE",_generation] call CBE_fnc_CortexGroupMove;
if (isNull (_waypoint param [0,grpNull,[grpNull]]) || {(_waypoint param [1,-1,[0]]) < 0}) exitWith {
    [_group,_generation,"INCOMPLETE","MOVEMENT_REJECTED"] call CBE_fnc_OperationRelease;
    [_group,"ARTILLERY_SCOOT",false] call CBE_fnc_CortexOwnershipLease;
    call _clear;
    false
};
_state set ["movementLease",["ARTILLERY_SCOOT",time+120]];
_state set ["artilleryScootOperationGeneration",_operation get "generation"];
call _clear;
true
    };
    false
};
_started
