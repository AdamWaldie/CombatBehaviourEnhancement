/*
 * Author: WaldoTheWarfighter
 * Internal arguments: 2 cap-only BOOL false; 3 offered ARRAY [] of
 * [state,baseline,group,issuing epoch,original server deadline,driver,commander,issuer,custodian].
 * Unconfirmed ordinary cap restoration retains exact state/baseline and a finite cap-only
 * cleanup receipt. Retries never rerun child controllers or renew the original 30-second window.
 * Queue crossing paths also retire through exact BypassRelease ownership before cap restoration; convoy work remains separately owned.
 * Unknown recovery command modes retain their cap/baseline and journal. Destination and
 * SIMPLE_BACK cleanup use their own exact native ownership proof before cap restoration.
 * Purpose: Releases the standalone CBE driving safety speed cap and restores the exact pre-CBE
 * forced-speed value only while that cap remains owned by CBE; a newer controller cap is preserved.
 * Matching pass consent retires its exact broker token before ordinary cap cleanup.
 * Matching corridor work retires through its exact command/route handback before cap cleanup.
 * Locality / Authority: Runs only where the vehicle is local; does not alter waypoints, route
 * selection, collision, damage, fuel, simulation or any external driving controller.
 * Final restoration/deletion checks the exact entry cap/state and owner epoch atomically after helper cleanup.
 * Repeat/JIP: Safe when called repeatedly or after ownership changes; only a locally stored CBE
 * restore record can be applied. A complete public pending fact may be adopted only on a real
 * vehicle Local edge through DrivingCapReleaseAdopt. Player, remote-controlled or specialist effective commanders
 * preserve their newer cap even when an ordinary AI driver belongs to another group.
 * A newer finite CBE movement lease also prevents restoration over its tactical speed policy.
 * Exact deferred reverse handback retains its original cap/restoration receipt rather than
 * restoring speed while the rear command is still owned. Original movement deadlines remain unchanged; a receipt-only cleanup service survives shutdown.
 * Arguments:
 * 0: vehicle <OBJECT> - ground vehicle to release.
 * 1: expected group <GROUP, grpNull> - group-scoped cleanup; grpNull permits subsystem shutdown.
 * Return Value: Nothing.
 * Current callers: CBE_fnc_DrivingAssistStart, CBE_fnc_CortexStop and
 * CBE_fnc_DrivingRecoveryCleanup (internal cap-only retry).
 * Example: [truck1] call CBE_fnc_DrivingAssistRelease;
 */

params [["_vehicle",objNull,[objNull]],["_expectedGroup",grpNull,[grpNull]],
    ["_capOnly",false,[true]],["_offered",[],[[]]]];
// Internal retry proof: state, baseline, original group/epoch/deadline and original seats.
// Unknown or superseded proof cannot borrow the current ordinary controller's receipts.
if (_capOnly && {count _offered != 9 || {!((_offered select 0) isEqualType [])}
    || {!((_offered select 1) isEqualType [])} || {!((_offered select 2) isEqualType grpNull)}
    || {!((_offered select 3) isEqualType 0)} || {!finite (_offered select 3)}
    || {!((_offered select 4) isEqualType 0)} || {!finite (_offered select 4)}
    || {!((_offered select 5) isEqualType objNull)} || {!((_offered select 6) isEqualType objNull)}
    || {[7,8] findIf {private _identity=_offered select _x;
        !(_identity isEqualType []) || {count _identity != 3}
            || {_identity findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} >= 0}} >= 0}}) exitWith {};
if (isNull _vehicle || {!local _vehicle}) exitWith {};
if (_capOnly && {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isNotEqualTo _offered
    || {(_offered select 2) != _expectedGroup} || {isNull _expectedGroup} || {!local _expectedGroup}
    || {(_offered select 8) isNotEqualTo [clientOwner,_expectedGroup getVariable ["CBE_AIPass_Epoch",0],
        _expectedGroup getVariable ["CBE_Driving_Generation",0]]}
    || {driver _vehicle != (_offered select 5)} || {effectiveCommander _vehicle != (_offered select 6)}
    || {group (driver _vehicle) != _expectedGroup} || {!local (driver _vehicle)}
    || {!isNull effectiveCommander _vehicle && {group (effectiveCommander _vehicle) != _expectedGroup
        || {!local (effectiveCommander _vehicle)}}}
    || {["CBE_DrivingRecovery_Work","CBE_DrivingPass_Work","CBE_DrivingCorridor_Work","CBE_DrivingBypass_Work"]
        findIf {count (_vehicle getVariable [_x,createHashMap]) > 0} >= 0}}) exitWith {
    if ((_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo _offered) then {
        _vehicle setVariable ["CBE_DrivingCapRelease_Result",["UNRESOLVED_HANDOVER",serverTime]];
    };
};
private _destinationReleaseAvailable={
    private _modeWork=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
    count _modeWork == 0 || {(_modeWork getOrDefault ["commandMode","DESTINATION"]) in ["DESTINATION","SIMPLE_BACK"]}
};
if !(call _destinationReleaseAvailable) exitWith {};
// Capture the cap lease before helper cleanup can yield. A same-group successor is still
// a different receipt and must survive this release callback.
private _releaseState=[];private _releaseRestore=[];private _releaseEpochGroup=grpNull;private _releaseEpoch=-1;
isNil {
    _releaseState=+(_vehicle getVariable ["CBE_DrivingAssist_State",[]]);
    _releaseRestore=+(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]);
    _releaseEpochGroup=_releaseState param [3,_expectedGroup];
    if (isNull _releaseEpochGroup) then {
        _releaseEpochGroup=(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) getOrDefault ["group",grpNull];
    };
    if (!isNull _releaseEpochGroup) then {_releaseEpoch=_releaseEpochGroup getVariable ["CBE_AIPass_Epoch",0]};
    if (_capOnly) then {
        _releaseState=+(_offered select 0);_releaseRestore=+(_offered select 1);
        _releaseEpochGroup=_offered select 2;_releaseEpoch=(_offered select 8) select 1;
    };
};
if (!_capOnly) then {
["CANCEL",_expectedGroup,_vehicle] call CBE_fnc_DrivingPassAdmission;
[_vehicle,_expectedGroup] call CBE_fnc_DrivingPassRetireInherited;
private _pass=_vehicle getVariable ["CBE_DrivingPass_Work",createHashMap];
if (count _pass > 0 && {isNull _expectedGroup || {(_pass get "group") == _expectedGroup}}) then {
    [_vehicle,_pass get "group","DRIVING_RELEASED",true] call CBE_fnc_DrivingPassFinish;
};
[_vehicle,_expectedGroup] call CBE_fnc_DrivingPassAgreementRelease;
private _recoveryPending=false;
private _recovery=_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap];
if (count _recovery > 0 && {isNull _expectedGroup || {(_recovery get "group") == _expectedGroup}}) then {
    isNil {
        if (local _vehicle && {_releaseState isEqualTo []}
            && {(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isEqualTo _releaseState}
            && {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isEqualTo _releaseRestore}
            && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _recovery}
            && {abs ((getForcedSpeed _vehicle)-(_recovery get "cap")) <= 0.1}) then {
            _releaseState=[_recovery get "cap",0,time,_recovery get "group"];
            _releaseRestore=+(_recovery get "baseline");
            _vehicle setVariable ["CBE_DrivingAssist_State",_releaseState];
            _vehicle setVariable ["CBE_DrivingAssist_Restore",_releaseRestore];
        };
    };
    private _retired=[_vehicle,_recovery get "group","DRIVING_RELEASED"] call CBE_fnc_DrivingRecoveryRelease;
    _recoveryPending=!_retired && {_recovery getOrDefault ["releasePending",false]}
        && {(_vehicle getVariable ["CBE_DrivingRecovery_Work",createHashMap]) isEqualTo _recovery};
};
// A failed exact handback is not a completed cap release. Retain the same baseline,
// owned cap and work proof for receipt-only cleanup observation; never recreate a rear leg.
if (_recoveryPending) exitWith {[_vehicle] call CBE_fnc_DrivingRecoveryCleanup};
[_vehicle,_expectedGroup,["ORDINARY"],true] call CBE_fnc_DrivingNativePathWatch;
private _corridor=_vehicle getVariable ["CBE_DrivingCorridor_Work",createHashMap];
private _corridorGroup=_corridor getOrDefault ["group",grpNull];
if (!isNull _corridorGroup && {isNull _expectedGroup || {_expectedGroup == _corridorGroup}}
    && {((_corridor getOrDefault ["controller",["ORDINARY",-1]]) param [0,""]) == "ORDINARY"}) then {
    [_vehicle,_corridorGroup,"DRIVING_RELEASED"] call CBE_fnc_DrivingCorridorRelease;
};
private _bypass=_vehicle getVariable ["CBE_DrivingBypass_Work",createHashMap];
private _bypassGroup=_bypass getOrDefault ["group",grpNull];
if (!isNull _bypassGroup && {isNull _expectedGroup || {_expectedGroup == _bypassGroup}}
    && {((_bypass getOrDefault ["controller",["ORDINARY",-1]]) param [0,""]) in ["ORDINARY","QUEUE"]}) then {
    [_vehicle,_bypassGroup,"DRIVING_RELEASED"] call CBE_fnc_DrivingBypassRelease;
};
};
private _capPending=false;
// Final cap restoration and receipt retirement are one transaction. Earlier helpers do not
// authorise deletion of a successor's state, even when its group and native cap are identical.
isNil {
if !(call _destinationReleaseAvailable) exitWith {false};
if (!local _vehicle
    || {(_vehicle getVariable ["CBE_DrivingAssist_State",[]]) isNotEqualTo _releaseState}
    || {(_vehicle getVariable ["CBE_DrivingAssist_Restore",[]]) isNotEqualTo _releaseRestore}
    || {!isNull _releaseEpochGroup && {_releaseEpoch != (_releaseEpochGroup getVariable ["CBE_AIPass_Epoch",0])}}) exitWith {
    if (_capOnly && {(_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]]) isEqualTo _offered}) then {
        _vehicle setVariable ["CBE_DrivingCapRelease_Work",nil,true];
        _vehicle setVariable ["CBE_DrivingCapRelease_Result",["SUPERSEDED",serverTime]];
    };
    false
};
private _restore=_vehicle getVariable ["CBE_DrivingAssist_Restore",[]];
private _state=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
if (!isNull _expectedGroup && {(_state param [3,grpNull]) != _expectedGroup}) exitWith {};
private _ownedCap=_state param [0,-1];
private _ownerGroup=_state param [3,grpNull];
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
private _commanderTaken=!isNull _commander && {
    isPlayer _commander || {!isNull remoteControlled _commander}
        || {!isNull (_commander getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
        || {[_commander] call CBE_fnc_CortexExternalOwner != ""}
        || {[_commander] call CBE_fnc_CompatibilityExternalControl}
};
private _externalControl=(!isNull _ownerGroup && {[_ownerGroup] call CBE_fnc_CortexExternalTakeover})
    || {!isNull _driver && {isPlayer _driver || {!isNull remoteControlled _driver}
        || {[_driver] call CBE_fnc_CortexExternalOwner != ""}}}
    || {_commanderTaken}
    || {!isNull _ownerGroup && {!([_ownerGroup] call CBE_fnc_DrivingMovementAvailable)}}
    || {_vehicle getVariable ["CBE_Convoy_Active",false]};
// A pending cap receipt is not retired merely because restoration is currently forbidden.
// Preserve the exact baseline while an unchanged cap is held by external authority. The
// observer stops this ticket as unresolved; this neither acknowledges provider quiescence
// nor grants another native write. Changed native caps still follow ordinary retirement.
if (_capOnly && {_externalControl || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}}
    && {abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1}) exitWith {
    _vehicle setVariable ["CBE_DrivingCapRelease_Result",["UNRESOLVED_HANDOVER",serverTime]];
};
// Restore only the cap that this driving lease still owns. If another controller changed it,
// clear our state and leave that newer value untouched.
if (_restore isNotEqualTo [] && {_ownedCap >= 0}
    && {!_externalControl}
    && {isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
    && {abs ((getForcedSpeed _vehicle)-_ownedCap) <= 0.1}) then {
    private _restoreValue=_restore param [0,-1,[0]];
    if (!finite _restoreValue || {_restoreValue < 0 && {_restoreValue != -1}}) exitWith {_capPending=true};
    if (!_capOnly || {serverTime < (_offered select 4)}) then {
        _vehicle forceSpeed (_restore param [0,-1]);
    };
    if (abs ((getForcedSpeed _vehicle)-_restoreValue) > 0.1) then {
        _capPending=true;
        private _pendingCap=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
        if (_pendingCap isEqualTo []) then {
            _pendingCap=[+_releaseState,+_releaseRestore,_ownerGroup,_releaseEpoch,
                serverTime+30,_driver,_commander,
                [clientOwner,_releaseEpoch,_ownerGroup getVariable ["CBE_Driving_Generation",0]],
                [clientOwner,_releaseEpoch,_ownerGroup getVariable ["CBE_Driving_Generation",0]]];
            _vehicle setVariable ["CBE_DrivingCapRelease_Work",_pendingCap,true];
        };
        private _capStatus=if (_pendingCap isEqualType [] && {count _pendingCap == 9}
            && {(_pendingCap select 4) isEqualType 0} && {finite (_pendingCap select 4)}
            && {serverTime >= (_pendingCap select 4)}) then {"UNRESOLVED_DEADLINE"} else {"PENDING"};
        _vehicle setVariable ["CBE_DrivingCapRelease_Result",[_capStatus,serverTime]];
    };
    // Release cleanup can observe an abort STOP only after this exact baseline was
    // actually restored. This receipt never authorizes another speed write.
    private _abort=_vehicle getVariable ["CBE_DrivingAbort_Hold",createHashMap];
    private _baseline=_restore param [0,-1];
    if (_abort isEqualType createHashMap && {count _abort > 0}
        && {(_abort getOrDefault ["group",grpNull]) == _ownerGroup}
        && {(_abort getOrDefault ["owner",[]]) isEqualTo ([_ownerGroup] call CBE_fnc_DrivingOwnerReceipt)}
        && {(_abort getOrDefault ["route",[]]) isEqualTo ([_ownerGroup] call CBE_fnc_DrivingRouteReceipt)}
        && {_baseline isEqualType 0} && {finite _baseline}
        && {abs ((getForcedSpeed _vehicle)-_baseline) <= 0.1}) then {
        _abort set ["releasedCap",_baseline];
        _vehicle setVariable ["CBE_DrivingAbort_Hold",_abort,true];
    };

};
if (_capPending) exitWith {};
_vehicle setVariable ["CBE_DrivingCapRelease_Work",nil,true];
_vehicle setVariable ["CBE_DrivingCapRelease_Result",["RETIRED",serverTime]];
_vehicle setVariable ["CBE_DrivingAssist_Restore",nil];
_vehicle setVariable ["CBE_DrivingAssist_Next",nil];
_vehicle setVariable ["CBE_DrivingTrafficSeen",nil];
_vehicle setVariable ["CBE_DrivingSolidSeen",nil];
_vehicle setVariable ["CBE_DrivingAssist_State",nil];
_vehicle setVariable ["CBE_DrivingAssist_Traffic",nil];

_vehicle setVariable ["CBE_DrivingAssist_Obstacle",nil];

};
// Register with the existing bounded observer after cap/receipt retirement.
[_vehicle] call CBE_fnc_DrivingRecoveryCleanup;
