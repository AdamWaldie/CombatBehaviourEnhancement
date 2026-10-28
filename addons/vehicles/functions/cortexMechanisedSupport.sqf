/*
 * Author: WaldoTheWarfighter
 * Purpose: Plan or revalidate one rear support bound for a vehicle's CBE-owned dismounts.
 * Locality/authority: Read-only on the local vehicle/group owner. Only original cargo
 * recorded by the group's current dismount continuation supplies the troop body.
 * The native infantry formation must have an on-foot leader independent of operating crew.
 * Repeat/JIP: No commands, handlers or jobs. Supplied context retains its original contact,
 * troop anchor, dismount receipt and deadline. CHECK never plans another destination.
 * After admission the parent generation retires ordinary dismount continuation; the exact
 * worker may retain its snapshot when that public record is empty. A different live record refuses.
 * Arguments: group GROUP grpNull; platform OBJECT objNull; contact ARRAY [] or
 * [known target OBJECT, believed ATL ARRAY3, original observedAt server NUMBER];
 * context ARRAY [] for PLAN, otherwise original [dismount receipt,contact,body ASL,deadline];
 * goal ARRAY [] for PLAN, otherwise original ATL ARRAY3 for CHECK.
 * Return: ARRAY [] on refusal, otherwise [goal ATL, original deadline, context].
 * Limits: At most16 tracked cargo and32 nearby people, five rear candidates, one bounded
 * avenue selection. Straight hull corridor and one elevated visibility ray per candidate
 * are observations, not proof of the engine's actual planned route or future clearance.
 * Current callers: CortexVehicles (PLAN), VehicleTacticalMoveStart/Step (CHECK).
 * Example: private _plan=[_group,_apc,[_target,_belief,serverTime]] call CBE_fnc_CortexMechanisedSupport;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],
    ["_contact",[],[[]]],["_context",[],[[]]],["_goal",[],[[]]]];
if (isNull _group || {!local _group} || {isNull _vehicle} || {!local _vehicle}
    || {!alive _vehicle} || {!canMove _vehicle} || {!canFire _vehicle}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!(_vehicle isKindOf "Tank" || {_vehicle isKindOf "Wheeled_APC_F"})}
    || {(_group getVariable ["CBE_Cortex_CombinedRole",[]]) isNotEqualTo []}
    || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {[]};
// This optional cooperation is never emergency permission to abandon a held,
// concealed or explicitly tasked group. Native/Zeus replacement guards remain in the worker.
private _nativeIndex=currentWaypoint _group;
if (combatMode _group in ["BLUE","GREEN"] || {behaviour driver _vehicle == "STEALTH"}
    || {(_group getVariable ["CBE_AIPass_Garrison",[]]) isNotEqualTo []}
    || {(_group getVariable ["CBE_AIPass_Defend",[]]) isNotEqualTo []}
    || {_group getVariable ["CBE_AIPass_ClearBuilding",false]}
    || {_nativeIndex < count waypoints _group
        && {waypointType [_group,_nativeIndex] in ["HOLD","SENTRY"]}
        && {waypointDescription [_group,_nativeIndex] != "CBE AI PASS"}}) exitWith {[]};
private _checking=_context isNotEqualTo [];
if (_checking && {count _context != 4 || {count _goal != 3}
    || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}}) exitWith {[]};
private _proof=if (_checking) then {_context select 0} else {
    _group getVariable ["CBE_Cortex_DismountContinuation",[]]
};
if (!(_proof isEqualType []) || {count _proof != 4}
    || {!((_proof select 0) isEqualType 0)} || {!finite (_proof select 0)}
    || {serverTime >= (_proof select 0)} || {(_proof select 0) > serverTime+60}
    || {!((_proof select 1) isEqualType 0)}
    || {!((_proof select 2) isEqualType [])} || {count (_proof select 2) > 16}
    || {!((_proof select 3) isEqualType [])}
    || {private _liveProof=_group getVariable ["CBE_Cortex_DismountContinuation",[]];
        (!_checking || {_liveProof isNotEqualTo []}) && {_proof isNotEqualTo _liveProof}}
    || {(_proof select 3) isNotEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
    || {!_checking && {(_proof select 1) != (_group getVariable ["CBE_OperationGeneration",0])}}) exitWith {[]};
if (_checking) then {_contact=_context select 1};
if (!(_contact isEqualType []) || {count _contact != 3}
    || {!((_contact select 0) isEqualType objNull)} || {isNull (_contact select 0)}
    || {!((_contact select 1) isEqualType [])} || {count (_contact select 1) != 3}
    || {(_contact select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!((_contact select 2) isEqualType 0)} || {!finite (_contact select 2)}
    || {(_contact select 2) > serverTime} || {serverTime-(_contact select 2) > 30}) exitWith {[]};
_contact params ["_target","_belief","_observedAt"];
if (!alive _target || {captive _target} || {(_target isKindOf "Air")}
    || {(side _group) getFriend (side _target) >= 0.6}) exitWith {[]};
private _observers=[gunner _vehicle,effectiveCommander _vehicle,leader _group];
private _observerIndex=_observers findIf {
    !isNull _x && {local _x} && {group _x == _group}
        && {[_x] call CBE_fnc_CortexCombatEffective} && {_x knowsAbout _target > 0}
        && {!((_x targetKnowledge _target) param [7,false,[true]])}
        && {private _nativeBelief=_x getHideFrom _target;
            count _nativeBelief == 3 && {_nativeBelief isNotEqualTo [0,0,0]}
                && {_nativeBelief findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
                && {_nativeBelief distance2D _belief <= 25}}
};
if (_observerIndex < 0) exitWith {[]};
private _until=if (_checking) then {_context select 3} else {
    ((_proof select 0) min (serverTime+30)) min (_observedAt+30)
};
if (!(_until isEqualType 0) || {!finite _until} || {_until <= serverTime}
    || {_until > (_proof select 0)} || {_until > _observedAt+30}
    || {!_checking && {_until < serverTime+5}}) exitWith {[]};
private _operators=[driver _vehicle,effectiveCommander _vehicle,gunner _vehicle];
private _foot=[];
{
    if (_x isEqualType [] && {count _x == 2} && {(_x select 0) isEqualType objNull}
        && {(_x select 1) isEqualType objNull} && {(_x select 1) == _vehicle}) then {
        private _person=_x select 0;
        if (!isNull _person && {local _person} && {group _person == _group}
            && {!(_person in _operators)} && {!isPlayer _person}
            && {isNull objectParent _person} && {simulationEnabled _person} && {!isObjectHidden _person}
            && {[_person] call CBE_fnc_CortexCombatEffective} && {!fleeing _person}
            && {_person checkAIFeature "MOVE"} && {_person checkAIFeature "PATH"}
            && {currentCommand _person != "STOP"}) then {_foot pushBackUnique _person};
    };
} forEach (_proof select 2);
// A shared-group bound must not drag the troop formation behind a moving crew
// leader. Separate passenger groups require their own original-cargo contract later.
if (count _foot < 2 || {!(leader _group in _foot)}
    || {_foot findIf {formLeader _x in _operators} >= 0}) exitWith {[]};
private _xs=[];private _ys=[];private _zs=[];
{private _point=getPosASL _x;_xs pushBack (_point select 0);_ys pushBack (_point select 1);_zs pushBack (_point select 2)} forEach _foot;
_xs sort true;_ys sort true;_zs sort true;
private _middle=floor (count _foot/2);
private _median={
    params ["_values"];
    if ((count _values) mod 2 == 0) then {((_values select (_middle-1))+(_values select _middle))/2} else {_values select _middle}
};
private _centreASL=[[_xs] call _median,[_ys] call _median,[_zs] call _median];
if (_checking && {!((_context select 2) isEqualType []) || {count (_context select 2) != 3}
    || {_centreASL vectorDistance (_context select 2) > 15}}) exitWith {[]};
private _origin=getPosATL _vehicle;
private _centre=ASLToATL _centreASL;
if (_origin distance2D _centre > 100 || {_centre distance2D _belief < 20}) exitWith {[]};
private _rearBearing=_belief getDir _centre;
// Do not shift a platform just to occupy a mathematically preferred point. A useful
// current rear position keeps its native orders; this grants no stationary hold.
private _rearDirection=_belief vectorDiff _centre;_rearDirection set [2,0];_rearDirection=vectorNormalized _rearDirection;
private _currentOffset=_origin vectorDiff _centre;
private _currentRear=(_currentOffset select 0)*(_rearDirection select 0)+(_currentOffset select 1)*(_rearDirection select 1);
if (!_checking && {_origin distance2D _centre >= 20} && {_origin distance2D _centre <= 40}
    && {_currentRear < -10}
    && {!lineIntersects [(getPosASL _vehicle) vectorAdd [0,0,2.5],
        (ATLToASL _belief) vectorAdd [0,0,1.5],_vehicle,_target]}) exitWith {[]};
private _candidates=if (_checking) then {[_goal]} else {
    [0,-30,30,-60,60] apply {_centre getPos [25,_rearBearing+_x]}
};
// Bound both the native query and every projected hull loop. Dense areas refuse this
// optional bound rather than treating a partial friendly set as complete clearance.
private _radius=if (_checking) then {(_origin distance2D _goal)+15} else {(_origin distance2D _centre)+40};
private _people=_vehicle nearEntities ["CAManBase",_radius];
if (count _people > 32) exitWith {[]};
private _friendly=_people select {alive _x && {isNull objectParent _x}
    && {(side _group) getFriend (side group _x) >= 0.6}};
private _safe=[];
{
    private _point=_x;
    private _rearVector=_belief vectorDiff _centre;_rearVector set [2,0];_rearVector=vectorNormalized _rearVector;
    private _offset=_point vectorDiff _centre;
    private _rear=(_offset select 0)*(_rearVector select 0)+(_offset select 1)*(_rearVector select 1);
    private _distance=_origin distance2D _point;
    if (_rear < -10 && {_distance <= 100} && {_checking || {_distance >= 10}}
        && {!surfaceIsWater _point} && {((surfaceNormal _point) select 2) >= 0.65}) then {
        private _along=if (_checking && {_distance < 1}) then {vectorDir _vehicle} else {_origin vectorFromTo _point};_along set [2,0];
        if (vectorMagnitude _along > 0.1) then {
            _along=vectorNormalized _along;
            private _right=[_along select 1,-(_along select 0),0];
            private _frame=getPosWorld _vehicle;
            private _hull=[_vehicle,_frame,_right,_along,[0,0,1]] call CBE_fnc_DrivingHullInterval;
            private _clear=count _hull == 6;
            if (_clear) then {
                _clear=_friendly findIf {
                    private _body=[_x,_frame,_right,_along,[0,0,1]] call CBE_fnc_DrivingHullInterval;
                    count _body != 6 || {(_body select 1) >= (_hull select 0)-1
                        && {(_body select 0) <= (_hull select 1)+1}
                        && {(_body select 5) >= (_hull select 4)-0.3}
                        && {(_body select 4) <= (_hull select 5)+0.3}
                        && {(_body select 3) >= (_hull select 2)}
                        && {(_body select 2) <= _distance+(_hull select 3)}}
                } < 0;
            };
            if (_clear && {!lineIntersects [(ATLToASL _point) vectorAdd [0,0,2.5],
                (ATLToASL _belief) vectorAdd [0,0,1.5],_vehicle,_target]}) then {_safe pushBack [_point]};
        };
    };
} forEach _candidates;
if (_safe isEqualTo []) exitWith {[]};
if (_checking) exitWith {[+_goal,_until,_context]};
private _route=[_origin,_safe,_belief,[],_target,"VEHICLE",_vehicle] call CBE_fnc_CortexSelectAvenue;
if (_route isEqualTo []) exitWith {[]};
private _point=_route select ((count _route)-1);
[+_point,_until,[+_proof,[_target,+_belief,_observedAt],_centreASL,_until]]
