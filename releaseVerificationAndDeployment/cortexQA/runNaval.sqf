/*
 * Author: WaldoTheWarfighter
 * Physically audits Cortex coastal assault with separate and combined crew/passenger groups.
 *
 * One bounded terrain search finds a real dry-to-water transition on the current world. Each case
 * starts offshore with an ordinary AI-driven armed boat and a visible, damageable land target.
 * Target knowledge is supplied explicitly so the audit measures the naval controller rather than
 * discovery luck. It then requires real water travel, a shallow stop, passenger exit, dry-ground
 * egress, crew retention and finite plan cleanup. No waypoint, position or completion state is
 * injected after the fixture starts. HC batches transfer through the actual companion provider
 * during an observed stop; authenticated owner samples check retained cap/token/deadline and restore.
 * Normal and HC focuses use Altis separately. This is known-contact movement, not combat acceptance.
 * Locality/authority: scheduled server fixture; production Cortex runs on the current owners.
 * Repeat/JIP: fresh groups/vehicles per case; all fixtures are deleted and settings restored.
 *
 * Arguments: check <CODE>, phase <CODE>, wait <CODE>.
 * Return Value: Nothing.
 * Current caller: cortexQAServer.sqf when focus is naval/all/features.
 * Example: [_check,_phase,_wait] call compile preprocessFileLineNumbers "cortexQANaval.sqf";
 */

params ["_check","_phase","_wait"];
private _hc=missionNamespace getVariable ["CBE_CortexQA_HeadlessBatch",false];
private _owners=[];
if (_hc) then {
    private _providerReady=!isNil "Waldo_fnc_HeadlessMigrateGroup"
        && {!isNil "CBE_CortexQA_NavalSampleOwner"};
    ["NAVAL-HC-real-provider",_providerReady] call _check;
    if (_providerReady) then {
        [{private _registered=(missionNamespace getVariable ["Waldo_Headless_Clients",[]]) apply {_x select 0};
            private _connected=(allPlayers select {_x isKindOf "HeadlessClient_F"}) apply {owner _x};
            count (_registered arrayIntersect _connected) >= 2},45] call _wait;
        private _registered=(missionNamespace getVariable ["Waldo_Headless_Clients",[]]) apply {_x select 0};
        private _connected=(allPlayers select {_x isKindOf "HeadlessClient_F"}) apply {owner _x};
        _owners=(_registered arrayIntersect _connected) select [0,2];
    };
};
if (_hc && {count _owners != 2}) exitWith {["NAVAL-HC-two-real-registered",false] call _check};
private _sampleSerial=0;
private _sampleOwner={
    params ["_boat","_wantedOwner"];
    _sampleSerial=_sampleSerial+1;
    private _nonce=format ["NAVAL:%1:%2",diag_tickTime,_sampleSerial];
    missionNamespace setVariable ["CBE_CortexQA_NavalPending",[_nonce,_wantedOwner,_boat]];
    missionNamespace setVariable ["CBE_CortexQA_NavalSample",[]];
    [_nonce,_boat] remoteExecCall ["CBE_CortexQA_NavalSampleOwner",_wantedOwner];
    private _received=[{private _ack=missionNamespace getVariable ["CBE_CortexQA_NavalSample",[]];
        count _ack == 2 && {(_ack select 0) == _nonce}},5] call _wait;
    private _ack=missionNamespace getVariable ["CBE_CortexQA_NavalSample",[]];
    missionNamespace setVariable ["CBE_CortexQA_NavalPending",nil];
    if (_received) then {_ack select 1} else {[]}
};

[createHashMapFromArray [
    ["CBE_AIPass_Enable",true],
    ["CBE_AIPass_Contact_Enable",true],
    ["CBE_AIPass_NavalAssault_Enable",true],
    ["CBE_AIPass_Vehicles_Enable",true],
    ["CBE_AIPass_Flank_Enable",false],
    ["CBE_AIPass_Advance_Enable",false],
    ["CBE_AIPass_CoordinatedAssault_Enable",false],
    ["CBE_AIPass_Reinforce_Enable",false],
    ["CBE_AIPass_Morale_Enable",false],
    ["CBE_AIPass_PostContact_Enable",false]
]] call CBE_fnc_CortexTuning;
private _pin={
    params ["_group"];
    _group setVariable ["CBE_Headless_ExcludeGroup",true,true];
    _group setVariable ["acex_headless_blacklist",true,true];
    {_x setVariable ["acex_headless_blacklist",true,true]} forEach units _group;
};

// Find a real coastline once. The audit, unlike production, may spend a larger bounded search budget.
private _centre=[worldSize*0.5,worldSize*0.5,0];
private _coast=[];
for "_bearing" from 0 to 350 step 10 do {
    if (_coast isEqualTo []) then {
        private _lastDry=[];
        for "_radius" from 250 to (worldSize*0.7) step 250 do {
            private _sample=_centre getPos [_radius,_bearing];
            if (surfaceIsWater _sample) then {
                if (_lastDry isNotEqualTo []) then {
                    private _shore=+_lastDry;
                    private _water=_shore getPos [60,_shore getDir _sample];
                    private _offshore=_shore getPos [350,_shore getDir _sample];
                    private _inland=_shore getPos [220,_sample getDir _shore];
                    if (surfaceIsWater _water && {surfaceIsWater _offshore} && {!surfaceIsWater _inland}
                        && {((surfaceNormal _shore) select 2) >= 0.65}
                        && {((surfaceNormal _inland) select 2) >= 0.65}) then {
                        _coast=[_shore,_water,_offshore,_inland];
                    };
                };
            } else {
                _lastDry=_sample;
            };
        };
    };
};
["NAVAL-terrain-coast",_coast isNotEqualTo [],format ["world=%1 worldSize=%2 coast=%3",worldName,worldSize,_coast]] call _check;
if (_coast isEqualTo []) exitWith {};
_coast params ["_shore","_water","_offshore","_inland"];

{
    private _combined=_x;
    private _suffix=(["","HC-"] select _hc)+(["SEPARATE","COMBINED"] select _combined);
    private _boat=createVehicle ["O_Boat_Armed_01_hmg_F",_offshore getPos [40*_forEachIndex,90],[],0,"NONE"];
    _boat setDir (_boat getDir _shore);
    private _baselineCap=25;_boat forceSpeed _baselineCap;
    createVehicleCrew _boat;
    private _crewGroup=group driver _boat;
    [_crewGroup] call _pin;
    private _passengerGroup=if (_combined) then {_crewGroup} else {createGroup [east,true]};
    [_passengerGroup] call _pin;
    private _passengers=[];
    for "_index" from 0 to 5 do {
        private _unit=_passengerGroup createUnit ["O_Soldier_F",_offshore,[],0,"NONE"];
        _unit assignAsCargo _boat;
        _unit moveInCargo _boat;
        _unit setVariable ["CBE_CortexQA_Label",format ["NAVAL %1 P%2",_suffix,_index+1],true];
        _passengers pushBack _unit;
    };
    private _enemy=createVehicle ["B_APC_Wheeled_01_cannon_F",_inland getPos [30*_forEachIndex,270],[],0,"NONE"];
    createVehicleCrew _enemy;
    private _enemyGroup=group driver _enemy;
    [_enemyGroup] call _pin;
    _enemyGroup setVariable ["CBE_AIPass_Exclude",true,true];
    // Known-contact movement diagnostic: a real hostile crew holds fire; nobody is invulnerable.
    _enemyGroup setCombatMode "BLUE";
    _crewGroup reveal [_enemy,4];
    _passengerGroup reveal [_enemy,4];
    private _start=getPosATL _boat;
    missionNamespace setVariable ["CBE_CortexQA_Actors",(crew _boat)+_passengers+[_enemy],true];
    ["Naval assault: "+toLowerANSI _suffix,"The boat must make a real coastal approach. Operating crew stays aboard; all surviving passengers physically dismount and move onto dry ground. Cyan trails and NAVAL status labels show actual travel and phase.",_shore] call _phase;
    private _started=[{(_boat getVariable ["CBE_Cortex_NavalPlan",[]]) isNotEqualTo []},35] call _wait;
    ["NAVAL-"+_suffix+"-production-start",_started,str (_boat getVariable ["CBE_Cortex_NavalPlan",[]])] call _check;
    private _travelled=[{_boat distance2D _start >= 100},120] call _wait;
    ["NAVAL-"+_suffix+"-physical-water-travel",_travelled,str [_start,getPosATL _boat,speed _boat]] call _check;
    private _targetOwner=2;
    if (_hc && {_started}) then {
        _targetOwner=_owners select _forEachIndex;
        private _stopReady=[{private _r=_boat getVariable ["CBE_Cortex_NavalForcedSpeed",[]];
            count _r == 4 && {(_r select 1) isEqualTo 0}},90] call _wait;
        ["NAVAL-"+_suffix+"-stop-before-migration",_stopReady] call _check;
        if (_stopReady) then {
            private _before=[_boat,2] call _sampleOwner;
            private _heldReceipt=if (count _before == 4) then {_before select 2} else {[]};
            private _heldPlan=if (count _before == 4) then {_before select 3} else {[]};
            ["NAVAL-"+_suffix+"-server-stop-proof",count _before == 4 && {(_before select 1) == 0}
                && {count _heldReceipt == 4} && {count _heldPlan == 9},str _before] call _check;
            _crewGroup setVariable ["CBE_Headless_ExcludeGroup",false,true];
            private _requested=[_crewGroup,_targetOwner] call Waldo_fnc_HeadlessMigrateGroup;
            if (_passengerGroup != _crewGroup) then {
                _passengerGroup setVariable ["CBE_Headless_ExcludeGroup",false,true];
                _requested=([_passengerGroup,_targetOwner] call Waldo_fnc_HeadlessMigrateGroup) && _requested;
            };
            private _adopted=[{groupOwner _crewGroup == _targetOwner && {owner _boat == _targetOwner}
                && {groupOwner _passengerGroup == _targetOwner}
                && {([_crewGroup,_targetOwner] call CBE_fnc_CompatibilityHeadlessRecord) isNotEqualTo []}},30] call _wait;
            ["NAVAL-"+_suffix+"-real-owner-adoption",_requested && {_adopted},str [groupOwner _crewGroup,owner _boat]] call _check;
            private _after=[_boat,_targetOwner] call _sampleOwner;
            ["NAVAL-"+_suffix+"-borrowed-stop-retained",count _after == 4 && {(_after select 1) == 0}
                && {(_after select 2) isEqualTo _heldReceipt} && {count (_after select 3) == 9}
                && {count _heldPlan == 9} && {((_after select 3) select 0) == (_heldPlan select 0)}
                && {((_after select 3) select 7) == (_heldPlan select 7)},str _after] call _check;
        };
    };
    private _dismounted=[{_passengers findIf {!alive _x || {vehicle _x != _x}} < 0},90] call _wait;
    ["NAVAL-"+_suffix+"-physical-dismount",_dismounted,str (_passengers apply {[vehicle _x,currentCommand _x]} )] call _check;
    private _dry=[{_passengers findIf {alive _x && {surfaceIsWater getPosATL _x}} < 0},90] call _wait;
    ["NAVAL-"+_suffix+"-dry-egress",_dismounted && {_dry},str (_passengers apply {getPosATL _x})] call _check;
    private _crewRetained=(crew _boat) findIf {
        private _role=(assignedVehicleRole _x) param [0,""];
        alive _x && {!(_x in _passengers)} && {vehicle _x != _boat} && {toUpperANSI _role != "CARGO"}
    } < 0;
    ["NAVAL-"+_suffix+"-crew-retained",_crewRetained,str (crew _boat)] call _check;
    private _released=[{(_boat getVariable ["CBE_Cortex_NavalPlan",[]]) isEqualTo []},75] call _wait;
    ["NAVAL-"+_suffix+"-finite-cleanup",_released,str [_boat getVariable ["CBE_Cortex_NavalPlan",[]],getForcedSpeed _boat]] call _check;
    if (_hc) then {
        private _final=[_boat,_targetOwner] call _sampleOwner;
        ["NAVAL-"+_suffix+"-owner-speed-restored",count _final == 4
            && {abs ((_final select 1)-_baselineCap) <= 0.1} && {(_final select 2) isEqualTo []},str _final] call _check;
    } else {
        ["NAVAL-"+_suffix+"-speed-restored",abs ((getForcedSpeed _boat)-_baselineCap) <= 0.1] call _check;
    };
    missionNamespace setVariable ["CBE_CortexQA_Actors",[],true];
    {deleteVehicle _x} forEach ((crew _boat)+_passengers+(crew _enemy)+[_enemy,_boat]);
    deleteGroup _enemyGroup;
    deleteGroup _passengerGroup;
    if (_passengerGroup != _crewGroup) then {deleteGroup _crewGroup};
} forEach [false,true];
