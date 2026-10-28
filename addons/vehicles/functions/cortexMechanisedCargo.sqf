/*
 * Author: WaldoTheWarfighter
 * Purpose: Retain actual cargo and local passenger-owner consent for finite troop support.
 * Locality/authority: Vehicle, crew group and participating passenger groups must all be
 * local to this AI host. This is not a remote consent or controller handover protocol.
 * Repeat/JIP: ACK records actual mounted cargo before the CBE exit command. Original
 * cohort expiry never extends. READ is side-effect free. Metadata is local, not JIP authority.
 * Arguments: vehicle OBJECT objNull; crew group GROUP grpNull; mode STRING READ;
 * actor OBJECT objNull (ACK only); expected source ARRAY [] or original
 * [passenger group,passenger epoch,cohort identity,acknowledged cargo actors] (READ/CHECK).
 * Return: READ [dismount proof,source] or []; ACK returns cohort identity or[].
 * Limits:64seat rows,4passenger groups,16original actors per group,64owned-exit rows.
 * No seat, group, movement, reveal, setting or scheduler operation is issued.
 * Current callers: CortexOnboardContact (ACK), CortexMechanisedSupport (READ).
 * Example: [_apc,group driver _apc,"ACK",_passenger] call CBE_fnc_CortexMechanisedCargo;
 */
params [["_vehicle",objNull,[objNull]],["_crewGroup",grpNull,[grpNull]],
    ["_mode","READ",[""]],["_actor",objNull,[objNull]],["_expected",[],[[]]]];
_mode=toUpperANSI _mode;
if (!(_mode in ["READ","ACK"]) || {remoteExecutedOwner > 0}
    || {isNull _vehicle} || {!local _vehicle} || {isNull _crewGroup} || {!local _crewGroup}
    || {!alive _vehicle} || {!(_crewGroup getVariable ["CBE_AIPass_Adopted",false])}
    || {group driver _vehicle != _crewGroup} || {group effectiveCommander _vehicle != _crewGroup}
    || {[_crewGroup] call CBE_fnc_CortexExternalTakeover}) exitWith {[]};
private _crewEpoch=_crewGroup getVariable ["CBE_AIPass_Epoch",-1];
private _crewContext=[clientOwner,_crewEpoch,_crewGroup,driver _vehicle,effectiveCommander _vehicle,
    [_crewGroup] call CBE_fnc_NativeOrderReceipt];
private _cohort=_vehicle getVariable ["CBE_Cortex_MechCargo",[]];
private _current=_cohort isEqualType [] && {count _cohort == 4}
    && {(_cohort select 0) isEqualType []} && {count (_cohort select 0) == 3}
    && {(_cohort select 1) isEqualTo _crewContext}
    && {(_cohort select 2) isEqualType 0} && {finite (_cohort select 2)}
    && {serverTime < (_cohort select 2)} && {(_cohort select 2) <= serverTime+60}
    && {(_cohort select 3) isEqualType []} && {count (_cohort select 3) <= 4};
if (_mode == "ACK") exitWith {
    if (isNull _actor || {!local _actor} || {isPlayer _actor} || {!alive _actor}
        || {objectParent _actor != _vehicle}) exitWith {[]};
    private _passengerGroup=group _actor;
    if (_passengerGroup == _crewGroup || {!local _passengerGroup}
        || {!(_passengerGroup getVariable ["CBE_AIPass_Adopted",false])}
        || {side _passengerGroup != side _crewGroup}
        || {[_passengerGroup] call CBE_fnc_CortexExternalTakeover}) exitWith {[]};
    private _state=_passengerGroup getVariable ["CBE_AIPass_State",createHashMap];
    private _owned=_state getOrDefault ["dismounted",[]];
    if (count _owned > 64 || {_owned findIf {_x isEqualType [] && {count _x == 2}
        && {(_x select 0) isEqualTo _actor} && {(_x select 1) isEqualTo _vehicle}} < 0}) exitWith {[]};
    private _seats=fullCrew [_vehicle,"",false];
    if (count _seats > 64) exitWith {[]};
    private _actual=(_seats select {
        private _person=_x select 0;private _role=_x select 1;
        alive _person && {local _person} && {!isPlayer _person} && {group _person == _passengerGroup}
            && {_role == "cargo" || {_role == "turret" && {_x select 4}}}
    }) apply {_x select 0};
    if (!(_actor in _actual) || {count _actual > 16}) exitWith {[]};
    if (!_current) then {
        private _serial=(_vehicle getVariable ["CBE_Cortex_MechCargoSerial",0])+1;
        _vehicle setVariable ["CBE_Cortex_MechCargoSerial",_serial];
        _cohort=[[clientOwner,_crewEpoch,_serial],_crewContext,serverTime+60,[]];
    };
    private _rows=+(_cohort select 3);
    private _index=_rows findIf {(_x select 0) isEqualTo _passengerGroup};
    if (_index < 0 && {count _rows >= 4}) exitWith {[]};
    private _epoch=_passengerGroup getVariable ["CBE_AIPass_Epoch",-1];
    private _native=[_passengerGroup] call CBE_fnc_NativeOrderReceipt;
    private _row=if (_index < 0) then {[]} else {+(_rows select _index)};
    if (_row isEqualTo [] || {(_row select 1) != _epoch} || {(_row select 2) isNotEqualTo _native}) then {
        _row=[_passengerGroup,_epoch,_native,[],[],_passengerGroup getVariable ["CBE_OperationGeneration",0]];
    };
    private _original=+(_row select 3);
    {_original pushBackUnique _x} forEach _actual;
    if (count _original > 16) exitWith {[]};
    _row set [3,_original];
    private _exits=+(_row select 4);
    _exits pushBackUnique _actor;
    _row set [4,_exits];
    if (_index < 0) then {_rows pushBack _row} else {_rows set [_index,_row]};
    _cohort set [3,_rows];
    _vehicle setVariable ["CBE_Cortex_MechCargo",_cohort];
    +(_cohort select 0)
};
if (!_current || {_expected isNotEqualTo [] && {count _expected != 4}}) exitWith {[]};
private _used=_vehicle getVariable ["CBE_Cortex_MechCargoUsed",[]];
private _result=[];
{
    _x params ["_passengerGroup","_epoch","_native","_original","_acknowledged","_generation"];
    private _source=[_passengerGroup,_epoch,+(_cohort select 0),+_acknowledged];
    if (_expected isEqualTo _source || {_expected isEqualTo []
        && {!([_cohort select 0,_passengerGroup] in _used)}}) then {
        private _index=currentWaypoint _passengerGroup;
        private _leader=leader _passengerGroup;
        if (local _passengerGroup && {!isNull _leader} && {isNull objectParent _leader}
            && {[_leader] call CBE_fnc_CortexCombatEffective}
            && {combatMode _passengerGroup != "BLUE"} && {combatMode _passengerGroup != "GREEN"}
            && {behaviour _leader != "STEALTH"}
            && {(_passengerGroup getVariable ["CBE_AIPass_Garrison",[]]) isEqualTo []}
            && {(_passengerGroup getVariable ["CBE_AIPass_Defend",[]]) isEqualTo []}
            && {!(_passengerGroup getVariable ["CBE_AIPass_ClearBuilding",false])}
            && {!(_index < count waypoints _passengerGroup
                && {waypointType [_passengerGroup,_index] in ["HOLD","SENTRY"]}
                && {waypointDescription [_passengerGroup,_index] != "CBE AI PASS"})}
            && {_epoch == (_passengerGroup getVariable ["CBE_AIPass_Epoch",-1])}
            && {side _passengerGroup == side _crewGroup}
            && {_native isEqualTo ([_passengerGroup] call CBE_fnc_NativeOrderReceipt)}
            && {!([_passengerGroup] call CBE_fnc_CortexExternalTakeover)}
            && {[_passengerGroup,"CBE_AIPass_Vehicles_Enable",true] call CBE_fnc_CortexFeatureEnabled}
            && {[_passengerGroup,"CBE_AIPass_VehicleDismount_Enable",true] call CBE_fnc_CortexFeatureEnabled}) then {
            private _state=_passengerGroup getVariable ["CBE_AIPass_State",createHashMap];
            private _owned=_state getOrDefault ["dismounted",[]];
            if (count _owned <= 64) then {
                private _ownedActors=(_owned select {_x isEqualType [] && {count _x == 2}
                    && {(_x select 1) isEqualTo _vehicle}}) apply {_x select 0};
                private _mobile=_acknowledged select {
                    _x in _original && {_x in _ownedActors} && {local _x} && {group _x == _passengerGroup}
                        && {isNull objectParent _x} && {!isPlayer _x}
                        && {simulationEnabled _x} && {!isObjectHidden _x}
                        && {[_x] call CBE_fnc_CortexCombatEffective} && {!fleeing _x}
                        && {_x checkAIFeature "MOVE"} && {_x checkAIFeature "PATH"}
                        && {currentCommand _x != "STOP"}
                };
                if (count _mobile >= 2) then {
                    _result=[[_cohort select 2,_generation,_acknowledged apply {[_x,_vehicle]},+_native],_source];
                };
            };
        };
    };
    if (_result isNotEqualTo []) exitWith {};
} forEach (_cohort select 3);
_result
