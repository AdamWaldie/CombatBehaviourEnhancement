/*
 * Author: WaldoTheWarfighter
 * Purpose: Execute one current-owner pre-fire positioning step under the existing server mission FSM.
 * Locality/authority: Server-addressed battery/group/AI-seat owner only. Geometry is a proposal;
 * only physical arrival and fresh native range permit READY. No firing occurs here.
 * Repeat/JIP: Exact original session/deadline and public attempt prevent duplicate movement.
 * Owner migration refuses replay; existing locality cleanup retires the old group operation.
 * No new scheduler, teleport, repair, inventory change or fixed path is installed.
 * Arguments: 0 battery OBJECT,objNull; 1 token STRING,""; 2 session ARRAY,[];
 * [magazine,targetATL,serverDeadline,group,nativeOrder,fireGeneration,purpose,mode,smokeGeneration,holdUntil].
 * 3 cancel BOOL,false, retires only this exact session's movement.
 * Return: BOOL, handled proposal/observation; never firing or arrival proof by itself.
 * Current callers: CortexArtilleryMissionStep, authenticated server only.
 * Example: [_battery,_token,_session] remoteExecCall ["CBE_fnc_CortexArtilleryPosition",owner _battery];
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_session",[],[[]]],["_cancel",false,[true]]];
if ((remoteExecutedOwner != 2 && {!(_cancel && {remoteExecutedOwner == 0})}) || {isNull _battery} || {!local _battery} || {count _session != 10}) exitWith {false};
_session params ["_magazine","_target","_until","_group","_route","_fireGeneration","_purpose","_mode","_smokeGeneration","_holdUntil"];
private _work=_battery getVariable ["CBE_ArtilleryPosition_Work",createHashMap];
private _ours=count _work > 0 && {(_work getOrDefault ["token",""]) == _token}
    && {(_work getOrDefault ["session",[]]) isEqualTo _session};
private _finish={
    params ["_status"];
    if (_ours && {local _group} && {_status != "READY"}) then {
        private _generation=_work getOrDefault ["generation",-1];
        private _operation=_group getVariable ["CBE_Operation",createHashMap];
        if ((_operation getOrDefault ["generation",-2]) == _generation
            && {(_operation getOrDefault ["ownerEpoch",-1]) == (_work get "epoch")}
            && {(_operation getOrDefault ["intent",""]) == "ARTILLERY_POSITION"}) then {
            [_group,_generation,"INCOMPLETE",_status] call CBE_fnc_OperationRelease;
        };
        private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
        if ((_state getOrDefault ["artilleryPositionOperationGeneration",-2]) == _generation) then {
            private _lease=_state getOrDefault ["movementLease",[]];
            if ((_lease param [0,""]) == "ARTILLERY_POSITION"
                && {(_group getVariable ["CBE_OperationGeneration",-2]) == _generation}
                && {(_group getVariable ["CBE_AIPass_Epoch",-1]) == (_work get "epoch")}) then {
                [_group,"ARTILLERY_POSITION",false] call CBE_fnc_CortexOwnershipLease;
                _state deleteAt "movementLease";
            };
            _state deleteAt "artilleryPositionOperationGeneration";
        };
    };
    if (_ours) then {_work set ["status",_status]};
    [_battery,_token,_status,clientOwner,if (_ours) then {_work getOrDefault ["spot",[]]} else {[]},
        if (_ours) then {_work getOrDefault ["generation",-1]} else {-1}]
        remoteExecCall ["CBE_fnc_CortexArtilleryPositionReport",2];
    false
};
if (_cancel) exitWith {
    if (_ours) then {
        ["CANCELLED"] call _finish;
        if ((_battery getVariable ["CBE_ArtilleryPosition_Work",createHashMap]) isEqualTo _work) then {
            _battery setVariable ["CBE_ArtilleryPosition_Work",nil];
        };
    };true
};
if ((_battery getVariable ["CBE_ArtilleryPosition_Session",[]]) isNotEqualTo _session
    || {(_battery getVariable ["CBE_AIPass_FireToken",""]) != _token}) exitWith {false};
private _driver=driver _battery;private _operator=effectiveCommander _battery;
if (isNull _operator) then {_operator=_driver};
private _current={
    local _battery && {alive _battery} && {canMove _battery}
        && {_battery isKindOf "LandVehicle"} && {!(_battery isKindOf "StaticWeapon")}
        && {local _group} && {[_group,false,false,true] call CBE_fnc_CortexIsEligible}
        && {!(_battery getVariable ["CBE_Convoy_Active",false])}
        && {isNil {_battery getVariable "CBE_ExternalDrivingOwner"}}
        && {vehicle leader _group == _battery}
        && {count units _group <= 64}
        && {(units _group) findIf {alive _x && {vehicle _x != _battery}} < 0}
        && {group _driver == _group} && {driver _battery == _driver}
        && {(effectiveCommander _battery) in [_operator,objNull]}
        && {simulationEnabled _battery} && {!isObjectHidden _battery}
        && {serverTime < _holdUntil} && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
        && {!([] call CBE_fnc_CortexIsPaused)}
        && {(_battery getVariable ["CBE_ArtilleryPosition_Session",[]]) isEqualTo _session}
        && {(_battery getVariable ["CBE_AIPass_FireToken",""]) == _token}
        && {_fireGeneration == (missionNamespace getVariable [["CBE_Artillery_SupportFireGeneration","CBE_AIPass_CounterGeneration"] select (_purpose == "COUNTER"),0])}
        && {_mode != "SMOKE" || {_smokeGeneration == (missionNamespace getVariable ["CBE_Artillery_SmokeFireGeneration",0])
            && {[_group,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled}}}
        && {[_group,["CBE_AIPass_Artillery_Enable","CBE_AIPass_CounterBattery_Enable"] select (_purpose == "COUNTER"),false] call CBE_fnc_CortexFeatureEnabled}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {[_driver,_operator] findIf {isNull _x || {!local _x} || {group _x != _group}
            || {vehicle _x != _battery} || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
            || {[_x] call CBE_fnc_CortexExternalOwner != ""}
            || {[_x] call CBE_fnc_CompatibilityExternalControl}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {!(currentCommand _x in ["","MOVE","WAIT"])}} < 0}
};

if (!(call _current)) exitWith {["AUTHORITY_OR_DEADLINE"] call _finish};
if (_ours) exitWith {
    private _status=_work getOrDefault ["status","MOVING"];

    private _generation=_work get "generation";
    private _operation=_group getVariable ["CBE_Operation",createHashMap];
    if ((_work get "epoch") != (_group getVariable ["CBE_AIPass_Epoch",0])) exitWith {["OWNER_CHANGED"] call _finish};
    private _intent=_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap];
    private _legOwned=(_operation getOrDefault ["generation",-2]) == _generation
        && {(_operation getOrDefault ["intent",""]) == "ARTILLERY_POSITION"}
        && {(_intent getOrDefault ["operationGeneration",-2]) == _generation}
        && {(_intent getOrDefault ["requestedPosition",[]]) isEqualTo (_work get "spot")}
        && {(_intent getOrDefault ["waypoint",[]]) isEqualTo [_group,currentWaypoint _group]}
        && {waypointType [_group,currentWaypoint _group] == "HOLD"};
    if (serverTime >= _until && {_status != "READY"}) exitWith {["ARRIVAL_TIMEOUT"] call _finish};
    private _arrived=_battery distance2D (_work get "spot") <= 25
        && {abs (((getPosATL _battery) select 2)-((_work get "spot") select 2)) <= 3};

    if (!_legOwned) exitWith {["MOVEMENT_REPLACED"] call _finish};
    if (_arrived && {vectorMagnitude velocity _battery < 0.278} && {vectorMagnitude angularVelocity _battery < 0.01}) exitWith {
        [["ARRIVED_OUT_OF_RANGE","READY"] select (_target inRangeOfArtillery [[_battery],_magazine]) ] call _finish
    };
    true
};
// A public attempt survives locality; absence of this machine's exact journal never permits replay.
if ((_battery getVariable ["CBE_ArtilleryPosition_Attempt",[]]) isEqualTo _session) exitWith {["OWNER_CHANGED"] call _finish};
if (([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _route
    || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {!isNil {_battery getVariable "CBE_ExternalDrivingOwner"}}) exitWith {["ORDER_BUSY"] call _finish};
if ([_driver,_operator] findIf {
    currentCommand _x == "MOVE" && {
        private _index=currentWaypoint _group;
        private _destination=(expectedDestination _x) param [0,[]];
        _index <= 0 || {_index >= count waypoints _group} || {count _destination != 3}
            || {_destination vectorDistance (waypointPosition [_group,_index]) > 3}
    }
} >= 0) exitWith {["DIRECT_ORDER"] call _finish};
_battery setVariable ["CBE_ArtilleryPosition_Attempt",+_session,true];
private _origin=getPosATL _battery;private _bearing=_origin getDir _target;
private _ranked=[];
// Twelve native probes inform separation only. They never prove future firing reachability.
private _distanceToFix=_origin distance2D _target;
{
    private _probe=_origin getPos [_x,_bearing];
    if (_battery getArtilleryETA [_probe,_magazine] >= 0) then {
        private _candidate=_target getPos [_x,_target getDir _origin];
        private _travel=_origin distance2D _candidate;
        if (_travel >= 60 && {_travel <= 4000}) then {_ranked pushBack [_travel,_candidate]};
    };
} forEach ([_distanceToFix*0.9,_distanceToFix*0.75,_distanceToFix*0.5,_distanceToFix*0.25,
    _distanceToFix*1.25,_distanceToFix*1.5,_distanceToFix*2,_distanceToFix*4,500,2000,8000,32000] apply {(_x max 100) min 64000});
_ranked sort true;
private _candidates=(_ranked select [0,6]) apply {[+(_x select 1)]};
private _selected=[_origin,_candidates,_origin,[],objNull,"VEHICLE"] call CBE_fnc_CortexSelectAvenue;
if (_selected isEqualTo []) exitWith {["NO_SUPPORTED_POSITION"] call _finish};
private _spot=_selected select (count _selected-1);
private _started=false;
isNil {
    if (call _current && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _route}
        && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
        && {[_group,"ARTILLERY_POSITION",true,_holdUntil] call CBE_fnc_CortexOwnershipLease}) then {
        private _operation=[_group,"ARTILLERY_POSITION",_spot,[],[_spot],"MOVING"] call CBE_fnc_OperationStart;
        if (count _operation > 0) then {
            private _generation=_operation get "generation";
            _work=createHashMapFromArray [["token",_token],["session",+_session],["generation",_generation],
                ["epoch",_group getVariable ["CBE_AIPass_Epoch",0]],["spot",+_spot],["status","MOVING"]];
            _battery setVariable ["CBE_ArtilleryPosition_Work",_work];_ours=true;
            private _waypoint=[_group,_spot,5,"HOLD",_generation] call CBE_fnc_CortexGroupMove;
            if (!isNull (_waypoint param [0,grpNull]) && {(_waypoint param [1,-1]) >= 0}) then {
                private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
                _state set ["movementLease",["ARTILLERY_POSITION",time+((_holdUntil-serverTime) max 0)]];
                _state set ["artilleryPositionOperationGeneration",_generation];
                _battery setVariable ["CBE_ArtilleryPosition_Issued",[_token,+_session,_group,
                    _generation,_work get "epoch",+_spot,clientOwner],true];
                _started=true;
            } else {["MOVEMENT_REFUSED"] call _finish};
        } else {[_group,"ARTILLERY_POSITION",false] call CBE_fnc_CortexOwnershipLease};
    };
};
if (!_started) then {["MOVEMENT_REFUSED"] call _finish};
_started
