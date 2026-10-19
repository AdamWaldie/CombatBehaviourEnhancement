/*
 * Author: WaldoTheWarfighter
 * Purpose: Yield the optional skill/aim layer to declared mission ownership or an observed edit.
 * Locality/authority: Actual unit owner; synchronous setting-only receipt check and release.
 * Repeat/JIP: Public CBE_AI_SkillOwner survives owner transfer and profile stop/restart. A nonempty
 * owner label blocks automatic reacquisition; only the mission clears it to authorise a new episode.
 * Original/applied receipts are validated before cleanup; malformed state refuses without writes.
 * Arguments: 0 unit <OBJECT>, objNull.
 * Return: BOOL - true when profiling must not write. False grants no movement authority.
 * Current callers: AIApplyProfile before planning and at its final setting commit.
 * Example: soldier1 setVariable ["CBE_AI_SkillOwner","MISSION",true]; [soldier1] call CBE_fnc_AIProfileYield;
 */
params [["_unit",objNull,[objNull]]];
if (isNull _unit || {!local _unit}) exitWith {true};
private _cbeSkillBlocked=true;
isNil {
_cbeSkillBlocked=call {
    if (!local _unit) exitWith {true};
    private _names=["aimingSpeed","aimingAccuracy","aimingShake","spotTime","spotDistance","commanding","general","courage","reloadSpeed"];
    private _original=_unit getVariable ["CBE_AI_OriginalSkills",createHashMap];
    private _applied=_unit getVariable ["CBE_AI_AppliedSkills",createHashMap];
    private _valid={
        params ["_receipt"];
        _receipt isEqualType createHashMap && {count _receipt in [0,9]}
            && {keys _receipt findIf {!(_x in _names) || {!((_receipt get _x) isEqualType 0)}
                || {!finite (_receipt get _x)} || {(_receipt get _x) < 0} || {(_receipt get _x) > 1}} < 0}
    };
    if (!([_original] call _valid) || {!([_applied] call _valid)}) exitWith {true};
    if (keys _applied findIf {!(_x in _original)} >= 0) exitWith {true};
    private _originalAim=_unit getVariable ["CBE_AI_OriginalAimCoef",-1];
    private _appliedAim=_unit getVariable ["CBE_AI_AppliedAimCoef",-1];
    if (!(_originalAim isEqualType 0) || {!finite _originalAim} || {_originalAim < -1}
        || {!(_appliedAim isEqualType 0)} || {!finite _appliedAim} || {_appliedAim < -1}
        || {_appliedAim >= 0 && {_originalAim < 0}}) exitWith {true};
    private _owner=_unit getVariable ["CBE_AI_SkillOwner",""];
    if (!(_owner isEqualType "") || {_owner != ""}) exitWith {
        [_unit] call CBE_fnc_AIRestoreProfile;
        true
    };
    // An interrupted first plan can have a baseline without an applied receipt. That baseline
    // must not become permission to overwrite a later mission edit on the retry.
    private _expected=if (count _applied > 0) then {_applied} else {_original};
    private _changed=keys _expected findIf {abs ((_unit skill _x)-(_expected get _x)) >= 0.00001} >= 0;
    private _expectedAim=if (_appliedAim >= 0) then {_appliedAim} else {_originalAim};
    if (_expectedAim >= 0 && {abs (getCustomAimCoef _unit-_expectedAim) >= 0.00001}) then {_changed=true};
    if (!_changed) exitWith {false};
    // This identifies a changed value, not which script or addon changed it. Identical-value
    // writes are inherently indistinguishable. Preserve the edit and release unchanged effects.
    _unit setVariable ["CBE_AI_SkillOwner","OBSERVED_EXTERNAL_CHANGE",true];
    [_unit] call CBE_fnc_AIRestoreProfile;
    true
};
};
_cbeSkillBlocked
