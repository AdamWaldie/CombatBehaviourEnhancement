/*
 * Author: WaldoTheWarfighter
 * Purpose: Restores recorded formation, attack permission, vehicle speed and unload settings; cancels only follower paths. A speed baseline is restored only when the
 * vehicle is leaving WAIT control, WAIT still owns the current cap and no newer controller owns it.
 * Unload policy and attack permission restore only while their convoy-applied values remain current.
 * A different current movement-operator group preserves the successor vehicle policy and orders.
 * Crew target cleanup also checks actor ownership and combat effectiveness; a newer target owner
 * keeps its command while obsolete convoy target metadata is retired.
 * Locality/authority: server owns registration; driving commands execute only on current owners.
 * Repeat/JIP: ordered registry snapshots replace old settings; owner-local paths rebuild on migration.
 * Arguments: 0: group <GROUP>, grpNull; 1: forget baseline <BOOL>, true; 2: baseline <ARRAY>, [] reads the locally received baseline; 3: still-controlled vehicles <ARRAY>, []; 4: cancellation reason <STRING, RELEASED>.
 * Return Value: Nothing.
 * Current callers: WAIT_fnc_ConvoySync, WAIT_fnc_ConvoyTick and the convoy operation FSM.
 * Example: [convoyGroup] call WAIT_fnc_ConvoyReleaseLocal;
 */
params [["_group", grpNull, [grpNull]], ["_forget", true, [true]], ["_restore", [], [[]]], ["_keepCrew", [], [[]]], ["_reason", "RELEASED", [""]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {};
private _brain=_group getVariable ["WAIT_Convoy_Brain",createHashMap];
if (count _brain > 0 && {_forget || {toUpperANSI _reason in ["ZEUS","PLAYER","EXTERNAL","EXTERNAL_OWNER","OWNERSHIP_LOST"]}}) then {
    _brain set ["cancelled",true];
    _brain set ["cancelReason",toUpperANSI _reason];
};
if (_forget) then {
    _group setVariable ["WAIT_Convoy_Brain",nil];
    _group setVariable ["WAIT_Convoy_Brain_FSM",nil];
};
if (local _group) then {
    private _state = _group getVariable ["WAIT_Convoy_LocalState",createHashMap];
    private _generation = _state getOrDefault ["operationGeneration",-1];
    private _operation = _group getVariable ["WAIT_Operation",createHashMap];
    if (_generation >= 0 && {(_operation getOrDefault ["intent",""]) == "CONVOY"}) then {
        [_group,_generation,toUpperANSI _reason] call WAIT_fnc_OperationCancel;
    };
};
if (_restore isEqualTo []) then {_restore = _group getVariable ["WAIT_Convoy_Restore", []]};
if (_restore isNotEqualTo []) then {
    _restore params ["_formation", "_attack", "_vehicles"];
    // A feature shutdown must restore the column's own baseline. A route, curator,
    // player or specialist controller is different: it owns the replacement order and
    // the saved convoy formation, attack permission and follower paths are evidence only.
    private _externalTakeover = local _group && {[_group] call WAIT_fnc_CortexExternalTakeover};
    private _mayRestoreGroup=local _group && {!_externalTakeover};
    if (_mayRestoreGroup) then {
        if (formation _group == "COLUMN") then {_group setFormation _formation};
        if (!attackEnabled _group) then {_group enableAttack _attack};
    };
    {
        _x params ["_vehicle", "_speed", "_unload"];
        if (_forget && {isServer} && {!(_vehicle in _keepCrew)} && {(_vehicle getVariable ["WAIT_Convoy_Group", grpNull]) == _group}) then {
            _vehicle setVariable ["WAIT_Convoy_Group", nil, true];
            _vehicle setVariable ["WAIT_Convoy_Active", nil, true];
        };
        {
            private _unit = _x;
            if (local _unit && {_forget} && {((_unit getVariable ["WAIT_Convoy_PassengerRevision",[]]) param [0,grpNull]) == _group}) then {
                _unit setVariable ["WAIT_Convoy_PassengerRevision",nil,true];
            };
            private _target = _unit getVariable ["WAIT_Convoy_Target", objNull];
            if (local _unit && {!isPlayer _unit} && {!isNull _target}) then {
                if ([_unit] call WAIT_fnc_CortexCombatEffective
                    && {!([group _unit,false,_unit] call WAIT_fnc_CortexExternalTakeover)}
                    && {assignedTarget _unit == _target}) then {_unit doTarget objNull};
                _unit setVariable ["WAIT_Convoy_Target", nil, true];
            };
        } forEach crew _vehicle;
        if (!(_vehicle in _keepCrew) && {local _vehicle}
            && {(_vehicle getVariable ["WAIT_Convoy_HitEHOwner",[]]) isEqualTo [_group,clientOwner]}) then {
            private _hitEH = _vehicle getVariable ["WAIT_Convoy_HitEH", -1];
            if (_hitEH >= 0) then {_vehicle removeEventHandler ["Hit", _hitEH]};
            _vehicle setVariable ["WAIT_Convoy_HitEH", nil];
            _vehicle setVariable ["WAIT_Convoy_HitEHOwner",nil];
        };
        if (local _vehicle) then {
            private _driver = driver _vehicle;
            private _externalCrew = (crew _vehicle) findIf {
                private _crewGroup = group _x;
                // The release can run after a replacement controller claimed just one crew
                // member. Do not issue a formation recall to that vehicle unless every crew
                // group remains outside the common Zeus/player/specialist handover boundary.
                [_crewGroup] call WAIT_fnc_CortexExternalTakeover
            } >= 0;
            private _movementOperator=effectiveCommander _vehicle;
            if (isNull _movementOperator) then {_movementOperator=_driver};
            private _reassignedVehicle=!isNull _movementOperator && {group _movementOperator != _group};
            private _externalVehicle=_reassignedVehicle
                || {!isNil {_vehicle getVariable "WAIT_ExternalDrivingOwner"}}
                || {[_group] call WAIT_fnc_CompatibilityExternalControl};
            private _ownedSpeed=_vehicle getVariable ["WAIT_Convoy_OwnedSpeed",[]];
            private _ownsCurrentSpeed=count _ownedSpeed == 3
                && {(_ownedSpeed select 0) isEqualTo _group}
                && {abs ((getForcedSpeed _vehicle)-(_ownedSpeed select 2)) <= 0.1};
            if !(_vehicle in _keepCrew) then {
                if (!_externalTakeover && {!_externalCrew} && {!_externalVehicle} && {_ownsCurrentSpeed}) then {
                    _vehicle forceSpeed _speed;
                };
                if (count _ownedSpeed >= 1 && {(_ownedSpeed select 0) isEqualTo _group}) then {
                    _vehicle setVariable ["WAIT_Convoy_OwnedSpeed",nil];
                };
                if (!_externalTakeover && {!_externalCrew} && {!_externalVehicle}
                    && {getUnloadInCombat _vehicle isEqualTo [false,false]}) then {
                    _vehicle setUnloadInCombat _unload;
                };
            };
            // A vehicle retained by the successor convoy still owns its route. An
            // external vehicle-level owner may likewise leave group ownership unchanged.
            // Neither permits a formation recall during obsolete convoy cleanup.
            if (_mayRestoreGroup && {!isNull _driver} && {!_externalCrew} && {!_externalVehicle}
                && {!(_vehicle in _keepCrew)} && {local _driver} && {group _driver == _group} && {_driver != leader _group}) then {
                _driver doFollow leader _group;
            };
        };
    } forEach _vehicles;
};
_group setVariable ["WAIT_Convoy_LocalState", nil];
if (_forget) then {_group setVariable ["WAIT_Convoy_Restore", nil]};
