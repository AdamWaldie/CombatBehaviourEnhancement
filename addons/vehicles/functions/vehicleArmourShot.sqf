/*
 * Author: WaldoTheWarfighter
 * Purpose: Observe one real main-cannon shot before an optional short armour cover move.
 * Locality/authority: Internal platform/group/gunner owner only. Records a native Fired
 * event with exact station, projectile parents, task generation and native route; never fires,
 * moves, reveals, changes ammunition or grants movement authority.
 * Repeat/JIP: One private20-second episode/platform, one Fired listener and one expiry callback.
 * Repeated ARM never renews it. First matching shot removes the listener; TAKE consumes proof
 * once. Ownership/task changes discard proof. No JIP replay or new owner adoption.
 * Only ordinary main-turret shotShell fire on tanks/APCs qualifies; missiles, AA and artillery
 * retain their own controllers. Native manual fire and external/player control refuse.
 * Arguments: 0 vehicle OBJECT objNull; 1 mode STRING ARM (ARM/SHOT/TAKE/EXPIRE);
 * 2 payload ARRAY []: ARM [target OBJECT, original believed ASL ARRAY3, loaded observation HASHMAP];
 * SHOT [native Fired ARRAY, native handler ID NUMBER]; EXPIRE [original token STRING].
 * Return: TAKE ARRAY [target, believed ASL, original server deadline, actual shot time], or[];
 * other modes BOOL. A shot receipt is not a hit, kill, cover or movement-completion receipt.
 * Callers: CortexVehicles actual object-fire dispatch and standoff planning; native Fired
 * and the exact finite local expiry callback. Cost: no scans/rays; at most two operating checks.
 * Example: [_tank,"ARM",[_enemy,_beliefASL,_loaded]] call CBE_fnc_VehicleArmourShot;
 */
params [["_vehicle",objNull,[objNull]],["_mode","ARM",[""]],["_payload",[],[[]]]];
private _result=if (_mode == "TAKE") then {[]} else {false};
if (remoteExecutedOwner > 0 || {isNull _vehicle}
    || {!(_mode in ["ARM","SHOT","TAKE","EXPIRE"])}) exitWith {_result};
isNil {
_result=call {
    private _state=_vehicle getVariable ["CBE_ArmourShot_Work",createHashMap];
    private _clear={
        private _handler=_state getOrDefault ["handler",-1];
        if (_handler >= 0) then {_vehicle removeEventHandler ["Fired",_handler]};
        if ((_vehicle getVariable ["CBE_ArmourShot_Work",createHashMap]) isEqualTo _state) then {
            _vehicle setVariable ["CBE_ArmourShot_Work",nil];
        };
    };
    private _group=grpNull;private _gunner=objNull;private _target=objNull;
    private _valid={
        local _vehicle && {alive _vehicle} && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
            && {local _group} && {!isNull _group}
            && {!isNull _gunner} && {local _gunner} && {gunner _vehicle == _gunner}
            && {group _gunner == _group} && {!isPlayer _gunner} && {isNull remoteControlled _gunner}
            && {[_gunner] call CBE_fnc_CortexCombatEffective}
            && {simulationEnabled _gunner} && {!isObjectHidden _gunner}
            && {[_gunner] call CBE_fnc_CortexActorFireTaskAvailable}
            && {(_group getVariable ["CBE_AIPass_Epoch",-1]) == (_state get "epoch")}
            && {(_group getVariable ["CBE_OperationGeneration",0]) == (_state get "operationGeneration")}
            && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_state get "route")}
            && {serverTime < (_state get "until")}
            && {missionNamespace getVariable ["CBE_AIPass_Active",false]} && {!([] call CBE_fnc_CortexIsPaused)}
            && {[_group,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
            && {[_group,"CBE_AIPass_VehicleGunnery_Enable",true] call CBE_fnc_CortexFeatureEnabled}
            && {[_group] call CBE_fnc_CortexIsEligible}
            && {((_state get "route") param [1,-2,[0]]) == -1}
            && {private _index=currentWaypoint _group;
                _index >= count waypoints _group || {!(waypointType [_group,_index] in ["HOLD","SENTRY"])}}
            && {(_group getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []}
            && {(_group getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
            && {!(_group getVariable ["CBE_AIPass_ClearBuilding",false])}
            && {count (_group getVariable ["CBE_Operation",createHashMap]) == 0}
            && {(_group getVariable ["CBE_Cortex_CombinedRole",[]]) isEqualTo []}
            && {!([_group,false,_gunner] call CBE_fnc_CortexExternalTakeover)}
            && {!([_vehicle] call CBE_fnc_CompatibilityExternalControl)}
            && {!isManualFire _vehicle} && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
            && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
            && {(_group getVariable ["CBE_AIPass_State",createHashMap]) getOrDefault ["phase",""] == "CONTACT"}
            && {!isNull _target} && {alive _target} && {!captive _target}
            && {!(_target getVariable ["ace_captives_isSurrendering",false])}
            && {!(_target getVariable ["ace_captives_isHandcuffed",false])}
            && {(side _group) getFriend (side _target) < 0.6}
            && {_mode == "ARM" || {
                getAttackTarget _gunner in [objNull,_target] && {assignedTarget _gunner in [objNull,_target]}
                    && {getAttackTarget _gunner == _target || {assignedTarget _gunner == _target}}
            }}
    };
    if (_mode == "ARM") exitWith {
        if (!(_state isEqualType createHashMap) || {count _state > 0} || {count _payload != 3}
            || {!((_payload select 0) isEqualType objNull)}
            || {!((_payload select 1) isEqualType [])} || {count (_payload select 1) != 3}
            || {(_payload select 1) findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
            || {!((_payload select 2) isEqualType createHashMap)}
            || {!(_vehicle isKindOf "Tank" || {_vehicle isKindOf "Wheeled_APC_F"})}
            || {getNumber (configOf _vehicle >> "artilleryScanner") > 0}
            || {toLowerANSI getText (configOf _vehicle >> "editorSubcategory") == "edsubcat_aas"}) exitWith {false};
        _gunner=gunner _vehicle;_group=group _gunner;_target=_payload select 0;
        if ([driver _vehicle,effectiveCommander _vehicle] findIf {
            isNull _x || {!(currentCommand _x in ["","WAIT"])}
        } >= 0) exitWith {false};
        private _loaded=_payload select 2;
        private _magazine=_loaded getOrDefault ["loadedMagazine",""];
        private _ammo=getText (configFile >> "CfgMagazines" >> _magazine >> "ammo");
        if ((_loaded getOrDefault ["loadedTurret",[]]) isNotEqualTo [0]
            || {toLowerANSI getText (configFile >> "CfgAmmo" >> _ammo >> "simulation") != "shotshell"}
            || {vehicle _target isKindOf "Air"}) exitWith {false};
        private _serial=(_vehicle getVariable ["CBE_ArmourShot_Serial",0])+1;
        private _token=format ["ARMOUR_SHOT:%1:%2",clientOwner,_serial];
        _state=createHashMapFromArray [["schema",1],["token",_token],["group",_group],["gunner",_gunner],
            ["target",_target],["position",+(_payload select 1)],["until",serverTime+20],
            ["owner",clientOwner],["epoch",_group getVariable ["CBE_AIPass_Epoch",-1]],
            ["operationGeneration",_group getVariable ["CBE_OperationGeneration",0]],
            ["route",[_group] call CBE_fnc_NativeOrderReceipt],
            ["weapon",_loaded getOrDefault ["loadedWeapon",""]],
            ["muzzle",_loaded getOrDefault ["loadedMuzzle",""]],["magazine",_magazine],["ammo",_ammo],
            ["shotAt",-1],["handler",-1]];
        if !(call _valid) exitWith {false};
        private _handler=_vehicle addEventHandler ["Fired",{
            params ["_entity"];
            [_entity,"SHOT",[_this,_thisEventHandler]] call CBE_fnc_VehicleArmourShot;
        }];
        if (_handler < 0) exitWith {false};
        _state set ["handler",_handler];
        _vehicle setVariable ["CBE_ArmourShot_Serial",_serial];
        _vehicle setVariable ["CBE_ArmourShot_Work",_state];
        [{params ["_entity","_token"];[_entity,"EXPIRE",[_token]] call CBE_fnc_VehicleArmourShot},
            [_vehicle,_token],20] call CBA_fnc_waitAndExecute;
        true
    };
    if (!(_state isEqualType createHashMap) || {(_state getOrDefault ["schema",-1]) != 1}) exitWith {_result};
    if (_mode == "EXPIRE") exitWith {
        if ((_payload param [0,"",[""]]) != (_state get "token")) exitWith {false};
        call _clear;true
    };
    _group=_state get "group";_gunner=_state get "gunner";_target=_state get "target";
    private _shotMatches=true;
    if (_mode == "SHOT") then {
        private _event=_payload param [0,[],[[]]];
        _shotMatches=!( count _event < 8 || {(_payload param [1,-1,[0]]) != (_state get "handler")}
        || {(_state get "handler") < 0} || {(_state get "shotAt") >= 0}
        || {(_event select 0) != _vehicle} || {(_event select 7) != _gunner}
        || {(_event select 1) != (_state get "weapon")} || {(_event select 2) != (_state get "muzzle")}
        || {(_event select 4) != (_state get "ammo")} || {(_event select 5) != (_state get "magazine")}
        || {isNull (_event select 6)}
        || {(getShotParents (_event select 6)) isNotEqualTo [_vehicle,_gunner]});
    };
    if (!_shotMatches) exitWith {false};
    if ((_state get "owner") != clientOwner || {!(call _valid)}) exitWith {call _clear;_result};
    if (_mode == "TAKE") exitWith {
        if ((_state get "shotAt") < 0) exitWith {[]};
        private _proof=[_target,+(_state get "position"),_state get "until",_state get "shotAt"];
        call _clear;_proof
    };
    _vehicle removeEventHandler ["Fired",_state get "handler"];
    _state set ["handler",-1];_state set ["shotAt",serverTime];true
};
};
_result
