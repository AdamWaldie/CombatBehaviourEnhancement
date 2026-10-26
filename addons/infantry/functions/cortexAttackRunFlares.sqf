/*
 * Author: WaldoTheWarfighter
 * Releases countermeasure bursts while approaching and leaving an assigned attack target.
 * Locality/authority: aircraft owner only; never changes flight paths or target knowledge.
 * Repeat/JIP: one local scheduler job; public cooldown survives owner migration. No JIP effects.
 * Target discovery checks the effective commander and bounded actual crew witnesses for native
 * assignments because helicopters commonly give the attack target to the gunner rather than pilot.
 * At most16 crew witnesses supply a native-known believed point. The finite episode retains that
 * fixed ASL estimate; hidden live target transforms never drive approach/departure timing.
 * A firing helper acknowledgement is a dispatched request, not an observed countermeasure release.
 * Arguments: 0: job <HASHMAP>, empty default; aircraft <OBJECT> is required.
 * Return: NUMBER, next sampling delay or -1 to retire.
 * Current callers: CBE_fnc_CortexDiscover through the budgeted Cortex scheduler.
 * Example: [createHashMapFromArray [["aircraft",_plane]]] call CBE_fnc_CortexAttackRunFlares;
 */
params [["_job",createHashMap,[createHashMap]]];
private _aircraft=_job getOrDefault ["aircraft",objNull];
if (isNull _aircraft) exitWith {-1};
private _pilot=driver _aircraft;
private _group=group _pilot;
private _allowed=local _aircraft && {alive _aircraft} && {!isNull _pilot} && {alive _pilot}
    && {!isPlayer _pilot} && {!unitIsUAV _aircraft}
    && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
    && {!([] call CBE_fnc_CortexIsPaused)}
    && {[_group,"CBE_Cortex_AttackRunFlares_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group] call CBE_fnc_CortexIsEligible || {[_aircraft] call CBE_fnc_CortexAircraftEligible}};
if (!_allowed) exitWith {_aircraft setVariable ["CBE_Cortex_AttackFlareJob",false]; -1};
// The adaptive attack controller owns approach/departure bursts while it holds a finite plan.
// Keeping this sampler idle avoids duplicate releases without removing its fallback coverage.
if !((_aircraft getVariable ["CBE_Cortex_AirAttackPlan",[]]) isEqualTo []) exitWith {
    _job deleteAt "target";_job deleteAt "targetPoint";_job deleteAt "burst";1
};
if (isTouchingGround _aircraft || {speed _aircraft < 40}) exitWith {_job deleteAt "target"; _job deleteAt "burst"; 1};
if (combatMode _group in ["BLUE","GREEN"]) exitWith {_job deleteAt "target"; _job deleteAt "burst"; 1};
private _vectorValid={_this isEqualType [] && {count _this == 3}
    && {_this findIf {!(_x isEqualType 0) || {!finite _x}} < 0}};
private _targetValid={
    params ["_candidate"];
    !isNull _candidate && {alive _candidate} && {!captive _candidate}
        && {!(_candidate getVariable ["ace_captives_isSurrendering",false])}
        && {!(_candidate getVariable ["ace_captives_isHandcuffed",false])}
        && {(side _group) getFriend (side _candidate) < 0.6}
};
private _target=_job getOrDefault ["target",objNull];
private _point=_job getOrDefault ["targetPoint",[]];
if ("target" in _job && {!([_target] call _targetValid) || {!(_point call _vectorValid)}
    || {serverTime > (_job getOrDefault ["expires",0])}}) then {
    _target=objNull;_point=[];
    _job deleteAt "target";_job deleteAt "targetPoint";_job deleteAt "burst";
};
if (isNull _target) then {
    private _targetOwners=[];
    {
        if (!isNull _x && {alive _x}) then {_targetOwners pushBackUnique _x};
    } forEach ([effectiveCommander _aircraft,driver _aircraft,gunner _aircraft,commander _aircraft]
        +((crew _aircraft) select [0,12]));
    {
        private _candidate=assignedTarget _x;
        private _belief=[];
        if ([_candidate] call _targetValid && {_x knowsAbout _candidate >= 1}) then {
            _belief=_x getHideFrom _candidate;
        };
        if (_belief call _vectorValid && {_belief isNotEqualTo [0,0,0]}) exitWith {
            _target=_candidate;_point=ATLToASL _belief;
        };
    } forEach (_targetOwners select [0,16]);
    if (isNull _target) exitWith {};
    private _offset=_point vectorDiff (getPosASL _aircraft);
    if (vectorMagnitude _offset <= 1500 && {(velocity _aircraft) vectorDotProduct _offset > 0}
        && {serverTime >= (_aircraft getVariable ["CBE_Cortex_AttackFlareCooldown",0])}) then {
        _job set ["target",_target];_job set ["targetPoint",+_point];
        _job set ["expires",serverTime+90];
        _job set ["closest",vectorMagnitude _offset];
        _job set ["burst",3];
        _job set ["burstExpires",serverTime+8];
        _job set ["burstNext",serverTime];
        _aircraft setVariable ["CBE_Cortex_AttackFlareCooldown",serverTime+30,true];
        _aircraft setVariable ["CBE_Cortex_AttackFlarePhase","APPROACH",true];
    };
} else {
    private _offset=_point vectorDiff (getPosASL _aircraft);
    private _distance=vectorMagnitude _offset;
    private _closest=_job getOrDefault ["closest",_distance];
    _job set ["closest",_closest min _distance];
    if (_distance > _closest+100 && {(velocity _aircraft) vectorDotProduct _offset < 0}) then {
        _job set ["burst",3];
        _job set ["burstExpires",serverTime+8];
        _job set ["burstNext",serverTime];
        _job deleteAt "target";_job deleteAt "targetPoint";
        _aircraft setVariable ["CBE_Cortex_AttackFlareCooldown",serverTime+30,true];
        _aircraft setVariable ["CBE_Cortex_AttackFlarePhase","DEPARTURE",true];
    };
};
private _burst=_job getOrDefault ["burst",0];
if (_burst > 0 && {serverTime <= (_job getOrDefault ["burstExpires",serverTime])}
    && {serverTime >= (_job getOrDefault ["burstNext",0])}) then {
    // Count dispatched requests only. The helper does not acknowledge a native Fired event;
    // actual release/effectiveness must be observed separately. The original burst window bounds retries.
    if ([_aircraft] call CBE_fnc_CortexFireCountermeasure) then {
        _job set ["burst",_burst-1];
    };
    _job set ["burstNext",serverTime+0.8+random 0.8];
};
if (_burst > 0 && {serverTime > (_job getOrDefault ["burstExpires",serverTime])}) then {
    _job set ["burst",0];
};
1
