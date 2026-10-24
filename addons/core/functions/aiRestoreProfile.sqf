/*
 * Author: WaldoTheWarfighter
 * Purpose: Release only validated unchanged skill/aim pairs, retaining incomplete baseline data.
 * Locality/authority: Actual unit owner; receipt read, native comparisons, restoration and pair
 * retirement share one synchronous boundary. Human/specialist actors receive only owned cleanup.
 * Repeat/JIP: Complete pairs retire once; incomplete pairs remain available. No callback, retry
 * deadline or mission ownership reset is created. Changed complete pairs latch the existing
 * observed-edit owner only while no mission label exists, preserving it through stop/restart.
 * This does not prove ordered receipt delivery or identify which writer changed the value.
 * Arguments: 0 unit <OBJECT>, objNull.
 * Return: BOOL - at least one complete owned pair was retired; false for absent/invalid/pending only.
 * Current callers: AIProfileYield, AIApplyProfile, AILightingStep and AIRebalanceStop.
 * Example: [soldier1] call CBE_fnc_AIRestoreProfile;
 */
params [["_unit",objNull,[objNull]]];
if (isNull _unit || {!local _unit}) exitWith {false};
private _retired=false;
private _observedExternal=false;
isNil {
    if (!local _unit) exitWith {};
    private _receipt=[_unit] call CBE_fnc_AIProfileReceipt;
    if !(_receipt getOrDefault ["valid",false]) exitWith {};
    private _original=_receipt get "original";
    private _applied=_receipt get "applied";
    if (_receipt get "skillsReady") then {
        {
            if (_x in _applied) then {
                if (abs ((_unit skill _x)-(_applied get _x)) < 0.00001) then {
                    if (abs ((_unit skill _x)-(_original get _x)) >= 0.00001) then {_unit setSkill [_x,_original get _x]};
                } else {_observedExternal=true};
            };
        } forEach keys _original;
        _unit setVariable ["CBE_AI_OriginalSkills",nil,true];
        _unit setVariable ["CBE_AI_AppliedSkills",nil,true];
        _retired=true;
    };
    private _originalAim=_receipt get "originalAim";
    private _appliedAim=_receipt get "appliedAim";
    if (_receipt get "aimReady") then {
        if (abs (getCustomAimCoef _unit-_appliedAim) < 0.00001) then {
            if (abs (getCustomAimCoef _unit-_originalAim) >= 0.00001) then {
                _unit setCustomAimCoef _originalAim;
            };
        } else {_observedExternal=true};
        _unit setVariable ["CBE_AI_OriginalAimCoef",nil,true];
        _unit setVariable ["CBE_AI_AppliedAimCoef",nil,true];
        _retired=true;
    };
    // Direct stop/exclusion cleanup can be the first observer of a later edit.
    // Retiring its pairs must not allow a restart to silently reacquire that unit.
    if (_observedExternal) then {
        private _owner=_unit getVariable ["CBE_AI_SkillOwner",""];
        if (_owner isEqualType "" && {_owner == ""}) then {
            _unit setVariable ["CBE_AI_SkillOwner","OBSERVED_EXTERNAL_CHANGE",true];
        };
    };
    if (_retired) then {
        // Do not discard an unfinished pair merely because another setting finished cleanup.
        if (!(_receipt get "skillsPending") && {!(_receipt get "aimPending")}) then {
            _unit setVariable ["CBE_AI_SkillVarianceOffsets",nil,true];
        };
        _unit setVariable ["CBE_Cortex_LightingSignature",nil];
    };
};
_retired
