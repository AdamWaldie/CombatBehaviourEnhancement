/*
 * Author: WaldoTheWarfighter
 * Purpose: Observes canonical crew/order/pose receipts for a proposed2..4-vehicle queue roster.
 * Locality/authority: Read-only anywhere. Observer clientOwner is deliberately absent; each
 * actual owner must later authenticate its own rows. This is not consent or movement authority.
 * Repeat/JIP: Stateless snapshot, no commands/handlers/state or replay; old receipts grant nothing.
 * Arguments:0 vehicles <ARRAY of OBJECT>,[], ordered distinct live LandVehicles with native crews.
 * Return: ARRAY participant rows or[] invalid. Row=[vehicle,owner,driverReceipt,operatorReceipt,pose,nativeMoveTurn].
 * Native move/turn is captured for actual-owner deferred validation, never remote ownership proof.
 * Actor receipt=[actor,owner,group,groupOwner,epoch,public driving generation,player,remote,
 * native command,expectedDestination,authored route]. Pose=[world position,direction,up].
 * Current callers: DrivingQueueProposal and DrivingQueueProposalCurrent.
 * Example: private _rows=[[_front,_yielding,_rear]] call CBE_fnc_DrivingQueueContext;
 */
params [["_vehicles",[],[[]]]];
if (count _vehicles < 2 || {count _vehicles > 4}
    || {count (_vehicles arrayIntersect _vehicles) != count _vehicles}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}
        || {!(_x isKindOf "LandVehicle")} || {isNull driver _x}} >= 0}) exitWith {[]};
private _actorReceipt={
    params ["_actor"];
    if (isNull _actor) exitWith {[]};
    private _group=group _actor;
    [_actor,owner _actor,_group,groupOwner _group,_group getVariable ["CBE_AIPass_Epoch",0],
        (_group getVariable ["CBE_Driving_State",[]]) param [1,-1],isPlayer _actor,
        remoteControlled _actor,currentCommand _actor,+(expectedDestination _actor),
        [_group] call CBE_fnc_DrivingRouteReceipt]
};
_vehicles apply {
    private _operator=effectiveCommander _x;if (isNull _operator) then {_operator=driver _x};
    [_x,owner _x,[driver _x] call _actorReceipt,[_operator] call _actorReceipt,
        [getPosWorld _x,vectorDir _x,vectorUp _x],+(vehicleMoveInfo _x)]
}
