/*
 * Author: WaldoTheWarfighter
 * Puts the squad's best anti-tank gunner onto a known armoured vehicle, clear of backblast.
 *
 * When a tank or armoured vehicle the squad knows about is within 600 m, the
 * launcher gunner with ammunition, least damage and least suppression is ordered to target and fire on
 * it, unless he is already engaging it. Before firing, the backblast area (4 m behind him) is
 * checked for walls and for friendly soldiers; if it is blocked he first moves to a covered spot
 * nearby under one ten-second actor reservation. A replacement destination cancels that relocation;
 * it is never reissued every tick. An engagement order is held for 15 s. A squad with no anti-tank capability facing armour is handled by
 * morale (CBE_fnc_CortexMorale), which can make it withdraw.
 * Locality and authority: call where the group is local. Actor-local player/remote/external
 * ownership and native service actions refuse selection and are rechecked before writes.
 * FIREWEAPON-disabled actors, queued ACE treatment and native INIT/PLANNING/REPLAN defer
 * selection and new writes. This does not change native permissions or the medical queue.
 * Backblast uses the shared firing-safety allegiance policy: allied sides, civilians and
 * protected captives behind the gunner refuse. The existing6m actor query caps at64 candidates.
 * Native FOLLOW/CBE/STOP or non-route tasks also refuse opportunistic relocation. A MOVE
 * must address the current plain authored waypoint; individual destination replacements refuse.
 *
 * Shared typed movement reservations and current CLEAR/MEDICAL_AID/WITHDRAW participants
 * refuse new targeting and relocation. Unknown leases remain reserved; typed expired leases
 * may be reassessed. Two-team START protects the team selected for the next bound.
 * Review contract: A blocked backblast causes only a relocation request. A later group step must recheck clearance before ordering the shot.
 * Active actor reservations and every member of a tactical drill are not relocated. Explicit
 * holding/clearing orders and disabled PATH/MOVE also prevent relocation; stationary support
 * actors may still engage if their existing position has safe backblast.
 *
 * An opportunistic drill grenade thrower is not retargeted during its two-second action window;
 * the grenade never blocks the squad manoeuvre state.
 * Repeat/JIP: current feature gates and eligibility are rechecked; owner jobs are retired on migration.
 * Arguments:
 * 0: group <GROUP>
 * 1: state <HASHMAP>
 * 2: enemies <ARRAY> - from CBE_fnc_CortexKnowledge
 *
 * Return Value:
 * Boolean - true when an anti-tank order was given
 *
 * Example:
 * [_group, _state, _enemies] call CBE_fnc_CortexAntiArmour;
 * Result: the rifleman with the launcher engages the APC instead of the whole squad firing rifles at it.
 *
 * Current caller: CBE_fnc_CortexGroupTick.
 */

params [["_group", grpNull, [grpNull]], ["_state", createHashMap, [createHashMap]], ["_enemies", [], [[]]]];
if (isNull _group || {!local _group} || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {!([_group,"CBE_AIPass_AntiArmour_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {!(combatMode _group in ["YELLOW","RED"])}) exitWith {false};
private _protectedParticipants=[];
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if ((_operation getOrDefault ["intent",""]) in ["CLEAR","MEDICAL_AID","WITHDRAW"]
    && {(_operation getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}) then {
    _protectedParticipants=_operation getOrDefault ["participants",[]];
};
private _actorAvailable={
    params ["_actor"];
    !isNull _actor && {local _actor} && {group _actor == _group}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {!(_actor in _protectedParticipants)}
        && {!([_actor] call CBE_fnc_CortexActorMoveReserved)}
        && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {_actor checkAIFeature "FIREWEAPON"}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!(getUnitState _actor in ["INIT","PLANNING","REPLAN"])}
        && {([_actor] call CBE_fnc_CortexExternalOwner) == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {!(currentCommand _actor in ["GET IN","GET OUT","ACTION","HEAL","REARM","JOIN","REPAIR","REFUEL","SUPPORT","SCRIPTED",
            "HEAL SOLDIER","PATCH SOLDIER","FIRST AID","HEAL SELF","CARRY SOLDIER","DROP CARRIED","ASSEMBLE","DISASSEMBLE","TAKE BAG","DROP BAG"])}
};
private _now = time;
private _relocation = _state getOrDefault ["antiArmourRelocation",[]];
private _relocationBlocks = false;
if (count _relocation == 3) then {
    _relocation params ["_relocating","_relocationSpot","_relocationUntil"];
    private _stillOurs = alive _relocating && {local _relocating} && {group _relocating == _group}
        && {((expectedDestination _relocating) select 0) distance2D _relocationSpot < 1};
    if (_stillOurs && {_relocating distance2D _relocationSpot > 2} && {_now < _relocationUntil}) then {
        _relocationBlocks = true;
    } else {
        if (!isNull _relocating && {local _relocating}) then {
            private _actorMove=_relocating getVariable ["CBE_Cortex_ActorMove",[]];
            if (_actorMove isEqualType [] && {count _actorMove == 3}
                && {(_actorMove select 0) isEqualType ""} && {(_actorMove select 0) == "ANTI_ARMOUR"}
                && {(_actorMove select 1) isEqualType []} && {count (_actorMove select 1) == 3}
                && {(_actorMove select 1) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {(_actorMove select 2) isEqualType 0} && {finite (_actorMove select 2)}
                && {(_actorMove select 1) distance2D _relocationSpot < 1}
                && {(_actorMove select 2) == _relocationUntil}) then {
                _relocating setVariable ["CBE_Cortex_ActorMove",nil];
            };
        };
        _state deleteAt "antiArmourRelocation";
        if (_now >= _relocationUntil || {!_stillOurs}) then {[_state,"antiArmourMove",10] call CBE_fnc_CortexCooldown};
    };
};
if (_relocationBlocks || {[_state,"antiArmourMove"] call CBE_fnc_CortexCooldown}) exitWith {false};
private _drill = _state getOrDefault ["drill",createHashMap];
private _moving = if ((_drill getOrDefault ["stage",""]) in ["START","MOVE"]) then {
    if ((_drill getOrDefault ["stage",""]) == "START" && {(_drill getOrDefault ["teams",[]]) isNotEqualTo []}) then {
        // Selected movers change before new destinations exist. The prior bound's movers
        // cannot identify the next team during this admission interval.
        (_drill get "teams") param [_drill getOrDefault ["teamTurn",0],[]]
    } else {_drill getOrDefault ["movers",_drill getOrDefault ["units",[]]]}
} else {[]};
// Reserve an opportunistic grenade thrower only for its short action window.
if (time < (_drill getOrDefault ["grenadeActionUntil",-1])) then {
    _moving = +_moving;
    _moving pushBackUnique (_drill getOrDefault ["grenadeThrower",objNull]);
};
private _recovering = (_drill getOrDefault ["recovery",[]]) apply {_x select 0};
private _armourIndex = _enemies findIf {
    private _enemy = vehicle (_x select 0);
    (_enemy isKindOf "Tank" || {_enemy isKindOf "Wheeled_APC_F"}) && {(_x select 3) <= 600} && {(_x select 2) <= 30}
};
if (_armourIndex < 0) exitWith {false};
(_enemies select _armourIndex) params ["_enemyUnit", "_enemyPos"];
private _armour = vehicle _enemyUnit;
private _gunners = (units _group) select {
    ([_x] call _actorAvailable) && {!(_x in _moving)} && {!(_x in _recovering)} && {unitCombatMode _x in ["YELLOW","RED"]} && {isNull objectParent _x} && {"AT" in ([_x] call CBE_fnc_CortexCapabilities)}
};
if (_gunners findIf {assignedTarget _x == _armour && {(_x getVariable ["CBE_AIPass_TargetHold", -1]) > _now}} >= 0) exitWith {false};
private _ranked = [];
// Unavailable suppression (-1) is no evidence of exceptional readiness.
{_ranked pushBack [damage _x + ((getSuppression _x) max 0 min 1), _forEachIndex]} forEach _gunners;
_ranked sort true;
if (_ranked isEqualTo []) exitWith {false};
private _gunner = _gunners select ((_ranked select 0) select 1);

private _eye = eyePos _gunner;
private _behind = _eye vectorAdd ((_eye vectorFromTo (ATLToASL _enemyPos)) vectorMultiply -4);
private _blocked=(lineIntersectsSurfaces [_eye,_behind,_gunner,objNull,true,1]) isNotEqualTo [];
if (!_blocked) then {
    private _rearActors=_gunner nearEntities ["CAManBase",6];
    private _gunnerOrigin=getPosASL _gunner;
    private _threatAxis=(ATLToASL _enemyPos) vectorDiff _gunnerOrigin;
    _blocked=count _rearActors > 64 || {_rearActors findIf {
        private _otherSide=side group _x;
        private _protected=captive _x || {_x getVariable ["ace_captives_isSurrendering",false]}
            || {_x getVariable ["ace_captives_isHandcuffed",false]};
        _x != _gunner && {alive _x}
            && {_protected || {_otherSide == civilian} || {(side _group) getFriend _otherSide >= 0.6}}
            && {((getPosASL _x) vectorDiff _gunnerOrigin) vectorDotProduct _threatAxis < 0}
    } >= 0};
};
// Holding/clearing owns the destination even when the gunner may fire from it.
private _mayRelocate={
    if (!([_gunner] call _actorAvailable)) exitWith {false};
    private _command=currentCommand _gunner;
    if !(_command in ["","MOVE"]) exitWith {false};
    private _index=currentWaypoint _group;
    private _authored=_index > 0 && {_index < count waypoints _group};
    if (!_authored) exitWith {_command == ""};
    private _waypoint=[_group,_index];
    // Intentional conditions/scripts/attachments belong to the mission, not this task.
    if (waypointType _waypoint != "MOVE" || {waypointScript _waypoint != ""}
        || {(waypointStatements _waypoint) isNotEqualTo ["true",""]}
        || {(waypointTimeout _waypoint) findIf {_x != 0} >= 0}
        || {synchronizedWaypoints _waypoint isNotEqualTo []}
        || {synchronizedTriggers _waypoint isNotEqualTo []}
        || {!isNull waypointAttachedObject _waypoint}
        || {!isNull waypointAttachedVehicle _waypoint}) exitWith {false};
    private _destination=(expectedDestination _gunner) param [0,[]];
    _command == "" || {count _destination == 3
        && {_destination vectorDistance waypointPosition _waypoint <= 3}}
};
if (_blocked && {!call _mayRelocate}) exitWith {false};
if (_blocked && {!(_gunner checkAIFeature "PATH") || {!(_gunner checkAIFeature "MOVE")}
    || {_gunner in (_drill getOrDefault ["units",[]])}
    || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}
    || {_group getVariable ["CBE_AIPass_ClearBuilding",false]}}) exitWith {false};
if (_blocked) exitWith {
    private _relocationRoute=[_group] call CBE_fnc_NativeOrderReceipt;
    if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {false};
    if !([_gunner] call _actorAvailable) exitWith {false};
    private _spot = ([(getPosATL _gunner) getPos [6, (_enemyPos getDir _gunner) + selectRandom [-70, 70]], _enemyPos, 8, [], _group,"COVER",_gunner] call CBE_fnc_CortexFindCover) select 0;
    if (!call _mayRelocate || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _relocationRoute}) exitWith {false};
    _gunner doMove _spot;
    _gunner setVariable ["CBE_Cortex_ActorMove",["ANTI_ARMOUR",+_spot,_now+10]];
    _state set ["antiArmourRelocation",[_gunner,+_spot,_now+10]];
    false
};
if ([_group] call CBE_fnc_CortexExternalTakeover) exitWith {false};
if !([_gunner] call _actorAvailable) exitWith {false};
_gunner doTarget _armour;
_gunner doFire _armour;
_gunner setVariable ["CBE_AIPass_TargetHold", _now + 15];
true
