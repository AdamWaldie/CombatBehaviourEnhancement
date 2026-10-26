/*
 * Author: WaldoTheWarfighter
 * Purpose: Own one finite launcher backblast relocation and its exact native handback.
 * Locality/authority: Actor/group owner only; START uses original caller context and native
 * state. RELEASE/TRANSFER never acquire a new move. Changed orders, care, Zeus and providers win.
 * Repeat/JIP: Public immutable original lease/context survives local group-state retirement.
 * Travel lasts ten seconds; cancellation/return observation ends at original deadline plus30s.
 * Pending replies retain proof, never renew deadlines or replay doMove/doFollow. Unresolved
 * proof blocks competing actor admission until superseded or explicitly observed on cleanup.
 * Existing group/sparse discovery and stop/locality edges service it. One coalesced finite
 * four-second cleanup callback may observe a cancelled request after tactical shutdown.
 * No world query, firing, settings, posture, waypoint, forced movement or permanent controller.
 * Arguments: mode STRING SERVICE, START/RELEASE/TRANSFER/CLEANUP also valid; actor OBJECT
 * objNull; target ARRAY [] ATL; context ARRAY [] original group/owner/epoch/operation/route;
 * before ARRAY [] original native command/destination/formation anchor. Last3 are START-only.
 * Return: BOOL true while a valid or unknown journal still reserves this actor, not success.
 * Current callers: CortexAntiArmour, CortexGroupTick, DangerSetup, CortexRestoreCalm, CortexReleaseGroup,
 * CortexStop, CortexLocality and its finite cleanup observation callback.
 * Example: ["RELEASE",soldier1] call CBE_fnc_LauncherMove;
 */
params [["_mode","SERVICE",[""]],["_actor",objNull,[objNull]],
    ["_target",[],[[]]],["_context",[],[[]]],["_before",[],[[]]]];
if (isNull _actor || {!local _actor} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}
    || {!(_mode in ["START","SERVICE","RELEASE","TRANSFER","CLEANUP"])}) exitWith {false};
private _blocked=false;
isNil {
_blocked=call {
private _group=group _actor;
// Split actor/group arrival grants no native observation or retirement authority yet.
if (!local _group) exitWith {
    _mode != "START" && {(_actor getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isNotEqualTo createHashMap}
};
private _currentContext=[_group,clientOwner,_group getVariable ["CBE_AIPass_Epoch",0],
    _group getVariable ["CBE_OperationGeneration",0],[_group] call CBE_fnc_NativeOrderReceipt];
private _native=[currentCommand _actor,expectedDestination _actor,formLeader _actor];
private _work=_actor getVariable ["CBE_Cortex_LauncherMove",createHashMap];
if (!(_work isEqualType createHashMap)) exitWith {_mode != "START"};
private _available=!isNull _group && {local _group} && {alive _actor} && {!fleeing _actor}
    && {[_actor] call CBE_fnc_CortexCombatEffective} && {isNull objectParent _actor}
    && {simulationEnabled _actor} && {!isObjectHidden _actor} && {!isPlayer _actor}
    && {isNull remoteControlled _actor}
    && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
    && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
    && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
    && {!([_group,false,_actor] call CBE_fnc_CortexExternalTakeover)}
    && {!([_group] call CBE_fnc_CortexZeusHeld)}
    && {["CBE_Danger_FlightLease","CBE_Cortex_NavalEgressMove","CBE_PointActor_Order","CBE_IndoorActor_Order"]
        findIf {(_actor getVariable [_x,[]]) isNotEqualTo []} < 0};
if (_mode == "START") exitWith {
    if (isRemoteExecuted || {!_available} || {!(combatMode _group in ["YELLOW","RED"])}
        || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
        || {!(_actor checkAIFeature "FIREWEAPON")} || {!(unitCombatMode _actor in ["YELLOW","RED"])}
        || {time < (_actor getVariable ["CBE_Cortex_LauncherAfter",-1])}
        || {count _work > 0} || {_context isNotEqualTo _currentContext}
        || {_native isNotEqualTo _before} || {(_before param [0,"MISSING"]) != ""}
        || {[_actor] call CBE_fnc_CortexActorMoveReserved}
        || {!([_group,"CBE_AIPass_AntiArmour_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_group] call CBE_fnc_CortexIsEligible)} || {[] call CBE_fnc_CortexIsPaused}
        || {count _target != 3} || {_target findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        || {surfaceIsWater _target} || {(surfaceNormal _target select 2) < 0.55}) exitWith {false};
    private _lease=["ANTI_ARMOUR",+_target,time+10];
    private _deadline=serverTime+10;
    private _next=createHashMapFromArray [["lease",_lease],["context",+_context],
        ["before",+_before],["deadline",_deadline],["cleanupUntil",_deadline+30],
        ["phase","MOVE"]];
    // Publish original ownership before native issue; no later snapshot substitutes for it.
    _actor setVariable ["CBE_Cortex_ActorMove",_lease];
    _actor setVariable ["CBE_Cortex_LauncherMove",_next,true];
    _actor doMove _target;
    true
};
if (_work isEqualType createHashMap && {count _work == 0}) exitWith {false};
if (!(_work isEqualType createHashMap)) exitWith {true};
private _lease=_work getOrDefault ["lease",[]];private _original=_work getOrDefault ["context",[]];
private _prior=_work getOrDefault ["before",[]];private _until=_work getOrDefault ["deadline",-1];
private _hard=_work getOrDefault ["cleanupUntil",-1];private _phase=_work getOrDefault ["phase",""];
if (!(_lease isEqualType []) || {count _lease != 3} || {(_lease select 0) != "ANTI_ARMOUR"}
    || {!((_lease select 1) isEqualType [])} || {count (_lease select 1) != 3}
    || {(_lease select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!((_lease select 2) isEqualType 0)} || {!finite (_lease select 2)}
    || {!(_original isEqualType [])} || {count _original != 5}
    || {!(_prior isEqualType [])} || {count _prior != 3}
    || {!((_prior select 0) isEqualType "")} || {!((_prior select 1) isEqualType [])}
    || {!((_prior select 2) isEqualType objNull)}
    || {!(_until isEqualType 0)} || {!finite _until} || {!(_hard isEqualType 0)}
    || {!finite _hard} || {_hard != _until+30} || {!(_phase in ["MOVE","RETURN"])}) exitWith {true};
private _retire={
    params ["_result"];
    if ((_actor getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isEqualTo _work) then {
        if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _lease) then {
            _actor setVariable ["CBE_Cortex_ActorMove",nil];
        };
        _actor setVariable ["CBE_Cortex_LauncherMove",nil,true];
        if (_result != "POSITION_REACHED") then {_actor setVariable ["CBE_Cortex_LauncherAfter",time+10]};
        _actor setVariable ["CBE_Cortex_LauncherResult",[_result,serverTime,+(_lease select 1),_until],true];
    };
};
private _retirementContext=_work getOrDefault ["retirementContext",[]];
private _sameContext=([_original,_retirementContext] select (_retirementContext isNotEqualTo [])) isEqualTo _currentContext;
// Real locality and explicit shutdown epoch edges may cancel an unchanged original leg on its new owner.
// It cannot adopt travel or override a different operation/route.
private _edge=_group getVariable ["CBE_Cortex_LauncherTransfer",[]];
private _edgeCurrent=count _edge == 3 && {(_edge select 0) == clientOwner}
    && {(_edge select 1) == (_currentContext select 2)} && {serverTime < (_edge select 2)};
if (_mode == "SERVICE" && {(_original select 1) != clientOwner || {_edgeCurrent}}) then {
    _mode="TRANSFER";
};
if (_mode == "TRANSFER") then {
    _sameContext=(_original select 0) == _group
        && {(_original select 4) isEqualTo (_currentContext select 4)}
        && {(_original select 3) == (_currentContext select 3)
            || {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}};
};
private _marker=(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo _lease;
// A new owner may have no machine-private marker. The exact public task is cleanup only.
if ((_mode == "TRANSFER" || {_retirementContext isEqualTo _currentContext})
    && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []}) then {_marker=true};
if (!_sameContext || {!_available} || {!_marker}) exitWith {["SUPERSEDED"] call _retire;false};
if (_mode == "TRANSFER" && {_retirementContext isNotEqualTo _currentContext}) then {
    private _transfer=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
    _transfer set ["retirementContext",_currentContext];
    _actor setVariable ["CBE_Cortex_LauncherMove",_transfer,true];_work=_transfer;
};
private _goal=_lease select 1;private _anchor=_prior select 2;
private _destination=(_native select 1) param [0,[]];
private _ownsMove=(_native select 0) == "MOVE" && {(_native select 2) isEqualTo _anchor}
    && {count _destination == 3} && {_destination vectorDistance _goal <= 1}
    && {abs (((AGLToASL _destination) select 2)-((AGLToASL _goal) select 2)) <= 1.5};
private _pending=(_native select 0) in [_prior select 0,"MOVE"]
    && {(_native select 1) isEqualTo (_prior select 1)}
    && {(_native select 2) isEqualTo (_prior select 2)} && {!_ownsMove};
private _cancel=_mode in ["RELEASE","TRANSFER","CLEANUP"] || {"retirementContext" in _work} || {serverTime >= _until}
    || {!([_group,"CBE_AIPass_AntiArmour_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {[] call CBE_fnc_CortexIsPaused} || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {!(combatMode _group in ["YELLOW","RED"])};
if (_phase == "MOVE" && {!_pending} && {!_ownsMove}) exitWith {["NATIVE_REPLACED"] call _retire;false};
if (_phase == "MOVE" && {_ownsMove}
    && {(getPosASL _actor) vectorDistance (AGLToASL _goal) <= 2} && {!_cancel}) exitWith {
    ["POSITION_REACHED"] call _retire;false
};
if (_phase == "RETURN") then {
    private _returnBefore=_work getOrDefault ["returnBefore",[]];
    private _returnAnchor=_work getOrDefault ["returnAnchor",objNull];
    if ((_native select 0) == "FOLLOW" && {(_native select 2) == _returnAnchor}) exitWith {
        ["NATIVE_RETURN_OBSERVED"] call _retire;false
    };
    if (_native isNotEqualTo _returnBefore) exitWith {["NATIVE_REPLACED"] call _retire;false};
};
if ((_actor getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isNotEqualTo _work) exitWith {false};
if (_cancel && {_phase == "MOVE"} && {_ownsMove} && {serverTime < _hard}) then {
    if (isNull _anchor || {group _anchor != _group}
        || {!([_anchor] call CBE_fnc_CortexCombatEffective)}) then {
        _anchor=[_group] call CBE_fnc_CortexGroupAnchor;
    };
    if (!isNull _anchor && {local _anchor} && {group _anchor == _group}
        && {[_anchor] call CBE_fnc_CortexCombatEffective}) then {
        private _next=createHashMapFromArray (keys _work apply {[_x,_work get _x]});
        _next set ["phase","RETURN"];_next set ["returnBefore",_native];_next set ["returnAnchor",_anchor];
        _actor setVariable ["CBE_Cortex_LauncherMove",_next,true];_work=_next;
        _actor doFollow _anchor;
    };
};
if (_cancel) then {
    private _result=["CANCEL_PENDING","UNRESOLVED_DEADLINE"] select (serverTime >= _hard);
    private _last=_actor getVariable ["CBE_Cortex_LauncherResult",[]];
    if ((_last param [0,""]) != _result || {(_last param [3,-1]) != _until}) then {
        _actor setVariable ["CBE_Cortex_LauncherResult",[_result,serverTime,+_goal,_until],true];
    };
    // Finite cleanup survives master shutdown. One pending callback per immutable lease;
    // successor receipts and owner loss cannot replay commands or extend the lifetime.
    if (serverTime < _hard && {((_actor getVariable ["CBE_Cortex_LauncherCleanup",[]]) param [0,[]]) isNotEqualTo _lease}) then {
        private _serial=1+(_actor getVariable ["CBE_Cortex_LauncherCleanupSerial",0]);
        _actor setVariable ["CBE_Cortex_LauncherCleanupSerial",_serial];
        private _ticket=[+_lease,_serial];
        _actor setVariable ["CBE_Cortex_LauncherCleanup",_ticket];
        [{
            params ["_unit","_expectedLease","_ticket"];
            if (!isNull _unit && {local _unit}
                && {(_unit getVariable ["CBE_Cortex_LauncherCleanup",[]]) isEqualTo _ticket}) then {
                _unit setVariable ["CBE_Cortex_LauncherCleanup",nil];
                if (((_unit getVariable ["CBE_Cortex_LauncherMove",createHashMap]) getOrDefault ["lease",[]]) isEqualTo _expectedLease) then {
                    ["CLEANUP",_unit] call CBE_fnc_LauncherMove;
                };
            };
        },[_actor,+_lease,_ticket],4 min ((_hard-serverTime) max 0)] call CBA_fnc_waitAndExecute;
    };
};
(_actor getVariable ["CBE_Cortex_LauncherMove",createHashMap]) isNotEqualTo createHashMap
};
};
_blocked
