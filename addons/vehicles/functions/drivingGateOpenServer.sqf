/*
 * Author: WaldoTheWarfighter
 * Purpose: Serialise one finite, current-owner request to open a recognised unlocked gate.
 * Locality/authority: Server only. Authenticating the vehicle/group owner is followed by live
 * route, driver, feature, gate-transform, lock and forward-geometry validation before mutation.
 * Ordinary native route intent is rechecked at admission and mutation; owned alternate STOP
 * requires its unchanged finite journal. Convoy gate requests retain their registry contract.
 * animateSource has global effect; native animation state supplies JIP, without replay commands.
 * Repeat/JIP: One initial opening attempt and at most one unlock retry per gate/transform
 * in the current vehicle route/revision, with sixteen distinct gate contexts per route. A gate-wide twelve-second opening receipt coalesces
 * simultaneous requests. Observed completed closure permits one fresh passage cycle in that
 * same bounded gate slot. Optional finite passage/closure uses the shared server scheduler;
 * no gate ownership transfer or timeout-based clearance.
 * A LOCKED refusal may be reconsidered once after BIS locks clear, bound to its original
 * timestamp; the server validates the transition and retains the consumed retry through migration.
 * A context-bound acknowledgement prevents repeated owner requests; delivery retries return
 * the original outcome before geometry/config work. Driver/commander identity binds queued work.
 * Final mutation is atomic and rechecks expiry, crew ownership, convoy revision and live phases.
 * Initial phases are retained; already-open gates are untouched. A refused/expired request
 * grants no passage and never disables the geometry cap. Live lock changes remain authoritative.
 * Arguments: 0 payload <ARRAY, []> of named pairs: group GROUP, vehicle OBJECT, gate OBJECT,
 * route ARRAY, transform ARRAY, driver OBJECT, commander OBJECT, convoyRevision NUMBER (-1 for ordinary), expires NUMBER serverTime, unlockReceipt NUMBER (-1 or original LOCKED result timestamp).
 * Return Value: BOOL - an opening was commanded or an existing opening was shared; not passability.
 * Exact indexed Door/Gate_N_sound_source or Door/Gate_N_source metadata, N=1..8.
 * At most64 definitions and8 initial native phase reads; one preferred source per leaf, sound before plain.
 * Current callers: DrivingGateRequest on the server or current headless vehicle/group owner.
 * Example: [_payload] remoteExecCall ["CBE_fnc_DrivingGateOpenServer",2];
 */
params [["_payload",[],[[]]]];
if (!isServer || {count _payload != 10} || {_payload findIf {!(_x isEqualType []) || {count _x != 2} || {!((_x select 0) isEqualType "")}} >= 0}) exitWith {false};
private _values=createHashMapFromArray _payload;
private _group=_values getOrDefault ["group",grpNull];
private _vehicle=_values getOrDefault ["vehicle",objNull];
private _gate=_values getOrDefault ["gate",objNull];
private _requestedDriver=_values getOrDefault ["driver",objNull];
private _requestedCommander=_values getOrDefault ["commander",objNull];
private _route=_values getOrDefault ["route",[]];
private _transform=_values getOrDefault ["transform",[]];
private _revision=_values getOrDefault ["convoyRevision",-1];
private _expires=_values getOrDefault ["expires",-1];
private _unlockReceipt=_values getOrDefault ["unlockReceipt",-1];
if (!(_group isEqualType grpNull) || {!(_vehicle isEqualType objNull)} || {!(_gate isEqualType objNull)}
    || {!(_requestedDriver isEqualType objNull)} || {!(_requestedCommander isEqualType objNull)}
    || {!(_route isEqualType [])} || {!(_transform isEqualType [])} || {!(_revision isEqualType 0)}
    || {!finite _revision} || {_revision != floor _revision} || {_revision < -1}
    || {!(_expires isEqualType 0)} || {!finite _expires} || {_expires <= serverTime} || {_expires > serverTime+5}
    || {!(_unlockReceipt isEqualType 0)} || {!finite _unlockReceipt}
    || {isNull _group} || {isNull _vehicle} || {isNull _gate} || {!alive _gate}) exitWith {false};
private _sender=remoteExecutedOwner;
if (_sender > 0 && {_sender != 2}
    && {_sender != groupOwner _group || {_sender != owner _vehicle} || {_sender != owner driver _vehicle}}) exitWith {false};
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
if (isNull _commander) then {_commander=_driver};
if (isNull _driver || {_driver != _requestedDriver} || {_commander != _requestedCommander}
    || {!(_vehicle isKindOf "LandVehicle")} || {_vehicle isKindOf "StaticWeapon"}
    || {!alive _vehicle} || {!canMove _vehicle} || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled _driver} || {isObjectHidden _driver}
    || {!simulationEnabled _commander} || {isObjectHidden _commander} || {group _driver != _group} || {group _commander != _group}
    || {isPlayer _driver} || {isPlayer _commander} || {!isNull remoteControlled _driver}
    || {!isNull remoteControlled _commander} || {!([_driver] call CBE_fnc_CortexCombatEffective)}
    || {!([_commander] call CBE_fnc_CortexCombatEffective)}
    || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    || {!([_group,false,false,_revision >= 0] call CBE_fnc_CortexIsEligible)}
    || {[] call CBE_fnc_CortexIsPaused}
    || {_route isEqualTo []} || {([_group] call CBE_fnc_DrivingRouteReceipt) isNotEqualTo _route}
    || {_transform isNotEqualTo [getPosWorld _gate,vectorDir _gate,vectorUp _gate]}
    || {abs speed _vehicle > 8}) exitWith {false};
if ([_driver,_commander] findIf {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]
    || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}} >= 0) exitWith {false};
if (_revision >= 0) then {
    private _registry=missionNamespace getVariable ["CBE_Convoy_Registry",[]];
    private _index=_registry findIf {(_x select 0) == _group};
    if (_index < 0) exitWith {_revision=-2};
    private _config=(_registry select _index) select 1;
    if ((_config select 0) != _revision || {(_config select 5) != "TRAVEL"}
        || {!(_vehicle in (_config select 4))}
        || {!([_group,"CBE_Convoy_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}) then {_revision=-2};
} else {
    if (!(missionNamespace getVariable ["CBE_AIPass_Active",false])
        || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {!([_group,true] call CBE_fnc_DrivingMovementAvailable)}
        || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}) then {_revision=-2};
};
if (_revision == -2 || {_revision < 0 && {!([_group,_vehicle,_route] call CBE_fnc_DrivingGateIntent)}}) exitWith {false};
// Check the server-local attempt history before geometry/config work. A delivery retry
// receives the original outcome; it never becomes another animation or geometry scan.
private _stopSerial=missionNamespace getVariable ["CBE_DrivingGate_StopSerial",0];
private _receipt=_vehicle getVariable ["CBE_DrivingGate_ServerAttempts",[]];
private _attempts=if ((_vehicle getVariable ["CBE_DrivingGate_AttemptStopSerial",0]) == _stopSerial && {count _receipt == 4} && {(_receipt select 0) == _group} && {(_receipt select 1) isEqualTo _route} && {(_receipt select 2) == _revision}) then {+(_receipt select 3)} else {[]};
private _key=[_gate,+_transform];
private _attemptIndex=_attempts findIf {(_x select [0,2]) isEqualTo _key};
private _closedProof=_gate getVariable ["CBE_DrivingGate_ClosedProof",[]];
private _passageCycle=if (count _closedProof == 3 && {(_closedProof select 0) isEqualTo _transform}
    && {(_closedProof select 1) isEqualType 0} && {finite (_closedProof select 1)}
    && {(_closedProof select 1) > 0}) then {_closedProof select 1} else {0};
private _publishResult={
    params ["_reason","_until"];
    if (_attemptIndex >= 0) then {
        private _row=_attempts select _attemptIndex;
        _row set [2,_reason]; _row set [3,_until];
        _vehicle setVariable ["CBE_DrivingGate_AttemptStopSerial",_stopSerial];
    _vehicle setVariable ["CBE_DrivingGate_ServerAttempts",[_group,+_route,_revision,_attempts]];
    };
    private _ack=[_gate,_reason,_until,_group,+_route,_revision,+_transform,_passageCycle];
    if ((_vehicle getVariable ["CBE_DrivingGate_Result",[]]) isNotEqualTo _ack) then {
        _vehicle setVariable ["CBE_DrivingGate_Result",_ack,true];
    };
};
private _retryUnlock=false;
if (_attemptIndex >= 0 && {_unlockReceipt >= 0}) then {
    private _previous=_attempts select _attemptIndex;
    if ((_previous select 2) == "LOCKED" && {(_previous select 3) == _unlockReceipt}
        && {(_previous param [4,0]) == 0}) then {
        _retryUnlock=(_gate getVariable ["bis_disabled_Door",0]) isEqualTo 0;
        for "_index" from 1 to 8 do {
            if ((_gate getVariable [format ["bis_disabled_Door_%1",_index],0]) isNotEqualTo 0) exitWith {_retryUnlock=false};
        };
    };
};
private _retryPassage=false;
if (_attemptIndex >= 0) then {
    private _previous=_attempts select _attemptIndex;
    _retryPassage=_passageCycle > (_previous param [5,0,[0]])
        && {(_previous select 2) in ["OPEN_REQUESTED","SHARED_OPENING","OPEN_WINDOW_EXPIRED","ALREADY_OPEN_OR_MOVING"]};
};
if (_attemptIndex >= 0 && {!_retryUnlock} && {!_retryPassage}) exitWith {
    private _previous=_attempts select _attemptIndex;
    private _reason=_previous select 2;
    if (_reason in ["OPEN_REQUESTED","SHARED_OPENING"] && {serverTime >= (_previous select 3)}) then {_reason="OPEN_WINDOW_EXPIRED"};
    [_reason,_previous select 3] call _publishResult;
    false
};
if (!_retryUnlock && {!_retryPassage} && {count _attempts >= 16}) exitWith {["ROUTE_GATE_BUDGET",serverTime] call _publishResult;false};
private _observed=[_vehicle,0,true] call CBE_fnc_DrivingGateCap;
if ((_observed select 1) != _gate || {(_observed select 2) > 12} || {(_observed select 2) < 0}) exitWith {false};
if (_retryUnlock) then {
    _attempts set [_attemptIndex,[_gate,+_transform,"VALIDATING",serverTime+5,1,_passageCycle]];
} else {
    if (_retryPassage) then {
        _attempts set [_attemptIndex,[_gate,+_transform,"VALIDATING",serverTime+5,0,_passageCycle]];
    } else {
        _attemptIndex=count _attempts;
        _attempts pushBack [_gate,+_transform,"VALIDATING",serverTime+5,0,_passageCycle];
    };
};
_vehicle setVariable ["CBE_DrivingGate_AttemptStopSerial",_stopSerial];
    _vehicle setVariable ["CBE_DrivingGate_ServerAttempts",[_group,+_route,_revision,_attempts]];
private _sources=[];
private _preferredSources=createHashMap;
private _definitions="true" configClasses ((configOf _gate) >> "AnimationSources");
if (count _definitions <= 64) then {
    {
        private _name=configName _x;
        private _lowerName=toLowerANSI _name;
        private _parts=_lowerName splitString "_";
        if (count _parts in [3,4]) then {
            private _index=parseNumber (_parts select 1);
            if (_index >= 1 && {_index <= 8} && {_index == floor _index}) then {
                // One source per physical leaf: sound source first, then its plain alias.
                // Exact indexed names exclude lock/handle/nosound and arbitrary action scripts.
                private _aliases=[format ["door_%1_sound_source",_index],format ["gate_%1_sound_source",_index],
                    format ["door_%1_source",_index],format ["gate_%1_source",_index]];
                private _priority=_aliases find _lowerName;
                if (_priority >= 0) then {
                    private _key=str _index;
                    private _previous=_preferredSources getOrDefault [_key,[]];
                    if (_previous isEqualTo [] || {_priority < (_previous select 0)}) then {
                        _preferredSources set [_key,[_priority,_index,_name]];
                    };
                };
            };
        };
    } forEach _definitions;
};
for "_index" from 1 to 8 do {
    private _preferred=_preferredSources getOrDefault [str _index,[]];
    if (_preferred isNotEqualTo []) then {
        private _sourceName=_preferred select 2;
        _sources pushBack [_preferred select 1,_sourceName,_gate animationSourcePhase _sourceName];
    };
};
private _locked={
    (_gate getVariable ["bis_disabled_Door",0]) isNotEqualTo 0
        || {_sources findIf {(_gate getVariable [format ["bis_disabled_Door_%1",_x select 0],0]) isNotEqualTo 0} >= 0}
};
private _reason=if (_sources isEqualTo []) then {"UNSUPPORTED"} else {if (call _locked) then {"LOCKED"} else {"READY"}};
if (_reason != "READY") exitWith {
    [_reason,serverTime] call _publishResult;
    false
};
private _opening=_gate getVariable ["CBE_DrivingGate_ServerOpening",[]];
if (count _opening == 4 && {(_opening select 0) isEqualTo _transform} && {serverTime < (_opening select 2)}) exitWith {
    ["SHARED_OPENING",_opening select 2] call _publishResult;
    true
};
if (_sources findIf {(_x select 2) < 0.1} < 0) exitWith {
    ["ALREADY_OPEN_OR_MOVING",serverTime] call _publishResult;
    false
};
// Final mutation boundary: metadata is prepared first; authority, lock and animation
// are committed together. A convoy revision or crew change cannot borrow earlier admission.
private _opened=false;
isNil {
    private _convoyCurrent=true;
    if (_revision >= 0) then {
        private _liveRegistry=missionNamespace getVariable ["CBE_Convoy_Registry",[]];
        private _liveIndex=_liveRegistry findIf {(_x select 0) == _group};
        _convoyCurrent=false;
        if (_liveIndex >= 0) then {
            private _liveConfig=(_liveRegistry select _liveIndex) select 1;
            _convoyCurrent=(_liveConfig select 0) == _revision && {(_liveConfig select 5) == "TRAVEL"}
                && {_vehicle in (_liveConfig select 4)}
                && {[_group,"CBE_Convoy_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled};
        };
    };
    private _liveCommander=effectiveCommander _vehicle;
    if (isNull _liveCommander) then {_liveCommander=driver _vehicle};
    if (!_convoyCurrent || {serverTime >= _expires}
        || {_revision < 0 && {!(missionNamespace getVariable ["CBE_AIPass_Active",false])
            || {!([_group,_vehicle,_route] call CBE_fnc_DrivingGateIntent)}
            || {!([_group,true] call CBE_fnc_DrivingMovementAvailable)}
            || {!([_group,"CBE_AIPass_DrivingAssist_Enable",true,_vehicle] call CBE_fnc_CortexFeatureEnabled)}}}
        || {call _locked} || {!alive _gate} || {!alive _vehicle} || {!canMove _vehicle}
        || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle} || {abs speed _vehicle > 8}
        || {driver _vehicle != _driver} || {_liveCommander != _requestedCommander}
        || {[_driver,_liveCommander] findIf {isNull _x || {group _x != _group} || {isPlayer _x}
            || {!isNull remoteControlled _x} || {!simulationEnabled _x} || {isObjectHidden _x}
            || {!([_x] call CBE_fnc_CortexCombatEffective)}
            || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
            || {currentCommand _x in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}} >= 0}
        || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        || {_sender > 0 && {_sender != 2} && {_sender != groupOwner _group
            || {_sender != owner _vehicle} || {_sender != owner _driver} || {_sender != owner _liveCommander}}}
        || {_transform isNotEqualTo [getPosWorld _gate,vectorDir _gate,vectorUp _gate]}
        || {([_group] call CBE_fnc_DrivingRouteReceipt) isNotEqualTo _route}
        || {[] call CBE_fnc_CortexIsPaused}
        || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {_sources findIf {abs ((_gate animationSourcePhase (_x select 1))-(_x select 2)) > 0.02} >= 0}) exitWith {
        ["REQUEST_REPLACED",serverTime] call _publishResult;
    };
    // Another vehicle may have opened this gate while this request was planning.
    private _currentOpening=_gate getVariable ["CBE_DrivingGate_ServerOpening",[]];
    if (count _currentOpening == 4 && {(_currentOpening select 0) isEqualTo _transform}
        && {serverTime < (_currentOpening select 2)}) exitWith {
        ["SHARED_OPENING",_currentOpening select 2] call _publishResult;_opened=true;
    };
    _gate setVariable ["CBE_DrivingGate_ServerOpening",[+_transform,+_sources,serverTime+12,_group]];
    {
        if ((_x select 2) < 0.1) then {_gate animateSource [_x select 1,1]};
    } forEach _sources;
    // Closure is separately opt-in and requires a complete pre-passage observation.
    // Opening still succeeds when geometry/capacity cannot admit safe closure work.
    if ([_group,"CBE_AIPass_DrivingAssist_CloseGates_Enable",false,_vehicle] call CBE_fnc_CortexFeatureEnabled) then {
        private _closeJobs=(missionNamespace getVariable ["CBE_DrivingGate_CloseJobs",[]]) select {
            !(_x getOrDefault ["done",false])
        };
        missionNamespace setVariable ["CBE_DrivingGate_CloseJobs",_closeJobs];
        private _existingClose=_gate getVariable ["CBE_DrivingGate_CloseWork",createHashMap];
        if (count _closeJobs < 8 && {count _existingClose == 0 || {serverTime >= (_existingClose getOrDefault ["until",-1])}}) then {
            private _box=boundingBoxReal _gate;private _low=_box select 0;private _high=_box select 1;
            private _origin=_gate modelToWorldWorld ((_low vectorAdd _high) vectorMultiply 0.5);
            private _axis=if ((_high select 0)-(_low select 0) >= (_high select 1)-(_low select 1)) then {
                vectorDir _gate
            } else {private _dir=vectorDir _gate;[_dir select 1,-(_dir select 0),0]};
            _axis set [2,0];
            if (vectorMagnitude _axis > 0.1) then {
                _axis=vectorNormalized _axis;
                if (((getPosWorld _vehicle) vectorDiff _origin) vectorDotProduct _axis > 0) then {_axis=_axis vectorMultiply -1};
                private _side=[_axis select 1,-(_axis select 0),0];
                private _gateBounds=[_gate,_origin,_axis,_side] call CBE_fnc_DrivingHullInterval;
                private _gateSpan=if (count _gateBounds == 4) then {_gateBounds select [0,2]} else {[]};
                private _aperture=if (count _gateBounds == 4) then {_gateBounds select [2,2]} else {[]};
                private _hull=[_vehicle,_origin,_axis] call CBE_fnc_DrivingHullInterval;
                if (count _gateSpan == 2 && {count _aperture == 2} && {count _hull == 2}
                    && {(_hull select 1) < (_gateSpan select 0)-0.5}
                    && {(_aperture select 1)-(_aperture select 0) >= 1.5}
                    && {(_aperture select 1)-(_aperture select 0) <= 20}
                    && {(_gateSpan select 1)-(_gateSpan select 0) <= 8}) then {
                    private _serial=(missionNamespace getVariable ["CBE_DrivingGate_CloseSerial",0])+1;
                    missionNamespace setVariable ["CBE_DrivingGate_CloseSerial",_serial];
                    private _leaves=_sources select {(_x select 2) < 0.1};
                    private _job=createHashMapFromArray [["gate",_gate],["vehicle",_vehicle],["taskGroup",_group],
                        ["driver",_driver],["commander",_requestedCommander],["groupOwner",groupOwner _group],
                        ["vehicleOwner",owner _vehicle],["driverOwner",owner _driver],["commanderOwner",owner _requestedCommander],
                        ["native",[+(expectedDestination _driver),+(expectedDestination _requestedCommander)]],
                        ["nativeTasks",[currentCommand _driver,currentCommand _requestedCommander]],
                        ["route",+_route],["revision",_revision],
                        ["epoch",_group getVariable ["CBE_AIPass_Epoch",0]],
                        ["operation",_group getVariable ["CBE_OperationGeneration",0]],
                        ["transform",+_transform],["opening",+(_gate getVariable ["CBE_DrivingGate_ServerOpening",[]])],
                        ["leaves",+_leaves],["otherLeaves",_sources select {(_x select 2) >= 0.1}],
                        ["lastPhases",_leaves apply {_x select 2}],["phase","PASSAGE"],
                        ["started",serverTime],["until",serverTime+120],["origin",_origin],["axis",_axis],["side",_side],
                        ["gateSpan",_gateSpan],["aperture",_aperture],["sample",[serverTime,getPosWorld _vehicle]],
                        ["crossed",false],["done",false],["generation",_serial],
                        ["jobKey",format ["CBE_GATE_CLOSE_%1_%2",netId _gate,_serial]]];
                    _gate setVariable ["CBE_DrivingGate_CloseWork",_job];
                    _closeJobs pushBack _job;missionNamespace setVariable ["CBE_DrivingGate_CloseJobs",_closeJobs];
                    [CBE_fnc_DrivingGateCloseServer,_job,1,_job get "jobKey"] call CBE_fnc_CortexQueueJob;
                };
            };
        };
    };
    ["OPEN_REQUESTED",serverTime+12] call _publishResult;
    _opened=true;
};
_opened
