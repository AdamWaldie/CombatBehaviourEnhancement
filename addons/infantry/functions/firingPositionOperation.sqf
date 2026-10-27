/*
 * Author: WaldoTheWarfighter
 * Purpose: One finite owner-local firing-position FSM for a persistently obstructed rifleman.
 * ASSESS requires the same nearby belief and stationary origin across six seconds; four lateral
 * endpoints are tested once after a ten-second search cooldown. No target pose is read.
 * MOVE and RETURN are observed phases, not command acknowledgements inferred from elapsed time.
 * Locality/authority: Actor/group owner; newer native routes, specialist work and Zeus win.
 * Repeat/JIP: One public journal per actor and one slot per group; original 18+8 second budget,
 * one move and at most one original-anchor follow. Locality adopts observation, never replays issue.
 * No skill, feature, posture, speed, formation or waypoint edits. Native targeting remains enabled.
 * Arguments: mode STRING ASSESS; actor OBJECT objNull; believed ASL point ARRAY [];
 * optional serial NUMBER -1 for internal STEP callbacks (not an authority token).
 * Return: BOOL admission/retirement, or NUMBER delay/-1 for shared scheduled STEP.
 * Callers: CortexFireControl, CortexDiscover/Locality/Stop, CortexReleaseGroup/OrderLocal RELEASE.
 * Example: ["ASSESS",soldier1,ATLToASL [100,100,1]] call CBE_fnc_FiringPositionOperation;
 * ARRIVED means observed proximity/native readiness and a fresh outgoing ray, never successful fire.
 * Hard expiry retains unresolved native proof for passive discovery; it never renews movement.
 */
params [["_mode","ASSESS",[""]],["_actor",objNull,[objNull]],["_belief",[],[[]]],["_serial",-1,[0]]];
if (isNull _actor || {!local _actor} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _group=group _actor;
if (isNull _group || {!local _group}) exitWith {false};
private _vector={_this isEqualType [] && {count _this == 3} && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _copy={_this apply {if (_x isEqualType []) then {_x call _copy} else {_x}}};
private _order=_actor getVariable ["CBE_FiringPosition_Order",[]];
private _available={
    !isPlayer _actor && {isNull remoteControlled _actor} && {isNull objectParent _actor}
    && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!fleeing _actor}
    && {[_actor] call CBE_fnc_CortexCombatEffective} && {_actor checkAIFeature "MOVE"}
    && {_actor checkAIFeature "PATH"} && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
    && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
    && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
    && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
    && {[_actor] call CBE_fnc_IndoorActorGroupAvailable}
};
private _lane={
    params ["_from","_to"];
    if (terrainIntersectASL [_from,_to]) exitWith {false};
    private _hits=lineIntersectsSurfaces [_from,_to,_actor,objNull,true,1,"FIRE","GEOM"];
    _hits isEqualTo [] || {!isNull ((_hits select 0) select 2)
        && {((_hits select 0) select 0) vectorDistance _to <= 3}}
};
if (!(_mode in ["ASSESS","STEP","RETIRE","TRANSFER","REAP"])) exitWith {false};
if (_mode == "ASSESS") exitWith {
    if (!(call _available) || {_actor == leader _group} || {!unitReady _actor}
        || {abs speed _actor >= 0.5} || {getSuppression _actor >= 0.5}
        || {!([_actor] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {!(currentCommand _actor in ["","WAIT","FOLLOW"])}
        || {!(combatMode _group in ["YELLOW","RED"])} || {!(unitCombatMode _actor in ["YELLOW","RED"])}
        || {!(_belief call _vector)} || {(eyePos _actor) vectorDistance _belief < 30}
        || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
        || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}
        || {!isNull (_group getVariable ["CBE_FiringPosition_Actor",objNull])}) exitWith {false};
    if ([eyePos _actor,_belief] call _lane) exitWith {
        _actor setVariable ["CBE_FiringPosition_Blocked",nil];false
    };
    private _weapon=primaryWeapon _actor;
    private _magazine=currentMagazine _actor;
    if (_weapon == "" || {currentWeapon _actor != _weapon} || {_actor ammo currentMuzzle _actor <= 0}
        || {toLowerANSI getText (configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines"
            >> _magazine >> "ammo") >> "simulation") != "shotbullet"}) exitWith {false};
    private _origin=getPosATL _actor;
    private _sample=_actor getVariable ["CBE_FiringPosition_Blocked",[]];
    if (!(_sample isEqualType []) || {count _sample != 4}
        || {!((_sample select 0) call _vector)} || {!((_sample select 1) call _vector)}
        || {!((_sample select 2) isEqualType 0)} || {!finite (_sample select 2)}
        || {!((_sample select 3) isEqualType 0)} || {!finite (_sample select 3)}
        || {(_sample select 0) vectorDistance _belief > 3}
        || {(_sample select 1) distance _origin > 2} || {time-(_sample select 3) > 8}) exitWith {
        _actor setVariable ["CBE_FiringPosition_Blocked",[+_belief,+_origin,time,time]];false
    };
    _sample set [3,time];
    _actor setVariable ["CBE_FiringPosition_Blocked",_sample];
    if (time-(_sample select 2) < 6 || {time < (_group getVariable ["CBE_FiringPosition_SearchAfter",0])}) exitWith {false};
    _group setVariable ["CBE_FiringPosition_SearchAfter",time+10];
    private _before=[currentCommand _actor,+(expectedDestination _actor),formLeader _actor];
    private _route=[_group] call CBE_fnc_NativeOrderReceipt;
    private _bearing=_origin getDir (ASLToAGL _belief);
    private _candidates=[];
    {
        private _point=_origin getPos [_x select 0,_bearing+(_x select 1)];
        private _eye=(AGLToASL _point) vectorAdd [0,0,1.4];
        if ([_eye,_belief] call _lane) then {_candidates pushBack [_point]};
    } forEach [[6,90],[6,-90],[10,90],[10,-90]];
    private _legs=[_origin,_candidates,ASLToAGL _belief,[getPosATL leader _group],objNull,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
    if (_legs isEqualTo []) exitWith {false};
    private _point=+(_legs select -1);
    private _accepted=false;
    isNil {
    if (!(call _available) || {!([_actor] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _route}
        || {[currentCommand _actor,expectedDestination _actor,formLeader _actor] isNotEqualTo _before}
        || {!isNull (_group getVariable ["CBE_FiringPosition_Actor",objNull])}) exitWith {};
    private _generation=1+(_actor getVariable ["CBE_FiringPosition_Generation",0]);
    private _until=serverTime+18;
    private _lease=[format ["FIRING_POSITION:%1:%2",clientOwner,_generation],+_point,time+26];
    // Journal fields: serial, group, epoch, native route, destination, belief, original deadline,
    // original actor native snapshot, phase, exact lease, original origin. Nested arrays are copied.
    _order=[_generation,_group,_group getVariable ["CBE_AIPass_Epoch",0],_route,_point,+_belief,_until,_before,"MOVE",_lease,+_origin] call _copy;
    _actor setVariable ["CBE_FiringPosition_Generation",_generation];
    _actor setVariable ["CBE_FiringPosition_Order",_order,true];
    _actor setVariable ["CBE_Cortex_ActorMove",_lease call _copy];
    _group setVariable ["CBE_FiringPosition_Actor",_actor,true];
    _actor doMove _point;
    [{params ["_job"];["STEP",_job get "actor",[],_job get "serial"] call CBE_fnc_FiringPositionOperation},
        createHashMapFromArray [["actor",_actor],["serial",_generation],["subsystem","TACTICS"]],0.5,
        "CBE_FIRE_POSITION_"+netId _actor] call CBE_fnc_CortexQueueJob;
    _accepted=true;
    };
    _accepted
};
if (_order isEqualTo []) exitWith {if (_mode == "STEP") then {-1} else {true}};
private _typed=_order isEqualType [] && {count _order == 11}
    && {(_order select 0) isEqualType 0} && {(_order select 1) isEqualType grpNull}
    && {(_order select 2) isEqualType 0} && {(_order select 3) isEqualType []}
    && {(_order select 4) call _vector} && {(_order select 5) call _vector}
    && {(_order select 6) isEqualType 0} && {finite (_order select 6)}
    && {(_order select 7) isEqualType []} && {count (_order select 7) == 3}
    && {(_order select 8) in ["MOVE","RETURN"]} && {(_order select 9) isEqualType []}
    && {count (_order select 9) == 3} && {(_order select 10) call _vector}
    && {[0,2] findIf {!finite (_order select _x) || {(_order select _x) < 0} || {(_order select _x) != floor (_order select _x)}} < 0}
    && {((_order select 7) select 0) isEqualType ""}
    && {((_order select 7) select 1) isEqualType []}
    && {((_order select 7) select 2) isEqualType objNull}
    && {((_order select 9) select 0) isEqualType ""}
    && {((_order select 9) select 1) isEqualTo (_order select 4)}
    && {((_order select 9) select 2) isEqualType 0} && {finite ((_order select 9) select 2)};
if (!_typed || {_serial >= 0 && {_serial != (_order select 0)}}) exitWith {if (_mode == "STEP") then {-1} else {false}};
_order params ["_generation","_oldGroup","_epoch","_route","_point","_target","_until","_before","_phase","_lease","_origin"];
private _finish={
    params ["_reason"];
    if ((_actor getVariable ["CBE_FiringPosition_Order",[]]) isEqualTo _order) then {
        if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _lease) then {_actor setVariable ["CBE_Cortex_ActorMove",nil]};
        _actor setVariable ["CBE_FiringPosition_Result",[_generation,_reason,serverTime,+_point],true];
        _actor setVariable ["CBE_FiringPosition_Order",nil,true];
        _oldGroup setVariable ["CBE_FiringPosition_SearchAfter",time+30];
        if ((_oldGroup getVariable ["CBE_FiringPosition_Actor",objNull]) == _actor) then {_oldGroup setVariable ["CBE_FiringPosition_Actor",nil,true]};
    };
    -1
};
// Passive discovery may revisit terminal proof. Publish a changed outcome only;
// repeated observation must not turn unchanged unresolved custody into network churn.
private _reportPending={
    params ["_reason"];
    private _prior=_actor getVariable ["CBE_FiringPosition_Result",[]];
    if (!(_prior isEqualType []) || {count _prior < 2}
        || {(_prior select 0) != _generation} || {(_prior select 1) != _reason}) then {
        _actor setVariable ["CBE_FiringPosition_Result",[_generation,_reason,serverTime,+_point],true];
    };
};
private _goal=(expectedDestination _actor) param [0,[],[[]]];
private _ownsRoute=_oldGroup == _group && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _route};
private _marker=_actor getVariable ["CBE_Cortex_ActorMove",[]];
if (_marker isNotEqualTo [] && {_marker isNotEqualTo _lease}) exitWith {["OWNER_REPLACED"] call _finish};
private _ownsLeg=currentCommand _actor == "MOVE" && {_goal call _vector} && {_goal vectorDistance _point <= 0.25};
private _pending=currentCommand _actor in [_before select 0,"MOVE"] && {(expectedDestination _actor) isEqualTo (_before select 1)} && {!_ownsLeg};
if (!_ownsRoute || {!alive _actor}) exitWith {["PREEMPTED"] call _finish};
if (_phase == "RETURN") exitWith {
    if (currentCommand _actor == "FOLLOW" && {formLeader _actor == (_before select 2)}) exitWith {["RETURNED"] call _finish};
    if (!_ownsLeg && {!_pending}) exitWith {["NATIVE_TASK_CHANGED"] call _finish};
    if (serverTime >= _until+8) exitWith {
        ["RETURN_UNRESOLVED"] call _reportPending;-1
    };
    if (_mode == "STEP") then {0.5} else {false}
};
// Readiness plus physical rest/proximity can complete the exact owned native MOVE;
// do not require the command label itself to become empty before accepting arrival.
private _arrived=(getPosASL _actor) vectorDistance (AGLToASL _point) < 1.5 && {unitReady _actor}
    && {abs speed _actor < 0.5}
    && {_ownsLeg || {currentCommand _actor in ["","WAIT","FOLLOW"]}} && {call _available}
    && {[eyePos _actor,_target] call _lane};
if (_arrived) exitWith {["ARRIVED"] call _finish};
if (!_ownsLeg && {!_pending}) exitWith {["NATIVE_TASK_CHANGED"] call _finish};
private _enabled=missionNamespace getVariable ["CBE_AIPass_Active",false]
    && {!([] call CBE_fnc_CortexIsPaused)}
    && {combatMode _group in ["YELLOW","RED"]} && {unitCombatMode _actor in ["YELLOW","RED"]}
    && {behaviour _actor != "STEALTH"}
    && {[_group,"CBE_AIPass_FireControl_Enable",true] call CBE_fnc_CortexFeatureEnabled};
if (_mode in ["RETIRE","TRANSFER"] || {!_enabled} || {!(call _available)} || {serverTime >= _until}
    || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",0])}) exitWith {
    if (_ownsLeg && {serverTime < _until+8} && {call _available}
        && {_marker isEqualTo _lease || {_marker isEqualTo [] && {_mode in ["TRANSFER","REAP"]}
            && {(_oldGroup getVariable ["CBE_FiringPosition_Actor",objNull]) == _actor}}}
        && {!isNull (_before select 2)} && {(_before select 2) != _actor}
        && {group (_before select 2) == _group} && {alive (_before select 2)}) then {
        isNil {
        // A scheduled administrative caller must not carry a stale native-write gate.
        private _currentGoal=(expectedDestination _actor) param [0,[],[[]]];
        if (!local _actor || {!local _group} || {!(call _available)}
            || {serverTime >= _until+8} || {group _actor != _oldGroup}
            || {(_actor getVariable ["CBE_FiringPosition_Order",[]]) isNotEqualTo _order}
            || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _route}
            || {currentCommand _actor != "MOVE"} || {!(_currentGoal call _vector)}
            || {_currentGoal vectorDistance _point > 0.25}
            || {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo _marker}
            || {isNull (_before select 2)} || {!alive (_before select 2)}
            || {group (_before select 2) != _group}) exitWith {};
        // Persist before issue: observation/migration must never repeat this native return.
        private _returnOrder=_order call _copy;
        _returnOrder set [8,"RETURN"];
        _actor setVariable ["CBE_FiringPosition_Order",_returnOrder,true];
        _actor doFollow (_before select 2);
        };
    } else {
        ["NATIVE_UNRESOLVED"] call _reportPending;
    };
    if (_mode == "STEP" && {serverTime < _until+8}) then {0.5} else {-1}
};
if (_mode == "STEP") then {0.5} else {false}
