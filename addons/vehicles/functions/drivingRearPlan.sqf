/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects one bounded long or short rear observation for native recovery admission.
 * Locality/authority: Read-only current vehicle owner. A clear result grants no command,
 * reservation, speed change or lasting clearance; consumers retain their authority checks.
 * Repeat/JIP: Stateless, at most two observations. Never retain or replay the returned target.
 * Arguments: 0 vehicle <OBJECT, objNull>.
 * Return: ARRAY [DrivingRearClear observation, envelope [clearance metres, stop travel metres]].
 * Prefer8m/6m; only spatial/support refusal permits one3.5m/2m fallback. Unknown ownership,
 * dense scans and unsupported turning never trigger a second observation.
 * Current callers: DrivingAssistStart and DrivingQueueAgreementOwner leaf preflight.
 * Cost: At most two existing bounded rear observations; no new query type/timer/worker.
 * Example: private _plan=[truck1] call CBE_fnc_DrivingRearPlan;
 */
params [["_vehicle",objNull,[objNull]]];
private _cbeRearPlanEnvelope=[8,6];
private _cbeRearPlanClearance=[_vehicle,8] call CBE_fnc_DrivingRearClear;
if (!(_cbeRearPlanClearance select 0) && {(_cbeRearPlanClearance select 1) in [
    "REAR_GEOMETRY","REAR_SUPPORT","REAR_TARGET_SUPPORT","REAR_OCCUPIED","REAR_APPROACHING"]}) then {
    _cbeRearPlanEnvelope=[3.5,2];
    _cbeRearPlanClearance=[_vehicle,3.5] call CBE_fnc_DrivingRearClear;
};
[_cbeRearPlanClearance,_cbeRearPlanEnvelope]
