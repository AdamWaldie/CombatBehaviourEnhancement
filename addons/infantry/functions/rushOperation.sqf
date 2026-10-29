/*
 * Author: WaldoTheWarfighter
 * Further arrived approach chunks reuse timestamped native knowledge under the original deadline.
 * Purpose: Request one explicit finite offensive episode through the existing actor-scoped
 * advance/close-assault selector and tacticalDrill FSM. No second pursuit worker is started.
 * Locality/authority: Current group owner, local or inherited authenticated server context;
 * not remotely registered. Native belief/ROE/roles/morale/terrain and current mission gates apply.
 * Repeat/JIP: Active operations refuse another start. Exact tagged token/epoch/generation owns
 * CANCEL. Original deadline is enforced in the existing drill step and is never renewed.
 * Explicit episodes are not serialized for owner-transfer replay; normal cleanup restores state.
 * Arguments: 0 mode STRING START|CANCEL; 1 group GROUP,grpNull;
 * 2 payload ARRAY: START [knowledgeRange=800 (50..2000, capped by CBA engagement range),
 * timeLimit=180 (30..300 seconds)]; CANCEL [].
 * Return: BOOL, actual executor startup or exact tracked task retirement, not combat success.
 * Current callers: CortexOrderLocal and owner-local script API.
 * Example: ["START",_group,[800,180]] call CBE_fnc_RushOperation;
 */
params [["_mode","",[""]],["_group",grpNull,[grpNull]],["_payload",[],[[]]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _group} || {!local _group}) exitWith {false};
private _result=false;
isNil {
_result=call {
private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
private _drill=_state getOrDefault ["drill",createHashMap];
if (toUpperANSI _mode == "CANCEL") exitWith {
    private _task=_drill getOrDefault ["explicitRush",[]];
    if (!(_task isEqualType []) || {count _task != 4} || {(_task select 1) != (_group getVariable ["CBE_AIPass_Epoch",-1])}
        || {(_task select 2) != (_drill getOrDefault ["operationGeneration",-2])}
        || {(_task select 3) != (_drill getOrDefault ["token",""])}) exitWith {false};
    [_group,_state,"MODULE_RELEASE",_task select 3] call CBE_fnc_CortexFlankEnd
};
if (toUpperANSI _mode != "START") exitWith {false};
_payload params [["_range",800,[0]],["_duration",180,[0]]];
if (!finite _range || {_range < 50} || {_range > 2000} || {!finite _duration}
    || {_duration < 30} || {_duration > 300}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
    || {!([_group] call CBE_fnc_CortexIsEligible)}
    || {!([_group,"CBE_AIPass_Contact_Enable",true] call CBE_fnc_CortexFeatureEnabled)}
    || {count _drill > 0} || {(_group getVariable ["CBE_Operation",createHashMap]) isNotEqualTo createHashMap}
    || {(_group getVariable ["CBE_PatrolTask",createHashMap]) isNotEqualTo createHashMap}) exitWith {false};
private _members=units _group;
if (count _members > 64 || {_members findIf {isPlayer _x} >= 0}) exitWith {false};
private _living=_members select {alive _x};
private _foot=_living select {local _x && {isNull objectParent _x}};
if (count _foot < 2 || {count _foot != count _living} || {!([_group,true] call CBE_fnc_GroupBrainStart)}) exitWith {false};
_state=[_group] call CBE_fnc_CortexGroupState;
if (!((_state getOrDefault ["phase","CALM"]) in ["CALM","CONTACT"])) exitWith {false};
private _deadline=time+_duration;
_range=_range min (missionNamespace getVariable ["CBE_AIPass_EngageRange",800]);
private _knowledgeAt=time;
private _enemies=([_group,_range] call CBE_fnc_CortexKnowledge) select 0;
private _advance=[_group,"CBE_AIPass_Advance_Enable",true] call CBE_fnc_CortexFeatureEnabled;
private _assault=[_group,"CBE_AIPass_Assault_Enable",true] call CBE_fnc_CortexFeatureEnabled;
if ((_state getOrDefault ["phase","CALM"]) != "CONTACT"
    && {(missionNamespace getVariable ["CBE_AIPass_Advance_MinContactSeconds",0]) > 0}) then {_advance=false};
// Preserve the full native threat set: known uncountered armour must not disappear
// merely because the operator requested an offensive foot manoeuvre.
if (!([_group,_state,_enemies,false,_advance,_assault,_foot] call CBE_fnc_CortexTacticalStart)) exitWith {false};
_drill=_state getOrDefault ["drill",createHashMap];
private _token=_drill getOrDefault ["token",""];
private _generation=_drill getOrDefault ["operationGeneration",-1];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",-1];
if (_token == "" || {_generation < 0} || {!((_drill getOrDefault ["type",""]) in ["ADVANCE","ASSAULT"])}
    || {_generation != (_group getVariable ["CBE_OperationGeneration",-2])}
    || {(_drill getOrDefault ["ownerEpoch",-2]) != _epoch}) exitWith {false};
_drill set ["explicitRush",[_deadline,_epoch,_generation,_token]];
_drill set ["rushRange",_range];
_drill set ["rushChunks",1];
_state set ["rushKnowledge",[_knowledgeAt,_epoch,_enemies apply {
    private _record=+_x;_record set [1,+(_x select 1)];_record
}]];
_group setVariable ["CBE_Rush_Status",["ACTIVE",_drill get "type",_token,serverTime],true];
// Retain restoration receipts, but do not migrate this owner's timed explicit episode.
[_group] call CBE_fnc_CortexCheckpoint;
true
};
};
_result
