/*
 * Author: WaldoTheWarfighter
 * Purpose: One finite native infantry UGL illumination action, without dummy targets or inventory edits.
 * Locality/authority: Group/actor owner, existing groupTactics FSM callback; original epoch,
 * operation, native route, idle command and actor reservation govern every weapon command.
 * Repeat/JIP: Opt-in; one attempt per60s, <=16 actors/8muzzles/128inventory rows per admission.
 * Original25s deadline, one reload/selection/fire request; no worker or deadline renewal.
 * Public cleanup receipts survive locality; only the installing machine removes its handler ID.
 * New owners perform cleanup only, never loading, aiming or firing from inherited work.
 * FiredMan observes only the exact flare release and never changes its projectile. Cleanup removes
 * the local handler and only exact owned reservation/weapon selection. Same-value external watch
 * changes cannot be distinguished; cleanup requires unchanged route/actor authority and sky alignment.
 * Arguments: 0 group GROUP grpNull; 1 release-only BOOL false.
 * Return: BOOL - finite action remains active; never room safety or illumination effectiveness.
 * Current callers: GroupBrainStep, OperationStart, CortexReleaseGroup and CortexLocality.
 * Example: [_group] call CBE_fnc_CortexIlluminationStep;
 */
params [["_group",grpNull,[grpNull]],["_release",false,[true]]];
if (isNull _group) exitWith {false};
private _work=_group getVariable ["CBE_Illumination_Work",createHashMap];
// Disabled/empty work is a cheap feature lookup, not a native route/roster observation.
if (count _work == 0 && {_release || {!([_group,"CBE_AIPass_Illumination_Enable",false] call CBE_fnc_CortexFeatureEnabled)}}) exitWith {false};
private _actor=_work getOrDefault ["actor",objNull];
private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
private _migration=count _work > 0 && {(_work getOrDefault ["ownerId",clientOwner]) != clientOwner};
private _route=[_group] call CBE_fnc_NativeOrderReceipt;
private _authority={
    local _group && {!isNull _actor} && {local _actor} && {group _actor == _group}
        && {isNull objectParent _actor} && {!isPlayer _actor} && {isNull remoteControlled _actor}
        && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {currentCommand _actor == ""} && {isNull assignedTarget _actor} && {isNull getAttackTarget _actor}
};
private _finish={
    params ["_reason"];
    private _same=!isNull _actor && {(_actor getVariable ["CBE_Illumination_Work",createHashMap]) isEqualTo _work};
    if (_same) then {
        private _handler=_work getOrDefault ["handler",-1];
        if (_handler >= 0 && {(_work getOrDefault ["ownerId",-1]) == clientOwner}) then {_actor removeEventHandler ["FiredMan",_handler]};
        private _owned=call _authority && {(_work getOrDefault ["epoch",-1]) == _epoch}
            && {(_work getOrDefault ["operation",-1]) == (_group getVariable ["CBE_OperationGeneration",0])}
            && {_route isEqualTo (_work getOrDefault ["route",[]])}
            && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo (_work getOrDefault ["lease",[]])
                || {_migration && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []}}};
        private _applied=_work getOrDefault ["selected",[]];
        if (_owned && {_applied isNotEqualTo []} && {(weaponState _actor select [0,3]) isEqualTo _applied}) then {
            private _sky=_work get "sky";
            if ((_actor weaponDirection (_work get "muzzle")) vectorDotProduct ((eyePos _actor) vectorFromTo _sky) > 0.97) then {_actor doWatch objNull};
            _actor selectWeapon (_work get "before");
        };
        if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo (_work getOrDefault ["lease",[]])) then {
            _actor setVariable ["CBE_Cortex_ActorMove",nil];
        };
        _actor setVariable ["CBE_Illumination_Work",nil,local _group];
    };
    if ((_group getVariable ["CBE_Illumination_Work",createHashMap]) isEqualTo _work) then {
        _group setVariable ["CBE_Illumination_Result",[_reason,serverTime,_actor,_work getOrDefault ["released",false]],true];
        _group setVariable ["CBE_Illumination_Work",nil,local _group];
    };
    false
};
if (_release) exitWith {if (count _work > 0) then {["RELEASED"] call _finish} else {false}};
if (_migration) exitWith {["OWNER_CHANGED"] call _finish};
if (!local _group) exitWith {false};
private _state=_group getVariable ["CBE_AIPass_State",createHashMap];
private _enabled=missionNamespace getVariable ["CBE_AIPass_Active",false]
    && {!([] call CBE_fnc_CortexIsPaused)}
    && {[_group,"CBE_AIPass_Illumination_Enable",false] call CBE_fnc_CortexFeatureEnabled}
    && {(_state getOrDefault ["phase",""]) == "CONTACT"}
    && {!(behaviour leader _group in ["STEALTH","CARELESS"])}
    && {combatMode _group in ["YELLOW","RED"]}
    && {(getLighting select 1) <= (missionNamespace getVariable ["CBE_AI_DarknessThreshold",5])}
    && {!("NVG" in getArray (configFile >> "CfgWeapons" >> hmd leader _group >> "visionMode"))};
if (!_enabled) exitWith {if (count _work > 0) then {["DISABLED_OR_CONTEXT"] call _finish} else {false}};
if (count _work == 0) exitWith {
    if (serverTime < (_group getVariable ["CBE_Illumination_After",0])) exitWith {false};
    _group setVariable ["CBE_Illumination_After",serverTime+60,true];
    private _choice=[];
    {
        _actor=_x;
        if (!(call _authority) || {_actor == leader _group} || {abs speed _actor > 0.5}
            || {!unitReady _actor} || {getUnitState _actor in ["INIT","PLANNING","REPLAN","BUSY"]}
            || {[_actor] call CBE_fnc_CortexActorMoveReserved}
            || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}
            || {!(_actor checkAIFeature "FIREWEAPON")} || {!(_actor checkAIFeature "TARGET")}
            || {unitCombatMode _actor != "YELLOW" && {unitCombatMode _actor != "RED"}}
            || {behaviour _actor in ["STEALTH","CARELESS"]} || {getSuppression _actor >= 0.2}) then {continue};
        private _weapon=primaryWeapon _actor;
        if (_weapon == "" || {currentWeapon _actor != _weapon}) then {continue};
        private _muzzles=getArray (configFile >> "CfgWeapons" >> _weapon >> "muzzles");
        private _inventory=magazinesAmmoFull _actor;
        if (count _muzzles > 8 || {count _inventory > 128}) then {continue};
        {
            private _muzzle=_x;
            if (_muzzle in ["this","SAFE",_weapon]) then {continue};
            private _compatible=compatibleMagazines [_weapon,_muzzle];
            if (count _compatible > 128) then {continue};
            private _magazine="";
            {
                private _class=_x select 0;
                private _ammo=configFile >> "CfgAmmo" >> getText (configFile >> "CfgMagazines" >> _class >> "ammo");
                if ((_x select 1) > 0 && {_class in _compatible}
                    && {toLowerANSI getText (_ammo >> "simulation") == "shotilluminating"}
                    && {getNumber (_ammo >> "hit") == 0} && {getNumber (_ammo >> "indirectHit") == 0}
                    && {getText (_ammo >> "submunitionAmmo") == ""} && {!isArray (_ammo >> "submunitionAmmo")}) exitWith {_magazine=_class};
            } forEach _inventory;
            if (_magazine != "") exitWith {_choice=[_actor,_weapon,_muzzle,_magazine]};
        } forEach _muzzles;
        if (_choice isNotEqualTo []) exitWith {};
    } forEach ((units _group) select [0,16]);
    if (_choice isEqualTo []) exitWith {false};
    _choice params ["_unit","_weapon","_muzzle","_magazine"];
    _actor=_unit;
    if (!(call _authority) || {[_actor] call CBE_fnc_CortexActorMoveReserved}) exitWith {false};
    private _before=weaponState _actor select [0,3];
    if (count _before != 3) exitWith {false};
    private _sky=(getPosASL _actor) vectorAdd [80*sin getDir leader _group,80*cos getDir leader _group,150];
    private _deadline=serverTime+25;
    private _lease=["ILLUMINATE",ASLToAGL _sky,time+25];
    _work=createHashMapFromArray [["actor",_actor],["group",_group],["epoch",_epoch],["ownerId",clientOwner],
        ["operation",_group getVariable ["CBE_OperationGeneration",0]],["route",_route],
        ["weapon",_weapon],["muzzle",_muzzle],["magazine",_magazine],["before",_before],
        ["sky",_sky],["deadline",_deadline],["lease",_lease],["phase","LOAD"],["released",false]];
    _group setVariable ["CBE_Illumination_Work",_work];_actor setVariable ["CBE_Illumination_Work",_work];
    _actor setVariable ["CBE_Cortex_ActorMove",+_lease];
    private _handler=_actor addEventHandler ["FiredMan",{
        params ["_unit","_weapon","_muzzle","","","_magazine","_projectile"];
        private _work=_unit getVariable ["CBE_Illumination_Work",createHashMap];
        private _group=_work getOrDefault ["group",grpNull];
        if (local _unit && {!isNull _group} && {local _group}
            && {(_group getVariable ["CBE_Illumination_Work",createHashMap]) isEqualTo _work}
            && {(_work getOrDefault ["handler",-1]) == _thisEventHandler}
            && {(_work getOrDefault ["phase",""]) == "AWAIT_RELEASE"}
            && {serverTime < (_work getOrDefault ["deadline",-1])}
            && {(_work getOrDefault ["epoch",-1]) == (_group getVariable ["CBE_AIPass_Epoch",0])}
            && {(_work getOrDefault ["operation",-1]) == (_group getVariable ["CBE_OperationGeneration",0])}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_work getOrDefault ["route",[]])}
            && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
            && {[_group,"CBE_AIPass_Illumination_Enable",false] call CBE_fnc_CortexFeatureEnabled}
            && {!isPlayer _unit} && {isNull remoteControlled _unit}
            && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
            && {(_unit getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
            && {_weapon == (_work get "weapon")} && {_muzzle == (_work get "muzzle")}
            && {_magazine == (_work get "magazine")} && {!isNull _projectile}) then {
            _work set ["released",true];
            _group setVariable ["CBE_Illumination_Release",[serverTime,_unit,_magazine,netId _projectile],true];
        };
    }];
    _work set ["handler",_handler];
    private _loaded=_actor weaponState _muzzle;
    if ((_loaded param [3,""]) != _magazine || {(_loaded param [4,0]) <= 0}) then {_actor reload [_muzzle,_magazine]};
    _group setVariable ["CBE_Illumination_Work",_work,true];_actor setVariable ["CBE_Illumination_Work",_work,true];
    true
};
if (!(call _authority) || {_epoch != (_work get "epoch")}
    || {(_group getVariable ["CBE_OperationGeneration",0]) != (_work get "operation")}
    || {_route isNotEqualTo (_work get "route")}
    || {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isNotEqualTo (_work get "lease")}
    || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}
    || {!(unitCombatMode _actor in ["YELLOW","RED"])} || {!(_actor checkAIFeature "FIREWEAPON")}
    || {getSuppression _actor >= 0.2}) exitWith {["PREEMPTED"] call _finish};
if (serverTime >= (_work get "deadline")) exitWith {["TIMEOUT"] call _finish};
private _phase=_work get "phase";
if (_phase == "LOAD") exitWith {
    if ((weaponState _actor select [0,3]) isNotEqualTo (_work get "before")) exitWith {["WEAPON_CHANGED"] call _finish};
    private _loaded=_actor weaponState (_work get "muzzle");
    if ((_loaded param [3,""]) != (_work get "magazine") || {(_loaded param [4,0]) <= 0}
        || {(_loaded param [6,1]) != 0}) exitWith {true};
    private _selected=_loaded select [0,3];
    _actor selectWeapon _selected;_work set ["selected",_selected];
    _actor doWatch (ASLToAGL (_work get "sky"));_work set ["phase","AIM"];
    _group setVariable ["CBE_Illumination_Work",_work,true];_actor setVariable ["CBE_Illumination_Work",_work,true];
    true
};
if ((weaponState _actor select [0,3]) isNotEqualTo (_work get "selected")) exitWith {["WEAPON_CHANGED"] call _finish};
if (_phase == "AIM") exitWith {
    private _sky=_work get "sky";
    private _direction=_actor weaponDirection (_work get "muzzle");
    if ((_direction select 2) < 0.6 || {_direction vectorDotProduct ((eyePos _actor) vectorFromTo _sky) < 0.97}) exitWith {true};
    if (lineIntersectsSurfaces [eyePos _actor,_sky,_actor,objNull,true,1,"FIRE","GEOM"] isNotEqualTo []
        || {terrainIntersectASL [eyePos _actor,_sky]}) exitWith {["OBSTRUCTED"] call _finish};
    private _loaded=_actor weaponState (_work get "muzzle");
    if ((_loaded param [3,""]) != (_work get "magazine") || {(_loaded param [4,0]) <= 0}
        || {(_loaded param [6,1]) != 0}) exitWith {["AMMO_CHANGED"] call _finish};
    _work set ["phase","AWAIT_RELEASE"];_work set ["fireUntil",(serverTime+3) min (_work get "deadline")];
    _actor forceWeaponFire [_work get "muzzle",_loaded select 2];
    true
};
if (_phase == "AWAIT_RELEASE") exitWith {
    if (_work get "released") exitWith {["RELEASE_OBSERVED"] call _finish};
    if (serverTime >= (_work get "fireUntil")) exitWith {["NO_RELEASE"] call _finish};
    true
};
["INVALID_PHASE"] call _finish
