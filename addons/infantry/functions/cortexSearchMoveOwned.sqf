/*
 * Author: WaldoTheWarfighter
 * Purpose: Recognises an investigation/search MOVE actually issued by CBE for safe handback.
 * Locality/Authority: Read-only on current group/actor owner; refuses external, Zeus, service,
 * mounted, reserved actors and active clearance. Actual route and 3D native destination must match.
 * Repeat/JIP: Checkpoint carries at most sixteen receipts. No replay, deadlines or settings writes.
 * Arguments: 0 group <GROUP, grpNull>; 1 state/checkpoint <HASHMAP, empty>;
 * 2 actor <OBJECT, objNull>. Receipt rows: [actor, issued ATL position, native route receipt].
 * Return Value: BOOL - current MOVE or completed idle with unchanged destination is still owned.
 * Current callers: CortexGroupTick contact/search handback and CortexRestoreCalm.
 * Example: [group soldier1,_state,soldier1] call CBE_fnc_CortexSearchMoveOwned;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_actor",objNull,[objNull]]];
if (isNull _group || {!local _group} || {isNull _actor} || {!local _actor} || {group _actor != _group}
    || {isPlayer _actor} || {!isNull objectParent _actor} || {!isNull remoteControlled _actor}
    || {!([_actor] call CBE_fnc_CortexCombatEffective)}
    || {!(currentCommand _actor in ["MOVE",""])}
    || {[_actor] call CBE_fnc_CortexActorMoveReserved}
    || {([_actor] call CBE_fnc_CortexExternalOwner) != ""}
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {[_group,false,_actor] call CBE_fnc_CortexExternalTakeover}
    || {[_group] call CBE_fnc_CortexZeusHeld}
    || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}) exitWith {false};
private _rows=_state getOrDefault ["searchMoveReceipts",[]];
if !(_rows isEqualType []) exitWith {false};
private _index=(_rows select [0,16]) findIf {_x isEqualType [] && {count _x == 3} && {(_x select 0) isEqualTo _actor}};
if (_index < 0) exitWith {false};
private _row=_rows select _index;
private _target=_row select 1;
private _native=(expectedDestination _actor) param [0,[],[[]]];
_target isEqualType [] && {count _target == 3} && {count _native == 3}
    && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_native findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_native vectorDistance _target <= 0.25}
    && {(_row select 2) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
