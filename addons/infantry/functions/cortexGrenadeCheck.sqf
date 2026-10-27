/*
 * Author: WaldoTheWarfighter
 * A current clearance-owned native STOP may evade and retain its exact episode return
 * context. Foreign stops remain protected; clearance resumes through its existing writer.
 * Lets nearby AI react to a live hand grenade by moving away from it into cover.
 *
 * Grenade evasion is queued by the
 * ProjectileCreated handler that CBE_fnc_CortexInit installs (CBE_AIPass_GrenadeEvasion_Enable,
 * on by default; the handler and reaction job still restrict orders to locally owned AI. After a short
 * reaction delay, each local AI soldier
 * on foot within 12 m reacts if he can see the grenade or it is within 5 m, with a chance based on his
 * general skill and reduced by suppression. Escape seeds are 9 m from each reacting actor on an away bearing,
 * and moved into cover facing it where possible. Cover searches share the destinations already
 * issued by this grenade job. At most four endpoints are checked against those local reservations;
 * occupied fallbacks are not issued. This is endpoint separation, not collision-free native routing.
 * One Cortex scheduler job per grenade checks every
 * reacting soldier six seconds later; no callback or scheduler is created per unit. Each escape
 * receives a six-second GRENADE_EVASION actor lease, so a tactical bound or anti-armour relocation
 * cannot overwrite it. A soldier held as part of a coordinated base of fire temporarily leaves that
 * owned PATH hold, evades, then becomes eligible for the covering role again. Flank element members
 * and actors with another live reservation are left to their current task. Delayed regroup requires
 * the same group, authored waypoint receipt, Zeus token, actor lease and evasion
 * destination, an available on-foot soldier and no current clearance, defence, garrison,
 * support or actor-participating operation. Exact marker cleanup remains independent.
 * Admission and delayed recall yield to dormant/hidden actors, native fleeing and queued ACE care.
 * Support-list membership never enables PATH; only its actual legacy CBE marker permits handback.
 * An interrupted acknowledged room MOVE retains a local return proposal for the same
 * clearing executor; it issues no return command here and never survives owner migration.
 * Soldiers held in place by a
 * garrison order (PATH disabled) cannot move and are skipped.
 * Locality and authority: scheduler job on the machine that received the event; orders go only to
 * local units.
 *
 * Repeat/JIP: current feature gates and eligibility are rechecked; owner jobs are retired on migration.
 * At most 16 nearby actors are considered. Recovery matches exact expiry, operation generation and
 * owner epoch and source machine; stale callbacks cannot clear a transferred/newer evasion or issue follow over native/specialist tasks.
 * Admission preserves unknown/malformed actor reservations; delayed cleanup requires the exact
 * issued evasion lease, including its destination, so a replacement marker is never retired.
 * Legacy regroup records without a route receipt only retire their exact-owned marker.
 * Arguments:
 * 0: job <HASHMAP> - contains "projectile", or internal "regroup" actor records
 *
 * Return Value:
 * Number - -1 (one-shot)
 *
 * Example:
 * [CBE_fnc_CortexGrenadeCheck, createHashMapFromArray [["projectile", _grenade]], 0.5] call CBE_fnc_CortexQueueJob;
 * Result: soldiers next to the grenade dive away from it.
 *
 * Current caller: the ProjectileCreated handler installed by CBE_fnc_CortexInit.
 */

params [["_job", createHashMap, [createHashMap]]];
private _regroup = _job getOrDefault ["regroup", []];
if (_regroup isNotEqualTo []) exitWith {
    {
        _x params ["_unit","_group","_spot","_hold",
            ["_expires",-1,[0]],["_generation",-1,[0]],["_epoch",-1,[0]],["_nativeRoute",[],[[]]],["_issuer",-1,[0]]];
        private _actorMove = _unit getVariable ["CBE_Cortex_ActorMove",[]];
        private _ownsEvasion = _expires >= 0
            && {_actorMove isEqualTo ["GRENADE_EVASION",_spot,_expires]};
        if (_ownsEvasion && {local _unit}) then {
            // Split locality can leave the actor here after its group moved. Even
            // exact marker cleanup must not mutate a checkpoint inherited by another owner.
            private _sourceCurrent=_issuer == clientOwner && {local _group}
                && {group _unit == _group} && {groupOwner _group == clientOwner}
                && {(_group getVariable ["CBE_AIPass_Epoch",0]) == _epoch}
                && {(_group getVariable ["CBE_OperationGeneration",0]) == _generation};
            if (!_sourceCurrent) exitWith {};
            private _destination=(expectedDestination _unit) param [0,[],[[]]];
            private _stillOurs=local _group && {group _unit == _group} && {vehicle _unit == _unit}
                && {!isPlayer _unit} && {isNull remoteControlled _unit}
                && {(_group getVariable ["CBE_OperationGeneration",0]) == _generation}
                && {(_group getVariable ["CBE_AIPass_Epoch",0]) == _epoch}
                && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
                && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
                && {currentCommand _unit in ["","MOVE"]}
                && {[_unit] call CBE_fnc_CortexCombatEffective}
                && {simulationEnabled _unit} && {!isObjectHidden _unit} && {!fleeing _unit}
                && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
                && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
                && {[_group] call CBE_fnc_CortexIsEligible}
                && {(_group getVariable ["CBE_AIPass_ZeusHold",[]]) isEqualTo _hold}
                && {_nativeRoute isNotEqualTo []}
                && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo _nativeRoute}
                && {count _destination == 3} && {_destination vectorDistance _spot <= 0.25};
            if (_stillOurs) then {
                private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
                private _drill = _state getOrDefault ["drill",createHashMap];
                private _operation=_group getVariable ["CBE_Operation",createHashMap];
                // Retiring our interruption is not permission to recall an actor out
                // of a still-current clear, defence, garrison or support executor.
                private _taskOwned=(_group getVariable ["CBE_AIPass_ClearBuilding",false])
                    || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
                    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}
                    || {_state getOrDefault ["responding",false]} || {_state getOrDefault ["assaulting",false]}
                    || {_unit in (_operation getOrDefault ["participants",[]])};
                if (!_taskOwned && {!(_unit in (_drill getOrDefault ["units",[]]))} && {alive leader _group}) then {
                    _unit doFollow (leader _group);
                };
            };
            // The six-second marker is CBE bookkeeping, not engine ownership. Clear it even when
            // native AI or Zeus changed the destination under this unchanged source episode; only the exact-destination branch above
            // may issue a follow command over the expiring evasion.
            _unit setVariable ["CBE_Cortex_ActorMove",nil];
        };
    } forEach _regroup;
    -1
};
private _grenade = _job getOrDefault ["projectile", objNull];
if (isNull _grenade || {!(missionNamespace getVariable ["CBE_AIPass_GrenadeEvasion_Enable", true])}) exitWith {-1};
private _grenadePos = getPosATL _grenade;
private _grenadeASL = getPosASL _grenade;
private _checkedGroups = [];
private _checkedResults = [];
private _reacted = 0;
private _regroupActors = [];
private _clearHoldOwned={
    params ["_actor","_actorGroup"];
    private _brain=_actorGroup getVariable ["CBE_BuildingBrain",createHashMap];
    private _clearJob=_brain getOrDefault ["job",createHashMap];
    private _operation=_actorGroup getVariable ["CBE_Operation",createHashMap];
    private _motion=_actor getVariable ["CBE_Cortex_ClearMotion",[]];
    private _context=_clearJob getOrDefault ["visitContext",[]];
    local _actorGroup && {count _clearJob > 0} && {currentCommand _actor == "STOP"}
        && {!(_brain getOrDefault ["cancelled",false])} && {!(_brain getOrDefault ["finished",false])}
        && {(_clearJob getOrDefault ["group",grpNull]) == _actorGroup}
        && {(_clearJob getOrDefault ["ownerEpoch",-1]) == (_actorGroup getVariable ["CBE_AIPass_Epoch",0])}
        && {(_clearJob getOrDefault ["generation",-1]) == (_actorGroup getVariable ["CBE_AIPass_ClearGeneration",-2])}
        && {(_operation getOrDefault ["generation",-2]) == (_clearJob getOrDefault ["operationGeneration",-1])}
        && {(_operation getOrDefault ["intent",""]) == "CLEAR"}
        && {(_operation getOrDefault ["cancelReason",""]) == ""}
        && {serverTime < ((_clearJob getOrDefault ["deadline",-1]) min (_clearJob getOrDefault ["hardDeadline",-1]))}
        && {count _motion == 5} && {count _context == 4}
        && {(_motion select 0) isEqualTo _actorGroup} && {(_motion select 1) isEqualTo _context}
        && {(_motion select 2) == "HOLD"}
        && {[_actor,_clearJob] call CBE_fnc_BuildingActorHoldOwned}
};
{
    private _unit = _x;
    private _group = group _unit;
    private _groupIndex = _checkedGroups find _group;
    if (_groupIndex < 0) then {
        _groupIndex = count _checkedGroups;
        _checkedGroups pushBack _group;
        _checkedResults pushBack ([_group] call CBE_fnc_CortexIsEligible && {[_group,"CBE_AIPass_GrenadeEvasion_Enable",true] call CBE_fnc_CortexFeatureEnabled});
    };
    private _state = _group getVariable ["CBE_AIPass_State",createHashMap];
    private _drillUnits = (_state getOrDefault ["drill", createHashMap]) getOrDefault ["units", []];
    private _supportHeld = _state getOrDefault ["supportHeld",[]];
    private _ownedClearHold=currentCommand _unit == "STOP" && {[_unit,_group] call _clearHoldOwned};
    private _supportPathOwned=_unit in _supportHeld
        && {(_unit getVariable ["CBE_Cortex_SupportPathHold",false]) isEqualTo true};
    if (local _unit && {!isPlayer _unit} && {isNull remoteControlled _unit}
        && {[_unit] call CBE_fnc_CortexCombatEffective} && {vehicle _unit == _unit}
        && {simulationEnabled _unit} && {!isObjectHidden _unit} && {!fleeing _unit}
        && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!([_unit] call CBE_fnc_CompatibilityExternalControl)}
        && {([_unit] call CBE_fnc_CortexExternalOwner) == ""}
        && {currentCommand _unit in ["","MOVE","ATTACK","FIRE","SUPPRESS"] || {_ownedClearHold}}
        && {_unit checkAIFeature "MOVE"}
        && {_unit checkAIFeature "PATH" || {_supportPathOwned}}
        && {!(_unit in _drillUnits)} && {!([_unit] call CBE_fnc_CortexActorMoveReserved)}
        && {_checkedResults select _groupIndex} && {!([_group] call CBE_fnc_CortexExternalTakeover)}) then {
        private _sees = _unit distance _grenade < 5 || {([objNull, "VIEW"] checkVisibility [eyePos _unit, _grenadeASL]) > 0.2};
        private _chance = (0.5 + 0.5 * (_unit skill "general")) * (1 - 0.5 * ((getSuppression _unit) max 0 min 1));
        if (_sees && {random 1 < _chance}) then {
            private _origin=getPosATL _unit;
            private _direction = (_grenadePos getDir _unit) + ((_reacted mod 3) - 1) * 35;
            private _reserved=_regroupActors apply {+(_x select 2)};
            private _away=_origin getPos [9,_direction];
            private _covered=([_away,_grenadePos,6,_reserved,_group,"COVER",_unit] call CBE_fnc_CortexFindCover) select 0;
            // FindCover returns its seed when no post qualifies. Check that fallback too,
            // then two nearby away bearings; never order several responders to one post.
            // Only this finite grenade job's issued endpoints are reserved, not world space.
            private _escapeCandidates=[_covered,_away,_origin getPos [9,_direction-35],_origin getPos [9,_direction+35]];
            private _originDangerDistance=_origin distance2D _grenadePos;
            private _free=_escapeCandidates findIf {
                _x distance2D _grenadePos > _originDangerDistance
                    && {private _candidate=_x;_reserved findIf {_x distance2D _candidate < 2} < 0}
            };
            if (_free < 0) then {continue};
            private _spot=+(_escapeCandidates select _free);
            if (_supportPathOwned) then {
                if (!(_unit checkAIFeature "PATH")) then {_unit enableAI "PATH"};
                if (_unit checkAIFeature "PATH") then {_unit setVariable ["CBE_Cortex_SupportPathHold",nil,true]};
            };
            // Native support STOP needs no feature reset. A mission-disabled PATH remains disabled.
            if (!(_unit checkAIFeature "PATH")) then {continue};
            if (_unit in _supportHeld) then {_state set ["supportHeld",_supportHeld-[_unit]]};
            private _nativeRoute=[_group] call CBE_fnc_NativeOrderReceipt;
            private _expires=time+6;
            private _clearMotion=_unit getVariable ["CBE_Cortex_ClearMotion",[]];
            private _beforeEscape=(expectedDestination _unit) param [0,[]];
            // Local proposal only. The clearing executor rechecks every receipt before use.
            private _clearReturn=[];
            if (_ownedClearHold && {!([_unit,_group] call _clearHoldOwned)}) then {continue};
            if (count _clearMotion == 5 && {(_clearMotion select 0) isEqualTo _group}
                && {(_clearMotion select 1) isEqualTo (_group getVariable ["CBE_Cortex_ClearVisitContext",[]])}
                && {((_clearMotion select 2) == "MOVE" && {count _beforeEscape == 3}
                    && {_beforeEscape isEqualTo (_clearMotion select 3)})
                    || {_ownedClearHold && {(_clearMotion select 2) == "HOLD"}}}) then {
                _clearReturn=[+_clearMotion,+_spot,_expires,
                    _group getVariable ["CBE_AIPass_Epoch",0],
                    _group getVariable ["CBE_OperationGeneration",0],clientOwner];
            };
            _unit setVariable ["CBE_Cortex_ClearEvasionReturn",_clearReturn];
            _unit doMove _spot;
            _unit setVariable ["CBE_Cortex_ActorMove",["GRENADE_EVASION",+_spot,_expires]];
            _reacted = _reacted + 1;
            _regroupActors pushBack [_unit,_group,+_spot,+(_group getVariable ["CBE_AIPass_ZeusHold",[]]),
                _expires,_group getVariable ["CBE_OperationGeneration",0],_group getVariable ["CBE_AIPass_Epoch",0],_nativeRoute,clientOwner];
        };
    };
} forEach ((_grenade nearEntities ["CAManBase", 12]) select [0,16]);
if (_reacted > 0) then {
    missionNamespace setVariable ["CBE_AIPass_GrenadeReactions", (missionNamespace getVariable ["CBE_AIPass_GrenadeReactions", 0]) + _reacted];
    [CBE_fnc_CortexGrenadeCheck,createHashMapFromArray [["regroup",_regroupActors]],6] call CBE_fnc_CortexQueueJob;
};
-1
