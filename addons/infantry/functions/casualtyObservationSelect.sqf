/*
 * Author: WaldoTheWarfighter
 * Purpose: Resolve an observed own-group casualty without scanning world corpses or guessing identity.
 * Locality/authority: Read-only on the current observer/group owner. Native cause 5 or an explicit
 * owner script supplies the observation; death records alone never dispatch movement.
 * Repeat/JIP: Reads at most eight original five-minute casualty receipts. No expiry renewal,
 * timer or discovery query. Public records can corroborate the old group after corpse detachment.
 * Arguments: actor OBJECT objNull; observed position ARRAY []; optional native body OBJECT objNull.
 * Return: OBJECT known own-group dead soldier near the observation, or objNull if absent/ambiguous.
 * Current caller: PointActorOperation START, after actor/feature/native-task admission gates.
 * Example: private _body=[soldier1,_observed,objNull] call CBE_fnc_CasualtyObservationSelect;
 */
params [["_actor",objNull,[objNull]],["_observed",[],[[]]],["_source",objNull,[objNull]]];
if (isNull _actor || {!local _actor} || {!local group _actor}
    || {count _observed != 3} || {_observed findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {objNull};
private _group=group _actor;
private _rows=_group getVariable ["CBE_Danger_Casualties",[]];
private _known=[];
if (_rows isEqualType []) then {
    {
        if (_x isEqualType [] && {count _x == 3}
            && {(_x select 0) isEqualType objNull} && {!isNull (_x select 0)}
            && {!alive (_x select 0)} && {(_x select 0) isKindOf "CAManBase"}
            && {(_x select 1) isEqualType 0} && {finite (_x select 1)}
            && {(_x select 2) isEqualType 0} && {finite (_x select 2)}
            && {(_x select 1) <= serverTime} && {(_x select 2) > serverTime}
            && {(_x select 2) > (_x select 1)} && {(_x select 2) <= (_x select 1)+300}) then {
            _known pushBackUnique (_x select 0);
        };
    } forEach (_rows select [0,8]);
};
private _matches={
    !isNull _this && {!alive _this} && {!isObjectHidden _this} && {_this isKindOf "CAManBase"}
        && {group _this == _group || {_this in _known}}
        && {_this distance2D _observed <= 3}
};
if (_source call _matches) exitWith {_source};
private _candidates=_known select {_x call _matches};
// Multiple coincident casualties do not identify which body produced this event.
if (count _candidates == 1) then {_candidates select 0} else {objNull}
