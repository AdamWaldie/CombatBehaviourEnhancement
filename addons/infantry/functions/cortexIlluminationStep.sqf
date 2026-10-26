/*
 * Author: WaldoTheWarfighter
 * Native planner data waits and delayed search preserve existing intent and original budgets.
 * Purpose: One finite native infantry UGL illumination action, without dummy targets or inventory edits.
 * Weapon handback requires native selection readback. Unconfirmed original/applied selection
 * proof survives action retirement and blocks recapturing the launcher as a fresh baseline.
 * Admission observes that proof only; it never retries an old weapon command.
 * Locality/authority: Group/actor owner, existing groupTactics FSM callback; original epoch,
 * operation, native route, idle command and actor reservation govern every weapon command.
 * Repeat/JIP: Opt-in; one attempt per60s, <=16 actors/8muzzles/128inventory rows per admission.
 * The same bounded roster tries nonleaders first, then its leader if otherwise eligible.
 * Leader fallback adds no movement order, membership change or candidate search beyond that limit.
 * Original25s deadline, one reload/selection/fire request; no worker or deadline renewal.
 * Admission/loading/selection/fire require complete settled native weapon and magazine reload state;
 * an existing rifle or launcher reload is never replaced by an illumination request.
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
        && {!fleeing _actor} && {[_actor] call CBE_fnc_CortexCombatEffective}
        && {simulationEnabled _actor} && {!isObjectHidden _actor}
        && {(_actor getVariable ["ace_medical_ai_healQueue",[]]) isEqualTo []}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)} && {!([_group] call CBE_fnc_CortexZeusHeld)}
        && {[_actor] call CBE_fnc_CortexExternalOwner == ""}
        && {!([_actor] call CBE_fnc_CompatibilityExternalControl)}
        && {currentCommand _actor == ""} && {isNull assignedTarget _actor} && {isNull getAttackTarget _actor}
};
// Unknown or active native loading is not permission to replace the weapon task.
// This predicate reads an already sampled state and performs no native command.
// Native round phase-1 means no magazine: allow only that exact empty admission state,
// never launcher selection/fire or any positive/incomplete magazine reload.
private _settledWeapon={
    params ["_weaponState",["_allowEmpty",false]];
    _weaponState isEqualType [] && {count _weaponState >= 7}
        && {[0,1,2] findIf {!((_weaponState select _x) isEqualType "")
            || {(_weaponState select _x) == ""}} < 0}
        && {(_weaponState select 3) isEqualType ""}
        && {[4,5,6] findIf {!((_weaponState select _x) isEqualType 0)
            || {!finite (_weaponState select _x)}} < 0}
        && {(_weaponState select 4) >= 0} && {(_weaponState select 6) == 0}
        && {(_weaponState select 5) == 0 || {_allowEmpty
            && {(_weaponState select 5) == -1} && {(_weaponState select 3) == ""}
            && {(_weaponState select 4) == 0}}}
};
private _finish={
    params ["_reason"];
    private _weaponHandback="NOT_CHANGED";
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
        if (_applied isNotEqualTo []) then {
            _weaponHandback="UNCONFIRMED";
            // Native weapon state is local evidence. A remote actor retains cleanup proof,
            // never a speculative readback or a replayed selection on its previous owner.
            if (local _actor) then {
                private _selectedNow=weaponState _actor select [0,3];
                if (_selectedNow isEqualTo (_work get "before")) then {
                    _weaponHandback="BASELINE_OBSERVED";
                } else {
                    if (_selectedNow isNotEqualTo _applied) then {
                        _weaponHandback="SUPERSEDED";
                    } else {
                        if (_owned) then {
                            private _sky=_work get "sky";
                            if ((_actor weaponDirection (_work get "muzzle")) vectorDotProduct ((eyePos _actor) vectorFromTo _sky) > 0.97) then {_actor doWatch objNull};
                            _actor selectWeapon (_work get "before");
                            if ((weaponState _actor select [0,3]) isEqualTo (_work get "before")) then {_weaponHandback="RESTORED"};
                        };
                    };
                };
            };
            if (_weaponHandback == "UNCONFIRMED") then {
                _actor setVariable ["CBE_Illumination_WeaponUnresolved",[+(_work get "before"),+_applied,serverTime],true];
            };
        };
        if ((_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo (_work getOrDefault ["lease",[]])) then {
            _actor setVariable ["CBE_Cortex_ActorMove",nil];
        };
        _actor setVariable ["CBE_Illumination_Work",nil,local _group];
    };
    if ((_group getVariable ["CBE_Illumination_Work",createHashMap]) isEqualTo _work) then {
        _group setVariable ["CBE_Illumination_Result",[_reason,serverTime,_actor,_work getOrDefault ["released",false],_weaponHandback],true];
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
    private _illuminationRoster=(units _group) select [0,16];
    private _illuminationLeader=leader _group;
    // Preserve every original bounded candidate. Commanding actors are last-choice,
    // not excluded when they are the group's only otherwise eligible launcher.
    if (_illuminationLeader in _illuminationRoster) then {
        _illuminationRoster=_illuminationRoster-[_illuminationLeader];
        _illuminationRoster pushBack _illuminationLeader;
    };
    {
        _actor=_x;
        if (!(call _authority) || {abs speed _actor > 0.5}
            || {!unitReady _actor} || {getUnitState _actor in ["INIT","INITFAILED","PLANNING","REPLAN","DELAY","BUSY"]}
            || {[_actor] call CBE_fnc_CortexActorMoveReserved}
            || {!([_actor] call CBE_fnc_IndoorActorGroupAvailable)}
            || {!(_actor checkAIFeature "FIREWEAPON")} || {!(_actor checkAIFeature "TARGET")}
            || {unitCombatMode _actor != "YELLOW" && {unitCombatMode _actor != "RED"}}
            || {behaviour _actor in ["STEALTH","CARELESS"]} || {getSuppression _actor >= 0.2}) then {continue};
        // Old cleanup proof permits observation only. Never restore over a newer task or
        // capture the still-applied launcher as this action's original rifle selection.
        private _unresolved=_actor getVariable ["CBE_Illumination_WeaponUnresolved",[]];
        if (_unresolved isNotEqualTo []) then {
            private _typed=_unresolved isEqualType [] && {count _unresolved == 3}
                && {[0,1] findIf {private _selection=_unresolved select _x;
                    !(_selection isEqualType []) || {count _selection != 3}
                        || {_selection findIf {!(_x isEqualType "")} >= 0}} < 0}
                && {(_unresolved select 2) isEqualType 0} && {finite (_unresolved select 2)};
            if (!_typed) then {continue};
            private _selectionNow=weaponState _actor select [0,3];
            if (_selectionNow isEqualTo (_unresolved select 1)
                && {_selectionNow isNotEqualTo (_unresolved select 0)}) then {continue};
            // An observed original or a different native selection supersedes this fact;
            // neither case grants an old command authority or a renewed deadline.
            _actor setVariable ["CBE_Illumination_WeaponUnresolved",nil,true];
        };
        private _weapon=primaryWeapon _actor;
        if (_weapon == "" || {currentWeapon _actor != _weapon}) then {continue};
        if (!([weaponState _actor,true] call _settledWeapon)) then {continue};
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
            if (_magazine != "" && {[_actor weaponState _muzzle,true] call _settledWeapon}) exitWith {
                _choice=[_actor,_weapon,_muzzle,_magazine]
            };
        } forEach _muzzles;
        if (_choice isNotEqualTo []) exitWith {};
    } forEach _illuminationRoster;
    if (_choice isEqualTo []) exitWith {false};
    _choice params ["_unit","_weapon","_muzzle","_magazine"];
    _actor=_unit;
    if (!(call _authority) || {[_actor] call CBE_fnc_CortexActorMoveReserved}) exitWith {false};
    private _beforeState=weaponState _actor;
    private _loaded=_actor weaponState _muzzle;
    if (!([_beforeState,true] call _settledWeapon) || {!([_loaded,true] call _settledWeapon)}) exitWith {false};
    private _before=_beforeState select [0,3];
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
        || {!([_loaded] call _settledWeapon)}) exitWith {true};
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
        || {!([_loaded] call _settledWeapon)}) exitWith {["AMMO_CHANGED"] call _finish};
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
