/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes canonical crew/order/pose receipts for a proposed2..4-vehicle queue roster.
 * Locality/authority: Read-only anywhere. Observer clientOwner is deliberately absent; each
 * actual owner must later authenticate its own rows. This is not consent or movement authority.
 * Repeat/JIP: Stateless snapshot, no commands/handlers/state or replay; old receipts grant nothing.
 * Arguments:0 vehicles <ARRAY of OBJECT>,[], ordered distinct live LandVehicles with native crews.
 * Return: ARRAY participant rows or[] invalid. Row=[vehicle,owner,driverReceipt,operatorReceipt,pose,nativeMoveTurn].
 * Native move/turn is captured for actual-owner deferred validation, never remote ownership proof.
 * Remote group epoch/generation comes from owner-stamped driving status, never this
 * observer's private epoch. Missing identity refuses the whole context until publication.
 * Destination slot is deliberately empty in shared observations; actual-owner consent
 * captures private ownerOrders before ACK. Remote observations grant no native-task proof.
 * Actor receipt=[actor,owner,group,groupOwner,epoch,public driving generation,player,remote,
 * native command,empty destination slot,route identity].
 * Native identity=[NATIVE_MOVE,group,platform,driver,operator,owner,epoch,generation].
 * It is observational only: native queue admission/crossing remains disabled. Pose=[world position,direction,up].
 * Current callers: DrivingQueueProposal and DrivingQueueProposalCurrent.
 * Example: private _rows=[[_front,_yielding,_rear]] call CBE_fnc_DrivingQueueContext;
 */
params [["_vehicles",[],[[]]]];
if (count _vehicles < 2 || {count _vehicles > 4}
    || {count (_vehicles arrayIntersect _vehicles) != count _vehicles}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}
        || {!(_x isKindOf "LandVehicle")} || {isNull driver _x}} >= 0}) exitWith {[]};
private _receiptsReady=true;
private _actorReceipt={
    params ["_actor"];
    if (isNull _actor) exitWith {[]};
    private _group=group _actor;
    private _identity=[_group] call CBE_fnc_DrivingOwnerReceipt;
    if (_identity isEqualTo []) exitWith {_receiptsReady=false;[]};
    private _index=currentWaypoint _group;
    private _route=if (_index <= 0 || {_index >= count waypoints _group}) then {
        // Shared native identity carries no observer-native destination. The actual
        // owner must separately bind its full route and commands before consent.
        private _platform=vehicle _actor;
        private _operator=effectiveCommander _platform;
        if (isNull _operator) then {_operator=driver _platform};
        ["NATIVE_MOVE",_group,_platform,driver _platform,_operator,
            _identity select 0,_identity select 1,_identity select 2]
    } else {[_group] call CBE_fnc_DrivingRouteReceipt};
    [_actor,owner _actor,_group,_identity select 0,_identity select 1,
        _identity select 2,isPlayer _actor,
        remoteControlled _actor,currentCommand _actor,[],
        _route]
};
private _rows=_vehicles apply {
    private _operator=effectiveCommander _x;if (isNull _operator) then {_operator=driver _x};
    [_x,owner _x,[driver _x] call _actorReceipt,[_operator] call _actorReceipt,
        [getPosWorld _x,vectorDir _x,vectorUp _x],+(vehicleMoveInfo _x)]
};
if (!_receiptsReady) exitWith {[]};
_rows
