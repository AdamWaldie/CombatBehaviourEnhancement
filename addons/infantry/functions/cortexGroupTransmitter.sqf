/*
 * Author: WaldoTheWarfighter
 * Finds one combat-effective group member that can pass a report or support request, preferring the leader while
 * allowing an observing wingman to maintain communication when the leader is unavailable or jammed.
 * Locality/authority: read-only; callable on any machine. At most twelve eligible actors
 * reach the transmission hook. The roster walk stops on success or that limit, but may
 * inspect the full roster when fewer actors qualify. It performs no
 * reveal, target sharing, movement, inventory mutation or network call.
 * Repeat/JIP: recomputes current eligibility on every call and publishes no state.
 * Arguments: 0: group <GROUP>.
 * Return Value: communicating member <OBJECT>, objNull when no eligible member can transmit.
 * Current callers: support, reinforcement, artillery, report and combined-arms coordination.
 * Example: private _radio = [group _unit] call CBE_fnc_CortexGroupTransmitter;
 */
params [["_group", grpNull, [grpNull]]];
if (isNull _group) exitWith {objNull};
private _leader = leader _group;
private _leaderEligible=!isNull _leader && {group _leader == _group}
    && {!isPlayer _leader} && {[_leader] call CBE_fnc_CortexCombatEffective};
// Most calls finish here without constructing or filtering the group's roster.
if (_leaderEligible && {[_leader] call CBE_fnc_CortexCanTransmit}) exitWith {_leader};
private _checked=if (_leaderEligible) then {1} else {0};
private _transmitter = objNull;
{
    if (_checked >= 12) exitWith {};
    if (_x != _leader && {!isPlayer _x} && {[_x] call CBE_fnc_CortexCombatEffective}) then {
        _checked=_checked+1;
        if ([_x] call CBE_fnc_CortexCanTransmit) then {_transmitter = _x};
    };
    if (!isNull _transmitter) exitWith {};
} forEach (units _group);
_transmitter
