/*
 * Author: WaldoTheWarfighter
 * Purpose: Reads the crew, locality and native-order identity of two road-pass participants.
 * Locality/authority: Read-only anywhere; this receipt is an observation, never owner agreement.
 * Repeat/JIP: No state, commands or handlers. Re-read before consuming deferred scan evidence.
 * Arguments: 0 vehicles <ARRAY of OBJECT>, [], exactly two distinct live LandVehicles.
 * Return: ARRAY [observing client owner, participant rows], [] for invalid participants.
 * Each row is [vehicle, vehicle owner, driver receipt, effective-commander receipt]. An actor
 * receipt includes actor/owner, group/owner/epoch, player/remote control, native command and
 * expected destination, full authored route receipt, then ordinary driving generation.
 * Local groups use private owner epoch/generation; remote observations require owner-stamped
 * published identity. Unknown owner identity returns[] for the whole context. Owner
 * verification still compares the full row and actual live controller before consent.
 * Actor receipts have11 fields; missing crew use an empty row. Old schemas grant no consent.
 * Current callers: DrivingPassPlan, DrivingPassGeometry, DrivingPassTraffic, DrivingPassPrepare,
 * DrivingPassAgreementServer and DrivingPassAgreementOwner.
 * Example: private _receipt=[[truck1,truck2]] call CBE_fnc_DrivingPassContext;
 */
params [["_vehicles",[],[[]]]];
if (count _vehicles != 2 || {(_vehicles select 0) isEqualTo (_vehicles select 1)}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}
        || {!(_x isKindOf "LandVehicle")}} >= 0}) exitWith {[]};
private _receiptsReady=true;
private _actorReceipt={
    params ["_actor"];
    if (isNull _actor) exitWith {[]};
    private _group=group _actor;
    private _identity=[_group] call CBE_fnc_DrivingOwnerReceipt;
    if (_identity isEqualTo []) exitWith {_receiptsReady=false;[]};
    [_actor,owner _actor,_group,_identity select 0,_identity select 1,
        isPlayer _actor,remoteControlled _actor,currentCommand _actor,+(expectedDestination _actor),
        [_group] call CBE_fnc_NativeOrderReceipt,_identity select 2]
};
private _rows=_vehicles apply {
    private _operator=effectiveCommander _x;
    if (isNull _operator) then {_operator=driver _x};
    [_x,owner _x,[driver _x] call _actorReceipt,[_operator] call _actorReceipt]
};
if (!_receiptsReady) exitWith {[]};
[clientOwner,_rows]
