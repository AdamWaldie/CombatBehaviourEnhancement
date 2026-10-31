/*
 * Author: WaldoTheWarfighter
 * Purpose: Request finite covered fire-team advance to an explicit position, without an enemy proxy.
 * Locality/authority: Current group owner; inherited authenticated server2 context permitted.
 * Existing advance/tacticalDrill FSM owns all actual commands, native receipts and cleanup.
 * Repeat/JIP: Atomic admission; one original30..300s deadline/token/epoch/generation. No
 * incoming-owner replay or separate worker. CANCEL releases only this exact point order.
 * Arguments: 0 mode STRING START/CANCEL;1 group GROUP grpNull;2 payload ARRAY[]:
 * START [destinationATL,arrivalRadius10(5..25),duration180(30..300)]. Max2000m from own anchor.
 * Return: BOOL real drill admitted/released; arrival is not enemy neutralisation or room clearance.
 * Current callers: CortexOrderLocal, local scripts. CBA Advance permission remains required;
 * contact delay/Contact enable apply to autonomous contact responses, not this explicit point.
 * Example: ["START",group soldier1,[getPosATL destination1,10,180]] call CBE_fnc_PointAdvanceOperation;
 */
params [["_mode","",[""]],["_group",grpNull,[grpNull]],["_payload",[],[[]]]];
if (isNull _group || {!local _group} || {remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}}) exitWith {false};
private _result=false;
isNil {
_result=call {
private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
private _drill=_state getOrDefault ["drill",createHashMap];
if (toUpperANSI _mode == "CANCEL") exitWith {
    private _task=_drill getOrDefault ["explicitOrder",[]];
    if (count (_drill getOrDefault ["pointObjective",[]]) != 2
        || {!(_task isEqualType [])} || {count _task != 4}
        || {(_task select 1) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
        || {(_task select 2) != (_drill getOrDefault ["operationGeneration",-2])}
        || {(_task select 3) != (_drill getOrDefault ["token",""])}) exitWith {false};
    [_group,_state,"MODULE_RELEASE",_task select 3] call CBE_fnc_CortexFlankEnd
};
if (toUpperANSI _mode != "START") exitWith {false};
_payload params [["_goal",[],[[]]],["_radius",10,[0]],["_duration",180,[0]]];
if (count _goal != 3 || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!finite _radius} || {_radius < 5} || {_radius > 25}
    || {!finite _duration} || {_duration < 30} || {_duration > 300}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {!([_group,"CBE_AIPass_Advance_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {count _drill > 0} || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
    || {count (_group getVariable ["CBE_PatrolTask",createHashMap]) > 0}
    || {count (_group getVariable ["CBE_ClearAreaTask",createHashMap]) > 0}) exitWith {false};
private _members=units _group;
if (count _members > 64 || {_members findIf {isPlayer _x} >= 0}) exitWith {false};
private _living=_members select {alive _x};
private _foot=_living select {local _x && {isNull objectParent _x}};
if (count _foot < 2 || {count _foot != count _living} || {!([_group,true] call CBE_fnc_GroupBrainStart)}) exitWith {false};
_state=[_group] call CBE_fnc_CortexGroupState;
if (!((_state getOrDefault ["phase","CALM"]) in ["CALM","CONTACT"])) exitWith {false};
private _anchor=[_group,_foot] call CBE_fnc_CortexGroupAnchor;
if (isNull _anchor || {_anchor distance2D _goal > 2000}) exitWith {false};
private _enemies=([_group] call CBE_fnc_CortexKnowledge) select 0;
private _fresh=_enemies select {(_x select 2) >= 0 && {(_x select 2) <= 10}};
private _assessment=[_group,_state,_fresh,false,true,true] call CBE_fnc_CortexTacticalAssess;
if ((_assessment getOrDefault ["reason",""]) in ["ARMOUR_OVERMATCH","AIR_OVERMATCH"]) exitWith {false};
private _deadline=time+_duration;
if (!([_group,_state,_enemies,_foot,[+_goal,_radius,_deadline]] call CBE_fnc_CortexAdvanceStart)) exitWith {false};
_drill=_state getOrDefault ["drill",createHashMap];
private _receipt=_drill getOrDefault ["explicitOrder",[]];
if (count _receipt != 4 || {(_receipt select 0) != _deadline}) exitWith {false};
_group setVariable ["CBE_PointAdvance_Result",[],true];
_group setVariable ["CBE_PointAdvance_Status",["ACTIVE",+_goal,_receipt select 3,serverTime],true];
[_group] call CBE_fnc_CortexCheckpoint;
true
};
};
_result
