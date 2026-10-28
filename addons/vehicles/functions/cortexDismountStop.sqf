/*
 * Author: WaldoTheWarfighter
 * Passenger stop/continuation proof retains the full current native waypoint identity;
 * same-position policy, script, attachment or synchronization edits end old cooperation.
 * Purpose: Apply and retire an exact crew/native-order-owned passenger safe-stop speed cap.
 * New caps refuse active or unresolved selected-platform movement; release remains exact settings cleanup.
 * Locality/authority: Actual vehicle and crew-group owner only. Both original operating actors
 * must remain local, available and in their original seats. ACQUIRE continuation additionally
 * requires captured native tasks/order; RELEASE only restores an unchanged owned cap and
 * does not require obsolete movement intent to remain current. No route or task is issued.
 * Repeat/JIP: Public proof can be observed by a new actual owner without renewing the baseline.
 * Ordinary plain speed caps retire before acquisition; active recovery and outstanding
 * pass/queue consent refuse nested ownership. Consent cannot be treated as quiescent cap state.
 * No worker, route, boarding command or timer. Terminal refusal records unresolved evidence,
 * revokes the active proof and blocks reacquisition for this group epoch; it grants no late retry.
 * Operation generation is not release authority: common cleanup may already have advanced it.
 * Arguments: 0 vehicle OBJECT objNull; 1 crew group GROUP grpNull; 2 mode STRING ACQUIRE;
 * 3 restore BOOL true (RELEASE only; false yields without native writes).
 * Return: BOOL - confirmed owned stop or confirmed restoration/no-op; false means refused/unresolved.
 * Current callers: CortexVehicles, CortexReleaseGroup, CortexStop.
 * Example: [_truck,group driver _truck,"RELEASE",true] call CBE_fnc_CortexDismountStop;
 */
params [["_vehicle",objNull,[objNull]],["_group",grpNull,[grpNull]],
    ["_mode","ACQUIRE",[""]],["_restore",true,[false]]];
if (isNull _vehicle || {isNull _group} || {!local _vehicle}) exitWith {false};
_mode=toUpperANSI _mode;
if !(_mode in ["ACQUIRE","RELEASE"]) exitWith {false};
private _result=false;
isNil {
    if (!local _vehicle) exitWith {};
    private _saved=_vehicle getVariable ["CBE_Cortex_DismountForcedSpeed",[]];
    private _proof=_vehicle getVariable ["CBE_Cortex_DismountStopReceipt",[]];
    private _blocked=_vehicle getVariable ["CBE_Cortex_DismountStopUnresolved",[]];
    if (_mode == "RELEASE" && {_saved isEqualTo []} && {_proof isEqualTo []}) exitWith {
        // Repeated cleanup must not relabel an earlier unresolved handback as success.
        _result=_blocked isEqualTo [] || {_blocked isEqualType [] && {count _blocked == 6}
            && {(_blocked select 0) isEqualType grpNull} && {(_blocked select 0) != _group}};
    };
    private _typed=_saved isEqualType [] && {count _saved == 2}
        && {_saved findIf {!(_x isEqualType 0) || {!finite _x}} < 0}
        && {(_saved select 0) >= -1} && {(_saved select 1) == 0}
        && {_proof isEqualType []} && {count _proof == 8}
        && {(_proof select 0) isEqualType grpNull} && {(_proof select 0) == _group}
        && {(_proof select 1) isEqualType objNull} && {(_proof select 2) isEqualType objNull}
        && {(_proof select 3) isEqualType []}
        && {(_proof select 4) isEqualType ""} && {(_proof select 5) isEqualType []}
        && {(_proof select 6) isEqualType ""} && {(_proof select 7) isEqualType []};
    // Another group's live receipt cannot be retired by this caller.
    if (_proof isEqualType [] && {count _proof == 8}
        && {(_proof select 0) isEqualType grpNull} && {(_proof select 0) != _group}) exitWith {};
    private _dismountQueue=_vehicle getVariable ["CBE_DrivingQueue_Consent",createHashMap];
    private _dismountPass=_vehicle getVariable ["CBE_DrivingPass_Consent",[]];
    private _dismountAgreement=_vehicle getVariable ["CBE_DrivingPass_Agreement",[]];
    // Outstanding protocol proof must retire through its owner, never beneath a new stop.
    private _protocolFree=_dismountQueue isEqualType createHashMap && {count _dismountQueue == 0}
        && {_dismountPass isEqualType []} && {_dismountPass isEqualTo []}
        && {_dismountAgreement isEqualType []} && {_dismountAgreement isEqualTo []};
    private _driver=driver _vehicle;
    private _commander=effectiveCommander _vehicle;
    private _available=_protocolFree && {local _group} && {!isNull _driver} && {!isNull _commander}
        && {simulationEnabled _vehicle} && {!isObjectHidden _vehicle}
        && {!(_vehicle getVariable ["CBE_Convoy_Active",false])}
        && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        && {!([_vehicle] call CBE_fnc_CompatibilityExternalControl)}
        && {!([_group] call CBE_fnc_CortexExternalTakeover)}
        && {[_driver,_commander] findIf {
            !local _x || {group _x != _group} || {isPlayer _x}
                || {!isNull remoteControlled _x} || {!([_x] call CBE_fnc_CortexCombatEffective)}
                || {!simulationEnabled _x} || {isObjectHidden _x}
                || {!([_x] call CBE_fnc_CortexActorFireTaskAvailable)}
        } < 0};
    private _native=if (_available && {_mode == "ACQUIRE"}) then {[_group] call CBE_fnc_NativeOrderReceipt} else {[]};
    private _crewMatches=_typed && {_available}
        && {_driver == (_proof select 1)} && {_commander == (_proof select 2)};
    private _matches=_crewMatches
        && {_native isEqualTo (_proof select 3)}
        && {currentCommand _driver == (_proof select 4)}
        && {expectedDestination _driver isEqualTo (_proof select 5)}
        && {currentCommand _commander == (_proof select 6)}
        && {expectedDestination _commander isEqualTo (_proof select 7)};
    private _epoch=_group getVariable ["CBE_AIPass_Epoch",0];
    if (_mode == "ACQUIRE" && {_saved isEqualTo []} && {_proof isEqualTo []}) exitWith {
        if (!_available || {_blocked isEqualType [] && {count _blocked == 6}
            && {(_blocked select 0) == _group} && {(_blocked select 1) == _epoch}}) exitWith {};
        // Selected-platform native movement retains command custody through retirement.
        // A fresh boarding request cannot add an independent zero cap over that worker.
        private _selectedWork=_vehicle getVariable ["CBE_VehicleTacticalMove_Work",createHashMap];
        if ((_group getVariable ["CBE_VehicleTacticalMove_Reference",[]]) isNotEqualTo []
            || {!(_selectedWork isEqualType createHashMap)}
            || {count _selectedWork > 0 && {(_selectedWork getOrDefault ["phase",""]) != "RETIRED"}}) exitWith {};
        // Do not nest a passenger cap over an ordinary cap or its unfinished recovery.
        // A plain ordinary cap may hand back first; active native recovery must finish itself.
        if (["CBE_DrivingRecovery_Work","CBE_DrivingPass_Work","CBE_DrivingCorridor_Work","CBE_DrivingBypass_Work"]
            findIf {count (_vehicle getVariable [_x,createHashMap]) > 0} >= 0
            || {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isNotEqualTo []}) exitWith {};
        if ((_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isNotEqualTo []
            || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo []}) then {
            [_vehicle,_group] call CBE_fnc_DrivingAssistRelease;
        };
        if ((_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isNotEqualTo []
            || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo []}
            || {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isNotEqualTo []}
            || {([_group] call CBE_fnc_NativeOrderReceipt) isNotEqualTo _native}
            || {driver _vehicle != _driver} || {effectiveCommander _vehicle != _commander}) exitWith {};
        private _previous=getForcedSpeed _vehicle;
        if (!finite _previous || {_previous < -1}) exitWith {};
        _proof=[_group,_driver,_commander,_native,currentCommand _driver,expectedDestination _driver,
            currentCommand _commander,expectedDestination _commander];
        _vehicle setVariable ["CBE_Cortex_DismountStopReceipt",_proof,true];
        _vehicle setVariable ["CBE_Cortex_DismountStopOrder",[_group getVariable ["CBE_OperationGeneration",0],
            +_native],true];
        _saved=[_previous,0];
        _vehicle setVariable ["CBE_Cortex_DismountForcedSpeed",_saved,true];
        if (_previous != 0) then {_vehicle forceSpeed 0};
        _result=getForcedSpeed _vehicle == 0;
        // Retain an unconfirmed application for terminal retirement, never invent success.
    };
    if (_mode == "ACQUIRE" && {_matches} && {getForcedSpeed _vehicle == 0}) exitWith {_result=true};
    if (_saved isEqualTo [] && {_proof isEqualTo []}) exitWith {_result=true};
    // Returning an unchanged cap is settings cleanup, not permission to replay the old route.
    // A newer native order must not strand the same ordinary crew at our former zero cap.
    if (_mode == "RELEASE" && {_restore} && {_crewMatches}
        && {getForcedSpeed _vehicle == (_saved select 1)}) then {
        if ((_saved select 0) != (_saved select 1)) then {_vehicle forceSpeed (_saved select 0)};
        _result=getForcedSpeed _vehicle == (_saved select 0);
    };
    if (!_result) then {
        // Evidence only. Never replay this proof after a replacement task or delayed readback.
        _vehicle setVariable ["CBE_Cortex_DismountStopUnresolved",[_group,_epoch,serverTime,
            ["REFUSED","YIELDED"] select (!_restore),_saved,_proof],true];
    };
    _vehicle setVariable ["CBE_Cortex_DismountForcedSpeed",nil,true];
    _vehicle setVariable ["CBE_Cortex_DismountStopReceipt",nil,true];
    _vehicle setVariable ["CBE_Cortex_DismountStopOrder",nil,true];
};
_result
