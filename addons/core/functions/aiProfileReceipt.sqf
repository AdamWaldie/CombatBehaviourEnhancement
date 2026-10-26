/*
 * Author: WaldoTheWarfighter
 * Purpose: Read bounded typed skill/aim baseline and applied pairs for profile ownership decisions.
 * Locality/authority: Read-only on any machine; command callers still require actual unit ownership.
 * Repeat/JIP: Returns detached maps. Partial pairs remain pending rather than becoming restoration
 * authority. This is structural validation, not an ordered-delivery or fresh-admission handshake.
 * Arguments: 0 unit <OBJECT>, objNull.
 * Return: HASHMAP with valid; when valid, original/applied maps, aim values, ready/pending pair
 * flags and applicationReady. Invalid data returns valid=false without changing native or public state.
 * Current callers: AIProfileYield and AIRestoreProfile.
 * Example: private _receipt=[soldier1] call CBE_fnc_AIProfileReceipt;
 */
params [["_unit",objNull,[objNull]]];
private _invalid=createHashMapFromArray [["valid",false]];
if (isNull _unit) exitWith {_invalid};
private _names=["aimingSpeed","aimingAccuracy","aimingShake","spotTime","spotDistance","commanding","general","courage","reloadSpeed"];
private _original=_unit getVariable ["CBE_AI_OriginalSkills",createHashMap];
private _applied=_unit getVariable ["CBE_AI_AppliedSkills",createHashMap];
private _validMap={
    params ["_receipt"];
    _receipt isEqualType createHashMap && {count _receipt in [0,9]}
        && {keys _receipt findIf {!(_x in _names) || {!((_receipt get _x) isEqualType 0)}
            || {!finite (_receipt get _x)} || {(_receipt get _x) < 0} || {(_receipt get _x) > 1}} < 0}
};
if (!([_original] call _validMap) || {!([_applied] call _validMap)}) exitWith {_invalid};
private _originalAim=_unit getVariable ["CBE_AI_OriginalAimCoef",-1];
private _appliedAim=_unit getVariable ["CBE_AI_AppliedAimCoef",-1];
private _validAim={params ["_value"];_value isEqualType 0 && {finite _value} && {_value == -1 || {_value >= 0}}};
if (!([_originalAim] call _validAim) || {!([_appliedAim] call _validAim)}) exitWith {_invalid};
private _skillsReady=count _original == 9 && {count _applied == 9};
private _aimReady=_originalAim >= 0 && {_appliedAim >= 0};
createHashMapFromArray [
    ["valid",true],
    ["original",createHashMapFromArray (keys _original apply {[_x,_original get _x]})],
    ["applied",createHashMapFromArray (keys _applied apply {[_x,_applied get _x]})],
    ["originalAim",_originalAim],["appliedAim",_appliedAim],
    ["skillsReady",_skillsReady],["aimReady",_aimReady],
    ["skillsPending",!_skillsReady && {count _original > 0 || {count _applied > 0}}],
    ["aimPending",!_aimReady && {_originalAim >= 0 || {_appliedAim >= 0}}],
    ["applicationReady",!(count _applied > 0 && {count _original == 0}) && {!(_appliedAim >= 0 && {_originalAim < 0})}]
]
