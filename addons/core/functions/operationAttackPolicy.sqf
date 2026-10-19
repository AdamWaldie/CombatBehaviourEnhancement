/*
 * Author: WaldoTheWarfighter
 * Purpose: Acquire or check the common operation's reversible native group attack permission.
 * Locality/authority: Current group owner and matching live generation/owner epoch only.
 * Repeat/JIP: Repeated calls retain the first baseline and issue no command. A changed native
 * policy is refused, never reapplied. Migration may supply the admitted durable task baseline;
 * this does not adopt an old operation or replay movement. OperationRestore releases the receipt.
 * Arguments: 0 group <GROUP>, grpNull; 1 operation <HASHMAP>, empty; 2 applied policy <BOOL>, false;
 * 3 original policy <ARRAY>, [] to capture now or [BOOL] from an admitted durable task.
 * Return: STRING - ACQUIRED, OWNED, POLICY_CHANGED or REFUSED. No movement authority is granted.
 * Current callers: CortexFlankStep and CortexClearBuilding; release through OperationRestore.
 * Example: [_group,_operation,false] call CBE_fnc_OperationAttackPolicy;
 */
params [["_group",grpNull,[grpNull]],["_operation",createHashMap,[createHashMap]],
    ["_applied",false,[true]],["_original",[],[[]]]];
if (isNull _group || {!local _group} || {count _operation == 0}
    || {count _original > 1} || {_original findIf {!(_x isEqualType true)} >= 0}) exitWith {"REFUSED"};
private _cbePolicyResult="REFUSED";
isNil {
_cbePolicyResult=call {
    private _current=_group getVariable ["CBE_Operation",createHashMap];
    private _generation=_operation getOrDefault ["generation",-1];
    private _epoch=_operation getOrDefault ["ownerEpoch",-1];
    if (!local _group || {_current isNotEqualTo _operation}
        || {!(_generation isEqualType 0)} || {!finite _generation} || {_generation < 0}
        || {!(_epoch isEqualType 0)} || {!finite _epoch} || {_epoch < 0}
        || {_generation != (_group getVariable ["CBE_OperationGeneration",-2])}
        || {_epoch != (_group getVariable ["CBE_AIPass_Epoch",-2])}
        || {(_current getOrDefault ["phase",""]) == "CANCELLED"}) exitWith {"REFUSED"};
    private _members=units _group;
    private _anchor=leader _group;
    if (isNull _anchor || {!local _anchor} || {count _members > 64}
        || {[_group] call CBE_fnc_CortexExternalTakeover}
        || {_members findIf {!local _x || {isPlayer _x} || {!isNull remoteControlled _x}
            || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
            || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
            || {[_x] call CBE_fnc_CompatibilityExternalControl}} >= 0}) exitWith {"REFUSED"};
    private _restore=_current getOrDefault ["restore",createHashMap];
    if !(_restore isEqualType createHashMap) exitWith {"REFUSED"};
    private _lease=_restore getOrDefault ["groupAttack",[]];
    if !(_lease isEqualType []) exitWith {"REFUSED"};
    if (_lease isNotEqualTo []) exitWith {
        if (count _lease != 2 || {_lease findIf {!(_x isEqualType true)} >= 0}) exitWith {"REFUSED"};
        if (attackEnabled _anchor != (_lease select 1)) exitWith {"POLICY_CHANGED"};
        if (_applied != (_lease select 1)) exitWith {"REFUSED"};
        "OWNED"
    };
    private _baseline=if (_original isEqualTo []) then {attackEnabled _anchor} else {_original select 0};
    _restore set ["groupAttack",[_baseline,_applied]];
    _current set ["restore",_restore];
    _group setVariable ["CBE_Operation",_current,true];
    if (attackEnabled _anchor != _applied) then {_group enableAttack _applied};
    "ACQUIRED"
};
};
_cbePolicyResult
