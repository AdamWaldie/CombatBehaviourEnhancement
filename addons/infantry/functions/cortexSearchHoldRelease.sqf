/*
 * Author: WaldoTheWarfighter
 * Purpose: Retire only the completed hold provenance transferred to a search episode.
 * Locality/authority: Current group/actor owners only. This changes metadata, never movement.
 * Repeat/JIP: Optional fourth search-receipt field carries the exact new search issuer token.
 * Old checkpoints cannot erase a successor token. Nonlocal actors are left untouched.
 * Arguments: 0 group <GROUP, grpNull>; 1 state/checkpoint <HASHMAP, empty>;
 * 2 actor <OBJECT, objNull> - empty processes at most sixteen search receipts.
 * Return: Nothing. Callers separately prove any native command or task completion.
 * Current callers: CortexGroupTick search/contact transitions and CortexRestoreCalm.
 * Example: [_group,_state,_unit] call CBE_fnc_CortexSearchHoldRelease;
 */
params [["_group",grpNull,[grpNull]],["_state",createHashMap,[createHashMap]],["_actor",objNull,[objNull]]];
if (isNull _group || {!local _group}) exitWith {};
isNil {
    private _rows=_state getOrDefault ["searchMoveReceipts",[]];
    if !(_rows isEqualType []) exitWith {};
    {
        if (_x isEqualType [] && {count _x == 4}) then {
            private _unit=_x select 0;private _token=_x select 3;
            if (_unit isEqualType objNull && {!isNull _unit} && {local _unit}
                && {group _unit == _group} && {isNull _actor || {_unit == _actor}}
                && {_token isEqualType []} && {count _token == 5}
                && {(_token select 0) isEqualTo _group}
                && {(_token select 1) isEqualType ""} && {(_token select 1) != ""}
                && {[2,3,4] findIf {private _value=_token select _x; !(_value isEqualType 0)
                    || {!finite _value} || {_value < 0} || {_value != floor _value}} < 0}
                && {(_token select 2) > 0}
                && {(_unit getVariable ["CBE_Cortex_HolderToken",[]]) isEqualTo _token}) then {
                _unit setVariable ["CBE_Cortex_HolderToken",nil,true];
                private _holds=_state getOrDefault ["holderRecallReceipts",[]];
                if (_holds isEqualType []) then {
                    _state set ["holderRecallReceipts",_holds select {
                        !(_x isEqualType [] && {count _x == 8} && {(_x select 0) isEqualTo _unit}
                            && {(_x select [1,5]) isEqualTo _token})
                    }];
                };
            };
        };
    } forEach (_rows select [0,16]);
};
