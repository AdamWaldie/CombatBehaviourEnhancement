/*
 * Author: WaldoTheWarfighter
 * Non-finite geometry/timestamps are rejected before selection or observation side effects.
 * Purpose: Select one live engine danger record from at most48 recent records with a bounded
 * priority pass. The FSM separately submits at most12 observations including this selection.
 * Unsubmitted window records remain in the native queue with unchanged expiry for later passes.
 * Direct hits remain
 * highest, but an actor that can fire retains higher priority than casualty observation, shouting
 * or ambient fire so actionable combat is not displaced by weaker events from the same queue.
 * Locality / Authority: Pure owner-local selection. It performs no commands or state mutation.
 * Repeat/JIP: Stateless and repeat-safe; the engine supplies a fresh queue after locality changes.
 * Arguments: 0: engine danger records <ARRAY>, [].
 * Return Value: Array - selected [cause, position, expiry, source] record, or [].
 * Current callers: Engine-loaded infantry danger FSM.
 * Example: [[[2,getPosATL player,time + 1,objNull]]] call CBE_fnc_DangerEngineSelect;
 */

params [["_records",[],[[]]]];
// Engine causes: enemy detected, fire, hit, enemy near, explosion, own-group casualty,
// other casualty, scream, can fire, bullet close, synthetic assessment.
private _priorities=[2,1,9,4,3,6,3,5,8,7,0];
private _selected=[];
private _best=-1;
private _latest=-1;
{
    if (_x isEqualType [] && {count _x >= 3}) then {
        private _cause=_x param [0,-1,[0]];
        private _expiry=_x param [2,-1,[0]];
        private _position=_x param [1,[],[[]]];
        private _rank=if (finite _cause && {_cause == floor _cause} && {_cause >= 0} && {_cause < count _priorities}) then {_priorities select _cause} else {-1};
        if (_rank >= 0 && {count _position in [2,3]} && {_position findIf {!(_x isEqualType 0) || {!finite _x}} < 0} && {finite _expiry} && {_expiry >= time - 0.25} && {_rank > _best || {_rank == _best && {_expiry > _latest}}}) then {
            _selected=+_x;
            _best=_rank;
            _latest=_expiry;
        };
    };
} forEach (_records select [0,48]);
_selected
