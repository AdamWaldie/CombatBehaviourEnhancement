/*
 * Author: WaldoTheWarfighter
 * Native initialization data waits and delayed search retain planner ownership.
 * Weak-posture ownership is recorded only after native confirmation. Group-hide proof survives
 * a refused/unconfirmed actor handoff and retires only after its original baseline is carried or restored.
 * Native fleeing which begins after FSM classification vetoes non-forced action mutation.
 * Purpose: Apply one bounded, low-priority danger stance without taking movement, target or firing ownership or arresting a committed operation.
 * Locality / Authority: Runs only for the local AI soldier after ownership and order classification.
 * Repeat/JIP: Uses one machine-local, expiring weak-stance lease. A repeated danger response retains
 * the original authored stance and refreshes only CBE's applied value. Native or external stance
 * changes invalidate the lease and are not overwritten. A committed mover is never forced prone.
 * Native MOVE, actual actor motion and INIT/PLANNING/REPLAN retain mobile posture as scripted movers do.
 * This includes engine ATTACK travel, whose command label does not identify an idle rifleman.
 * Extreme native suppression lowers idle engaging riflemen prone without pinning committed movers.
 * Idle riflemen may perform one native lateral evasion after a hit or near round.
 * Standing/crouched actors use a short tactical lateral action only when two sampled
 * side segments are unobstructed. This is an obstruction veto, not a swept-body/path guarantee.
 * The existing cooldown also bounds failed lateral probes; committed movement is never dodged.
 * A single eligible overhead ray prevents prone rolls beneath roofs/cover.
 * A per-actor cooldown prevents repeated actions; committed routes and specialist/native tasks yield.
 * Live actor reservations use the shared expiry gate to retain mobile posture across indoor work.
 * The separate finite point executor may admit an identified own-group casualty investigation.
 * Posture itself creates no movement, target or firing lease.
 * Evasion defers during round/magazine reload or unknown weapon state without interrupting it.
 * FORCED may delegate idle on-foot native flight to DangerFlight under this same finite FSM.
 * Arguments: 0: soldier <OBJECT>, objNull; 1: mode <STRING>, ASSESS; 2: selected record <ARRAY>, [].
 * Return Value: Number - short observation deadline in seconds.
 * Current callers: Engine-loaded infantry danger FSM action states.
 * Example: [cursorObject,"IMMEDIATE",[2,getPosATL cursorObject,time + 1,objNull]] call CBE_fnc_DangerEngineAct;
 */

params [["_actor",objNull,[objNull]],["_mode","ASSESS",[""]],["_record",[],[[]]]];
if (isNull _actor || {!local _actor} || {!simulationEnabled _actor} || {isObjectHidden _actor}
    || {!([_actor] call CBE_fnc_CortexCombatEffective)}
    || {isPlayer _actor}) exitWith {0};
private _group=group _actor;
if (isNull _group || {!local _group}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!([_group,"CBE_AIPass_Danger_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_group,false,true,false,_actor] call CBE_fnc_CortexIsEligible)}
    || {[] call CBE_fnc_CortexIsPaused}
    // Classification and action are separate engine FSM states. A mission may replace the
    // behaviour between them; CARELESS never grants a final evasion/glance/posture request.
    || {behaviour _actor == "CARELESS"}) exitWith {0};
// Recheck actor-level authority at the command boundary; group eligibility alone does not
// cover a specialist actor sharing an otherwise ordinary group.
// ACE queues treatment before the native command becomes HEAL; pending care owns this actor.
if ((_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {_mode != "FORCED" && {fleeing _actor}}
    || {_mode != "FORCED" && {currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED","HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"]}}) exitWith {0};
// Eligibility already checked player, curator and external ownership in this unscheduled call.
// Use fixed branch values instead of allocating a lookup map for every actor reaction.
private _baseDelay=switch (_mode) do {
    case "HIDE": {1.25};
    case "VEHICLE";
    case "IMMEDIATE";
    case "ENGAGE": {1};
    default {0.75};
};
// A small local offset prevents an entire squad from changing stance on the same frame while
// retaining a strict upper bound and no recurring work.
private _delay=_baseDelay + random 0.25;
if (_mode == "FORCED") then {
    _delay=_delay max (["START",_actor,_record] call CBE_fnc_DangerFlight);
};
private _suppression=getSuppression _actor;
private _cause=_record param [0,-1,[0]];
private _desiredStance="";
private _operation=_group getVariable ["CBE_Operation",createHashMap];
private _participants=if (count _operation > 0) then {_operation getOrDefault ["participants",[]]} else {[]};
private _unavailable=if (count _operation > 0) then {_operation getOrDefault ["unavailable",[]]} else {[]};
// A live route belongs to the common operation owner. Immediate danger may lower a mover's profile,
// but a repeated explosion or suppression stream must not pin that actor prone and stall the route.
private _committedMover=count _operation > 0
    && {_actor in _participants}
    && {!(_actor in _unavailable)}
    && {(_operation getOrDefault ["route",[]]) isNotEqualTo []}
    && {toUpperANSI (_operation getOrDefault ["phase",""]) in ["APPROACH","ENTRY","SWEEP","REPLAN","EGRESS","MANOEUVRE","ASSAULT","MOVING","TRAVEL","WITHDRAW"]};

// A coordinated parent can remain ACCEPTED while its child executes a bound. Read the
// matching child roster instead of treating its moving actors as idle from the parent phase.
private _tacticalState=_group getVariable ["CBE_AIPass_State",createHashMap];
private _drill=_tacticalState getOrDefault ["drill",createHashMap];
if (count _operation > 0 && {count _drill > 0}
    && {(_drill getOrDefault ["operationGeneration",-1]) == (_operation getOrDefault ["generation",-2])}
    && {(_drill getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
    private _stage=_drill getOrDefault ["stage",""];
    private _moving=if (_stage == "START") then {
        private _teams=_drill getOrDefault ["teams",[]];
        if (_teams isEqualTo []) then {_drill getOrDefault ["units",[]]} else {
            _teams param [_drill getOrDefault ["teamTurn",0],[]]
        }
    } else {if (_stage == "MOVE") then {_drill getOrDefault ["movers",[]]} else {[]}};
    _committedMover=_actor in _moving
        || {(_drill getOrDefault ["recovery",[]]) findIf {(_x select 0) == _actor} >= 0};
};
// Any live actor movement reservation must retain mobility, including individual indoor
// investigation. Reuse the shared typed/expiry gate rather than maintaining a partial intent list.
// Unknown reservation state also cannot grant permission to pin its actor prone.
if ([_actor] call CBE_fnc_CortexActorMoveReserved) then {_committedMover=true;};
// Ordinary native routes deserve the same mobility as scripted manoeuvres. A stationary
// path-planning actor is not idle permission to roll or pin prone before its move begins.
// Native assault travel commonly uses ATTACK, while formation travel uses FOLLOW. Actual
// motion protects either without treating a stationary combatant as a permanent mover.
// Sample speed once for this unscheduled response; the existing 0.5 km/h evasion threshold applies.
private _actorSpeed=abs (speed _actor);
private _nativeRouteTask=currentCommand _actor == "MOVE"
    || {_actorSpeed >= 0.5}
    || {getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY"]};
if (_nativeRouteTask) then {_committedMover=true};
// A native task label does not describe an ongoing weapon reload. Inspect only after
// evasion's eligibility/cooldown gates; unknown or active phases cannot authorise an action.
private _evasionWeaponReady={
    private _evasionWeapon=weaponState _actor;
    count _evasionWeapon >= 7
        && {(_evasionWeapon select 0) isEqualTo currentWeapon _actor}
        && {[5,6] findIf {private _phase=_evasionWeapon select _x;
            !(_phase isEqualType 0) || {!finite _phase} || {_phase != 0}} < 0}
};
private _lateralEvasion=false;
// An idle prone rifleman can react physically without a new destination or a tactical worker.
// Native actions retain engine collision and animation handling. Never roll a committed mover,
// override another native action, or replay this response on every danger recycle.
if (_mode == "IMMEDIATE" && {_cause in [2,9]} && {!_committedMover}
    && {[_group,"CBE_AIPass_DangerEvasion_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {isNull objectParent _actor} && {stance _actor == "PRONE"}
    && {_actorSpeed < 0.5}
    && {currentCommand _actor in ["","ATTACK","FIRE","SUPPRESS"]}
    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {primaryWeapon _actor != ""} && {currentWeapon _actor == primaryWeapon _actor}
    && {time >= (_actor getVariable ["CBE_Danger_EvasionAfter",-1])}
    && {call _evasionWeaponReady}
    // Native roll needs open overhead space. Keep indoor/covered actors on posture only.
    // One short-circuited ray after eligibility/cooldown, never a roster/world scan.
    && {private _evasionEye=eyePos _actor;
        !(lineIntersects [_evasionEye,_evasionEye vectorAdd [0,0,7],_actor])}) then {
    private _point=_record param [1,[],[[]]];
    private _action=selectRandom ["EvasiveLeft","EvasiveRight"];
    if (count _point >= 2 && {_actor distance2D _point >= 3}) then {
        _action=["EvasiveRight","EvasiveLeft"] select (_actor getRelDir _point < 180);
    };
    _actor setVariable ["CBE_Danger_EvasionAfter",time+3];
    _actor playActionNow _action;
    _actor setVariable ["CBE_Danger_LastEvasion",[time,_cause,_action,
        _group getVariable ["CBE_Danger_Generation",-1],getPosATL _actor]];
};
// Retain the source intent of a short upright dodge without copying fast forward/back
// movement or issuing a second destination. A known side obstruction keeps posture only.
if (_mode == "IMMEDIATE" && {_cause in [2,9]} && {!_committedMover}
    && {stance _actor in ["STAND","CROUCH"]} && {_actorSpeed < 0.5}
    && {[_group,"CBE_AIPass_DangerEvasion_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {isNull objectParent _actor} && {currentCommand _actor in ["","ATTACK","FIRE","SUPPRESS"]}
    && {_actor checkAIFeature "MOVE"} && {_actor checkAIFeature "PATH"}
    && {primaryWeapon _actor != ""} && {currentWeapon _actor == primaryWeapon _actor}
    && {time >= (_actor getVariable ["CBE_Danger_EvasionAfter",-1])}
    && {call _evasionWeaponReady}) then {
    // Spend the same cooldown even when the probe refuses; a blocked actor cannot add
    // recurring casts on every danger recycle. No delayed action or new worker is queued.
    _actor setVariable ["CBE_Danger_EvasionAfter",time+3];
    private _point=_record param [1,[],[[]]];
    private _left=random 1 < 0.5;
    if (count _point >= 2 && {_actor distance2D _point >= 3}) then {_left=_actor getRelDir _point < 180};
    private _heading=vectorDir _actor;
    _heading set [2,0];
    if (vectorMagnitude _heading >= 0.1) then {
        _heading=vectorNormalized _heading;
        private _side=[_heading select 1,-(_heading select 0),0];
        _side=_side vectorMultiply ([2,-2] select _left);
        private _low=(getPosASL _actor) vectorAdd [0,0,0.3];
        private _eye=eyePos _actor;
        private _blocked=[_low,_eye] findIf {
            (lineIntersectsSurfaces [_x,_x vectorAdd _side,_actor,objNull,true,1,"GEOM","NONE"]) isNotEqualTo []
        } >= 0;
        if (!_blocked) then {
            private _action=["TactR","TactL"] select _left;
            _actor playActionNow _action;
            _lateralEvasion=true;
            _actor setVariable ["CBE_Danger_LastEvasion",[time,_cause,_action,
                _group getVariable ["CBE_Danger_Generation",-1],getPosATL _actor]];
        };
    };
};
// Body and scream observations deserve a visible finite assessment, not only a stance flag.
// Use the position form only: an object argument would fully disclose that object.
// Preserve committed movement and concrete native tasks; this never reveals an enemy.
if (_mode == "HIDE" && {_cause in [5,6,7]} && {!_committedMover}
    && {[_group,"CBE_AIPass_DangerObservation_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {isNull objectParent _actor} && {currentCommand _actor == ""}) then {
    private _position=_record param [1,[],[[]]];
    if (count _position == 3 && {_position findIf {!(_x isEqualType 0)} < 0}) then {
        _actor glanceAt _position;
    };
};
// A native own-group casualty source or bounded actual-death receipt can identify a body.
// Missing/ambiguous corroboration retains the glance; the point owner revalidates admission.
if (_mode == "HIDE" && {_cause == 5} && {!_committedMover}) then {
    private _body=_record param [3,objNull,[objNull]];
    if (["START",_actor,createHashMapFromArray [["body",_body],
        ["observed",_record param [1,[],[[]]]]]] call CBE_fnc_PointActorOperation) then {_committedMover=true};
};
// Forced orders and vehicle crews already have an engine movement owner. Recording the response is
// useful, but changing their posture would compete with that owner. Foot soldiers receive only a
// short scripted stance. Direct commander stance orders have higher engine priority, while another
// script or controller changing the scripted stance invalidates CBE's exact lease on release.
if (_mode == "IMMEDIATE") then {
    // Visible fire, a direct hit, an explosion and a near round are immediate physical hazards.
    // The group layer may grant one idle actor a bounded cover move; this actor-local reflex also
    // lowers the profile immediately while that scheduled cover selection is pending.
    private _hardCover=(_suppression > 0.55) || {_cause in [1,2,4,9]} || {currentCommand _actor == "STOP"};
    _desiredStance=["MIDDLE","DOWN"] select (_hardCover && {!_committedMover} && {!_lateralEvasion});
};
if (_mode == "HIDE") then {
    // Seeing a casualty or hearing a scream is alerting evidence, not proof of rounds arriving at
    // this actor. Keep a mobile crouch unless native suppression itself justifies going prone.
    _desiredStance=["MIDDLE","DOWN"] select (!_committedMover && {_suppression > 0.45});
};
if (_mode == "ENGAGE") then {
    // An authored stealth/hold-fire element should reduce its silhouette when it detects a real
    // hostile instead of CBE converting awareness into fire or movement authority. This remains a
    // weak, expiring stance and is never applied to a committed mover.
    private _stealthHold=behaviour _actor == "STEALTH"
        && {unitCombatMode _actor in ["BLUE","GREEN"]}
        && {_actorSpeed < 1}
        && {!_committedMover};
    if (_stealthHold) then {
        _desiredStance="DOWN";
    } else {
        // Extreme native suppression warrants a lower idle profile even without a new hit.
        // Retain mobility for an actor committed to a route; weak posture still expires.
        if (_suppression > 0.9 && {!_committedMover}) then {
            _desiredStance="DOWN";
        } else {
            if (_suppression > 0.2 && {stance _actor == "STAND"}) then {
                _desiredStance="MIDDLE";
            };
        };
    };
};

if (_desiredStance != "") then {
    private _currentStance=toUpperANSI (unitPos _actor);
    private _lease=_actor getVariable ["CBE_Danger_EngineStanceLease",[]];
    private _priorStance=_currentStance;
    // A group-hide lease is another CBE posture owner, not an external authored stance.
    // Transfer its original baseline before the actor FSM acquires this soldier; otherwise the
    // actor captures a temporary crouch/prone value and restores that value permanently later.
    private _groupLeases=_group getVariable ["CBE_Danger_GroupHideLeases",[]];
    private _groupTransfer=[];
    private _groupLeaseIndex=_groupLeases findIf {(_x param [0,objNull]) == _actor};
    if (_groupLeaseIndex >= 0) then {
        private _groupLease=_groupLeases select _groupLeaseIndex;
        if (_currentStance == (_groupLease param [2,"",[""]])
            && {count _groupLease == 6} && {(_groupLease select 4) == (_group getVariable ["CBE_OperationGeneration",0])
                && {(_groupLease select 5) == (_group getVariable ["CBE_AIPass_Epoch",0])}}) then {
            _priorStance=_groupLease param [1,_currentStance,[""]];
            if (_priorStance in ["AUTO","UP","MIDDLE","DOWN"]) then {_groupTransfer=+_groupLease};
        };
    };
    private _mayApply=true;
    if (count _lease > 0 && {count _lease != 6}) then {
        _actor setVariable ["CBE_Danger_EngineStanceLease",nil];
        _mayApply=false;
    };
    if (count _lease == 6) then {
        _priorStance=_lease param [0,_currentStance,[""]];
        private _previousApplied=_lease param [1,"",[""]];
        // A different owner changed the stance during our response. Drop CBE's lease and leave it alone.
        if (_currentStance != _previousApplied
            || {count _lease >= 6 && {(_lease select 3) != (_group getVariable ["CBE_OperationGeneration",0])
                || {(_lease select 4) != (_group getVariable ["CBE_AIPass_Epoch",0])}
                || {(_lease select 5) != _group}}}) then {
            _actor setVariable ["CBE_Danger_EngineStanceLease",nil];
            _mayApply=false;
        };
    };
    if (_mayApply) then {
        // Weak stance is deliberate: native combat AI and the active movement owner can override it
        // immediately. CBE records the exact applied value only so cleanup remains generation-safe.
        if (_currentStance != _desiredStance) then {_actor setUnitPosWeak _desiredStance};
        // A lower-priority request is not ownership of the resulting native rule.
        // Keep the old actor/group proof when commander/script priority prevents this request.
        if (toUpperANSI unitPos _actor == _desiredStance) then {
        // Renew proof without reissuing the same engine command. When the authored baseline
        // already equals the desired stance, CBE changed nothing and owns no restoration.
        if (_priorStance != _desiredStance) then {
            _actor setVariable ["CBE_Danger_EngineStanceLease",[_priorStance,_desiredStance,time+_delay,
                _group getVariable ["CBE_OperationGeneration",0],_group getVariable ["CBE_AIPass_Epoch",0],_group]];
        } else {
            _actor setVariable ["CBE_Danger_EngineStanceLease",nil];
        };
        // Publish the incoming original baseline (or confirm it restored) before consuming
        // exact outgoing proof. A different actor receipt cannot borrow this baseline.
        if (_groupTransfer isNotEqualTo [] && {_priorStance == (_groupTransfer select 1)}
            && {(_group getVariable ["CBE_Danger_GroupHideLeases",[]]) isEqualTo _groupLeases}
            && {(_groupLeases param [_groupLeaseIndex,[]]) isEqualTo _groupTransfer}) then {
            _groupLeases deleteAt _groupLeaseIndex;
            _group setVariable ["CBE_Danger_GroupHideLeases",_groupLeases];
        };
        };
    };
};

private _stats=_group getVariable ["CBE_Danger_EngineStats",createHashMap];
private _modes=_stats getOrDefault ["modes",createHashMap];
_modes set [_mode,((_modes getOrDefault [_mode,0])+1) min 100000];
_stats set ["modes",_modes];
_stats set ["lastMode",_mode];
_stats set ["lastActor",_actor];
_stats set ["lastActionAt",time];
if (_mode == "VEHICLE") then {
    // Preserve the domain distinction at the engine boundary. The FSM still owns no movement:
    // group, vehicle, aircraft and support controllers consume the matching bounded handoff.
    _stats set ["lastVehicleProfile",[_actor] call CBE_fnc_DangerVehicleProfile];
};
_group setVariable ["CBE_Danger_EngineStats",_stats];
_actor setVariable ["CBE_Danger_EngineResponse",[_mode,_cause,time,time+_delay,
    _group getVariable ["CBE_OperationGeneration",0],_group getVariable ["CBE_AIPass_Epoch",0],_group]];
["START",_actor] call CBE_fnc_DangerAttackPace;
_delay
