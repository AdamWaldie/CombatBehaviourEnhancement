/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply one Eden vehicle opt-out without changing CBA or mission-script exclusions.
 * Locality/authority: Server-only mission attribute evaluation; refuses remote execution.
 * Repeat/JIP: Idempotent metadata update, public for current and later owners/JIP. No commands,
 * workers or event handlers. Clearing one attribute removes only its editor-owned exclusion.
 * Arguments: 0 vehicle OBJECT objNull; 1 feature STRING empty; 2 disabled BOOL false.
 * Return: BOOL accepted, not execution or physical handback acknowledgement.
 * Current callers: Cfg3DEN CBE driving attributes; server mission scripts may use the same policy.
 * Example: [truck1,"CBE_AIPass_DrivingAssist_Recovery_Enable",true] call CBE_fnc_DrivingAttributeApply;
 */
params [["_vehicle",objNull,[objNull]],["_feature","",[""]],["_disabled",false,[true]]];
if (!isServer || {remoteExecutedOwner > 0} || {isNull _vehicle}
    || {!(_vehicle isKindOf "LandVehicle")} || {_vehicle isKindOf "StaticWeapon"}
    || {!(_feature in ["CBE_AIPass_DrivingAssist_Enable","CBE_AIPass_DrivingAssist_Recovery_Enable",
        "CBE_AIPass_DrivingAssist_CrewRecall_Enable","CBE_AIPass_DrivingAssist_Passing_Enable",
        "CBE_AIPass_DrivingAssist_Queue_Enable","CBE_AIPass_DrivingAssist_CloseGates_Enable",
        "CBE_Convoy_DrivingAssist_Enable","CBE_Convoy_RouteRecovery_Enable"])}) exitWith {false};
private _before=_vehicle getVariable ["CBE_Driving_EditorDisabledFeatures",[]];
if (!(_before isEqualType []) || {_before findIf {!(_x isEqualType "")} >= 0}) exitWith {false};
private _after=+_before;
if (_disabled) then {_after pushBackUnique _feature} else {_after=_after-[_feature]};
if (_after isNotEqualTo _before) then {_vehicle setVariable ["CBE_Driving_EditorDisabledFeatures",_after,true]};
true
