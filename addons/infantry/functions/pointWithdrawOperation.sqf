/*
 * Author: WaldoTheWarfighter
 * Purpose: Request or cancel finite withdrawal to an explicit ground position using the existing retreat owner.
 * Locality/authority: Current group owner; remote execution only from the authenticated server2 dispatch.
 * Repeat/JIP: Atomic START/CANCEL; one original120s episode and generation, <=4 route retries.
 * Local metadata is not replayed after locality transfer; the public POINT intent is not autonomous resume authority.
 * Arguments: 0 mode STRING START/CANCEL;1 group GROUP grpNull;2 destination ATL ARRAY[].
 * Destination must be35..2000m from the friendly anchor and within -0.5..2.5m ATL ground height.
 * Return: BOOL owner admitted/released, not physical arrival. Result remains separate from admission.
 * Current callers: owner-local scripts and CortexOrderLocal START/RELEASE from native/optional ZEN tasks.
 * Example: ["START",group soldier1,[1200,1800,0]] call CBE_fnc_PointWithdrawOperation;
 */
params [["_mode","START",[""]],["_group",grpNull,[grpNull]],["_goal",[],[[]]]];
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {false};
private _accepted=false;
isNil {
if (isNull _group || {!local _group}) exitWith {};
private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
private _point=_state getOrDefault ["pointWithdrawal",[]];
private _operation=_group getVariable ["CBE_Operation",createHashMap];
if (_mode == "CANCEL") exitWith {
    if (count _point == 7 && {(_point select 2) == (_group getVariable ["CBE_AIPass_Epoch",-1])}
        && {(_point select 3) == (_operation getOrDefault ["generation",-2])}
        && {(_operation getOrDefault ["intent",""]) == "WITHDRAW"}) then {
        private _retired=[_group,_point select 3,"MODULE_RELEASE"] call CBE_fnc_OperationCancel;
        if (_retired && {(_group getVariable ["CBE_AIPass_State",createHashMap]) isEqualTo _state}
            && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}) then {
            [_group,_state,false,false,"MODULE_RELEASE"] call CBE_fnc_CortexRestoreCalm;
            _accepted=true;
        };
    };
};
if (_mode != "START" || {count _goal != 3} || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {[] call CBE_fnc_CortexIsPaused} || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}
    || {count _operation > 0} || {_point isNotEqualTo []}
    || {count (_state getOrDefault ["drill",createHashMap]) > 0}
    || {_state getOrDefault ["responding",false]} || {_state getOrDefault ["assaulting",false]}
    || {count (_group getVariable ["CBE_PatrolTask",createHashMap]) > 0}
    || {count (_group getVariable ["CBE_ClearAreaTask",createHashMap]) > 0}
    || {count (_group getVariable ["CBE_Cortex_GroupMoveIntent",createHashMap]) > 0}) exitWith {};
private _members=units _group;
if (count _members > 64 || {count waypoints _group > 64}
    || {_members findIf {isPlayer _x || {alive _x && {!local _x || {!isNull objectParent _x} || {!isNull attachedTo _x}}}} >= 0}) exitWith {};
if (!([_group,true] call CBE_fnc_GroupBrainStart)) exitWith {};
_state=[_group] call CBE_fnc_CortexGroupState;
if (!((_state getOrDefault ["phase","CALM"]) in ["CALM","CONTACT"])) exitWith {};
private _known=([_group] call CBE_fnc_CortexKnowledge) select 0;
private _fresh=_known select {(_x select 2) >= 0 && {(_x select 2) <= 10}};
private _threat=if (_fresh isEqualTo []) then {[]} else {+((_fresh select 0) select 1)};
_accepted=[_group,_state,[],[+_goal,_threat]] call CBE_fnc_CortexRetreat;
if (_accepted) then {
    _group setVariable ["CBE_PointWithdrawal_Result",[],true];
    _group setVariable ["CBE_PointWithdrawal_Status",["ACTIVE",+_goal,serverTime],true];
    [_group] call CBE_fnc_CortexCheckpoint;
};
};
_accepted
