/*
 * Author: WaldoTheWarfighter
 * Current gunner availability, protected tasks/treatment, simulation and player/specialist
 * control are checked before safety work and again at the atomic native shot boundary.
 * Executes exactly one checked shot on the current battery owner. The server observes the actual firing event.
 * Locality/authority: documented guards enforce server coordination and owner-local execution.
 * Smoke enablement is checked both before safety work and at the final command boundary.
 * Repeat/JIP: mission tokens reject stale work; server state survives HC migration, not restart.
 * Arguments: 0: battery <OBJECT>; 1: aim ATL <ARRAY>; 2: magazine <STRING>; 3: purpose <STRING>; 4: mode <STRING>; 5: token <STRING>;
 * 6 counter generation <NUMBER, -1>, required for COUNTER requests from the server;
 * 7 shot serial <NUMBER, -1>, required positive integer for every request.
 * 8 fire generation <NUMBER, -1>, required original purpose generation;
 * 9 smoke generation <NUMBER, -1>, required original generation for SMOKE.
 * Exact duplicate and older serials are consumed without fire or rejection callbacks; a
 * conflicting same-serial payload refuses without cancelling the genuine pending command.
 * Final native issue rechecks current generation, live feature/ROE and crew/token atomically.
 * No command can undo a projectile or native shot already issued before cancellation.
 * Return Value: Boolean, command issued or exact duplicate/older request consumed; never firing proof.
 * Current callers: ArtilleryMissionStep.
 * Example: [_gun, _aim, _mag, "SUPPORT", "HE", _token,-1,1,_supportGeneration,-1] remoteExecCall ["CBE_fnc_CortexArtilleryShot", owner _gun];
 */
params ["_battery", "_aim", "_magazine", "_purpose", "_mode", "_token",["_counterGeneration",-1,[0]],["_shotSerial",-1,[0]],["_fireGeneration",-1,[0]],["_smokeGeneration",-1,[0]]];
if (remoteExecutedOwner != 2) exitWith {false};
if (!finite _shotSerial || {_shotSerial < 1} || {_shotSerial != floor _shotSerial}) exitWith {false};
// Malformed geometry cannot consume a shot receipt or reject a genuine pending shot.
if (!(_aim isEqualType []) || {!(count _aim in [2,3])}
    || {_aim findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {false};
private _signature=[+_aim,_magazine,_purpose,_mode,_counterGeneration,_fireGeneration,_smokeGeneration];
private _requestState={
    private _receipt=_battery getVariable ["CBE_AIPass_ShotReceipt",[]];
    if (_receipt isEqualTo []) exitWith {"NEW"};
    if (!(_receipt isEqualType []) || {count _receipt != 4}
        || {!((_receipt select 0) isEqualType "")}
        || {!((_receipt select 1) isEqualType 0)} || {!finite (_receipt select 1)}) exitWith {"INVALID"};
    if ((_receipt select 0) != _token) exitWith {"NEW"};
    if (_shotSerial < (_receipt select 1)) exitWith {"STALE"};
    if (_shotSerial == (_receipt select 1)) exitWith {
        ["CONFLICT","DUPLICATE"] select ((_receipt select 2) isEqualTo _signature)
    };
    "NEW"
};
// A duplicate/old/conflicting request must not reject the genuine pending native shot.
// This returns handling status only; the server still needs its independent Fired event.
private _request=call _requestState;
if (_request != "NEW") exitWith {_request in ["DUPLICATE","STALE"]};
private _reject = {
    [_battery, _token, clientOwner] remoteExecCall ["CBE_fnc_CortexArtilleryRejected", 2];
    false
};
private _fireGenerationName=switch (_purpose) do {
    case "SUPPORT": {"CBE_Artillery_SupportFireGeneration"};
    case "DANGER": {"CBE_Artillery_DangerFireGeneration"};
    default {"CBE_AIPass_CounterGeneration"};
};
private _fireSessionCurrent={
    finite _fireGeneration && {_fireGeneration >= 0}
        && {_fireGeneration == (missionNamespace getVariable [_fireGenerationName,0])}
        && {_mode != "SMOKE" || {finite _smokeGeneration && {_smokeGeneration >= 0}
            && {_smokeGeneration == (missionNamespace getVariable ["CBE_Artillery_SmokeFireGeneration",0])}}}
        && {_purpose != "COUNTER" || {finite _counterGeneration && {_counterGeneration >= 0}
            && {_counterGeneration == (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])}
            && {missionNamespace getVariable ["CBE_AIPass_CounterBattery_Enable",false]}}}
};
private _danger=_purpose == "DANGER";
private _operator=gunner _battery;
private _crewGroup=if (isNull gunner _battery) then {grpNull} else {group gunner _battery};
// A queued shot cannot outlive its positioned battery's current local HOLD.
// Ordinary in-range requests have no positioning work and retain their existing gates.
private _positionCurrent={
    private _work=_battery getVariable ["CBE_ArtilleryPosition_Work",createHashMap];
    private _session=_battery getVariable ["CBE_ArtilleryPosition_Session",[]];
    if (count _work == 0 && {_session isEqualTo []}) exitWith {true};
    if ((_work getOrDefault ["token",""]) != _token || {count _session != 10}
        || {(_work getOrDefault ["session",[]]) isNotEqualTo _session}
        || {(_work getOrDefault ["status",""]) != "READY"}) exitWith {false};
    private _group=_session select 3;
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
    private _generation=_work get "generation";
    local _group && {group gunner _battery == _group}
        && {serverTime < (_session select 9)}
        && {(_work get "epoch") == (_group getVariable ["CBE_AIPass_Epoch",-1])}
        && {(_operation getOrDefault ["generation",-2]) == _generation}
        && {(_operation getOrDefault ["intent",""]) == "ARTILLERY_POSITION"}
        && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_operation getOrDefault ["artilleryPositionOrder",[]])}
        && {(_intent getOrDefault ["operationGeneration",-2]) == _generation}
        && {(_intent getOrDefault ["waypoint",[]]) isEqualTo [_group,currentWaypoint _group]}
        && {waypointType [_group,currentWaypoint _group] == "HOLD"}
        && {vectorMagnitude velocity _battery < 0.278}
        && {vectorMagnitude angularVelocity _battery < 0.01}
};
private _operatorAvailable={
    local _battery && {alive _battery} && {simulationEnabled _battery} && {!isObjectHidden _battery}
        && {!isNull _operator} && {local _operator} && {gunner _battery == _operator}
        && {vehicle _operator == _battery} && {!isPlayer _operator}
        && {simulationEnabled _operator} && {!isObjectHidden _operator}
        && {isNull remoteControlled _operator}
        && {isNull (_operator getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {[_operator] call CBE_fnc_CortexExternalOwner == ""}
        && {!([_operator] call CBE_fnc_CompatibilityExternalControl)}
        && {[_operator] call CBE_fnc_CortexActorFireTaskAvailable}
        && {_operator checkAIFeature "FIREWEAPON"}
        && {!([_crewGroup] call CBE_fnc_CortexExternalTakeover)}
};
if (!(call _fireSessionCurrent) || {!(call _positionCurrent)} || {!(call _operatorAvailable)} || {!local _battery} || {!alive _battery} || {!([_operator] call CBE_fnc_CortexCombatEffective)}
    || {combatMode group gunner _battery == "BLUE"} || {unitCombatMode gunner _battery == "BLUE"}
    || {(_battery getVariable ["CBE_AIPass_FireToken", ""]) != _token}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active", false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!([group gunner _battery] call CBE_fnc_CortexIsEligible)}
    || {_mode == "SMOKE" && {!([_crewGroup,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)}}
    || {!_danger && {!([_battery, _purpose] call CBE_fnc_CortexArtilleryRole)}}
    || {if (_danger) then {
        !([_crewGroup,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)
        || {!([_crewGroup,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_crewGroup,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {[_crewGroup] call CBE_fnc_CortexExternalTakeover}
    } else {
        !([_crewGroup, ["CBE_AIPass_Artillery_Enable", "CBE_AIPass_CounterBattery_Enable"] select (_purpose == "COUNTER"), false] call CBE_fnc_CortexFeatureEnabled)
    }}) exitWith {call _reject};
private _minimum = if (_mode == "SMOKE") then {50} else {missionNamespace getVariable [["CBE_AIPass_Artillery_MinFriendlyDistance", "CBE_AIPass_CounterBattery_MinFriendlyDistance"] select (_purpose == "COUNTER"), 200]};
private _side = side group gunner _battery;
if ((_aim nearEntities [["CAManBase", "LandVehicle", "Air", "Ship"], _minimum]) findIf {
    private _entity = _x;
    alive _entity && {([_entity] + crew _entity) findIf {alive _x && {side _x == civilian || {_side getFriend (side _x) >= 0.6}}} >= 0}
} >= 0) exitWith {call _reject};
if (!(_magazine in getArtilleryAmmo [_battery]) || {(magazinesAllTurrets [_battery,true]) findIf {(_x select 0) == _magazine && {(_x select 2) > 0}} < 0} || {!(_aim inRangeOfArtillery [[_battery], _magazine])}
    || {_battery getArtilleryETA [_aim, _magazine] < 0}) exitWith {call _reject};
// Safety/munition checks are not a lease over the operating crew or mission token.
private _issued=false;
isNil {
    _issued=call {
private _currentRequest=call _requestState;
if (_currentRequest != "NEW") exitWith {_currentRequest in ["DUPLICATE","STALE"]};
if (!(call _fireSessionCurrent) || {!(call _positionCurrent)} || {!(call _operatorAvailable)} || {!local _battery} || {gunner _battery != _operator}
    || {!alive _battery} || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {[] call CBE_fnc_CortexIsPaused}
    || {combatMode group _operator == "BLUE"} || {unitCombatMode _operator == "BLUE"}
    || {!_danger && {!([_battery,_purpose] call CBE_fnc_CortexArtilleryRole)}}
    || {!_danger && {!([group _operator,["CBE_AIPass_Artillery_Enable","CBE_AIPass_CounterBattery_Enable"] select (_purpose == "COUNTER"),false] call CBE_fnc_CortexFeatureEnabled)}}
    || {_danger && {!([group _operator,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)
        || {!([group _operator,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([group _operator,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {[_crewGroup] call CBE_fnc_CortexExternalTakeover}}}
    || {!([_operator] call CBE_fnc_CortexCombatEffective)}
    || {(_battery getVariable ["CBE_AIPass_FireToken",""]) != _token}
    || {!([group _operator] call CBE_fnc_CortexIsEligible)}
    || {_mode == "SMOKE" && {!([group _operator,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled)}}) exitWith {call _reject};
// Retain one public last-issued receipt across locality changes; never mark it as fired.
_battery setVariable ["CBE_AIPass_ShotReceipt",[_token,_shotSerial,_signature,serverTime],true];
_battery doArtilleryFire [_aim, _magazine, 1];
true
    };
    false
};
_issued
