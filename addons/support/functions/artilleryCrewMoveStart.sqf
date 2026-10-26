/*
 * Author: WaldoTheWarfighter
 * Purpose: Admit a finite native movement for only an explicitly selected battery's operating crew.
 * Locality/authority: Current local battery/group/AI crew, authenticated positioning or relocation caller only.
 * Shared movement acquisition first retires ordinary driving; unresolved parent work refuses.
 * No group waypoint or membership is changed. Only the later owner-local FSM may issue crew moves.
 * Repeat/JIP: One exact token/session/reference, original deadlines and monotonic serial; existing
 * work never becomes a new baseline. New owners may retire old work, never replay its outward leg.
 * Arguments: 0 battery OBJECT,objNull; 1 token STRING,""; 2 original positioning(10) or relocation(7) session ARRAY,[];
 * 3 selected supported endpoint ARRAY of three finite NUMBER,[]; 4 kind STRING,"POSITION" or "SCOOT".
 * Return: BOOL admission and FSM start, not native acknowledgement, arrival or firing readiness.
 * Current callers: CortexArtilleryPosition and CortexArtilleryScoot; not an exposed task module.
 * Example: [_battery,_token,_session,_spot] call CBE_fnc_ArtilleryCrewMoveStart;
 */
params [["_battery",objNull,[objNull]],["_token","",[""]],["_session",[],[[]]],["_spot",[],[[]]],["_kind","POSITION",[""]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
if (isNull _battery || {!local _battery} || {_token == ""} || {count _session != ([10,7] select (_kind == "SCOOT"))}
    || {count _spot != 3} || {_spot findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
    || {surfaceIsWater _spot}) exitWith {false};
private _scoot=_kind == "SCOOT";
if !(_kind in ["POSITION","SCOOT"]) exitWith {false};
private _movementOrder=if (_scoot) then {_session select 5} else {[_session select 3,_session select 4]};
if (!(_movementOrder isEqualType []) || {count _movementOrder != 2}
    || {!((_movementOrder select 0) isEqualType grpNull)}
    || {!((_movementOrder select 1) isEqualType [])}) exitWith {false};
if (_scoot && {[1,2,3] findIf {!((_session select _x) isEqualType 0) || {!finite (_session select _x)}} >= 0
    || {!((_session select 6) isEqualType [])} || {count (_session select 6) != 2}}) exitWith {false};
private _purpose=_session select ([6,4] select _scoot);
private _counter=_purpose == "COUNTER";
private _identityCurrent={
    if (_scoot) exitWith {
        (_session select 0) == _token && {serverTime < (_session select 3)}
            && {(_battery getVariable ["CBE_Cortex_ArtilleryScootToken",""]) == _token}
            && {(_battery getVariable ["CBE_Cortex_ArtilleryScootSession",[]]) isEqualTo _session}
    };
    (_battery getVariable ["CBE_AIPass_FireToken",""]) == _token
        && {(_battery getVariable ["CBE_ArtilleryPosition_Session",[]]) isEqualTo _session}
};
private _generationCurrent={
    if (_scoot) exitWith {
        (_session select 1) == (missionNamespace getVariable [
            ["CBE_ArtilleryScoot_SupportGeneration","CBE_ArtilleryScoot_CounterGeneration"] select _counter,0])
            && {!_counter || {(_session select 2) == (missionNamespace getVariable ["CBE_AIPass_CounterGeneration",0])}}
            && {missionNamespace getVariable [["CBE_AIPass_Artillery_ShootAndScoot","CBE_AIPass_CounterBattery_ShootAndScoot"] select _counter,true]}
            && {(_session select 6) isEqualTo _seats}
    };
    (_session select 5) == (missionNamespace getVariable [
        ["CBE_Artillery_SupportFireGeneration","CBE_AIPass_CounterGeneration"] select _counter,0])
        && {(_session select 7) != "SMOKE" || {
            (_session select 8) == (missionNamespace getVariable ["CBE_Artillery_SmokeFireGeneration",0])
            && {[_group,"CBE_AIPass_ArtillerySmoke_Enable",true] call CBE_fnc_CortexFeatureEnabled}}}
};
private _started=false;
isNil {
    _started=call {
        private _group=_movementOrder select 0;
        private _driver=driver _battery;private _operator=effectiveCommander _battery;
        if (isNull _operator) then {_operator=_driver};
        private _seats=[_driver,_operator];
        private _until=if (_scoot) then {(serverTime+120) min ((_session select 3)+120)} else {_session select 2};
        private _holdUntil=if (_scoot) then {_until} else {_session select 9};
        if (!(_group isEqualType grpNull) || {isNull _group} || {!local _group}
            || {!(_until isEqualType 0)} || {!finite _until} || {_until <= serverTime}
            || {!(_holdUntil isEqualType 0)} || {!finite _holdUntil} || {_holdUntil < _until}
            || {!alive _battery} || {!canMove _battery} || {waterDamaged _battery}
            || {!simulationEnabled _battery} || {isObjectHidden _battery}
            || {!(_battery isKindOf "LandVehicle")} || {_battery isKindOf "StaticWeapon"}
            || {!([_group,false,false,true] call CBE_fnc_CortexIsEligible)}
            || {[_group] call CBE_fnc_CortexExternalTakeover}
            || {!(call _identityCurrent)}
            || {(_group getVariable ["CBE_ArtilleryCrew_Reference",[]]) isNotEqualTo []}
            || {count (_group getVariable ["CBE_Operation",createHashMap]) > 0}
            || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_movementOrder select 1)}) exitWith {false};
        // Discovery may not yet have adopted this group. Establish the epoch before the
        // journal, then recheck the server session and native route after that cleanup.
        if (!(_group getVariable ["CBE_AIPass_Adopted",false])) then {
            // Locality normally resumes pending scoot tokens. This caller IS their first
            // admission; suppress that synchronous callback, not other adoption cleanup.
            [_group,true,!_scoot] call CBE_fnc_CortexLocality;
        };
        if (!local _group || {!(_group getVariable ["CBE_AIPass_Adopted",false])}) exitWith {false};
        private _sourceCurrent={
            call _identityCurrent && {call _generationCurrent}
                && {([_group] call CBE_fnc_NativeOrderReceipt) isEqualTo (_movementOrder select 1)}
                && {serverTime < _until} && {missionNamespace getVariable ["CBE_AIPass_Active",false]}
                && {!([] call CBE_fnc_CortexIsPaused)}
                && {[_group,["CBE_AIPass_Artillery_Enable","CBE_AIPass_CounterBattery_Enable"] select _counter,false]
                    call CBE_fnc_CortexFeatureEnabled}
                && {isNil {_battery getVariable "CBE_ExternalDrivingOwner"}}
                && {!(_battery getVariable ["CBE_Convoy_Active",false])}
                && {!([_battery] call CBE_fnc_CompatibilityExternalControl)}
                && {!([_group] call CBE_fnc_CortexZeusHeld)}
        };
        private _crewCurrent={
            _seats findIf {isNull _x || {!local _x} || {group _x != _group}
                || {objectParent _x != _battery} || {isPlayer _x} || {!isNull remoteControlled _x}
                || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                || {!simulationEnabled _x} || {isObjectHidden _x}
                || {!([_x] call CBE_fnc_CortexCombatEffective)}
                || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
                || {([_x] call CBE_fnc_CortexExternalOwner) != ""}
                || {[_x] call CBE_fnc_CompatibilityExternalControl}
                || {!(_x checkAIFeature "MOVE")} || {!(_x checkAIFeature "PATH")}
                || {!(currentCommand _x in ["","MOVE","WAIT"])}} < 0
        };
        if (!(call _sourceCurrent) || {!(call _crewCurrent)}) exitWith {false};
        // Ordinary driving is group-scoped: authored receipts are waypoint metadata, not
        // NATIVE_MOVE's nine-field vehicle receipt. Retire only a current gun-only brain.
        // Check both the tracked cleanup roster and current operating seats before the
        // common handover can call DrivingOperationFinish over every tracked vehicle.
        private _driving=_group getVariable ["CBE_Driving_Brain",createHashMap];
        private _drivingGunOnly=true;
        if (count _driving > 0) then {
            private _route=_driving getOrDefault ["route",[]];
            private _controlled=_group getVariable ["CBE_DrivingAssist_Vehicles",[]];
            private _members=units _group;
            private _crewVehicle=_driving getOrDefault ["crewVehicle",objNull];
            _drivingGunOnly=_route isEqualType [] && {_route isNotEqualTo []}
                && {_controlled isEqualType []} && {count _controlled <= 64} && {count _members <= 64}
                && {_controlled findIf {!(_x isEqualType objNull) || {!isNull _x && {_x != _battery}}} < 0}
                && {_crewVehicle isEqualType objNull} && {isNull _crewVehicle || {_crewVehicle == _battery}}
                && {([_group] call CBE_fnc_DrivingRouteReceipt) isEqualTo _route}
                && {(_route param [0,"",[""]]) != "NATIVE_MOVE"
                    || {count _route == 9 && {(_route select 2) isEqualTo _battery}}}
                && {_members findIf {
                    private _occupied=objectParent _x;
                    !isNull _occupied && {_occupied != _battery}
                        && {_occupied isKindOf "LandVehicle"} && {!(_occupied isKindOf "StaticWeapon")}
                        && {driver _occupied in _members || {effectiveCommander _occupied in _members}}
                } < 0};
        };
        if (!_drivingGunOnly) exitWith {false};
        if !([_group,"ARTILLERY_CREW",true,_holdUntil] call CBE_fnc_CortexOwnershipLease) exitWith {false};
        private _refuse={[_group,"ARTILLERY_CREW",false] call CBE_fnc_CortexOwnershipLease;false};
        if (!(call _sourceCurrent) || {!(call _crewCurrent)} || {driver _battery != _driver}
            || {!((effectiveCommander _battery) in [_operator,objNull])}
            || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo (_movementOrder select 1)}) exitWith {call _refuse};
        private _baseline=[_driver,_operator] call CBE_fnc_VehicleCrewNativeObservation;
        if (count _baseline != 4) exitWith {call _refuse};
        if ([0,2] findIf {(_baseline select _x) == "MOVE" && {
            private _goal=(_baseline select (_x+1)) param [0,[],[[]]];
            count _goal != 3 || {_goal findIf {!(_x isEqualType 0) || {!finite _x}} >= 0}
        }} >= 0) exitWith {call _refuse};
        private _serial=(_battery getVariable ["CBE_ArtilleryCrew_Serial",0])+1;
        private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
        private _reference=[_battery,_token,_serial,_epoch,clientOwner];
        private _lease=["ARTILLERY_CREW",time+(_holdUntil-serverTime)];
        private _work=createHashMapFromArray [["token",_token],["serial",_serial],["group",_group],["kind",_kind],
            ["owner",clientOwner],["epoch",_epoch],["reference",_reference],["crew",_seats],
            ["session",+_session],["route",+(_movementOrder select 1)],["baseline",_baseline],
            ["goal",+_spot],["spot",+_spot],["phase","ISSUE"],["moveUntil",_until],
            ["holdUntil",_holdUntil],["localLease",_lease],["progressPosition",getPosASL _battery],
            ["progressAt",serverTime],["release",false]];
        _battery setVariable ["CBE_ArtilleryCrew_Serial",_serial,true];
        _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
        _group setVariable ["CBE_ArtilleryCrew_Reference",_reference,true];
        private _state=[_group] call CBE_fnc_CortexGroupState;
        _state set ["movementLease",_lease];
        private _executorSerial=(_battery getVariable ["CBE_ArtilleryCrew_ExecutorSerial",0])+1;
        _battery setVariable ["CBE_ArtilleryCrew_ExecutorSerial",_executorSerial];
        private _handle=[_battery,_token,_serial,_executorSerial] execFSM "\z\cbe\addons\main\fsm\artilleryCrewMove.fsm";
        _battery setVariable ["CBE_ArtilleryCrew_FSM",[_serial,_handle,clientOwner,_epoch,_executorSerial]];
        if (!(_handle isEqualType 0) || {!finite _handle} || {_handle < 0}) exitWith {
            _work set ["phase","RETIRED"];_work set ["result","FSM_START_REFUSED"];
            _battery setVariable ["CBE_ArtilleryCrew_Work",_work,true];
            _group setVariable ["CBE_ArtilleryCrew_Reference",nil,true];
            if ((_state getOrDefault ["movementLease",[]]) isEqualTo _lease) then {_state deleteAt "movementLease"};
            call _refuse
        };
        [_battery,"INSTALL",["CBE_ArtilleryCrew_Work","CBE_ArtilleryCrew_Reference","ARTILLERY_CREW"]]
            call CBE_fnc_VehicleCrewMoveDeletionWatch;
        true
    };
};
_started
