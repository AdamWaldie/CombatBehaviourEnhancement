/*
 * Author: WaldoTheWarfighter
 * Lets an approaching soldier on an explicit building order open a recognised unlocked door.
 * Locality/authority: called only on the soldier owner; direct non-server network invocation
 * is refused. Local calls and server-dispatched owner work retain their normal actor/order gates.
 * BIS door animation has global effect; lock/order/cooldown and fresh visibility geometry
 * commit atomically. Visibility rays are limited to four; normal scheduler calls run unscheduled.
 * Repeat/JIP: two-second building cooldown bounds requests; engine door state persists for JIP.
 * Door model metadata is cached per building on each owner; locks are always read live.
 * At most four nearby-door geometry rays check interaction visibility per call. A closed door
 * may occlude its own final 0.5 m, but an earlier wall/other object cannot justify remote opening.
 * The owner-local per-building cursor rotates after tested doors so the query budget cannot
 * permanently starve later entries. It is an observation hint, not replayable task authority.
 * Only combat-effective ordinary actors may request an opening; capture and specialist ownership
 * are rechecked independently of the group order. Indoor requests also recheck contact identity,
 * feature gates and group task priority immediately before the global animation side effect.
 * CLEAR/GARRISON requests bind the live building/transform, participant assignment and owned
 * movement receipt; generation alone cannot authorize another building or a newer native task.
 * Arguments: 0 unit <OBJECT>, default objNull; 1 building <OBJECT>, default objNull;
 * 2 context <ARRAY, []> - [CLEAR/GARRISON/INDOOR, generation] or [ROUTE, owner epoch, group].
 * ROUTE assists a current plain authored MOVE only, with the door within0.8m of its forward
 * native-goal line. It never redirects movement, unlocks doors or admits a scripted/wait waypoint.
 * 3 metadata only <BOOL, false> - cache model definitions without interaction or cooldown.
 * Metadata discovery is read-only world observation and does not require an available actor.
 * STOP, pending medical care, disabled movement, hidden actors and disabled simulation veto
 * opening requests. Care is read before interaction queries and again before animation.
 * Empty-context direct calls require an unreserved idle/MOVE actor; owned INDOOR combat
 * retains its separate exact contact/task receipt rather than borrowing this exemption.
 * Return: BOOL, an opening request was issued (not proof of entry).
 * Current callers: CortexClearBuilding, CortexGarrisonApplyLocal, IndoorActorOperation
 * and CortexRouteDoors through existing group-owner work.
 * Example: [_soldier,_house] call CBE_fnc_CortexBuildingDoor;
 */
params [["_unit",objNull,[objNull]],["_building",objNull,[objNull]],["_context",[],[[]]],["_metadataOnly",false,[true]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _building) exitWith {false};
// Model metadata is stable for this object's lifetime. Locks and animation phases are not.
private _doors=_building getVariable ["CBE_Cortex_DoorDefinitions",[]];
if (isNil {_building getVariable "CBE_Cortex_DoorDefinitions"}) then {
    private _config=configOf _building;
    private _count=(getNumber (_config >> "numberOfDoors")) min 64;
    for "_index" from 1 to _count do {
        private _source=format ["Door_%1_sound_source",_index];
        if (isClass (_config >> "AnimationSources" >> _source)) then {
            private _memory=_building selectionPosition [format ["Door_%1_trigger",_index],"Memory"];
            if (_memory isNotEqualTo [0,0,0]) then {_doors pushBack [_index,_source,_memory]};
        };
    };
    _building setVariable ["CBE_Cortex_DoorDefinitions",_doors];
};
// Discovery never opens a door or consumes the interaction cooldown.
if (_metadataOnly) exitWith {false};
private _vectorValid={
    _this isEqualType [] && {count _this == 3}
        && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
};
private _orderCurrent={
    // A direct script request has no owned-operation receipt. It may assist an
    // ordinary approach, never borrow an unrelated reserved/native service task.
    if (_context isEqualTo []) exitWith {
        !([_unit] call CBE_fnc_CortexActorMoveReserved)
            && {currentCommand _unit in ["","MOVE"]}
    };
    if ((_context param [0,"",[""]]) == "ROUTE") exitWith {
        private _routeGroup=group _unit;
        if (count _context != 3 || {!((_context select 1) isEqualType 0)}
            || {!finite (_context select 1)} || {(_context select 2) isNotEqualTo _routeGroup}
            || {!local _routeGroup} || {(_context select 1) != (_routeGroup getVariable ["CBE_AIPass_Epoch",0])}
            || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
            || {!([_routeGroup,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
            || {behaviour _unit in ["STEALTH","CARELESS"]} || {currentCommand _unit != "MOVE"}
            || {!isNull getAttackTarget _unit} || {!isNull assignedTarget _unit}
            || {!([_unit] call CBE_fnc_IndoorActorGroupAvailable)}
            || {[_unit] call CBE_fnc_CortexActorMoveReserved}) exitWith {false};
        private _routeIndex=currentWaypoint _routeGroup;
        if (_routeIndex <= 0 || {_routeIndex >= count waypoints _routeGroup}) exitWith {false};
        private _routeWaypoint=[_routeGroup,_routeIndex];private _routeStatements=waypointStatements _routeWaypoint;
        private _routeCondition=toLowerANSI ((_routeStatements param [0,"true"]) splitString (toString [32,9,13,10]) joinString "");
        private _routeTarget=(expectedDestination _unit) param [0,[],[[]]];
        waypointType _routeWaypoint == "MOVE" && {_routeCondition == "true"}
            && {((_routeStatements param [1,""]) splitString (toString [32,9,13,10])) isEqualTo []}
            && {waypointScript _routeWaypoint == ""} && {(waypointTimeout _routeWaypoint param [2,0]) <= 0}
            && {isNull waypointAttachedVehicle _routeWaypoint} && {isNull waypointAttachedObject _routeWaypoint}
            && {synchronizedWaypoints _routeWaypoint isEqualTo []} && {synchronizedTriggers _routeWaypoint isEqualTo []}
            && {_routeTarget call _vectorValid} && {_routeTarget vectorDistance waypointPosition _routeWaypoint <= 3}
    };
    if (count _context != 2 || {!((_context select 0) isEqualType "")} || {!((_context select 1) isEqualType 0)}) exitWith {false};
    private _group=group _unit;
    if ((_context select 0) == "INDOOR") exitWith {
        private _brain=_unit getVariable ["CBE_IndoorActor_Brain",createHashMap];
        private _destination=(expectedDestination _unit) param [0,[],[[]]];
        private _target=_brain getOrDefault ["target",[]];
        private _contact=_brain getOrDefault ["contact",objNull];
        private _engaging=getAttackTarget _unit;
        private _assigned=assignedTarget _unit;
        if ((_brain getOrDefault ["contactRequired",false] && {isNull _contact})
            || {!isNull _contact && {!alive _contact || {captive _contact}
                || {_contact getVariable ["ace_captives_isSurrendering",false]}
                || {_contact getVariable ["ace_captives_isHandcuffed",false]}
                || {(side _group) getFriend (side _contact) >= 0.6}
                || {(_unit targetKnowledge _contact) param [7,false,[true]]}}}
            || {!isNull _engaging && {_engaging != _contact}}
            || {!isNull _assigned && {_assigned != _contact}}) exitWith {false};
        private _combatCommand=currentCommand _unit in ["ATTACK","FIRE"] && {!isNull _contact}
            && {getAttackTarget _unit == _contact}
            && {isNull assignedTarget _unit || {assignedTarget _unit == _contact}};
        local _group && {(_brain getOrDefault ["generation",-1]) == (_context select 1)}
            && {!(_brain getOrDefault ["finished",true])} && {(_brain getOrDefault ["phase",""]) == "APPROACH"}
            && {(_brain getOrDefault ["building",objNull]) == _building}
            && {(_brain getOrDefault ["group",grpNull]) == _group}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_brain getOrDefault ["operationGeneration",-1]) == (_group getVariable ["CBE_OperationGeneration",0])}
            && {[_unit] call CBE_fnc_IndoorActorGroupAvailable}
            && {serverTime < (_brain getOrDefault ["deadline",0])}
            && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
            && {[_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled}
            && {[_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled}
            && {(_group getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []}
            && {(_group getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
            && {!(_group getVariable ["CBE_AIPass_ClearBuilding",false])}
            && {getSuppression _unit < 0.5} && {combatMode _group in ["YELLOW","RED","WHITE"]}
            && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
            && {currentCommand _unit in ["","MOVE"] || {_combatCommand}}
            && {_destination call _vectorValid} && {_target call _vectorValid}
            && {_destination vectorDistance _target <= 0.25}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_brain getOrDefault ["route",[]])}
            && {[getPosWorld _building,vectorDir _building,vectorUp _building] isEqualTo (_brain getOrDefault ["transform",[]])}
            && {(_unit getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo (_brain getOrDefault ["lease",[]])}
    };
    private _key=switch (_context select 0) do {
        case "CLEAR": {"CBE_AIPass_ClearGeneration"};
        case "GARRISON": {"CBE_AIPass_GarrisonGeneration"};
        default {""};
    };
    if (!local _group || {_key == ""} || {(_group getVariable [_key,-1]) != (_context select 1)}
        || {[_unit] call CBE_fnc_CortexActorMoveReserved}
        || {!(currentCommand _unit in ["","MOVE"])}) exitWith {false};
    if ((_context select 0) == "CLEAR") exitWith {
        private _brain=_group getVariable ["CBE_BuildingBrain",createHashMap];
        private _job=_brain getOrDefault ["job",createHashMap];
        private _issued=(_job getOrDefault ["movementTargets",createHashMap]) getOrDefault [netId _unit,[]];
        private _live=(expectedDestination _unit) param [0,[],[[]]];
        (_group getVariable ["CBE_AIPass_ClearBuilding",false])
            && {!(_brain getOrDefault ["cancelled",true])} && {!(_brain getOrDefault ["finished",true])}
            && {(_brain getOrDefault ["ownerEpoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_job getOrDefault ["generation",-1]) == (_context select 1)}
            && {(_job getOrDefault ["building",objNull]) == _building}
            && {_unit in ((_job getOrDefault ["team",[]])+(_job getOrDefault ["securityActors",[]]))}
            && {(_job getOrDefault ["buildingTransform",[]]) isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_job getOrDefault ["nativeOrderReceipt",[]])}
            && {currentCommand _unit == "" || {_issued call _vectorValid && {_live call _vectorValid}
                && {_live vectorDistance _issued <= 0.25}}}
    };
    private _assignment=_unit getVariable ["CBE_AIPass_GarrisonPos",[]];
    private _receipt=_unit getVariable ["CBE_Cortex_GarrisonMove",[]];
    private _live=(expectedDestination _unit) param [0,[],[[]]];
    (_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []
        && {_assignment isEqualType []} && {count _assignment >= 4}
        && {(_assignment select 2) == _building}
        && {(_assignment select 3) isEqualTo [getPosWorld _building,vectorDir _building,vectorUp _building]}
        && {_receipt isEqualType []} && {count _receipt == 5}
        && {(_receipt select 4) isEqualTo _assignment}
        && {(_receipt select 0) == _group} && {(_receipt select 1) == (_context select 1)}
        && {(_receipt select 2) == (_group getVariable ["CBE_AIPass_Epoch",0])}
        && {(_receipt select 3) call _vectorValid} && {_live call _vectorValid}
        && {currentCommand _unit == "" || {_live vectorDistance (_receipt select 3) <= 0.25}}
};
if (isNull _unit || {isNull _building} || {!local _unit} || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {isPlayer _unit} || {[group _unit,false,_unit] call CBE_fnc_CortexExternalTakeover}
    || {vehicle _unit != _unit} || {!alive _building}
    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {!([group _unit] call CBE_fnc_CortexIsEligible)}) exitWith {false};
if !(call _orderCurrent) exitWith {false};
if (serverTime < (_building getVariable ["CBE_Cortex_DoorRequestUntil",-1])) exitWith {false};
if (_doors isEqualTo []) exitWith {false};
private _doorCount=count _doors;
private _cursor=_building getVariable ["CBE_Cortex_DoorVisibilityCursor",0];
if (!(_cursor isEqualType 0) || {!finite _cursor}) then {_cursor=0};
_cursor=((floor _cursor) max 0) mod _doorCount;
// Ordinary route assistance requires this doorway on the current native approach,
// not just a nearby unlocked door. Re-read at mutation so a newer goal can veto it.
private _routeDoorRelevant={
    params ["_cbeDoorWorld"];
    if ((_context param [0,"",[""]]) != "ROUTE") exitWith {true};
    private _cbeDoorTarget=(expectedDestination _unit) param [0,[],[[]]];
    if (!(_cbeDoorTarget call _vectorValid)) exitWith {false};
    private _cbeDoorOrigin=getPosASL _unit;
    private _cbeDoorLeg=(AGLToASL _cbeDoorTarget) vectorDiff _cbeDoorOrigin;_cbeDoorLeg set [2,0];
    private _cbeDoorLength=vectorMagnitude _cbeDoorLeg;
    if (_cbeDoorLength < 0.1) exitWith {false};
    private _cbeDoorAxis=_cbeDoorLeg vectorMultiply (1/_cbeDoorLength);
    private _cbeDoorOffset=_cbeDoorWorld vectorDiff _cbeDoorOrigin;_cbeDoorOffset set [2,0];
    private _cbeDoorAlong=_cbeDoorOffset vectorDotProduct _cbeDoorAxis;
    _cbeDoorAlong >= 0 && {_cbeDoorAlong <= _cbeDoorLength}
        && {vectorMagnitude (_cbeDoorOffset vectorDiff (_cbeDoorAxis vectorMultiply _cbeDoorAlong)) <= 0.8}
};
private _nextCursor=_cursor;
private _scanDoors=(_doors select [_cursor])+(_doors select [0,_cursor]);
private _requested=false;
private _visibilityChecks=0;
{
    _x params ["_index","_source","_memory"];
    private _lock=_building getVariable [format ["bis_disabled_Door_%1",_index],0];
    // Unknown door/lock conventions are left to their mod rather than guessed or unlocked.
    if (_lock isEqualTo 0 && {(_building getVariable ["bis_disabled_Door",0]) isEqualTo 0}
        && {_building animationSourcePhase _source < 0.1}) then {
        private _position=_building modelToWorldWorld _memory;
        // Open only within interaction approach distance and on the actor's floor.
        // A nearby ground-floor actor must not open upper-storey doors remotely.
        private _near=([_position] call _routeDoorRelevant)
            && {(getPosASL _unit) vectorDistance _position <= 3}
            && {abs (((getPosASL _unit) select 2)-(_position select 2)) <= 1.5};
        private _visible=false;
        private _visibilityProof=[];
        if (_near && {_visibilityChecks < 4}) then {
            _visibilityChecks=_visibilityChecks+1;
            _nextCursor=(_cursor+_forEachIndex+1) mod _doorCount;
            _visibilityProof=[getPosWorld _building,vectorDir _building,vectorUp _building,eyePos _unit,time];
            private _hits=lineIntersectsSurfaces [eyePos _unit,_position,_unit,objNull,true,1,"GEOM","NONE"];
            _visible=_hits isEqualTo [];
            if (!_visible) then {
                private _hit=_hits select 0;
                // The closed leaf can hide its own trigger. Do not accept an intervening
                // wall just because it belongs to this same building.
                _visible=((_hit select 2) == _building || {(_hit select 3) == _building})
                    && {(_hit select 0) vectorDistance _position <= 0.5};
            };
        };
        if (_near && {_visible}) then {
        isNil {
        if (_near && {_visible}
            && {count _visibilityProof == 5} && {time >= (_visibilityProof select 4)}
            && {time-(_visibilityProof select 4) <= 0.5}
            && {[getPosWorld _building,vectorDir _building,vectorUp _building] isEqualTo (_visibilityProof select [0,3])}
            && {(eyePos _unit) vectorDistance (_visibilityProof select 3) <= 0.5}
            && {alive _building} && {_building animationSourcePhase _source < 0.1}
            && {serverTime >= (_building getVariable ["CBE_Cortex_DoorRequestUntil",-1])}
            && {(_building getVariable ["bis_disabled_Door",0]) isEqualTo 0}
            && {(_building getVariable [format ["bis_disabled_Door_%1",_index],0]) isEqualTo 0}
            && {call _orderCurrent} && {[_position] call _routeDoorRelevant}
            && {[_unit] call CBE_fnc_CortexCombatEffective}
            && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
            && {!isPlayer _unit} && {isNull remoteControlled _unit}
            && {local _unit} && {isNull objectParent _unit} && {simulationEnabled _unit}
            && {!isObjectHidden _unit} && {_unit checkAIFeature "MOVE"} && {_unit checkAIFeature "PATH"}
            && {currentCommand _unit != "STOP"}
            && {(getPosASL _unit) vectorDistance _position <= 3}
            && {abs (((getPosASL _unit) select 2)-(_position select 2)) <= 1.5}
            && {!([group _unit,false,_unit] call CBE_fnc_CortexExternalTakeover)}) then {
            _building setVariable ["CBE_Cortex_DoorRequestUntil",serverTime+2,true];
            [_building,_index,1] call BIS_fnc_door;
            _requested=true;
        };
        };
        };
    };
    if (_requested || {_visibilityChecks >= 4}) exitWith {};
} forEach _scanDoors;
_building setVariable ["CBE_Cortex_DoorVisibilityCursor",_nextCursor];
_requested
