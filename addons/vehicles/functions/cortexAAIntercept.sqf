/*
 * Author: WaldoTheWarfighter
 * START searches bounded station capability; each STEP freshly reads only its exact admitted muzzle.
 * Purpose: Finite experimental point-defence aiming and real-shot observation for a native
 * incoming-missile warning. This is the aim/shot building block, with an optional owner-local measured direct-pass fuse effect.
 * Locality/authority: Current local AI main turret [0] only. Existing task/ROE/owner checks apply.
 * No radar, skill, movement, ammunition creation or projectile steering is changed.
 * Explosive shotBullet cannons may aim/fire through the loaded-magazine blast safety check.
 * Only nonexplosive same-owner real bullet passes may request a missile fuse; effect helper owns that policy.
 * Explosive cannon impacts remain native; shots and closest passes are not interception proof.
 * Repeat/JIP: One eight-second episode/platform, max four local platforms, sixteen fire requests,
 * eight observed rounds and 160 steps. New warnings cannot renew an active episode. No JIP replay.
 * Temporary native point locks release at target/limit; an observed unlocked turret ends the episode.
 * The fire lease expires at the original deadline even after discarded cleanup.
 * Measured stable-track miss calibration may adjust later aim through bounded CortexAASpot.
 * Exact unchanged camera point may be unlocked; successor locks/orders/crew always win.
 * Cleanup retains exact fire-owner proof and current actor/platform external-control gates,
 * independently of feature enablement and original epoch. Yielding does not cancel native fire.
 * Arguments: 0 vehicle OBJECT,objNull; 1 mode STRING,START (START/STEP/SHOT/RELEASE);
 * 2 payload ARRAY,[] (START: [canonical shared warning ARRAY8] or native own receipt;
 * STEP: [job state HASHMAP]; SHOT: native Fired arguments).
 * Return: START/SHOT/RELEASE BOOL; STEP NUMBER next delay or -1. Fuse request is not physical intercept proof.
 * Callers: CortexAAObserve Fired/cleanup, CortexAAAllocate START and owner-local scheduler adapter.
 * Example: [_vehicle,"START"] call CBE_fnc_CortexAAIntercept;
 */
params [["_vehicle",objNull,[objNull]],["_mode","START",[""]],["_payload",[],[[]]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {[-1,false] select (_mode != "STEP")};
if (isNull _vehicle) exitWith {
    if (_mode == "STEP") then {
        private _gone=_payload param [0,createHashMap,[createHashMap]];
        private _actor=_gone getOrDefault ["gunner",objNull];
        private _lease=[_gone getOrDefault ["token",""],_gone getOrDefault ["until",-1]];
        if (!isNull _actor && {(_actor getVariable ["CBE_AA_InterceptOwner",[]]) isEqualTo _lease}) then {
            _actor setVariable ["CBE_AA_InterceptOwner",nil];
        };
        _gone set ["finished",true];
        missionNamespace setVariable ["CBE_AA_InterceptVehicles",
            (missionNamespace getVariable ["CBE_AA_InterceptVehicles",[]])-[objNull]];
    };
    [-1,false] select (_mode != "STEP")
};
private _state=_vehicle getVariable ["CBE_AA_Intercept",createHashMap];
private _finish={
    params [["_reason","RELEASED"]];
    if (count _state == 0) exitWith {false};
    private _actor=_state get "gunner";private _token=_state get "token";
    private _turret=_state get "turret";
    private _applied=_state getOrDefault ["applied",[]];
    private _releaseGroup=group _actor;
    // Release may remove our exact old lock after feature shutdown or epoch change,
    // but locality and value equality alone do not override a current controller.
    if (!isNull _actor && {local _actor} && {local _vehicle} && {gunner _vehicle == _actor}
        && {!isNull _releaseGroup} && {local _releaseGroup}
        && {(_actor getVariable ["CBE_AA_InterceptOwner",[]]) isEqualTo [_token,_state get "until"]}
        && {!([_releaseGroup,false,_actor] call CBE_fnc_CortexExternalTakeover)}
        && {!([_vehicle] call CBE_fnc_CompatibilityExternalControl)}
        && {_vehicle turretLocal _turret} && {_applied isNotEqualTo []}) then {
        private _lock=_vehicle lockedCameraTo _turret;
        if (!isNil "_lock" && {_lock isEqualTo _applied}) then {
            _vehicle lockCameraTo [objNull,_turret,false];
        };
    };
    if (!isNull _actor && {(_actor getVariable ["CBE_AA_InterceptOwner",[]]) isEqualTo [_token,_state get "until"]}) then {
        _actor setVariable ["CBE_AA_InterceptOwner",nil];
    };
    _state set ["finished",true];
    _vehicle setVariable ["CBE_AA_InterceptResult",[_reason,_state getOrDefault ["shots",0],
        _state getOrDefault ["closestPass",-1],_state get "until",_state getOrDefault ["effect",[]]]];
    _vehicle setVariable ["CBE_AA_Intercept",nil];
    missionNamespace setVariable ["CBE_AA_InterceptVehicles",
        (missionNamespace getVariable ["CBE_AA_InterceptVehicles",[]])-[_vehicle,objNull]];
    true
};
if (_mode == "RELEASE") exitWith {[] call _finish};
if (_mode == "SHOT") exitWith {
    if (count _state == 0 || {!local _vehicle} || {time > (_state getOrDefault ["shotWindow",-1])}) exitWith {false};
    _payload params ["","_weapon","_muzzle","","_ammo","_magazine","_round","_operator"];
    if (isNull _round || {!local _round} || {_operator != (_state get "gunner")}
        || {_weapon != (_state get "weapon")} || {_muzzle != (_state get "muzzle")}
        || {_magazine != (_state get "magazine")}
        || {toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation") != "shotbullet"}) exitWith {false};
    private _rounds=_state get "rounds";
    if (count _rounds >= 8 || {_rounds findIf {(_x select 0) == _round} >= 0}) exitWith {false};
    private _shotContext=+(_state getOrDefault ["aimContext",[]]);
    if (count _shotContext == 5) then {
        _shotContext set [0,time];_shotContext set [1,getPosASL (_state get "missile")];
        _shotContext set [2,velocity (_state get "missile")];
        _shotContext set [4,_vehicle modelToWorldWorld (_vehicle selectionPosition [_state get "barrel","Memory"])];
    };
    _rounds pushBack [_round,getPosASL _round,getPosASL (_state get "missile"),time,
        getPosASL _round,vectorDir (_state get "missile"),vectorUp (_state get "missile"),_shotContext,false];
    _state set ["shots",(_state get "shots")+1];
    true
};
if (_mode == "START") exitWith {
    if (count _state > 0 && {time >= (_state get "until")}) then {
        ["EXPIRED"] call _finish;_state=createHashMap;
    };
    if (count _state > 0) exitWith {false};
    private _gunner=gunner _vehicle;private _group=group _gunner;
    if (!local _vehicle || {isNull _gunner} || {!local _gunner}
        || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {!simulationEnabled _gunner} || {isObjectHidden _gunner}
        || {!([_group,"CBE_AIPass_AAIntercept_Enable",false] call CBE_fnc_CortexFeatureEnabled)}
        || {!([_gunner] call CBE_fnc_CortexActorFireTaskAvailable)}
        || {!([_group] call CBE_fnc_CortexIsEligible)}
        || {!([_gunner] call CBE_fnc_CortexCombatEffective)}
        || {isPlayer _gunner} || {!isNull remoteControlled _gunner}
        || {toLowerANSI getText (configOf _vehicle >> "editorSubcategory") != "edsubcat_aas"}) exitWith {false};
    private _warning=_vehicle getVariable ["CBE_AA_MissileWarning",[]];
    private _victim=_vehicle;
    if (_payload isNotEqualTo []) then {
        private _shared=_payload param [0,[],[[]]];
        private _tracks=_group getVariable ["CBE_AA_WarningTracks",[]];
        if (count _shared != 8 || {count _tracks != 3} || {(_tracks select 0) != clientOwner}
            || {(_tracks select 1) != (_group getVariable ["CBE_AIPass_Epoch",0])}
            || {(_tracks select 2) findIf {_x isEqualTo _shared} < 0}) exitWith {_warning=[]};
        _warning=_shared select [0,6];_victim=_shared select 6;
    };
    if (count _warning != 6 || {(_warning select 0) != clientOwner} || {(_warning select 1) != _group}
        || {(_warning select 2) != (_group getVariable ["CBE_AIPass_Epoch",0])}
        || {serverTime >= (_warning select 3)} || {isNull (_warning select 4)}
        || {isNull (_warning select 5)} || {(side _group) getFriend (side (_warning select 5)) >= 0.6}) exitWith {false};
    if (!([_vehicle,_gunner,_group,_victim] call CBE_fnc_CortexAAWarningLink)) exitWith {false};
    // Reap at most four terminal local records, including work discarded on master stop.
    {
        private _old=_x getVariable ["CBE_AA_Intercept",createHashMap];
        if (count _old > 0 && {time >= (_old get "until")}) then {[_x,"RELEASE"] call CBE_fnc_CortexAAIntercept};
    } forEach ((missionNamespace getVariable ["CBE_AA_InterceptVehicles",[]]) select [0,4]);
    private _registry=(missionNamespace getVariable ["CBE_AA_InterceptVehicles",[]])-[objNull];
    if (count _registry >= 4) exitWith {false};
    private _observation=createHashMap;
    if (!([_vehicle,_gunner,objNull,_observation,false,false,true] call CBE_fnc_CortexGroundFireReady)
        || {!((_observation get "loadedTurret") isEqualTo [0])}) exitWith {false};
    private _turret=[0];
    private _lock=_vehicle lockedCameraTo _turret;
    if (!isNil "_lock" && {!(_lock isEqualType objNull && {isNull _lock})}) exitWith {false};
    private _magazine=_observation get "loadedMagazine";
    private _speed=getNumber (configFile >> "CfgMagazines" >> _magazine >> "initSpeed");
    private _weaponConfig=configFile >> "CfgWeapons" >> (_observation get "loadedWeapon");
    private _muzzleConfig=_weaponConfig >> (_observation get "loadedMuzzle");
    private _override=getNumber (_weaponConfig >> "initSpeed");
    if (isNumber (_muzzleConfig >> "initSpeed")) then {_override=getNumber (_muzzleConfig >> "initSpeed")};
    if (_override > 0) then {_speed=_override};
    if (_override < 0) then {_speed=_speed*(-_override)};
    private _ammoConfig=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
    private _gravity=if (isNumber (_ammoConfig >> "coefGravity")) then {getNumber (_ammoConfig >> "coefGravity")} else {1};
    if (!finite _speed || {!finite _gravity} || {_gravity < 0} || {_gravity > 4}) exitWith {false};
    private _turretConfig=configOf _vehicle >> "Turrets";
    private _main=("true" configClasses _turretConfig) param [0,configNull];
    private _barrel=getText (_main >> "gunBeg");
    private _optic=getText (_main >> "memoryPointGunnerOptics");
    private _selections=_vehicle selectionNames "Memory";
    if (_speed < 100 || {_speed > 2000} || {!(_barrel in _selections)} || {!(_optic in _selections)}) exitWith {false};
    private _serial=(_vehicle getVariable ["CBE_AA_InterceptSerial",0])+1;
    _vehicle setVariable ["CBE_AA_InterceptSerial",_serial];
    private _token=format ["AA:%1:%2:%3",clientOwner,_serial,netId _vehicle];
    _state=createHashMapFromArray [["vehicle",_vehicle],["group",_group],["gunner",_gunner],
        ["token",_token],["turret",_turret],["missile",_warning select 4],["source",_warning select 5],
        ["weapon",_observation get "loadedWeapon"],["muzzle",_observation get "loadedMuzzle"],
        ["magazine",_magazine],["directFuse",getNumber (_ammoConfig >> "indirectHit") <= 0 && {getNumber (_ammoConfig >> "explosive") <= 0}],["speed",_speed],["gravity",_gravity],["barrel",_barrel],["optic",_optic],
        ["ownerEpoch",_group getVariable ["CBE_AIPass_Epoch",0]],
        ["route",[_group] call CBE_fnc_NativeOrderReceipt],["command",currentCommand _gunner],
        ["target",getAttackTarget _gunner],["assigned",assignedTarget _gunner],
        ["until",time+(8 min ((_warning select 3)-serverTime))],["victim",_victim],["linkDue",time+1],["steps",0],["attempts",0],["shots",0],["rounds",[]],["nextFire",time+0.5]];
    _vehicle setVariable ["CBE_AA_Intercept",_state];
    _gunner setVariable ["CBE_AA_InterceptOwner",[_token,_state get "until"]];
    _registry pushBackUnique _vehicle;missionNamespace setVariable ["CBE_AA_InterceptVehicles",_registry];
    [{params ["_job"];[_job get "vehicle","STEP",[_job]] call CBE_fnc_CortexAAIntercept},
        // Deliberately no scheduler group key: cleanup must observe locality/epoch loss
        // itself rather than be discarded before exact local lock/marker retirement.
        createHashMapFromArray [["vehicle",_vehicle],["gunner",_gunner],["token",_token],
            ["until",_state get "until"],["subsystem","TACTICS"]],
        0,format ["AA_INTERCEPT:%1",_token]] call CBE_fnc_CortexQueueJob;
    true
};
if (_mode != "STEP" || {count _state == 0}) exitWith {-1};
private _job=_payload param [0,createHashMap,[createHashMap]];
if ((_job getOrDefault ["token",""]) != (_state get "token")) exitWith {-1};
private _gunner=_state get "gunner";private _group=_state get "group";
private _missile=_state get "missile";private _turret=_state get "turret";
private _token=_state get "token";
private _valid=local _vehicle && {alive _vehicle} && {local _gunner} && {local _group}
    && {gunner _vehicle == _gunner} && {_vehicle turretLocal _turret}
    && {group _gunner == _group} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
    && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
    && {(_group getVariable ["CBE_AIPass_Epoch",0]) == (_state get "ownerEpoch")}
    && {(_gunner getVariable ["CBE_AA_InterceptOwner",[]]) isEqualTo [_token,_state get "until"]}
    && {missionNamespace getVariable ["CBE_AIPass_Active",false]} && {!([] call CBE_fnc_CortexIsPaused)}
    && {[_group,"CBE_AIPass_AAIntercept_Enable",false] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}
    && {[_group] call CBE_fnc_CortexIsEligible} && {[_gunner] call CBE_fnc_CortexCombatEffective}
    && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
    && {isNull (_gunner getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
    && {([_gunner] call CBE_fnc_CortexExternalOwner) == ""}
    && {!([_gunner] call CBE_fnc_CompatibilityExternalControl)}
    && {[_gunner,_token] call CBE_fnc_CortexActorFireTaskAvailable}
    && {_gunner checkAIFeature "FIREWEAPON"}
    && {combatMode _group in ["YELLOW","RED"]} && {unitCombatMode _gunner in ["YELLOW","RED"]}
    && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_state get "route")}
    && {currentCommand _gunner == (_state get "command")}
    && {getAttackTarget _gunner == (_state get "target")} && {assignedTarget _gunner == (_state get "assigned")};
if (!_valid || {time >= (_state get "until")} || {(_state get "steps") >= 160}) exitWith {
    ["EXPIRED_OR_REPLACED"] call _finish;-1
};
if (isNull _missile || {!alive _missile} || {isNull (_state get "source")}
    || {(side _group) getFriend (side (_state get "source")) >= 0.6}) exitWith {["THREAT_ENDED"] call _finish;-1};
private _victim=_state getOrDefault ["victim",_vehicle];
if (isNull _victim || {!alive _victim} || {(side _group) getFriend (side _victim) < 0.6}) exitWith {["DEFENDED_ASSET_LOST"] call _finish;-1};
if (time >= (_state getOrDefault ["linkDue",-1])) then {
    _state set ["linkDue",time+1];
    if (!([_vehicle,_gunner,_group,_victim] call CBE_fnc_CortexAAWarningLink)) then {_state set ["linkLost",true]};
};
if (_state getOrDefault ["linkLost",false]) exitWith {["WARNING_LINK_LOST"] call _finish;-1};
private _homing=missileTarget _missile;
if (!isNull _homing && {alive _homing}
    && {_homing isKindOf "Air" || {_homing isKindOf "LandVehicle"}
        || {_homing isKindOf "Ship"} || {_homing isKindOf "CAManBase"}}
    && {vehicle _homing != _victim}) exitWith {["RETARGETED"] call _finish;-1};
private _applied=_state getOrDefault ["applied",[]];
private _lock=_vehicle lockedCameraTo _turret;
if ((_applied isEqualTo [] && {!isNil "_lock"}
    && {!(_lock isEqualType objNull && {isNull _lock})})
    || {_applied isNotEqualTo [] && {isNil "_lock" || {!(_lock isEqualTo _applied)}}}) exitWith {
    ["CAMERA_REPLACED"] call _finish;-1
};
private _targetPos=getPosASL _missile;
private _rounds=_state get "rounds";
private _effectRequested=false;
// A measured same-time relative segment, never an extrapolated vanished projectile.
for "_i" from ((count _rounds)-1) to 0 step -1 do {
    private _row=_rounds select _i;private _round=_row select 0;private _dt=time-(_row select 3);
    if (isNull _round || {_dt > 0.2}) then {_rounds deleteAt _i} else {
        if (_dt > 0) then {
            private _roundPos=getPosASL _round;
            private _start=(_row select 1) vectorDiff (_row select 2);
            private _end=_roundPos vectorDiff _targetPos;private _delta=_end vectorDiff _start;
            private _length=_delta vectorDotProduct _delta;
            private _fraction=if (_length > 0.0001) then {((-(_start vectorDotProduct _delta)/_length) max 0) min 1} else {0};
            private _miss=vectorMagnitude (_start vectorAdd (_delta vectorMultiply _fraction));
            private _best=_state getOrDefault ["closestPass",-1];
            if (_best < 0 || {_miss < _best}) then {_state set ["closestPass",_miss]};
            if (!(_row select 8) && {_dt <= 0.1} && {_fraction > 0} && {_fraction < 1}) then {
                _row set [8,true];
                private _context=_row select 7;
                if (count _context == 5) then {
                    private _passTarget=(_row select 2) vectorAdd ((_targetPos vectorDiff (_row select 2)) vectorMultiply _fraction);
                    private _error=_start vectorAdd (_delta vectorMultiply _fraction);
                    private _flight=(_row select 3)+_dt*_fraction-(_context select 0);
                    [_state,"SAMPLE",[_error,_passTarget,_flight,_context]] call CBE_fnc_CortexAASpot;
                };
            };
            // Broad proximity only admits the exact, armed same-owner fuse policy.
            if (_miss <= 5 && {_state getOrDefault ["directFuse",false]}
                && {[_state,_row,_roundPos,_targetPos] call CBE_fnc_CortexAAInterceptEffect}) then {
                _effectRequested=true;
            } else {
                _rounds set [_i,[_round,_roundPos,+_targetPos,time,_row select 4,vectorDir _missile,vectorUp _missile,_row select 7,_row select 8]];
            };
        };
    };
    if (_effectRequested) exitWith {};
};
if (_effectRequested) exitWith {["FUSE_REQUESTED"] call _finish;-1};
private _origin=_vehicle modelToWorldWorld (_vehicle selectionPosition [_state get "barrel","Memory"]);
private _range=_origin distance _targetPos;
if (_range < 30 || {_range > 1500} || {(_targetPos select 2)-(getTerrainHeightASL _targetPos) < 5}) exitWith {
    ["OUTSIDE_ENVELOPE"] call _finish;-1
};
private _velocity=velocity _missile;
private _relative=_targetPos vectorDiff _origin;
private _speed=_state get "speed";
// Solve the positive constant-velocity interception time, rather than clipping an
// unreachable target into an apparently feasible aim point. Drag remains unmodelled.
private _a=(_velocity vectorDotProduct _velocity)-_speed*_speed;
private _b=2*(_relative vectorDotProduct _velocity);
private _c=_relative vectorDotProduct _relative;
private _tof=-1;
if (abs _a < 0.001) then {
    if (abs _b > 0.001) then {_tof=-_c/_b};
} else {
    private _disc=_b*_b-4*_a*_c;
    if (_disc >= 0) then {
        private _first=(-_b-sqrt _disc)/(2*_a);private _second=(-_b+sqrt _disc)/(2*_a);
        if (_first > 0) then {_tof=_first};
        if (_second > 0 && {_tof <= 0 || {_second < _tof}}) then {_tof=_second};
    };
};
if (!finite _tof || {_tof <= 0} || {_tof > 2} || {abs speed _vehicle > 3}) exitWith {
    ["NO_FINITE_SOLUTION"] call _finish;-1
};
private _aim=_targetPos vectorAdd (_velocity vectorMultiply _tof);
_aim set [2,(_aim select 2)+0.5*9.80665*(_state get "gravity")*_tof*_tof];
private _correction=[_state] call CBE_fnc_CortexAASpot;
private _los=_origin vectorFromTo _targetPos;
private _cross=_velocity vectorDiff (_los vectorMultiply (_velocity vectorDotProduct _los));
private _crossMagnitude=vectorMagnitude _cross;
private _up=[0,0,1] vectorDiff (_los vectorMultiply (_los select 2));
if (_crossMagnitude >= 5) then {
    _aim=_aim vectorAdd (_cross vectorMultiply (_correction select 0));
    private _along=_cross vectorMultiply (1/_crossMagnitude);
    _up=_up vectorDiff (_along vectorMultiply (_up vectorDotProduct _along));
};
if (vectorMagnitude _up > 0.1) then {_aim=_aim vectorAdd ((vectorNormalized _up) vectorMultiply ((_correction select 1)*_range))};
// Admission already qualified this exact immutable weapon/muzzle/ammo configuration.
// Fresh native state still proves permission; do not rescan unrelated station muzzles
// on every aim step or let another loaded weapon substitute for this episode's identity.
private _weapon=_state get "weapon";private _muzzle=_state get "muzzle";
private _magazine=_state get "magazine";
private _loaded=weaponState [_vehicle,_turret,_weapon,_muzzle];
private _roundCount=_loaded param [4,-1,[0]];
private _reloadPhase=_loaded param [6,1,[0]];
if (count _loaded < 7 || {(_loaded select 0) != _weapon} || {(_loaded select 1) != _muzzle}
    || {(_loaded select 3) != _magazine} || {!finite _roundCount} || {_roundCount < 20}
    || {!finite _reloadPhase} || {_reloadPhase != 0}
    || {!(_weapon in ((_vehicle weaponsTurret _turret) select [0,16]))}) exitWith {["STATION_CHANGED"] call _finish;-1};
private _observation=createHashMapFromArray [["loadedWeapon",_weapon],["loadedMuzzle",_muzzle],
    ["loadedMagazine",_magazine],["loadedTurret",+_turret]];
private _camera=_vehicle modelToWorldWorld (_vehicle selectionPosition [_state get "optic","Memory"]);
private _point=_aim vectorAdd (_camera vectorDiff _origin);
_vehicle lockCameraTo [_point,_turret,true];_state set ["applied",+_point];
_state set ["aimContext",[time,+_targetPos,+_velocity,+_correction,+_origin]];
private _direction=_vehicle weaponDirection (_state get "weapon");
private _aligned=(_direction vectorCos (_origin vectorFromTo _aim)) >= cos 0.5;
if (_aligned && {time >= (_state get "nextFire")} && {(_state get "attempts") < 16}
    && {[_gunner,_aim,_state get "magazine"] call CBE_fnc_CortexLineOfFireClear}
    && {!(terrainIntersectASL [_origin,_aim])}
    && {(lineIntersectsSurfaces [_origin,_aim,_vehicle,_missile,true,1,"FIRE","GEOM"]) isEqualTo []}
    && {[_vehicle,_gunner,_observation,_token] call CBE_fnc_CortexGroundSelectMuzzle}) then {
    _state set ["shotWindow",time+0.2];
    _state set ["attempts",(_state get "attempts")+1];_state set ["nextFire",time+0.15];
    _vehicle fireAtTarget [objNull,_state get "muzzle"];
};
_state set ["steps",(_state get "steps")+1];
0.05
