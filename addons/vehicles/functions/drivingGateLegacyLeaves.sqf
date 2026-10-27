/*
 * Author: WaldoTheWarfighter
 * Purpose: Read unambiguous legacy gate animation leaves from declarative open/close actions.
 * Locality/authority: Read-only owner geometry or server admission for a physically observed gate.
 * Never evaluates action statements. Only literal this animate [name,0/1] is accepted;
 * indexed Open/CloseDoor_N or Open/CloseGate_N pairs must name one identical model animation.
 * Repeat/JIP: Stateless, no worker/cache or replay. Caller uses only when no supported source
 * leaf exists; animation modes are never mixed by this fallback. Unknown mappings refuse.
 * Bounds: 32 actions,512 characters/statement,128 model animation names,8 leaves.
 * Arguments: 0 gate OBJECT objNull.
 * Return: ARRAY [index,animation,current phase,"ANIM"] rows, or[] when ambiguous/unsupported.
 * Current callers: DrivingGateOpenServer source-empty fallback; DrivingGeometryCap bounded candidate classification.
 * Example: private _leaves=[gate1] call CBE_fnc_DrivingGateLegacyLeaves;
 */
params [["_gate",objNull,[objNull]]];
if (isNull _gate) exitWith {[]};
private _actions="true" configClasses (configOf _gate >> "UserActions");
private _animations=animationNames _gate;
if (count _actions > 32 || {count _animations > 128}) exitWith {[]};
private _pairs=createHashMap;private _invalid=false;
private _space=toString [32,9,13,10];
{
    private _action=toLowerANSI configName _x;private _index=-1;private _phase=-1;
    for "_leaf" from 1 to 8 do {
        if (_action in [format ["opendoor_%1",_leaf],format ["opengate_%1",_leaf]]) exitWith {_index=_leaf;_phase=1};
        if (_action in [format ["closedoor_%1",_leaf],format ["closegate_%1",_leaf]]) exitWith {_index=_leaf;_phase=0};
    };
    if (_index < 0) then {continue};
    private _statement=getText (_x >> "statement");
    if (count _statement > 512) exitWith {_invalid=true};
    private _start=_statement find "[";private _end=_statement find "]";
    if (_start < 0 || {_end <= _start}
        || {toLowerANSI ((_statement select [0,_start]) splitString _space joinString "") != "thisanimate"}
        || {((_statement select [_end+1]) splitString (_space+";")) isNotEqualTo []}) exitWith {_invalid=true};
    private _literal=_statement select [_start+1,_end-_start-1];
    if ({_x == 44} count toArray _literal != 1) exitWith {_invalid=true};
    private _arguments=_literal splitString ",";
    if (count _arguments != 2 || {((_arguments select 1) splitString _space joinString "") != str _phase}) exitWith {_invalid=true};
    private _raw=toArray (_arguments select 0);
    private _quoteAt=_raw findIf {_x in [34,39]};
    if (_quoteAt < 0 || {(_raw select [0,_quoteAt]) findIf {!(_x in [32,9,13,10])} >= 0}) exitWith {_invalid=true};
    private _quote=_raw select _quoteAt;private _tail=_raw select [_quoteAt+1];
    private _quoteEnd=_tail find _quote;
    if (_quoteEnd <= 0 || {(_tail select [_quoteEnd+1]) findIf {!(_x in [32,9,13,10])} >= 0}) exitWith {_invalid=true};
    private _name=toString (_tail select [0,_quoteEnd]);
    if ((toArray _name) findIf {!(_x in [95] || {_x >= 48 && {_x <= 57}}
        || {_x >= 65 && {_x <= 90}} || {_x >= 97 && {_x <= 122}})} >= 0
        || {!(_name in _animations)}) exitWith {_invalid=true};
    private _key=str _index;private _row=_pairs getOrDefault [_key,[[],[]]];
    if ((_row select _phase) isNotEqualTo []) exitWith {_invalid=true};
    _row set [_phase,[_name]];_pairs set [_key,_row];
} forEach _actions;
if (_invalid) exitWith {[]};
private _leaves=[];
for "_index" from 1 to 8 do {
    private _pair=_pairs getOrDefault [str _index,[]];
    if (_pair isEqualTo []) then {continue};
    if ((_pair select 0) isEqualTo [] || {(_pair select 1) isEqualTo []}
        || {(_pair select 0) isNotEqualTo (_pair select 1)}) exitWith {_invalid=true};
    private _name=(_pair select 0) select 0;
    if (_leaves findIf {(_x select 1) == _name} >= 0) exitWith {_invalid=true};
    private _phase=_gate animationPhase _name;
    if (!finite _phase || {_phase < 0} || {_phase > 1}) exitWith {_invalid=true};
    _leaves pushBack [_index,_name,_phase,"ANIM"];
};
if (_invalid) then {[]} else {_leaves}
