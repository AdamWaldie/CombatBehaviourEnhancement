/*
 * Author: WaldoTheWarfighter
 * Recovery is explicitly mode-bound: destination and SIMPLE_BACK have distinct native
 * ownership proof. Unknown modes grant no cleanup, adoption or command authority.
 * Purpose: Offers an existing pending driving-release receipt to its new vehicle owner.
 * Locality / Authority: Native LandVehicle init/Local and actual driving-seat events on each machine, never remote calls.
 * Released abort STOP may adopt only a captured group-edge identity after exact native validation.
 * With tactics disabled and its group handler removed, an actual vehicle Local edge can capture
 * a five-second cleanup-only source proposal. Crew/init retries reuse that original window;
 * they never enable tactics, install a group handler or recreate a source identity.
 * Only cleanup registration is permitted; the existing exact release guards authorize commands.
 * Repeat/JIP: Every locality edge invalidates older lookup callbacks. At most five one-second
 * late-receipt or pending-flag lookups for occupied vehicles; later delivery remains unsupported.
 * Arguments: 0 vehicle <OBJECT, objNull>; 1 gained locality <BOOL, false>;
 * 2 lookup attempt <NUMBER, 0>; 3 local epoch <NUMBER, -1>;
 * 4 actual native vehicle-locality edge <BOOL, false>, internal XEH callback only.
 * Return Value: BOOL - true only when a pending reverse receipt was offered, not physical success.
 * Current callers: XEH_postInit LandVehicle init/Local, CortexLocality, DrivingRecoveryCrewAdopt and bounded delayed lookup.
 * Crew locality/entry/seat changes start a fresh observation window, never a fresh movement or recovery lifetime.
 * Example: [truck1,local truck1] call CBE_fnc_DrivingRecoveryAdopt;
 */
params [["_vehicle",objNull,[objNull]],["_gained",false,[true]],
    ["_attempt",0,[0]],["_epoch",-1,[0]],["_nativeEdge",false,[true]]];
if (remoteExecutedOwner > 0 || {isNull _vehicle} || {!(_vehicle isKindOf "LandVehicle")}
    || {_vehicle isKindOf "StaticWeapon"}
    || {!finite _attempt} || {_attempt < 0} || {_attempt > 5} || {_attempt != floor _attempt}) exitWith {false};
private _accepted=false;
isNil {
    if (_attempt == 0) then {
        _epoch=1+(_vehicle getVariable ["CBE_DrivingRecovery_LocalEpoch",0]);
        _vehicle setVariable ["CBE_DrivingRecovery_LocalEpoch",_epoch];
        if (_nativeEdge) then {
            _vehicle setVariable ["CBE_DrivingAbort_LocalEdge",nil];
            if (_gained && {local _vehicle} && {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}) then {
                private _edgeGroup=group driver _vehicle;
                private _status=_edgeGroup getVariable ["CBE_Driving_State",[]];
                if (!isNull _edgeGroup && {_status isEqualType []} && {count _status == 6}
                    && {[1,4,5] findIf {private _value=_status select _x;
                        !(_value isEqualType 0) || {!finite _value} || {_value < 0} || {_value != floor _value}} < 0}
                    && {(_status select 4) != clientOwner}) then {
                    _vehicle setVariable ["CBE_DrivingAbort_LocalEdge",[_edgeGroup,
                        [_status select 4,_status select 5,_status select 1],serverTime+5]];
                };
            };
        };
    };
    if (_epoch == (_vehicle getVariable ["CBE_DrivingRecovery_LocalEpoch",0])
        && {_gained} && {local _vehicle} && {alive _vehicle}) then {
        private _abort=_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap];
        if (_abort isEqualType createHashMap && {"releasedCap" in _abort}) then {
            private _abortGroup=_abort getOrDefault ["group",grpNull];
            if (!isNull _abortGroup && {local _abortGroup}) then {
                // Only the real vehicle edge captured this identity. Late group/crew
                // arrival consumes its original window; init and seat events cannot renew it.
                private _edge=_vehicle getVariable ["CBE_DrivingAbort_LocalEdge",[]];
                if (count _edge == 3 && {(_edge select 0) == _abortGroup}
                    && {(_edge select 1) isEqualTo (_abort getOrDefault ["owner",[]])}
                    && {serverTime < (_edge select 2)}
                    && {!(missionNamespace getVariable ["CBE_AIPass_Active",false])}
                    && {(_abortGroup getVariable ["CBE_AIPass_LocalHandler",-1]) < 0}) then {
                    if (isNil {_abortGroup getVariable "CBE_Driving_Generation"}) then {_abortGroup setVariable ["CBE_Driving_Generation",0]};
                    _abortGroup setVariable ["CBE_DrivingAbort_Transfer",[_edge select 1,
                        _abortGroup getVariable ["CBE_AIPass_Epoch",0],_edge select 2]];
                };
                private _transfer=_abortGroup getVariable ["CBE_DrivingAbort_Transfer",[]];
                if (count _transfer == 3) then {
                    [_vehicle,_abortGroup,createHashMap,[],{false},_transfer select 0] call CBE_fnc_DrivingAbortHandback;
                };
                [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
            };
        };
        private _work=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
        if (_work getOrDefault ["releasePending",false]
            && {(_work getOrDefault ["kind",""]) == "REVERSE"}
            && {(_work getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]}) then {
            [_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
            _accepted=true;
        } else {
            // A reverse receipt and its later pending flag can arrive separately. Observe
            // within the original window only; nonpending work never authorizes release.
            private _lookup=count _work == 0 || {(_work getOrDefault ["kind",""]) == "REVERSE"
                && {(_work getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]}};
            if (_lookup && {_attempt < 5} && {count crew _vehicle > 0}) then {
                [{_this call CBE_fnc_DrivingRecoveryAdopt},
                    [_vehicle,true,_attempt+1,_epoch],1] call CBA_fnc_waitAndExecute;
            };
        };
    };
};
_accepted
