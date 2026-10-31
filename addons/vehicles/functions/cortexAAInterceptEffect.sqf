/*
 * Author: WaldoTheWarfighter
 * Purpose: Apply one scripted direct-pass fuse effect from a captured real AA bullet.
 * This is an explicit gameplay fuse approximation, never a claim of native projectile collision.
 * Locality/authority: Unscheduled current turret-owner callback only; both round and warned
 * missile must be local, at the exact captured occupied primary turret path. Scheduled direct calls refuse rather than carry stale geometry to effect.
 * Exact private episode, native shot parents, original deadlines, actual current positions and
 * armed real-shot state qualify the effect. No remote identity guess or nearest copy fallback.
 * Repeat/JIP: Finished episodes refuse effects even if their exact camera cleanup is pending.
 * One receipt per missile, no replay/worker. Unknown geometry, temporal gaps,
 * turning over5deg, submunition payloads or cross-owner projectiles refuse without effects.
 * A damaging warhead checks protected entities at its current position: max12m/four times
 * indirectHitRange, <=250m; at most64 entries evaluated. One veto per engine time sample prevents
 * repeated scans by other rounds in the same episode/frame. No clear result is cached.
 * Arguments: 0 episode HASHMAP,empty; 1 captured row ARRAY,empty, [round,previous round ASL,
 * previous missile ASL,time,shot origin ASL,previous missile direction,previous missile up,shot context,spot attempted];
 * 2 current round ASL ARRAY,[]; 3 current missile ASL ARRAY,[].
 * Return: BOOL,true only when triggerAmmo was requested; not physical destruction/interception proof.
 * Current caller: CortexAAIntercept STEP after its owner/task/ROE and temporal admission.
 * Example: private _requested=[_state,_row,_roundPos,_targetPos] call CBE_fnc_CortexAAInterceptEffect;
 */
params [["_episode",createHashMap,[createHashMap]],["_row",[],[[]]],
    ["_roundPos",[],[[]]],["_targetPos",[],[[]]]];
if (remoteExecutedOwner > 0 || {canSuspend} || {_episode getOrDefault ["finished",false]} || {count _row != 9}) exitWith {false};
_row params ["_round","_previousRound","_previousMissile","_at","_origin","_previousDir","_previousUp"];
private _vehicle=_episode getOrDefault ["vehicle",objNull];
private _missile=_episode getOrDefault ["missile",objNull];
private _gunner=_episode getOrDefault ["gunner",objNull];
private _group=_episode getOrDefault ["group",grpNull];
private _source=_episode getOrDefault ["source",objNull];
private _victim=_episode getOrDefault ["victim",_vehicle];
private _token=_episode getOrDefault ["token",""];
private _turret=_episode getOrDefault ["turret",[]];
private _until=_episode getOrDefault ["until",-1];
if (isNull _victim || {!alive _victim} || {isNull _round} || {isNull _missile} || {isNull _vehicle} || {isNull _gunner} || {isNull _source}
    || {!local _round} || {!local _missile} || {!local _vehicle} || {!local _gunner} || {!local _group}
    || {!alive _round} || {!alive _missile} || {!alive _vehicle}
    || {gunner _vehicle != _gunner} || {group _gunner != _group}
    || {!(_turret isEqualType [])} || {count _turret < 1} || {count _turret > 8}
    || {_turret findIf {!(_x isEqualType 0) || {!finite _x}
        || {_x != floor _x} || {_x < 0} || {_x >= 32}} >= 0}
    || {!(_vehicle turretLocal _turret)} || {_vehicle turretUnit _turret != _gunner}
    || {time >= _until} || {time-_at <= 0} || {time-_at > 0.1}
    || {(_group getVariable ["CBE_AIPass_Epoch",0]) != (_episode getOrDefault ["ownerEpoch",-1])}
    || {(_gunner getVariable ["CBE_AA_InterceptOwner",[]]) isNotEqualTo [_token,_until]}
    || {((_vehicle getVariable ["CBE_AA_Intercept",createHashMap]) getOrDefault ["token",""]) != _token}
    || {!isNil {_missile getVariable "CBE_AA_FuseReceipt"}}
    || {(_episode getOrDefault ["rounds",[]]) findIf {(_x select 0) == _round && {_x isEqualTo _row}} < 0}
    || {!([_gunner,_token] call CBE_fnc_CortexActorFireTaskAvailable)}
    || {!(_gunner checkAIFeature "FIREWEAPON")}
    || {!(combatMode _group in ["YELLOW","RED"])} || {!(unitCombatMode _gunner in ["YELLOW","RED"])}
    || {!(missionNamespace getVariable ["CBE_AIPass_Active",false])} || {[] call CBE_fnc_CortexIsPaused}
    || {!([_group,"CBE_AIPass_AAIntercept_Enable",false] call CBE_fnc_CortexFeatureEnabled)}
    || {!([_missile,_group,_source] call CBE_fnc_CortexAAThreat)}
    || {(side _group) getFriend (side _victim) < 0.6}) exitWith {false};
private _validVectors=true;
{
    if (count _x != 3 || {_x findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}) exitWith {_validVectors=false};
} forEach [_previousRound,_previousMissile,_origin,_previousDir,_previousUp,_roundPos,_targetPos];
if (!_validVectors || {_roundPos distance (getPosASL _round) > 0.01}
    || {_targetPos distance (getPosASL _missile) > 0.01}
    || {_targetPos distance (getPosASL _vehicle) < 30}
    || {_targetPos distance (getPosASL _victim) < 30}
    || {(_targetPos select 2)-(getTerrainHeightASL _targetPos) < 5}) exitWith {false};
private _parents=getShotParents _round;private _targetParents=getShotParents _missile;
if ((_parents param [0,objNull]) != _vehicle || {(_parents param [1,objNull]) != _gunner}
    || {(_targetParents param [0,objNull]) != _source}) exitWith {false};
private _roundInfo=getShotInfo _round;
if (count _roundInfo < 8 || {!(_roundInfo select 5)} || {_roundInfo select 7}
    || {(_roundInfo select 1) > 0}) exitWith {false};
private _ammo=configFile >> "CfgAmmo" >> typeOf _round;
private _targetAmmo=configFile >> "CfgAmmo" >> typeOf _missile;
if (toLowerANSI getText (_ammo >> "simulation") != "shotbullet"
    || {getNumber (_ammo >> "hit") <= 0} || {getNumber (_ammo >> "indirectHit") > 0}
    || {getNumber (_ammo >> "explosive") > 0}
    || {typeOf _round != getText (configFile >> "CfgMagazines" >> (_episode get "magazine") >> "ammo")}
    || {!(toLowerANSI getText (_targetAmmo >> "simulation") in ["shotmissile","shotrocket"])}
    || {getText (_targetAmmo >> "submunitionAmmo") != ""}
    || {getArray (_targetAmmo >> "submunitionAmmo") isNotEqualTo []}) exitWith {false};
private _direction=vectorDir _missile;private _up=vectorUp _missile;
if ((_direction vectorCos _previousDir) < cos 5 || {(_up vectorCos _previousUp) < cos 5}) exitWith {false};
// Cache only model geometry for this exact missile/episode, never impact permission.
private _geometry=_episode getOrDefault ["fuseGeometry",[]];
if !(_episode getOrDefault ["fuseGeometryRead",false]) then {
    private _box=boundingBoxReal _missile;
    if (count _box >= 2) then {
        private _minimum=_box select 0;private _maximum=_box select 1;
        private _dimensions=_maximum vectorDiff _minimum;
        private _widths=_dimensions apply {abs _x};_widths sort true;
        private _radius=((_widths select 0)*0.5) min 0.15;
        private _centre=(_maximum vectorAdd _minimum) vectorMultiply 0.5;
        if (_radius >= 0.02 && {vectorMagnitude _centre <= 4}) then {_geometry=[_centre,_radius]};
    };
    _episode set ["fuseGeometry",_geometry];_episode set ["fuseGeometryRead",true];
};
if (_geometry isEqualTo []) exitWith {false};
_geometry params ["_centre","_radius"];
private _modelOffset={
    params ["_forward","_upVector"];
    ((_forward vectorCrossProduct _upVector) vectorMultiply (_centre select 0))
        vectorAdd (_forward vectorMultiply (_centre select 1))
        vectorAdd (_upVector vectorMultiply (_centre select 2))
};
private _previousCentre=_previousMissile vectorAdd ([_previousDir,_previousUp] call _modelOffset);
private _currentCentre=_targetPos vectorAdd ([_direction,_up] call _modelOffset);
private _start=_previousRound vectorDiff _previousCentre;
private _end=_roundPos vectorDiff _currentCentre;private _delta=_end vectorDiff _start;
private _squared=_delta vectorDotProduct _delta;
if (_squared < 0.0001) exitWith {false};
private _fraction=(-(_start vectorDotProduct _delta)/_squared);
// Require an observed interior closest pass. End-point proximity alone is not a crossing.
if (_fraction <= 0 || {_fraction >= 1}) exitWith {false};
private _distance=vectorMagnitude (_start vectorAdd (_delta vectorMultiply _fraction));
if (_distance > _radius) exitWith {false};
private _pass=_previousRound vectorAdd ((_roundPos vectorDiff _previousRound) vectorMultiply _fraction);
private _arming=getNumber (_ammo >> "fuseDistance");
if (_pass distance _origin < (_arming max 3) || {_pass distance (getPosASL _vehicle) < 30}
    || {_pass distance (getPosASL _victim) < 30}
    || {_pass distance (getPosASL _source) < 3}) exitWith {false};
// A scripted fuse detonates the incoming warhead here, not merely our harmless bullet.
// Reuse the loaded-fire policy's conservative radius, including aircraft/ship occupants.
// Only a confirmed direct pass reaches this query; no clear result grants later permission.
private _blastRange=getNumber (_targetAmmo >> "indirectHitRange");
private _blastDamage=getNumber (_targetAmmo >> "indirectHit");
private _explosive=getNumber (_targetAmmo >> "explosive");
if (!finite _blastRange || {_blastRange < 0} || {!finite _blastDamage} || {_blastDamage < 0}
    || {!finite _explosive} || {_explosive < 0}) exitWith {false};
private _blastRadius=if (_blastDamage > 0 || {_explosive > 0}) then {12 max (4*_blastRange)} else {0};
if (_blastRadius > 250) exitWith {false};
if (_blastRadius > 0) then {
    if ((_episode getOrDefault ["fuseCollateralVetoAt",-1]) != time) then {
        private _area=[ASLToAGL _targetPos,_blastRadius,_blastRadius,0,false,_blastRadius];
        private _near=_area nearEntities [["CAManBase","LandVehicle","Air","Ship"],false,true,true];
        private _unsafe=count _near > 64;
        if (!_unsafe) then {
            private _side=side _group;
            _unsafe=_near findIf {
                private _other=_x;
                private _otherSide=if (_other isKindOf "CAManBase") then {side group _other} else {side _other};
                alive _other && {captive _other || {_other getVariable ["ace_captives_isSurrendering",false]}
                    || {_other getVariable ["ace_captives_isHandcuffed",false]}
                    || {_otherSide == civilian} || {_side getFriend _otherSide >= 0.6}}
            } >= 0;
        };
        if (_unsafe) then {_episode set ["fuseCollateralVetoAt",time]};
    };
};
// Keep this refusal at function scope: exiting the if block would still trigger the warhead.
if ((_episode getOrDefault ["fuseCollateralVetoAt",-1]) == time) exitWith {false};
// Both native projectiles and their actual same-owner samples still exist here. This
// command detonates the warhead where it is NOW, not at the historical closest pass.
// Record that latency; never teleport it, spawn an explosion copy or infer a vanished shot.
_missile setVariable ["CBE_AA_FuseReceipt",[_token,_round,serverTime,_distance,_radius,time-_at]];
_episode set ["effect",["FUSE_REQUESTED",serverTime,_distance,_radius,time-_at]];
triggerAmmo _missile;
true
