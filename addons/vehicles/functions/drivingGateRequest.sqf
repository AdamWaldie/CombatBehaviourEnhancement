/*
 * Author: WaldoTheWarfighter
 * Purpose: Forward a nearby gate observation to server authority under the current driving route.
 * Locality/authority: Current group/vehicle/driver owner only; non-server network calls are refused.
 * Server independently validates every authority, source, transform, lock and geometry condition.
 * Repeat/JIP: One initial request and at most one delivery retry per gate/route/passage context.
 * Only matching server-observed completed closure can admit another opening cycle.
 * A matching LOCKED refusal may start one separately bounded retry after BIS locks clear;
 * the server independently admits it once against the original refusal receipt.
 * Public pending context preserves the delivery count/deadline across owner migration;
 * a matching server acknowledgement suppresses later requests. Pending state grants no authority.
 * No JIP command replay or asynchronous callback; native animation state is separate.
 * Ordinary route intent is rechecked before delivery; convoy acquired STOP retains its own contract.
 * Opening receipt is diagnostic only. Existing geometry cap owns approach/wait and never times out
 * into clearance. Server retains a finite per-route attempt budget across owner migration.
 * Arguments: 0 group <GROUP, grpNull>; 1 vehicle <OBJECT, objNull>; 2 observation <ARRAY, []>
 * from DrivingGateCap; 3 convoy revision <NUMBER, -1> (-1 ordinary driving); 4 direction NUMBER1, +1/-1 (reverse ordinary only).
 * Return Value: BOOL - request sent, not opening, passability or physical passage confirmation.
 * Current callers: DrivingAssistStart and ConvoyTick after their live command-authority checks.
 * Example: [_group,_vehicle,_gateObservation] call CBE_fnc_DrivingGateRequest;
 */
params [["_group",grpNull,[grpNull]],["_vehicle",objNull,[objNull]],["_observation",[],[[]]],["_revision",-1,[0]],["_travelDirection",1,[0]]];
if (remoteExecutedOwner > 0 && {remoteExecutedOwner != 2}) exitWith {false};
// Reject malformed/nonfinite observations before comparisons, object reads or public writes.
if (count _observation != 5 || {!((_observation select 1) isEqualType objNull)}
    || {[0,2,3,4] findIf {!((_observation select _x) isEqualType 0) || {!finite (_observation select _x)}} >= 0}
    || {!(_travelDirection in [-1,1])} || {_travelDirection == -1 && {_revision >= 0}}
    || {!finite _revision} || {_revision < -1} || {_revision != floor _revision}) exitWith {false};
if (isNull _group || {isNull _vehicle} || {!local _group} || {!local _vehicle}
    || {isNull driver _vehicle} || {!local driver _vehicle} || {group driver _vehicle != _group}
    || {count _observation != 5} || {isNull (_observation select 1)}
    || {(_observation select 2) < 0} || {(_observation select 2) > 12}
    || {!simulationEnabled _vehicle} || {isObjectHidden _vehicle}
    || {!simulationEnabled driver _vehicle} || {isObjectHidden driver _vehicle}
    || {abs speed _vehicle > 8} || {[_group] call CBE_fnc_CortexExternalTakeover}) exitWith {false};
private _route=[_group] call CBE_fnc_DrivingRouteReceipt;
if (_route isEqualTo [] || {_revision < 0 && {!([_group,_vehicle,_route] call CBE_fnc_DrivingGateIntent)}}) exitWith {false};
if (_travelDirection == -1 && {([_group,_vehicle,_route,_revision,[],[],_travelDirection] call CBE_fnc_DrivingGateOwnerCheck) isEqualTo []}) exitWith {false};
private _gate=_observation select 1;
private _driver=driver _vehicle;
private _commander=effectiveCommander _vehicle;
if (isNull _commander) then {_commander=_driver};
private _transform=[getPosWorld _gate,vectorDir _gate,vectorUp _gate];
private _context=[_group,+_route,_revision,_gate,+_transform];
private _ack=_vehicle getVariable ["CBE_DrivingGate_Result",[]];
private _ackCurrent=count _ack in [7,8] && {(_ack select 0) == _gate} && {(_ack select 3) == _group}
    && {(_ack select 4) isEqualTo _route} && {(_ack select 5) == _revision}
    && {(_ack select 6) isEqualTo _transform};
// A physically observed completed closure starts a new passage opportunity. This
// public hint only separates delivery contexts; the server validates private proof.
private _closedCycle=_gate getVariable ["CBE_DrivingGate_ClosedCycle",[]];
private _cycleCurrent=count _closedCycle == 3 && {(_closedCycle select 0) isEqualTo _transform}
    && {(_closedCycle select 1) isEqualType 0} && {finite (_closedCycle select 1)} && {(_closedCycle select 1) > 0};
if (_cycleCurrent) then {_context pushBack ["PASSAGE_RETRY",_closedCycle select 1]};
if (_ackCurrent && {_cycleCurrent}
    && {(_ack select 1) in ["OPEN_REQUESTED","SHARED_OPENING","OPEN_WINDOW_EXPIRED","ALREADY_OPEN_OR_MOVING"]}
    && {(_closedCycle select 1) > (_ack param [7,0,[0]])}) then {_ackCurrent=false};
private _unlockReceipt=-1;
if (_ackCurrent && {(_ack select 1) == "LOCKED"}) then {
    private _unlocked=(_gate getVariable ["bis_disabled_Door",0]) isEqualTo 0;
    for "_index" from 1 to 8 do {
        if ((_gate getVariable [format ["bis_disabled_Door_%1",_index],0]) isNotEqualTo 0) exitWith {_unlocked=false};
    };
    if (_unlocked) then {
        _unlockReceipt=_ack select 2;
        _context pushBack ["UNLOCK_RETRY",_unlockReceipt];
    };
};
if (_ackCurrent && {_unlockReceipt < 0}) exitWith {
    private _reason=_ack select 1;
    if (_reason in ["OPEN_REQUESTED","SHARED_OPENING"] && {serverTime >= (_ack select 2)}) then {_reason="OPEN_WINDOW_EXPIRED"};
    _vehicle setVariable ["CBE_DrivingGate_RequestState",[_context,_reason,_ack select 2]];
    false
};
private _pending=_vehicle getVariable ["CBE_DrivingGate_Pending",[]];
private _same=count _pending == 3 && {(_pending select 0) isEqualTo _context};
private _attempts=if (_same) then {_pending select 2} else {0};
if (_same && {serverTime < (_pending select 1)}) exitWith {false};
if (_attempts >= 2) exitWith {
    _vehicle setVariable ["CBE_DrivingGate_RequestState",[_context,"REQUEST_TIMEOUT",_pending select 1]];
    false
};
// The current seats bind this request too; a queued request cannot borrow a successor driver.
private _payload=[["group",_group],["vehicle",_vehicle],["gate",_gate],["route",_route],
    ["transform",_transform],["driver",_driver],["commander",_commander],
    ["convoyRevision",_revision],["expires",serverTime+5],["unlockReceipt",_unlockReceipt],["travelDirection",_travelDirection]];
_vehicle setVariable ["CBE_DrivingGate_Pending",[_context,serverTime+5,_attempts+1],true];
_vehicle setVariable ["CBE_DrivingGate_RequestState",[_context,"AWAITING_SERVER",serverTime+5]];
if (isServer) then {[_payload] call CBE_fnc_DrivingGateOpenServer}
else {[_payload] remoteExecCall ["CBE_fnc_DrivingGateOpenServer",2]};
true
