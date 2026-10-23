/*
 * Author: WaldoTheWarfighter
 * Native flight, queued care and mission-disabled MOVE/PATH grant no ordinary recall authority.
 * Purpose: Recognises an investigation/search MOVE actually issued by CBE for safe handback.
 * Locality/Authority: Read-only on current group/actor owner; refuses external, Zeus, service,
 * mounted, dormant, queued-treatment or reserved actors and active clearance. Actual route and 3D native destination must match.
 * Repeat/JIP: Checkpoint carries at most sixteen receipts. No replay, deadlines or settings writes.
 * Arguments: 0 group <GROUP, grpNull>; 1 state/checkpoint <HASHMAP, empty>;
 * 2 actor <OBJECT, objNull>. Receipt rows: [actor, issued ATL position, native route receipt, optional transferred issuer token].
 * Return Value: BOOL - current MOVE/completed idle or exact transferred CBE STOP is still owned.
 * Current callers: CortexGroupTick contact/search handback and CortexRestoreCalm.
 * Example: [group soldier1,_state,soldier1] call CBE_fnc_CortexSearchMoveOwned;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_actor",objNull,[objNull]]];
if (isNull _group || {!local _group} || {isNull _actor} || {!local _actor} || {group _actor != _group}
    || {isPlayer _actor} || {!isNull objectParent _actor} || {!isNull remoteControlled _actor}
    || {fleeing _actor}
    || {!([_actor] call CBE_fnc_CortexCombatEffective)}
    || {!simulationEnabled _actor} || {isObjectHidden _actor}
    || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")}
    || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {!(currentCommand _actor in ["MOVE","","STOP"])}
    || {[_actor] call CBE_fnc_CortexActorMoveReserved}
    || {([_actor] call CBE_fnc_CortexExternalOwner) != ""}
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {[_group,false,_actor] call CBE_fnc_CortexExternalTakeover}
    || {[_group] call CBE_fnc_CortexZeusHeld}
    || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}) exitWith {false};
private _rows=_state getOrDefault ["searchMoveReceipts",[]];
if !(_rows isEqualType []) exitWith {false};
private _index=(_rows select [0,16]) findIf {_x isEqualType [] && {count _x in [3,4]} && {(_x select 0) isEqualTo _actor}};
if (_index < 0) exitWith {false};
private _row=_rows select _index;
// A search can inherit only its newly issued exact CBE hold token. This preserves
// cleanup during native MOVE acknowledgement without treating arbitrary STOP as ours.
if (count _row == 4 && {
    private _token=_row select 3;
    !(_token isEqualType []) || {count _token != 5} || {(_token select 0) isNotEqualTo _group}
        || {!((_token select 1) isEqualType "")} || {(_token select 1) == ""}
        || {[2,3,4] findIf {private _value=_token select _x; !(_value isEqualType 0)
            || {!finite _value} || {_value < 0} || {_value != floor _value}} >= 0}
        || {(_token select 2) <= 0}
        || {(_actor getVariable ["CBE_Cortex_HolderToken",[]]) isNotEqualTo _token}
}) exitWith {false};
if (currentCommand _actor == "STOP") exitWith {
    count _row == 4 && {(_row select 2) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
        && {[_group,_state,_actor] call CBE_fnc_CortexHolderRecallOwned}
};
private _target=_row select 1;
private _native=(expectedDestination _actor) param [0,[],[[]]];
_target isEqualType [] && {count _target == 3} && {count _native == 3}
    && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_native findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_native vectorDistance _target <= 0.25}
    && {(_row select 2) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
