/*
 * Author: WaldoTheWarfighter
 * Purpose: Adopts only a complete pending ordinary speed-cap release on an actual vehicle Local edge.
 * Locality/authority: Internal local calls only; actual vehicle, original group and seats must be local.
 * The edge opens five seconds for late receipt/group delivery. Init/crew calls cannot create it.
 * Repeat/JIP: Metadata only, no tactical startup or native command. Reuses the immutable original
 * release deadline and baseline; incompatible private state or newer child work refuses adoption.
 * Loss/gain events can arrive in either order across machines: source creation must fit the
 * original five-second edge window, rather than assuming the source event arrived first.
 * An already-present original baseline permits metadata-only retirement even when the old
 * applied cap no longer exists on this owner. A third native value still refuses adoption.
 * No general cruising-cap migration or external-provider quiescence is established here.
 * Arguments: 0 vehicle <OBJECT, objNull>.
 * Return: BOOL - complete metadata adopted/matched, never proof of physical restoration.
 * Current callers: DrivingRecoveryAdopt at the existing bounded locality lookup.
 * Example: private _offered=[truck1] call CBE_fnc_DrivingCapReleaseAdopt;
 */
params [["_vehicle",objNull,[objNull]]];
if (remoteExecutedOwner > 0 || {isNull _vehicle} || {!local _vehicle}) exitWith {false};
private _accepted=false;
isNil {
    private _edge=_vehicle getVariable ["CBE_DrivingCap_LocalEdge",[]];
    private _fact=_vehicle getVariable ["CBE_DrivingCapRelease_Work",[]];
    if (!(_edge isEqualType []) || {count _edge != 3}
        || {!((_edge select 0) isEqualType grpNull)}
        || {[1,2] findIf {!((_edge select _x) isEqualType 0) || {!finite (_edge select _x)}} >= 0}
        || {serverTime < (_edge select 1)} || {serverTime >= (_edge select 2)}
        || {!(_fact isEqualType [])} || {count _fact != 9}) exitWith {};
    _fact params ["_originalState","_originalRestore","_originalGroup","_issuingEpoch",
        "_originalDeadline","_originalDriver","_originalCommander","_issuer","_custodian"];
    private _identityValid={
        params ["_identity"];
        _identity isEqualType [] && {count _identity == 3}
            && {_identity findIf {!(_x isEqualType 0) || {!finite _x} || {_x < 0} || {_x != floor _x}} < 0}
    };
    if (!(_originalState isEqualType []) || {!(count _originalState in [4,11,12])}
        || {!(_originalRestore isEqualType [])} || {count _originalRestore != 1}
        || {!(_originalGroup isEqualType grpNull)} || {isNull _originalGroup} || {!local _originalGroup}
        || {!(_issuingEpoch isEqualType 0)} || {!finite _issuingEpoch}
        || {!(_originalDeadline isEqualType 0)} || {!finite _originalDeadline}
        || {serverTime >= _originalDeadline} || {_originalDeadline > (_edge select 2)+30}
        || {!(_originalDriver isEqualType objNull)} || {!(_originalCommander isEqualType objNull)}
        || {!([_issuer] call _identityValid)} || {!([_custodian] call _identityValid)}
        || {_issuingEpoch != (_issuer select 1)}
        || {(_originalState select 3) isNotEqualTo _originalGroup}
        || {!((_originalState select 0) isEqualType 0)} || {!finite (_originalState select 0)}
        || {(_originalState select 0) < 0}
        || {!((_originalRestore select 0) isEqualType 0)} || {!finite (_originalRestore select 0)}
        || {(_originalRestore select 0) < 0 && {(_originalRestore select 0) != -1}}) exitWith {};
    if (!isNull (_edge select 0) && {(_edge select 0) != _originalGroup}) exitWith {};
    private _incomingCap=getForcedSpeed _vehicle;
    private _inheritedCap=abs (_incomingCap-(_originalState select 0)) <= 0.1;
    private _baselinePresent=abs (_incomingCap-(_originalRestore select 0)) <= 0.1;
    if (!alive _vehicle || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
        || {driver _vehicle != _originalDriver} || {effectiveCommander _vehicle != _originalCommander}
        || {isNull _originalDriver} || {[_originalDriver,_originalCommander] findIf {
            !isNull _x && {!local _x || {group _x != _originalGroup} || {isPlayer _x}
                || {!isNull remoteControlled _x}
                || {!isNull (_x getVariable ["bis_fnc_moduleRemoteControl_owner",objNull])}
                || {[_x] call CBE_fnc_CortexExternalOwner != ""}
                || {[_x] call CBE_fnc_CompatibilityExternalControl}}
        } >= 0}
        || {[_originalGroup] call CBE_fnc_CortexZeusHeld}
        || {[_originalGroup] call CBE_fnc_CortexExternalTakeover}
        || {!([_originalGroup] call CBE_fnc_DrivingMovementAvailable)}
        || {_vehicle getVariable ["CBE_Convoy_Active",false]}
        || {!isNil {_vehicle getVariable "CBE_ExternalDrivingOwner"}}
        || {!finite _incomingCap} || {!_inheritedCap && {!_baselinePresent}}
        || {["CBE_DrivingRecovery_Work","CBE_DrivingPass_Work","CBE_DrivingCorridor_Work","CBE_DrivingBypass_Work"]
            findIf {count (_vehicle getVariable [_x,createHashMap]) > 0} >= 0}) exitWith {};
    private _privateState=_vehicle getVariable ["CBE_DrivingAssist_State",[]];
    private _privateRestore=_vehicle getVariable ["CBE_DrivingAssist_Restore",[]];
    if (_privateState isNotEqualTo [] && {_privateState isNotEqualTo _originalState}
        || {_privateRestore isNotEqualTo [] && {_privateRestore isNotEqualTo _originalRestore}}) exitWith {};
    private _currentIdentity=[clientOwner,_originalGroup getVariable ["CBE_AIPass_Epoch",0],
        _originalGroup getVariable ["CBE_Driving_Generation",0]];
    if (!([_currentIdentity] call _identityValid) || {groupOwner _originalGroup != clientOwner}) exitWith {};
    // Only this custody field changes. Original issuer, seats, baseline and deadline survive.
    // These are historical receipts, not permission to recreate the old cap. The existing
    // release executor rereads native state and can retire an already-present baseline.
    private _adopted=+_fact;
    _adopted set [8,_currentIdentity];
    _vehicle setVariable ["CBE_DrivingAssist_State",+_originalState];
    _vehicle setVariable ["CBE_DrivingAssist_Restore",+_originalRestore];
    _vehicle setVariable ["CBE_DrivingCap_Issuer",[+_currentIdentity,_originalDriver,_originalCommander]];
    _vehicle setVariable ["CBE_DrivingCapRelease_Work",_adopted,true];
    _vehicle setVariable ["CBE_DrivingCapRelease_Result",["ADOPTED",serverTime]];
    _accepted=true;
};
_accepted
