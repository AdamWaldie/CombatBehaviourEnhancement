/*
 * Author: WaldoTheWarfighter
 * Purpose: Selects one stable observed crossing role for a two-vehicle queue pair.
 * Locality/authority: Read-only anywhere. This is a necessary role preflight, never
 * consent, right of way, physical reverse capability or authority over another vehicle.
 * Only the existing authenticated queue protocol can accept the selected roles.
 * Repeat/JIP: Stateless; current crew/input and distinct network identities are read
 * on every call. Ownership/native-order changes still revoke the containing episode.
 * Arguments: 0 vehicles <ARRAY of OBJECT, []>, exactly two distinct live LandVehicles.
 * Return: OBJECT crossing candidate, objNull if neither can take the reverse role or
 * network identity is unknown/ambiguous. A sole reverse-capable vehicle must yield;
 * otherwise the lexically first network identity crosses. No fairness guarantee.
 * Native BACK prerequisites here are distinct driver/operator and NONE turn only;
 * full owner/route/task/FSM admission remains in DrivingQueueProposalCurrent.
 * Cost: Two crew/input/identity observations, no search, ray, state, timer or commands.
 * Current callers: DrivingQueueProposal and DrivingQueueProposalCurrent.
 * Example: private _crossing=[[_first,_second]] call CBE_fnc_DrivingQueueCrossingVehicle;
 */
params [["_vehicles",[],[[]]]];
if (count _vehicles != 2 || {(_vehicles select 0) isEqualTo (_vehicles select 1)}
    || {_vehicles findIf {!(_x isEqualType objNull) || {isNull _x} || {!alive _x}
        || {!(_x isKindOf "LandVehicle")}} >= 0}) exitWith {objNull};
private _ids=_vehicles apply {netId _x};
if (_ids findIf {_x == ""} >= 0 || {(_ids select 0) == (_ids select 1)}) exitWith {objNull};
private _canReverse=_vehicles apply {
    private _driver=driver _x;private _operator=effectiveCommander _x;
    if (isNull _operator) then {_operator=_driver};
    !isNull _driver && {!isNull _operator} && {_driver != _operator}
        && {toUpperANSI ((vehicleMoveInfo _x) param [1,""]) == "NONE"}
};
if (!(_canReverse select 0) && {!(_canReverse select 1)}) exitWith {objNull};
if !(_canReverse select 0) exitWith {_vehicles select 0};
if !(_canReverse select 1) exitWith {_vehicles select 1};
private _ordered=+_ids;_ordered sort true;
_vehicles select (_ids find (_ordered select 0))
