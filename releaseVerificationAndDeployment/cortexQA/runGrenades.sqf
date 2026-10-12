/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe real carried smoke-grenade launch direction across cardinal bearings and stances.
 * Locality/authority: scheduled dedicated-server fixture; fresh groups remain server-owned.
 * Repeat/JIP: fresh actors and cleaned-up public target markers per case; no throw receipts or projectiles are fabricated. Observer phase is public.
 * Arguments: 0: check callback <CODE>; 1: phase callback <CODE>; 2: finite wait callback <CODE>.
 * Return: Nothing. This is a controlled direction fixture, not live-contact or fragmentation acceptance.
 * Current caller: cortexQA/runServer.sqf in the grenades/fire/mechanics batches.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAGrenades.sqf";
 */
params ["_check","_phase","_wait"];
{
    private _pose=_x;
    {
        private _bearing=_x;
        private _id=format ["GRENADE-SMOKE-%1-%2",_pose,_bearing];
        private _group=createGroup [east,true];
        _group setVariable ["WAIT_Headless_ExcludeGroup",true,true];
        _group setVariable ["acex_headless_blacklist",true,true];
        private _unit=_group createUnit ["O_Soldier_F",[6800,6800,0],[],0,"NONE"];
        _unit setDir _bearing;
        _unit setUnitPos _pose;
        _unit addMagazine "SmokeShell";
        private _target=(getPosATL _unit) getPos [25,_bearing];
        private _marker=createMarker [_id+"-TARGET",_target];
        _marker setMarkerType "mil_destroy";
        _marker setMarkerColor "ColorYellow";
        _marker setMarkerText (_id+" requested target");
        _unit setVariable ["WAIT_CortexQA_GrenadeTarget",_target];
        _unit setVariable ["WAIT_CortexQA_Label",_id,true];
        missionNamespace setVariable ["WAIT_CortexQA_Actors",[_unit],true];
        [_id,"Fresh server-owned actor throws carried smoke toward the marked direction. Require a real launch vector; queued fire alone cannot pass. No hostile actor is present to provoke an autonomous combat throw.",_target] call _phase;
        private _expectedPose=switch (_pose) do {case "UP":{"STAND"};case "MIDDLE":{"CROUCH"};default {"PRONE"}};
        [_id+"-stance-prerequisite",[{stance _unit == _expectedPose},5] call _wait] call _check;
        private _handler=_unit addEventHandler ["FiredMan",{
            params ["_actor","_weapon","_muzzle","_mode","_ammo","_magazine","_projectile"];
            if (_weapon != "Throw" || {_magazine != "SmokeShell"}) exitWith {};
            private _v=velocity _projectile;
            private _valid=!isNull _projectile && {(_v select 0)^2+(_v select 1)^2 > 0.01};
            private _requested=_actor getDir (_actor getVariable ["WAIT_CortexQA_GrenadeTarget",[]]);
            private _launch=if (_valid) then {(_v select 0) atan2 (_v select 1)} else {-1};
            private _error=if (_valid) then {abs (((_launch-_requested+540)%360)-180)} else {-1};
            _actor setVariable ["WAIT_CortexQA_GrenadeLaunch",[_valid,_error,_requested,_launch,_v,stance _actor,animationState _actor]];
        }];
        private _queued=[_unit,_target,"SMOKE"] call WAIT_fnc_CortexThrowGrenade;
        [_id+"-request-queued",_queued] call _check;
        private _released=if (_queued) then {[{!isNil {_unit getVariable "WAIT_CortexQA_GrenadeLaunch"}},20] call _wait} else {false};
        private _evidence=_unit getVariable ["WAIT_CortexQA_GrenadeLaunch",[]];
        [_id+"-physical-direction",_released && {count _evidence >= 2} && {_evidence select 0} && {(_evidence select 1) <= 30},str _evidence] call _check;
        _unit removeEventHandler ["FiredMan",_handler];
        deleteMarker _marker;
        deleteVehicle _unit;
        deleteGroup _group;
        missionNamespace setVariable ["WAIT_CortexQA_Actors",[],true];
    } forEach [0,90,180,270];
} forEach ["UP","MIDDLE","DOWN"];
