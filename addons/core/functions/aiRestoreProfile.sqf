/*
 * Author: WaldoTheWarfighter
 * Purpose: Restore only unchanged WAIT-owned skill and aim-coefficient values when profiling ends or an actor changes controller.
 * Locality/authority: Current unit owner only; human and specialist actors may receive narrow restoration of WAIT's own effects, never unconditional profile application.
 * Repeat/JIP: Idempotent; public original/applied receipts follow locality. Missing applied receipts grant no restoration authority. Retired receipts are cleared for a fresh later adoption.
 * Arguments: 0 unit <OBJECT, objNull>.
 * Return Value: BOOL - true when an owned profile receipt was retired.
 * Current callers: AIApplyProfile, AILightingStep and AIRebalanceStop.
 * Example: [soldier1] call WAIT_fnc_AIRestoreProfile;
 */
params [["_unit",objNull,[objNull]]];
if (isNull _unit || {!local _unit}) exitWith {false};
private _original=_unit getVariable ["WAIT_AI_OriginalSkills",createHashMap];
private _applied=_unit getVariable ["WAIT_AI_AppliedSkills",createHashMap];
private _hadReceipt=count _original > 0 || {!isNil {_unit getVariable "WAIT_AI_OriginalAimCoef"}};
{
    if (_x in _applied && {abs ((_unit skill _x)-(_applied get _x)) < 0.00001}) then {
        _unit setSkill [_x,_original get _x];
    };
} forEach keys _original;
private _originalAim=_unit getVariable ["WAIT_AI_OriginalAimCoef",-1];
private _appliedAim=_unit getVariable ["WAIT_AI_AppliedAimCoef",-1];
if (_originalAim >= 0 && {_appliedAim >= 0} && {abs (getCustomAimCoef _unit-_appliedAim) < 0.00001}) then {
    _unit setCustomAimCoef _originalAim;
};
if (_hadReceipt) then {
    {_unit setVariable [_x,nil,true]} forEach ["WAIT_AI_OriginalSkills","WAIT_AI_AppliedSkills",
        "WAIT_AI_OriginalAimCoef","WAIT_AI_AppliedAimCoef","WAIT_AI_SkillVarianceOffsets"];
    _unit setVariable ["WAIT_Cortex_LightingSignature",nil];
};
_hadReceipt