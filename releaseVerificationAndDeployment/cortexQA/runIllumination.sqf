/*
 * Author: WaldoTheWarfighter
 * Purpose: Normal-owner native UGL mechanics: disabled control, physical release and live disable.
 * Locality/authority: Dedicated server; real enemy acquisition creates CONTACT. A stationary
 * support group suppresses autonomous attack movement; the grenadier retains native aiming/fire.
 * Repeat/JIP: Fresh groups per case, original production deadlines/cadence untouched. Date,
 * tuning, handlers and objects restore; no completion callback, target reveal or phase injection.
 * Arguments: check CODE, phase CODE, bounded wait CODE, supplied by runServer.
 * Return: Nothing. This isolates weapon mechanics, not full combat/HC/light effectiveness acceptance.
 * Current callers: runServer illumination focus; no automatic inclusion in normal/all or HC batches.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQAIllumination.sqf";
 */
params ["_check","_phase","_wait"];
if (missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false]) exitWith {
    ["ILLUM-normal-batch-required",false,"This fixture does not test HC migration"] call _check;
};
private _savedDate=date;
private _keys=["CBE_AIPass_Enable","CBE_AIPass_Contact_Enable","CBE_AIPass_Illumination_Enable",
    "CBE_AIPass_FireControl_Enable","CBE_AIPass_Advance_Enable","CBE_AIPass_Flank_Enable",
    "CBE_AIPass_Assault_Enable","CBE_AIPass_StaticSupport_Enable","CBE_AIPass_StaticDeploy_Enable",
    "CBE_AIPass_Danger_Enable","CBE_AI_RebalanceActive"];
private _saved=_keys apply {missionNamespace getVariable [_x,nil]};
[createHashMapFromArray [["CBE_AIPass_Enable",true],["CBE_AIPass_Contact_Enable",true],
    ["CBE_AIPass_Illumination_Enable",false],["CBE_AIPass_FireControl_Enable",false],
    ["CBE_AIPass_Advance_Enable",false],["CBE_AIPass_Flank_Enable",false],
    ["CBE_AIPass_Assault_Enable",false],["CBE_AIPass_StaticSupport_Enable",false],
    ["CBE_AIPass_StaticDeploy_Enable",false],["CBE_AIPass_Danger_Enable",false]]]
    call CBE_fnc_CortexTuning;
missionNamespace setVariable ["CBE_AI_RebalanceActive",false];
private _night=+_savedDate;_night set [3,0];_night set [4,0];setDate _night;sleep 2;
private _flare="UGL_FlareWhite_F";
private _ready=isClass (configFile >> "CfgMagazines" >> _flare)
    && {isClass (configFile >> "CfgWeapons" >> "arifle_MX_GL_F")}
    && {(getLighting select 1) <= (missionNamespace getVariable ["CBE_AI_DarknessThreshold",5])};
["ILLUM-fixture-prerequisites",_ready,str [getLighting,_flare]] call _check;
if (_ready) then {
{
    private _case=_x;
    private _group=createGroup [west,true];private _enemyGroup=createGroup [east,true];
    {_x setVariable ["CBE_Headless_ExcludeGroup",true,true];_x setVariable ["acex_headless_blacklist",true,true]} forEach [_group,_enemyGroup];
    private _origin=[3400+_forEachIndex*80,3400,0];
    private _leader=_group createUnit ["B_Soldier_F",_origin,[],0,"NONE"];
    private _actor=_group createUnit ["B_Soldier_GL_F",_origin vectorAdd [4,-6,0],[],0,"NONE"];
    private _enemy=_enemyGroup createUnit ["O_Soldier_F",_origin vectorAdd [0,15,0],[],0,"NONE"];
    {_x allowDamage false;_x unlinkItem hmd _x;_x setSkill 1;_x setDir 0;
        _x setVariable ["acex_headless_blacklist",true,true]} forEach [_leader,_actor,_enemy];
    removeAllWeapons _enemy;_enemy disableAI "MOVE";
    _enemyGroup setCombatMode "BLUE";_enemyGroup setBehaviourStrong "CARELESS";
    _group setCombatMode "YELLOW";_group setBehaviourStrong "AWARE";_group enableAttack false;
    // Controlled support role: do not invent a CONTACT state or overwrite target assignments.
    // Native autonomous targeting is off only for the grenadier; TARGET/FIREWEAPON remain on.
    _actor disableAI "AUTOTARGET";
    removeAllWeapons _actor;
    _actor addMagazine "30Rnd_65x39_caseless_mag";
    _actor addMagazine "1Rnd_HE_Grenade_shell";
    _actor addWeapon "arifle_MX_GL_F";
    _actor addMagazine _flare;_actor addMagazine _flare;
    _actor selectWeapon "arifle_MX_GL_F";
    _actor setVariable ["CBE_CortexQA_Label","ILLUM "+_case,true];
    private _rounds={
        params ["_unit","_class"];
        private _total=0;{if ((_x select 0) == _class) then {_total=_total+(_x select 1)}} forEach magazinesAmmoFull _unit;
        _total
    };
    private _beforeRounds=[_actor,_flare] call _rounds;
    private _beforeWeapon=weaponState _actor select [0,3];
    _actor setVariable ["CBE_CortexQA_IllumRelease",[]];
    private _handler=_actor addEventHandler ["FiredMan",{
        params ["_unit","","_muzzle","","_ammo","_magazine","_projectile"];
        if (!isNull _projectile && {toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation") == "shotilluminating"}) then {
            _unit setVariable ["CBE_CortexQA_IllumRelease",[_projectile,getPosASL _projectile,velocity _projectile,_magazine,_muzzle,serverTime]];
        };
    }];
    missionNamespace setVariable ["CBE_CortexQA_Actors",[_leader,_actor,_enemy],true];
    ["Infantry illumination: "+_case,"Native enemy acquisition must establish CONTACT. Watch the grenadier reload a carried flare and aim upwards. Assignment is not release. This normal-only fixture isolates weapon mechanics; no target reveal, phase injection or forced completion is used.",getPosATL _actor] call _phase;
    private _contact=[{_leader knowsAbout _enemy >= 1
        && {((_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["phase",""]) == "CONTACT"}},45] call _wait;
    ["ILLUM-"+_case+"-native-contact",_contact,str [_leader knowsAbout _enemy,currentCommand _actor,getUnitState _actor]] call _check;
    if (_case == "DISABLED") then {
        sleep 8;
        ["ILLUM-disabled-no-work-or-shot",count (_group getVariable ["CBE_Illumination_Work",createHashMap]) == 0
            && {(_actor getVariable ["CBE_CortexQA_IllumRelease",[]]) isEqualTo []}
            && {([_actor,_flare] call _rounds) == _beforeRounds}] call _check;
    } else {
        _beforeWeapon=weaponState _actor select [0,3];
        [createHashMapFromArray [["CBE_AIPass_Illumination_Enable",true]]] call CBE_fnc_CortexTuning;
        private _admitted=[{count (_group getVariable ["CBE_Illumination_Work",createHashMap]) > 0},70] call _wait;
        ["ILLUM-"+_case+"-admitted",_admitted,str [currentCommand _actor,getUnitState _actor,assignedTarget _actor,getAttackTarget _actor]] call _check;
        if (_case == "INTERRUPT") then {
            [createHashMapFromArray [["CBE_AIPass_Illumination_Enable",false]]] call CBE_fnc_CortexTuning;
        };
        private _ended=[{count (_group getVariable ["CBE_Illumination_Work",createHashMap]) == 0},30] call _wait;
        private _release=_actor getVariable ["CBE_CortexQA_IllumRelease",[]];
        private _result=_group getVariable ["CBE_Illumination_Result",[]];
        ["ILLUM-"+_case+"-finite-cleanup",_ended
            && {(_actor getVariable ["CBE_Cortex_ActorMove",[]]) isEqualTo []}
            && {count (_actor getVariable ["CBE_Illumination_Work",createHashMap]) == 0},str _result] call _check;
        if (_case == "RELEASE") then {
            private _rose=false;
            if (count _release == 6) then {
                private _projectile=_release select 0;private _start=(_release select 1) select 2;
                _rose=[{!isNull _projectile && {(getPosASL _projectile select 2) > _start+3}},3] call _wait;
            };
            ["ILLUM-real-flare-and-upward-travel",count _release == 6 && {_rose}
                && {((_release select 2) select 2) > 0} && {(_release select 3) == _flare},str _release] call _check;
            ["ILLUM-one-existing-round-spent",([_actor,_flare] call _rounds) == _beforeRounds-1,str [_beforeRounds,[_actor,_flare] call _rounds]] call _check;
            ["ILLUM-selected-weapon-handback",(weaponState _actor select [0,3]) isEqualTo _beforeWeapon,str [weaponState _actor,_beforeWeapon]] call _check;
        } else {
            ["ILLUM-disable-before-release",_admitted && {_release isEqualTo []}
                && {([_actor,_flare] call _rounds) == _beforeRounds},str _release] call _check;
        };
        [createHashMapFromArray [["CBE_AIPass_Illumination_Enable",false]]] call CBE_fnc_CortexTuning;
    };
    _actor removeEventHandler ["FiredMan",_handler];
    [_group,true] call CBE_fnc_CortexIlluminationStep;
    {deleteVehicle _x} forEach [_leader,_actor,_enemy];{deleteGroup _x} forEach [_group,_enemyGroup];
} forEach ["DISABLED","RELEASE","INTERRUPT"];
};
missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];setDate _savedDate;
{missionNamespace setVariable [_x,_saved select _forEachIndex]} forEach _keys;
