/*
 * Author: WaldoTheWarfighter
 * Purpose: Bounded local CIWS aim calibration from measured, stable-track bullet misses.
 * Locality/authority: Current CBE AA episode owner only. Returns lead seconds/elevation radians;
 * no skill, projectile, movement, target knowledge, firing or damage command is issued.
 * Repeat/JIP: Finished episodes cannot read/apply or update calibration, including pending camera cleanup.
 * At most8 ammo/munition-class rows and4 estimates/axis, no worker/network replay.
 * Owner/epoch/gunner/exact turret path/weapon station changes invalidate history. Corrections halve every30s and expire60s.
 * Three consistent estimates/axis within30s are required; rejected axes cannot refresh learning.
 * Each accepted update is bounded; each accepted update moves20percent toward the median,
 * capped0.005s/0.0005rad per sample and0.05s/0.005rad total. No perfect-hit or accuracy guarantee.
 * Arguments: 0 episode HASHMAP,empty; 1 mode STRING,READ (READ/SAMPLE);
 * 2 sample ARRAY,[] [miss vector,actual target ASL,flight time,shot context]. Context is
 * [shot time,target ASL,target velocity,applied correction pair,first observed round ASL].
 * Return: ARRAY [lead seconds,elevation radians]. Zero when history/admission is unavailable.
 * Current caller: CortexAAIntercept; at most one SAMPLE attempt/captured real round.
 * Example: private _correction=[_state] call CBE_fnc_CortexAASpot;
 */
params [["_episode",createHashMap,[createHashMap]],["_mode","READ",[""]],["_sample",[],[[]]]];
private _vehicle=_episode getOrDefault ["vehicle",objNull];
private _gunner=_episode getOrDefault ["gunner",objNull];private _group=_episode getOrDefault ["group",grpNull];
private _missile=_episode getOrDefault ["missile",objNull];
private _until=_episode getOrDefault ["until",-1];
private _turret=_episode getOrDefault ["turret",[]];
if (remoteExecutedOwner > 0 || {_episode getOrDefault ["finished",false]} || {isNull _vehicle} || {isNull _gunner} || {isNull _missile}
    || {!local _vehicle} || {!local _gunner} || {!local _missile}
    || {gunner _vehicle != _gunner} || {!(_turret isEqualType [])}
    || {count _turret < 1} || {count _turret > 8}
    || {_turret findIf {!(_x isEqualType 0) || {!finite _x}
        || {_x != floor _x} || {_x < 0} || {_x >= 32}} >= 0}
    || {_vehicle turretUnit _turret != _gunner} || {!(_vehicle turretLocal _turret)}
    || {group _gunner != _group} || {!local _group}
    || {time >= _until} || {(_group getVariable ["CBE_AIPass_Epoch",0]) != (_episode getOrDefault ["ownerEpoch",-1])}) exitWith {[0,0]};
private _identity=[clientOwner,_group,_episode get "ownerEpoch",_gunner,+_turret,_episode get "weapon",_episode get "muzzle",_episode get "magazine"];
private _cache=_vehicle getVariable ["CBE_AA_Corrections",[[],[]]];
private _rows=if ((_cache select 0) isEqualTo _identity) then {+((_cache select 1) select [0,8])} else {[]};
private _ammo=getText (configFile >> "CfgMagazines" >> (_episode get "magazine") >> "ammo");
private _class=typeOf _missile;
private _index=_rows findIf {(_x select 0) == _ammo && {(_x select 1) == _class}};
private _entry=if (_index >= 0) then {+(_rows select _index)} else {[_ammo,_class,0,0,time,[],[]]};
private _age=(time-(_entry select 4)) max 0;
private _decay=if (_age <= 60) then {2^(-_age/30)} else {0};
private _lead=(_entry select 2)*_decay;private _elevation=(_entry select 3)*_decay;
if (_mode != "SAMPLE") exitWith {[_lead,_elevation]};
if (count _sample != 4) exitWith {[_lead,_elevation]};
_sample params ["_miss","_actual","_flight","_context"];
if (count _context != 5 || {_flight <= 0} || {_flight > 2}
    || {vectorMagnitude _miss > 6}) exitWith {[_lead,_elevation]};
_context params ["_shotAt","_atFire","_velocity","_applied","_origin"];
if (time-_shotAt > 2.1 || {_actual distance (_atFire vectorAdd (_velocity vectorMultiply _flight)) > 2}) exitWith {[_lead,_elevation]};
private _range=_origin distance _atFire;
if (_range < 50) exitWith {[_lead,_elevation]};
private _los=_origin vectorFromTo _atFire;
private _cross=_velocity vectorDiff (_los vectorMultiply (_velocity vectorDotProduct _los));
private _crossSpeed=vectorMagnitude _cross;
private _along=if (_crossSpeed >= 5) then {_cross vectorMultiply (1/_crossSpeed)} else {[0,0,0]};
private _up=[0,0,1] vectorDiff (_los vectorMultiply (_los select 2));
_up=_up vectorDiff (_along vectorMultiply (_up vectorDotProduct _along));
private _upMagnitude=vectorMagnitude _up;
private _leadSamples=if (_age <= 60) then {+(_entry select 5)} else {[]};
private _elevationSamples=if (_age <= 60) then {+(_entry select 6)} else {[]};
_leadSamples=_leadSamples select {time-(_x select 1) <= 30};
_elevationSamples=_elevationSamples select {time-(_x select 1) <= 30};
private _leadAdded=false;private _elevationAdded=false;
if (_crossSpeed >= 5) then {
    private _needed=(_applied select 0)-(_miss vectorDotProduct _along)/_crossSpeed;
    if (abs _needed <= 0.05) then {_leadSamples pushBack [_needed,time];_leadAdded=true};
};
if (_upMagnitude > 0.1) then {
    private _needed=(_applied select 1)-(_miss vectorDotProduct (_up vectorMultiply (1/_upMagnitude)))/_range;
    if (abs _needed <= 0.005) then {_elevationSamples pushBack [_needed,time];_elevationAdded=true};
};
if (!_leadAdded && {!_elevationAdded}) exitWith {[_lead,_elevation]};
private _adjust={
    params ["_samples","_current","_step"];
    if (count _samples > 4) then {_samples deleteAt 0};
    if (count _samples < 3) exitWith {_current};
    private _sorted=_samples apply {_x select 0};_sorted sort true;
    if ((_sorted select ((count _sorted)-1))-(_sorted select 0) > 4*_step) exitWith {_current};
    private _n=count _sorted;private _median=_sorted select floor (_n/2);
    if (_n mod 2 == 0) then {_median=(_median+(_sorted select ((_n/2)-1)))*0.5};
    _current+(((_median-_current)*0.2 max -_step) min _step)
};
if (_leadAdded) then {_lead=[_leadSamples,_lead,0.005] call _adjust};
if (_elevationAdded) then {_elevation=[_elevationSamples,_elevation,0.0005] call _adjust};
_entry=[_ammo,_class,(_lead max -0.05) min 0.05,(_elevation max -0.005) min 0.005,time,_leadSamples,_elevationSamples];
if (_index >= 0) then {_rows deleteAt _index};
_rows pushBack _entry;if (count _rows > 8) then {_rows deleteAt 0};
_vehicle setVariable ["CBE_AA_Corrections",[_identity,_rows]];
[_entry select 2,_entry select 3]
