/*
 * Author: WaldoTheWarfighter
 * Purpose: Reserve a static-support actor until an issued native cancellation/exit is observed.
 * Locality/authority: Actor-local metadata only. START is called inside the existing guarded
 * release before its native writes; this helper never boards, dismounts, follows or stops an actor.
 * Repeat/JIP: One identity-scoped half-second callback chain, at most20 callback observations per owner,
 * within the original10-second deadline. Owner migration stops old callbacks; discovery may
 * observe/adopt only the remaining time. Expiry preserves unresolved proof, never success.
 * Late REAP may retire proof after actual detachment or an observed boarding-command transition;
 * an idle actor whose pending boarding never became visible remains unresolved. No request retry.
 * Arguments: 0 mode STRING,REAP - START/OBSERVE/REAP;1 actor OBJECT,objNull;
 * 2 source group GROUP,grpNull;3 original static lease ARRAY,[] (START only);
 * 4 original identity ARRAY,[] (callback);5 attempt NUMBER,0 (callback0..20).
 * Return: STRING - ADMITTED/PENDING/RELEASED/DEAD/UNRESOLVED/YIELDED/INVALID/IDLE.
 * Current callers: CortexStaticSupport release, DangerSetup existing actor discovery and self callbacks.
 * Example: ["REAP",soldier1] call CBE_fnc_CortexStaticRetire;
 */
private _result="INVALID";
isNil {
_result=call {
params [["_mode","REAP",[""]],["_actor",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_lease",[],[[]]],["_identity",[],[[]]],["_attempt",0,[0]]];
if (isNull _actor) exitWith {"YIELDED"};
if (!local _actor) exitWith {
    // This old-machine marker is local only; never erase the replicated pending journal.
    if (_mode == "OBSERVE" && {(_actor getVariable ["CBE_Cortex_StaticRetirementWork",[]]) isEqualTo [_identity,clientOwner]}) then {
        _actor setVariable ["CBE_Cortex_StaticRetirementWork",nil];
    };
    "YIELDED"
};
if (!(_mode in ["START","OBSERVE","REAP"]) || {!finite _attempt}
    || {_attempt < 0} || {_attempt > 20} || {_attempt != floor _attempt}) exitWith {"INVALID"};
private _journal=_actor getVariable ["CBE_Cortex_StaticRetirement",[]];
if (_mode == "START") exitWith {
    if (_journal isNotEqualTo [] || {count _lease != 10} || {isNull _group} || {!local _group}
        || {group _actor != _group} || {(_lease param [1,objNull,[objNull]]) != _actor}) exitWith {"YIELDED"};
    private _seat=_lease param [8,[],[[]]];
    private _weapon=_lease param [2,objNull,[objNull]];
    if (count _seat != 3 || {isNull _weapon} || {(_seat param [0,-1,[0]]) != clientOwner}
        || {(_seat param [1,-1,[0]]) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {assignedVehicle _actor != _weapon}
        || {assignedVehicleRole _actor isNotEqualTo (_seat param [2,[],[[]]])}) exitWith {"YIELDED"};
    private _issued=serverTime;
    private _id=[clientOwner,_seat select 1,_lease select 0,_lease select 3];
    if (_id findIf {!(_x isEqualType 0) || {!finite _x}} >= 0 || {!finite _issued}) exitWith {"INVALID"};
    private _wasMounted=objectParent _actor == _weapon;
    private _sawBoarding=toUpperANSI currentCommand _actor in ["GET IN","GET OUT"];
    _journal=[_id,_group,_weapon,_issued,_issued+10,_wasMounted,_sawBoarding,"PENDING"];
    _actor setVariable ["CBE_Cortex_StaticRetirement",_journal,true];
    _actor setVariable ["CBE_Cortex_StaticRetirementWork",[_id,clientOwner]];
    [{_this call CBE_fnc_CortexStaticRetire},["OBSERVE",_actor,grpNull,[],_id,1],0.5] call CBA_fnc_waitAndExecute;
    "ADMITTED"
};
if (_journal isEqualTo []) exitWith {"IDLE"};
if (!(_journal isEqualType []) || {count _journal != 8}) exitWith {"INVALID"};
_journal params ["_id","_oldGroup","_weapon","_issued","_deadline","_wasMounted","_sawBoarding","_status"];
if (!(_id isEqualType []) || {count _id != 4}
    || {_id findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {!(_oldGroup isEqualType grpNull)} || {!(_weapon isEqualType objNull)}
    || {!(_issued isEqualType 0)} || {!finite _issued}
    || {!(_deadline isEqualType 0)} || {!finite _deadline} || {_deadline != _issued+10}
    || {!(_wasMounted isEqualType true)} || {!(_sawBoarding isEqualType true)}
    || {!(_status in ["PENDING","UNRESOLVED"])}) exitWith {"INVALID"};
if (_identity isNotEqualTo [] && {_identity isNotEqualTo _id}) exitWith {"YIELDED"};
private _work=[_id,clientOwner];
if (_mode == "OBSERVE" && {(_actor getVariable ["CBE_Cortex_StaticRetirementWork",[]]) isNotEqualTo _work}) exitWith {"YIELDED"};
private _boarding=toUpperANSI currentCommand _actor in ["GET IN","GET OUT"];
if (_boarding && {!_sawBoarding}) then {_journal set [6,true];_sawBoarding=true;_actor setVariable ["CBE_Cortex_StaticRetirement",_journal,true]};
// A deadline or idle command by itself cannot prove an unobserved native request ended.
private _ended=(_wasMounted || {_sawBoarding}) && {!_boarding}
    && {isNull objectParent _actor} && {isNull assignedVehicle _actor} && {isNull attachedTo _actor};
if (_ended || {!alive _actor}) exitWith {
    private _result=["DEAD","RELEASED"] select (alive _actor);
    isNil {
        if (local _actor && {(_actor getVariable ["CBE_Cortex_StaticRetirement",[]]) isEqualTo _journal}) then {
            _actor setVariable ["CBE_Cortex_StaticRetirement",nil,true];
            _actor setVariable ["CBE_Cortex_StaticRetirementWork",nil];
            _actor setVariable ["CBE_Cortex_StaticRetirementResult",[_id,_result,serverTime,_weapon],true];
        };
    };
    _result
};
if (serverTime >= _deadline || {_attempt >= 20} || {_status == "UNRESOLVED"}) exitWith {
    if (_status != "UNRESOLVED") then {
        _journal set [7,"UNRESOLVED"];
        _actor setVariable ["CBE_Cortex_StaticRetirement",_journal,true];
        _actor setVariable ["CBE_Cortex_StaticRetirementResult",[_id,"UNRESOLVED",serverTime,_weapon],true];
    };
    _actor setVariable ["CBE_Cortex_StaticRetirementWork",nil];
    "UNRESOLVED"
};
// Discovery can resume observation after migration, but cannot renew the deadline or native request.
if (_mode == "REAP" && {(_actor getVariable ["CBE_Cortex_StaticRetirementWork",[]]) isEqualTo _work}) exitWith {"PENDING"};
_actor setVariable ["CBE_Cortex_StaticRetirementWork",_work];
[{_this call CBE_fnc_CortexStaticRetire},["OBSERVE",_actor,grpNull,[],_id,_attempt+1],0.5] call CBA_fnc_waitAndExecute;
"PENDING"

};
};
_result
