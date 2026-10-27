/*
 * Author: WaldoTheWarfighter
 * Gives an unarmed civilian one finite, priority-aware escape response away from nearby danger.
 * One local exterior material-cover search first considers a route-screened refuge farther
 * from danger. If none qualifies, one bounded screened indoor search may use a native room point.
 * The original building geometry is retained; inaccessible rooms get no extra retry or success credit.
 * Otherwise three separated escape headings use the bounded terrain selector and a safe-position
 * adjustment is accepted only when its complete route remains passable. This avoids sending a
 * civilian into water, a cliff or an abrupt grade without installing a continuous path controller.
 * Idle roofed/material-screened positions may be retained for gunfire observations; a local
 * five-second observation receipt never renews on duplicate events or grants hold authority.
 * It does not install an FSM, force an animation, reserve a vehicle or continually steer the unit.
 * Player, Zeus, specialist and neutral external-control ownership always takes priority.
 *
 * Locality / Authority: execute where the civilian is local. The reaction marker is public so a
 * locality transfer cannot immediately duplicate the same response.
 * Native tasks and actor reservations refuse new escape work. Native group pace, behaviour
 * and actor posture remain unchanged; this route does not acquire settings ownership.
 * The final write rechecks the observed command, destination and authored route atomically.
 * Repeat/JIP: Eight-field receipts retain the original group. Expired observation can retain
 * exact native MOVE identity so fresh danger may redirect that escape after cooldown; it cannot
 * claim a transferred actor or a replaced destination. No expired job or movement is replayed.
 * Reactions are generation owned and cooldown limited. A stronger danger may replace a
 * weaker active response; duplicate or weaker events cannot churn the route. JIP needs no replay.
 *
 * Arguments:
 * 0: civilian <OBJECT>, default objNull
 * 1: threat <OBJECT or ARRAY position>, default objNull
 * 2: cause <STRING>, default "MANUAL"
 * 3: priority <NUMBER>, default 1
 *
 * Return Value:
 * Boolean - true when a real flee order was issued.
 *
 * Indoor destinations exclude up to16 current same-group escape destinations; larger rosters
 * keep the exterior/escape policy. No room capacity or route-access guarantee is inferred.
 * Current callers: FiredNear, Suppressed, Explosion and Hit handlers installed by CBE_fnc_CortexCivilianSetup,
 * plus the focused audit endpoint.
 *
 * Example:
 * [_civilian,_shooter] call CBE_fnc_CortexCivilianReact;
 * Result: the civilian moves to a nearby screened refuge or a safe escape point without a polling controller.
 */

params [["_unit",objNull,[objNull]],["_threat",objNull,[objNull,[]]],["_cause","MANUAL",[""]],["_priority",1,[0]]];
if (!finite _priority || {_priority < 0} || {isNull _unit} || {!local _unit} || {!([_unit] call CBE_fnc_CortexCombatEffective)} || {isPlayer _unit}
    || {side group _unit != civilian}
    || {primaryWeapon _unit != "" || {secondaryWeapon _unit != ""} || {handgunWeapon _unit != ""}}
    || {!(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Enable",true])}
    // This reaction is one direct movement order. Yield to the same broad boundary as combat,
    // convoy and aircraft work so an newer external ownership cannot be overwritten between
    // its event observation and this finite escape route.
    || {[group _unit] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _group=group _unit;
if (!local _group || {!simulationEnabled _unit} || {isObjectHidden _unit}
    || {!isNull objectParent _unit} || {!(_unit checkAIFeature "MOVE")} || {!(_unit checkAIFeature "PATH")}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {[_unit] call CBE_fnc_CortexActorMoveReserved}
    || {fleeing _unit}
    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}) exitWith {false};
private _commandBefore=currentCommand _unit;
private _goalBefore=+(expectedDestination _unit);
private _orderBefore=[_group] call CBE_fnc_NativeOrderReceipt;
private _cooldown=missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Cooldown",20];
private _active=_unit getVariable ["CBE_Cortex_CivilianReaction",[]];
if (_active isNotEqualTo [] && {serverTime < (_active param [0,0,[0]])}
    && {_priority <= (_active param [1,0,[0]])}) exitWith {false};
// Ordinary native MOVE is mission ownership unless this exact active escape still owns its goal.
private _ownMove=_commandBefore == "MOVE" && {count _active == 8}
    && {(_active param [6,grpNull,[grpNull]]) == _group}
    && {(_active param [2,-1,[0]]) == (_unit getVariable ["CBE_Cortex_CivilianGeneration",-2])}
    && {(_active param [5,[],[[]]]) isEqualTo _orderBefore}
    && {private _goal=_goalBefore param [0,[],[[]]];
        count _goal == 3 && {count (_active param [4,[],[[]]]) == 3}
            && {_goal findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {(_active select 4) findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
            && {_goal distance (_active select 4) <= 6}};
if (!(_commandBefore in ["","WAIT","FOLLOW"]) && {!_ownMove}) exitWith {false};
private _threatPos=if (_threat isEqualType objNull) then {
    if (isNull _threat) then {getPosATL _unit vectorAdd [sin (random 360),cos (random 360),0]} else {getPosATL _threat}
} else {+_threat};
if (count _threatPos != 3 || {_threatPos findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {false};
private _origin=getPosATL _unit;
private _away=_origin vectorDiff _threatPos;
_away set [2,0];
if (vectorMagnitude _away < 1) then {_away=[sin (random 360),cos (random 360),0]};
_away=vectorNormalized _away;
private _distance=(missionNamespace getVariable ["CBE_AIPass_CivilianReaction_Distance",180])*(0.75+random 0.5);
private _escapeBearing=_origin getDir (_origin vectorAdd _away);
private _threatObject=if (_threat isEqualType objNull) then {_threat} else {objNull};
private _destination=[];private _shelterBinding=[];
// Prefer a short material-screened exterior refuge over a long exposed escape. The shared
// cover selector considers at most10 objects inside25m, excludes this actor from occupancy/rays,
// and never treats another person as protection. A refuge must also gain distance from danger.
private _shelter=[_origin,false];
// Failed escape plans have no active reaction cooldown. Bound this additional search under
// repeated gunfire too; this local admission timestamp grants no movement or retry authority.
private _searchShelter=serverTime >= (_unit getVariable ["CBE_Cortex_CivilianShelterSearchAfter",0]);
// Gunfire alone need not eject an idle civilian from existing roofed material cover.
// This is short-lived observation deduplication, not a hold command or task reservation.
// Injury, explosions and an active native MOVE always retain the escape policy.
private _stayEligible=toUpperANSI _cause in ["FIRED_NEAR","SUPPRESSED"] && {_priority <= 2}
    && {_commandBefore in ["","WAIT","FOLLOW"]} && {unitReady _unit} && {abs speed _unit <= 0.5}
    && {[_group,"CBE_AIPass_BuildingCombat_Enable",true] call CBE_fnc_CortexFeatureEnabled};
private _coverObservation=_unit getVariable ["CBE_Cortex_CivilianCoverObservation",[]];
if (_stayEligible && {_coverObservation isEqualType []} && {count _coverObservation == 8}
    && {(_coverObservation select 0) isEqualTo clientOwner}
    && {(_coverObservation select 1) isEqualType 0} && {finite (_coverObservation select 1)}
    && {serverTime < (_coverObservation select 1)} && {(_coverObservation select 1) <= serverTime+5}
    && {(_coverObservation select 2) isEqualTo _group}
    && {(_coverObservation select 3) isEqualType []} && {count (_coverObservation select 3) == 3}
    && {(_coverObservation select 4) isEqualType []} && {count (_coverObservation select 4) == 3}
    && {[3,4] findIf {(_coverObservation select _x) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0} < 0}
    && {(getPosASL _unit) vectorDistance (_coverObservation select 3) <= 0.5}
    && {_threatPos vectorDistance (_coverObservation select 4) <= 0.5}
    && {(_coverObservation select 5) isEqualType objNull} && {!isNull (_coverObservation select 5)}
    && {alive (_coverObservation select 5)} && {!isObjectHidden (_coverObservation select 5)}
    && {(_coverObservation select 6) isEqualTo [getPosWorld (_coverObservation select 5),vectorDir (_coverObservation select 5),vectorUp (_coverObservation select 5),getObjectScale (_coverObservation select 5)]}
    && {(_coverObservation select 7) isEqualTo damage (_coverObservation select 5)}) exitWith {false};
private _keepShelter=false;
if (_searchShelter) then {
    _unit setVariable ["CBE_Cortex_CivilianShelterSearchAfter",serverTime+5];
    if (_stayEligible) then {
        private _eye=eyePos _unit;
        private _roof=lineIntersectsSurfaces [_eye,_eye vectorAdd [0,0,8],_unit,objNull,true,1,"GEOM","NONE"];
        if (_roof isNotEqualTo []) then {
            private _hit=_roof select 0;
            private _house=if (!isNull (_hit select 3)) then {_hit select 3} else {_hit select 2};
            if (!isNull _house && {_house isKindOf "House"} && {alive _house} && {!isObjectHidden _house}
                && {[(AGLToASL _threatPos) vectorAdd [0,0,1.6],_eye,_unit,"COVER",_threatObject] call CBE_fnc_CortexCoverScreened}) then {
                _keepShelter=true;
                _unit setVariable ["CBE_Cortex_CivilianCoverObservation",[clientOwner,serverTime+5,_group,getPosASL _unit,+_threatPos,
                    _house,[getPosWorld _house,vectorDir _house,vectorUp _house,getObjectScale _house],damage _house]];
            };
        };
    };
    if (!_keepShelter) then {_shelter=[_origin,_threatPos,25,[],_group,"COVER",_unit] call CBE_fnc_CortexFindCover};
};
// Return at function scope. An exit inside the search block would still issue escape below.
if (_keepShelter) exitWith {false};
if (_shelter select 1 && {(_shelter select 0) distance2D _threatPos > (_origin distance2D _threatPos)+2}) then {
    private _shelterRoute=[_origin,[[+(_shelter select 0)]],_threatPos,[],_threatObject,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
    if (_shelterRoute isNotEqualTo []) then {_destination=+(_shelterRoute select 0)};
};
// Reuse the existing roofed-node selector; native pathfinding, not a straight exterior
// terrain segment, owns doorway/stair access. Selection is not physical entry proof.
if (_searchShelter && {_destination isEqualTo []} && {count units _group <= 16}) then {
    private _reserved=[];
    {
        if (_x != _unit) then {
            private _other=_x getVariable ["CBE_Cortex_CivilianReaction",[]];
            if (_other isEqualType [] && {count _other == 8}
                && {(_other param [0,-1,[0]]) > serverTime}
                && {(_other param [6,grpNull,[grpNull]]) == _group}
                && {(_other param [2,-1,[0]]) == (_x getVariable ["CBE_Cortex_CivilianGeneration",-2])}) then {
                _reserved pushBack (_other param [4,[],[[]]]);
            };
        };
    } forEach units _group;
    private _indoor=[_unit,_origin,_threatPos,true,_reserved] call CBE_fnc_DangerRefugeSelect;
    if (count _indoor == 3) then {
        _destination=+(_indoor select 0);
        _shelterBinding=[_indoor select 1,_indoor select 2];
    };
};
private _shelterCurrent={
    _shelterBinding isEqualTo [] || {
        private _house=_shelterBinding select 0;
        !isNull _house && {alive _house} && {!isObjectHidden _house}
            && {(_shelterBinding select 1) isEqualTo [getPosWorld _house,vectorDir _house,vectorUp _house,getObjectScale _house]}
    }
};
// Never apply the broad safe-position adjustment to a screened refuge: it could move the
// destination out from behind the protecting object. Refusal uses the original escape policy.
if (_destination isEqualTo []) then {
    private _routes=[];
    {_routes pushBack [[_origin getPos [_distance,_escapeBearing+_x]]]} forEach [0,-45,45];
    private _route=[_origin,_routes,_threatPos,[],_threatObject,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
    if (_route isNotEqualTo []) then {
        private _routeDestination=+(_route select 0);
        private _safeDestination=[_routeDestination,0,35,3,0,0.35,0,[],[_routeDestination,_routeDestination]] call BIS_fnc_findSafePos;
        private _safeRoute=[_origin,[[_safeDestination]],_threatPos,[],_threatObject,"INFANTRY"] call CBE_fnc_CortexSelectAvenue;
        _destination=if (_safeRoute isEqualTo []) then {_routeDestination} else {+(_safeRoute select 0)};
    };
};
if (_destination isEqualTo []) exitWith {false};
private _issued=false;
isNil {
if (!local _unit || {!local _group} || {group _unit != _group}
    || {!simulationEnabled _unit} || {isObjectHidden _unit} || {!isNull objectParent _unit}
    || {!([_unit] call CBE_fnc_CortexCombatEffective)}
    || {!(_unit checkAIFeature "MOVE")} || {!(_unit checkAIFeature "PATH")}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {[_unit] call CBE_fnc_CortexActorMoveReserved}
    || {fleeing _unit}
    || {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {(_unit getVariable ["CBE_Cortex_CivilianReaction",[]]) isNotEqualTo _active}
    || {currentCommand _unit != _commandBefore} || {(expectedDestination _unit) isNotEqualTo _goalBefore}
    || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _orderBefore}
    || {[_group] call CBE_fnc_CortexExternalTakeover} || {!(call _shelterCurrent)}) exitWith {};
private _generation=(_unit getVariable ["CBE_Cortex_CivilianGeneration",0])+1;
private _until=serverTime+(_cooldown max 2);
// Stronger danger replaces only its own route. Native behaviour, group pace,
// posture and skill settings remain mission-owned throughout the escape.
_unit setVariable ["CBE_Cortex_CivilianGeneration",_generation,true];
_unit setVariable ["CBE_Cortex_CivilianReactionUntil",_until,true];
_unit setVariable ["CBE_Cortex_CivilianReaction",[_until,_priority,_generation,toUpperANSI _cause,_destination,+_orderBefore,_group,_shelterBinding],true];
// Publish the original retry allowance before movement and observation admission.
_unit setVariable ["CBE_Cortex_CivilianRetrySpent",[_generation,_until,_group,false],true];
_unit doMove _destination;
[_unit] call CBE_fnc_CortexCivilianAdopt;
_issued=true;
};
_issued
