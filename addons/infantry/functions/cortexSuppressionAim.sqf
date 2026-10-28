/*
 * Author: WaldoTheWarfighter
 * Purpose: Resolve a believed suppression point to nearby terrain/cover's near face, rejecting unrelated obstructions.
 * Locality/authority: Read-only; callers own knowledge, weapon, ROE and friendly-fire admission.
 * Repeat/JIP: Stateless; at most one nearest terrain/object surface query per call, no workers or state.
 * Only a first hit within3m of supplied belief can qualify; aim stays0.05m before that face.
 * Queries beyond the native5000m limit refuse instead of treating missing hits as clearance.
 * Arguments: 0 shooter <OBJECT, objNull>; 1 believed ASL point <ARRAY, []>;
 * 2 minimum shooter-to-belief and shooter-to-face range <NUMBER, 20>.
 * Return Value: ARRAY - resolved ASL point, or [] if invalid, too close or obstructed away from belief.
 * Current callers: CortexFireControl, CortexVehicles.
 * Example: private _aim=[_gunner,_reportedASL,50] call CBE_fnc_CortexSuppressionAim;
 */
params [["_shooter",objNull,[objNull]],["_targetASL",[],[[]]],["_minimum",20,[0]]];
if (isNull _shooter || {count _targetASL != 3}
    || {_targetASL findIf {!(_x isEqualType 0) || {!(finite _x)}} >= 0}
    || {!finite _minimum} || {_minimum < 0}) exitWith {[]};
private _from=eyePos _shooter;
private _range=_from vectorDistance _targetASL;
if (_range < _minimum || {_range > 5000}) exitWith {[]};
private _platform=vehicle _shooter;
if (_platform == _shooter) then {_platform=objNull};
private _aimASL=+_targetASL;
private _hits=lineIntersectsSurfaces [_from,_targetASL,_shooter,_platform,true,1,"FIRE","GEOM"];
private _clear=true;
if (_hits isNotEqualTo []) then {
    private _hit=_hits select 0;
    private _surface=_hit select 0;
    // Terrain has no object handle. Its first surface obeys the same tight
    // belief envelope; a foreground hill/wall cannot qualify by material alone.
    _clear=_surface vectorDistance _targetASL <= 3;
    if (_clear) then {
        _aimASL=_surface vectorDiff ((_from vectorFromTo _surface) vectorMultiply 0.05);
    };
};
if (!_clear || {_from vectorDistance _aimASL < _minimum}) exitWith {[]};
_aimASL
