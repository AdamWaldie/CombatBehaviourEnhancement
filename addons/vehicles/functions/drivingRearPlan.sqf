/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects one bounded long or short rear observation for native recovery admission.
 * Locality/authority: Read-only current vehicle owner. A clear result grants no command,
 * reservation, speed change or lasting clearance; consumers retain their authority checks.
 * Repeat/JIP: Stateless, at most two observations. Never retain or replay the returned target.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 fresh STATIC observation ARRAY [], optional;
 * 2 maximum stop travel NUMBER 6, finite6..24m. Extended requests use actual obstacle/hull
 * room arithmetic and require independent rear clearance; the result grants no movement.
 * Return: ARRAY [DrivingRearClear observation, envelope [clearance metres, stop travel metres]].
 * Default8m/6m permits a3.5m/2m spatial fallback. A qualified extended plan instead
 * permits one ordinary8m/6m fallback. Source/vehicle transforms recheck after observation. Unknown ownership,
 * dense scans and unsupported turning never trigger a second observation.
 * Current callers: DrivingAssistStart and DrivingQueueAgreementOwner leaf preflight.
 * Cost: At most two existing bounded rear observations; no new query type/timer/worker.
 * Example: private _plan=[truck1] call CBE_fnc_DrivingRearPlan;
 */
params [["_vehicle",objNull,[objNull]],["_observation",[],[[]]],["_maximumTravel",6,[0]]];
if (!finite _maximumTravel || {_maximumTravel < 6} || {_maximumTravel > 24}) exitWith {
    [[false,"INVALID_REAR_PLAN",time,0],[8,6]]
};
private _cbeRearPlanEnvelope=[8,6];
private _source=objNull;private _sourcePose=[];private _vehiclePose=[];
if (_maximumTravel > 6 && {count _observation == 9}) then {
    _source=_observation param [1,objNull,[objNull]];
    private _sampled=_observation param [3,-1,[0]];
    private _gap=_observation param [2,-1,[0]];
    if (!isNull _vehicle && {local _vehicle} && {alive _vehicle}
        && {(_observation param [5,"",[""]]) == "STATIC"}
        && {finite _sampled} && {time >= _sampled} && {time-_sampled <= 1.5}
        && {finite _gap} && {_gap >= 0} && {_gap <= 8}
        && {[_source] call CBE_fnc_DrivingBypassObstacleAvailable}) then {
        _sourcePose=[getPosWorld _source,vectorDir _source,vectorUp _source];
        _vehiclePose=[getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle];
        private _bounds=boundingBoxReal _vehicle;private _low=_bounds select 0;private _high=_bounds select 1;
        private _width=(abs (_low select 0)) max (abs (_high select 0));
        private _length=(abs (_low select 1)) max (abs (_high select 1));
        private _radius=sqrt (_width^2+_length^2)+1;
        private _forward=+(_vehiclePose select 1);_forward set [2,0];_forward=vectorNormalized _forward;
        private _right=[_forward select 1,-(_forward select 0),0];
        private _along=[_source,_vehiclePose select 0,_forward] call CBE_fnc_DrivingHullInterval;
        private _across=[_source,_vehiclePose select 0,_right] call CBE_fnc_DrivingHullInterval;
        if (_sourcePose isEqualTo (_observation select 8) && {_along isNotEqualTo []} && {_across isNotEqualTo []}
            && {(boundingBoxReal _source select 0) vectorDistance (boundingBoxReal _source select 1) >= 0.5}) then {
            private _required=1e6;
            {
                private _room=[[_across select 0,_across select 1,_along select 0,_along select 1],_radius,_x,false] call CBE_fnc_DrivingBypassRoom;
                if ((_room getOrDefault ["reason",""]) in ["INSUFFICIENT_APPROACH_ROOM","INSUFFICIENT_TURN_ROOM"]
                    && {"requiredBack" in _room}) then {_required=_required min (_room get "requiredBack")};
            } forEach [-1,1];
            private _travel=ceil (_required+1);
            if (_travel > 6 && {_travel <= _maximumTravel}) then {_cbeRearPlanEnvelope=[_travel+2,_travel]};
        };
    };
};
private _cbeRearPlanClearance=[_vehicle,_cbeRearPlanEnvelope select 0] call CBE_fnc_DrivingRearClear;
if (!(_cbeRearPlanClearance select 0) && {(_cbeRearPlanClearance select 1) in [
    "REAR_GEOMETRY","REAR_SUPPORT","REAR_TARGET_SUPPORT","REAR_OCCUPIED","REAR_APPROACHING"]}) then {
    // An extended refusal falls back to the ordinary long plan; default requests
    // retain their original short fallback. Never spend a third observation.
    _cbeRearPlanEnvelope=if ((_cbeRearPlanEnvelope select 1) > 6) then {[8,6]} else {[3.5,2]};
    _cbeRearPlanClearance=[_vehicle,_cbeRearPlanEnvelope select 0] call CBE_fnc_DrivingRearClear;
};
if ((_cbeRearPlanEnvelope select 1) > 6
    && {!([_source] call CBE_fnc_DrivingBypassObstacleAvailable)
        || {[getPosWorld _source,vectorDir _source,vectorUp _source] isNotEqualTo _sourcePose}
        || {[getPosASL _vehicle,vectorDir _vehicle,vectorUp _vehicle] isNotEqualTo _vehiclePose}}) then {
    _cbeRearPlanClearance=[false,"CORNER_CONTEXT_CHANGED",time,(_cbeRearPlanClearance select 3)];
};
[_cbeRearPlanClearance,_cbeRearPlanEnvelope]
