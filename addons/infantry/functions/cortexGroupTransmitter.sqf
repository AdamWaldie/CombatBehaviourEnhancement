/*
 * Author: WaldoTheWarfighter
 * Finds one combat-effective group member for radio transmission or an explicit nearby voice witness, preferring the leader while
 * allowing an observing wingman to maintain communication when the leader is unavailable or jammed.
 * Locality/authority: read-only; callable on any machine. At most twelve eligible actors
 * reach the transmission hook in radio mode. Explicit voice mode skips only that jamming
 * hook; both modes retain combat readiness, player exclusion, leader priority and the same
 * roster limit. A voice result is not radio permission. The roster walk stops on success or that limit, but may
 * inspect the full roster when fewer actors qualify. It performs no
 * reveal, target sharing, movement, inventory mutation or network call.
 * Repeat/JIP: recomputes current eligibility on every call and publishes no state.
 * Arguments: 0 group <GROUP>; 1 require radio transmission hook <BOOL,true>.
 * Internal report/combined callers use false only to locate a voice witness after radio fails;
 * the caller must still enforce actual3D voice reach and separate default-mode radio results.
 * Return Value: communicating member <OBJECT>, objNull when no eligible member can transmit.
 * Current callers: support, reinforcement, artillery, report and combined-arms coordination.
 * Example: private _radio = [group _unit] call CBE_fnc_CortexGroupTransmitter;
 */
params [["_group", grpNull, [grpNull]],["_requireRadio",true,[true]]];
if (isNull _group) exitWith {objNull};
private _leader = leader _group;
private _leaderEligible=!isNull _leader && {group _leader == _group}
    && {!isPlayer _leader} && {[_leader] call CBE_fnc_CortexCombatEffective};
// Most calls finish here without constructing or filtering the group's roster.
if (_leaderEligible && {!_requireRadio || {[_leader] call CBE_fnc_CortexCanTransmit}}) exitWith {_leader};
private _checked=if (_leaderEligible) then {1} else {0};
private _transmitter = objNull;
{
    if (_checked >= 12) exitWith {};
    if (_x != _leader && {!isPlayer _x} && {[_x] call CBE_fnc_CortexCombatEffective}) then {
        _checked=_checked+1;
        if (!_requireRadio || {[_x] call CBE_fnc_CortexCanTransmit}) then {_transmitter = _x};
    };
    if (!isNull _transmitter) exitWith {};
} forEach (units _group);
_transmitter
