/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects one bounded long or short rear observation for native recovery admission.
 * Locality/authority: Read-only current vehicle owner. A clear result grants no command,
 * reservation, speed change or lasting clearance; consumers retain their authority checks.
 * Repeat/JIP: Stateless, at most two observations. Never retain or replay the returned target.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 fresh STATIC observation ARRAY [], optional;
 * 2 maximum stop travel NUMBER 6, finite6..24m. Extended requests use actual obstacle/hull
 * room arithmetic and require independent rear clearance; the result grants no movement.
 * 3 optional queue envelope ARRAY []; integral travel6..maximumTravel, clearance=travel+2.
 * Extended queue refusal never falls back to an insufficient shorter leg. Read-only caller
 * must separately bind this demand to authenticated consent; this grants no command.
 * Return: ARRAY [DrivingRearClear observation, envelope [clearance metres, stop travel metres]].
 * Default8m/6m permits a3.5m/2m spatial fallback. A qualified extended STATIC plan instead
 * permits one ordinary8m/6m fallback; extended queue demand never falls back. Source/vehicle transforms recheck after observation. Unknown ownership,
 * dense scans and unsupported turning never trigger a second observation.
 * Current callers: DrivingAssistStart and DrivingQueueAgreementOwner leaf preflight.
 * Cost: At most two existing bounded rear observations; no new query type/timer/worker.
 * Example: private _plan=[truck1] call CBE_fnc_DrivingRearPlan;
 */
params [["_vehicle",objNull,[objNull]],["_observation",[],[[]]],["_maximumTravel",6,[0]],["_queueEnvelope",[],[[]]]];
if (!finite _maximumTravel || {_maximumTravel < 6} || {_maximumTravel > 24}) exitWith {
    [[false,"INVALID_REAR_PLAN",time,0],[8,6]]
};
if (_queueEnvelope isNotEqualTo [] && {count _queueEnvelope != 2
    || {_queueEnvelope findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {(_queueEnvelope select 1) < 6} || {(_queueEnvelope select 1) > _maximumTravel}
    || {(_queueEnvelope select 1) != floor (_queueEnvelope select 1)}
    || {(_queueEnvelope select 0) != (_queueEnvelope select 1)+2}}) exitWith {
    [[false,"INVALID_QUEUE_ENVELOPE",time,0],[8,6]]
};
private _cbeRearPlanEnvelope=[8,6];
if (_queueEnvelope isNotEqualTo []) then {_cbeRearPlanEnvelope=+_queueEnvelope};
private _source=objNull;private _sourcePose=[];private _vehiclePose=[];
if (_queueEnvelope isEqualTo [] && {_maximumTravel > 6} && {count _observation == 9}) then {
    _source=_observation param [1,objNull,[objNull]];
    private _approach=[_vehicle,_observation] call CBE_fnc_DrivingBypassApproach;
    if ((_approach getOrDefault ["status",""]) == "BACKOFF") then {
        _sourcePose=_approach get "sourcePose";_vehiclePose=_approach get "vehiclePose";
        private _travel=ceil ((_approach get "requiredBack")+1);
        if (_travel > 6 && {_travel <= _maximumTravel}) then {_cbeRearPlanEnvelope=[_travel+2,_travel]};
    };
};
private _cbeRearPlanClearance=[_vehicle,_cbeRearPlanEnvelope select 0] call CBE_fnc_DrivingRearClear;
if (!(_cbeRearPlanClearance select 0) && {_queueEnvelope isEqualTo [] || {(_queueEnvelope select 1) == 6}} && {(_cbeRearPlanClearance select 1) in [
    "REAR_GEOMETRY","REAR_SUPPORT","REAR_TARGET_SUPPORT","REAR_OCCUPIED","REAR_APPROACHING"]}) then {
    // An extended refusal falls back to the ordinary long plan; default requests
    // retain their original short fallback. Never spend a third observation.
    _cbeRearPlanEnvelope=if ((_cbeRearPlanEnvelope select 1) > 6) then {[8,6]} else {[3.5,2]};
    _cbeRearPlanClearance=[_vehicle,_cbeRearPlanEnvelope select 0] call CBE_fnc_DrivingRearClear;
};
if (_queueEnvelope isEqualTo [] && {(_cbeRearPlanEnvelope select 1) > 6}
    && {!([_source] call CBE_fnc_DrivingBypassObstacleAvailable)
        || {[getPosWorld _source,vectorDir _source,vectorUp _source] isNotEqualTo _sourcePose}
        || {[getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle] isNotEqualTo _vehiclePose}}) then {
    _cbeRearPlanClearance=[false,"CORNER_CONTEXT_CHANGED",time,(_cbeRearPlanClearance select 3)];
};
[_cbeRearPlanClearance,_cbeRearPlanEnvelope]
