/*
 * Author: WaldoTheWarfighter
 * Native flight and queued care grant no ordinary recall authority.
 * Purpose: Read exact completed-drill hold provenance before ordinary actor recall.
 * Locality/authority: Current group and actor owner only; public rows alone grant no command.
 * Repeat/JIP: Read-only. Immutable issuer owner/epoch/generation survive checkpoint transfer;
 * a new actual owner must still match actor, group, native destination and authored order.
 * The current per-actor issuer token must match; old checkpoints cannot consume newer holds.
 * No lifetime is renewed and no worker is installed. This is passive command provenance,
 * not a complete finite standing-hold operation or physical rejoin acknowledgement.
 * Arguments: 0 group <GROUP>, grpNull; 1 state/checkpoint <HASHMAP>, empty;
 * 2 actor <OBJECT>, objNull. holderRecallReceipts rows have eight fields:
 * [actor,group,issuer token,issuer owner,issuer epoch,issuer generation,native ATL target,order receipt].
 * Return: BOOL - true for an unchanged idle/STOP hold with no competing actor task.
 * Current callers: CortexGroupTick, CortexRestoreCalm, CortexRetreat, natural manoeuvre
 * admission and CortexDrillStart completed-hold transfer.
 * Example: if ([_group,_state,_unit] call CBE_fnc_CortexHolderRecallOwned) then {_unit doFollow leader _group};
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_actor",objNull,[objNull]]];
if ((remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) || {isNull _group} || {!local _group} || {isNull _actor} || {!local _actor}
    || {group _actor != _group} || {isPlayer _actor} || {!isNull objectParent _actor}
    || {fleeing _actor}
    || {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isNotEqualTo []}
    || {!([_actor] call CBE_fnc_CortexCombatEffective)} || {!simulationEnabled _actor} || {isObjectHidden _actor}
    || {!(_actor checkAIFeature "MOVE")} || {!(_actor checkAIFeature "PATH")}
    || {!isNull remoteControlled _actor}
    || {!isNull (_actor getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    || {([_actor] call CBE_fnc_CortexExternalOwner) != ""}
    || {[_actor] call CBE_fnc_CompatibilityExternalControl}
    || {[_actor] call CBE_fnc_CortexActorMoveReserved}
    || {!(toUpperANSI currentCommand _actor in ["","STOP"])}
    || {[_group,false,_actor] call CBE_fnc_CortexExternalTakeover}
    || {(_group getVariable ["CBE_AIPass_ClearOrder",[]]) isNotEqualTo []}) exitWith {false};
private _rows=_state getOrDefault ["holderRecallReceipts",[]];
if (!(_rows isEqualType []) || {count _rows > 64}) exitWith {false};
private _index=_rows findIf {_x isEqualType [] && {count _x == 8} && {(_x select 0) isEqualTo _actor}};
if (_index < 0) exitWith {false};
private _row=_rows select _index;
if ((_row select 1) isNotEqualTo _group || {!((_row select 2) isEqualType "")} || {(_row select 2) == ""}
    || {[3,4,5] findIf {private _value=_row select _x; !(_value isEqualType 0) || {!finite _value} || {_value < 0} || {_value != floor _value}} >= 0}
    || {(_row select 3) <= 0} || {!((_row select 7) isEqualType [])}) exitWith {false};
// Original checkpoint values cannot recall a newer hold at the same native destination.
if ((_actor getVariable ["CBE_Cortex_HolderToken",[]]) isNotEqualTo (_row select [1,5])) exitWith {false};
private _target=_row select 6;
private _native=(expectedDestination _actor) param [0,[]];
_target isEqualType [] && {_native isEqualType []} && {count _target == 3} && {count _native == 3}
    && {_target findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_native findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
    && {_native vectorDistance _target <= 0.25}
    && {(_row select 7) isEqualTo ([_group] call CBE_fnc_NativeOrderReceipt)}
